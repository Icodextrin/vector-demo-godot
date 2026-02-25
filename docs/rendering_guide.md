# Vector Beam Rendering Project Guide

This document is the technical reference for the vector-beam rendering framework in this repository.

## 1) Scope

The project implements a reusable 2D vector rendering stack for Godot 4.x with:
- Line-based geometry (polyline rendering)
- Beam core + halo layering
- Vertex dwell dots
- Phosphor-like persistence trails
- Per-style persistence control (`decay_alpha`)

Primary implementation files:
- `res://scripts/vector_renderer.gd`
- `res://scripts/vector_entity.gd`
- `res://scripts/vector_style.gd`
- `res://scripts/vector_shape.gd`

Demo scenes:
- `res://scenes/main.tscn` (bouncing circle)
- `res://scenes/player_ship_walls_demo.tscn` (player ship + static walls)

## 2) Architecture Overview

The framework separates simulation from rendering:

1. `VectorEntity` subclasses simulate gameplay.
2. Each entity submits draw commands every frame to `VectorRenderer`.
3. `VectorRenderer` stores per-command trail history, applies decay, then draws all layers.

This decoupling keeps gameplay logic clean and centralizes rendering behavior/performance tuning.

## 3) Rendering Pipeline

Per frame, `VectorRenderer` performs:

1. Decay existing trail energy for each command key.
2. Ingest new frame commands from entities.
   - Near-duplicate samples are merged using `min_sample_motion` instead of always appending.
3. Remove dead samples (energy threshold).
4. Clear to black.
5. Draw each layer in ascending order.
6. For each sample:
   - Optionally apply age-based ghost jitter offset.
   - Draw softened outer halo (`_draw_outer_halo`).
   - Draw optional age-based ghost blur passes.
   - Draw inner core polyline.
   - Draw optional vertex dots with corner dwell and retrace dimming factors.

Persistence model:
- Each submitted command updates trail state when `trail_enabled = true`.
- If the new sample is near the latest sample (by `min_sample_motion`), the latest sample is refreshed instead of appending.
- Sample energies are multiplied by a frame decay factor.
- Decay uses per-command/per-style `decay_alpha` with renderer fallback.

## 4) Custom Resources

### 4.1 `VectorStyle` (`res://scripts/vector_style.gd`)

Defines beam appearance and persistence behavior.

Exports:
- `beam_width_outer: float`
- `beam_width_inner: float`
- `vertex_dot_radius: float`
- `decay_alpha: float` (`0.0..1.0`)
- `beam_color_outer: Color`
- `beam_color_inner: Color`
- `vertex_dot_color: Color`

Notes:
- Use HDR-friendly values (`> 1.0` RGB) for stronger glow.
- `decay_alpha` controls trail fade speed per style.

### 4.2 `VectorShape` (`res://scripts/vector_shape.gd`)

Defines local-space geometry for an entity.

Exports:
- `points_local: PackedVector2Array`
- `closed: bool`
- `draw_vertex_dots: bool`

Notes:
- `points_local` are transformed to world space by `VectorEntity`.
- Closed shapes automatically connect last point to first during rendering.

### 4.3 Style Resources

Current resources:
- `res://styles/default_vector_style.tres`
- `res://styles/player_vector_style.tres`
- `res://styles/wall_vector_style.tres`

Current persistence values:
- Default: `decay_alpha = 0.03`
- Player: `decay_alpha = 0.02` (longer trails)
- Wall: `decay_alpha = 0.08` (faster fade; walls also disable trails in demo)

### 4.4 `VectorRendererPreset` (`res://scripts/vector_renderer_preset.gd`)

Defines reusable renderer-level tuning bundles (trail, blur, jitter, dwell, retrace, decay).

Notable field groups:
- Trail sampling/decay: `decay_alpha`, `default_max_trail_samples`, `default_min_sample_motion`, `two_stage_decay_*`
- Halo shaping: `outer_soft_blur_*`, `ghost_blur_*`
- Jitter behavior: `ghost_jitter_*` (including `ghost_jitter_motion_response` and `ghost_jitter_max_rise_per_sample` for movement-start smoothing)
- Beam character: `corner_dwell_*`, `retrace_*`

Built-in preset resources:
- `res://presets/vector_renderer/clean_vector.tres`
- `res://presets/vector_renderer/medium_vector.tres`
- `res://presets/vector_renderer/oscilloscope.tres`
- `res://presets/vector_renderer/blown_out_oscilloscope.tres`

Usage:
- Assign a preset to `VectorRenderer.renderer_preset`.
- `VectorRenderer` uses preset values as its runtime source of truth.
- Tuning should be done in the preset resource, not directly on `VectorRenderer`.

### 4.5 Recommended Preset Ranges (Quick Tuning)

| Setting | Typical range | Lower values tend to... | Higher values tend to... |
| --- | --- | --- | --- |
| `decay_alpha` | `0.01` to `0.08` | Keep trails longer | Fade trails faster |
| `default_max_trail_samples` | `120` to `360` | Reduce ghost history length | Increase ghost history length/cost |
| `default_min_sample_motion` | `0.003` to `0.06` | Keep more subtle sub-frame motion | Suppress grouped duplicate ghosts |
| `outer_soft_blur_passes` | `2` to `6` | Keep halo tighter/cleaner | Increase halo softness and fill |
| `outer_soft_blur_width_step` | `0.3` to `1.2` | Keep glow close to line | Push glow farther from line |
| `outer_soft_blur_alpha_scale` | `0.08` to `0.50` | Reduce outer haze | Increase bloom/halo density |
| `ghost_blur_width_scale` | `1.5` to `5.2` | Keep ghosts crisp | Smear older ghosts wider |
| `ghost_blur_alpha_scale` | `0.06` to `0.45` | Make tails cleaner/fainter | Make tails thicker/brighter |
| `ghost_jitter_pixels` | `0.0` to `2.0` | Keep ghosts stable | Add analog wobble |
| `ghost_jitter_motion_response` | `0.12` to `0.30` | Smooth response to motion changes | React to movement changes faster |
| `ghost_jitter_max_rise_per_sample` | `0.05` to `0.16` | Reduce startup jitter spikes | Allow faster jitter ramp-up |
| `retrace_dimming_strength` | `0.01` to `0.05` | Keep long segments brighter | Dim long retrace segments more |

### 4.6 Built-in Preset Value Matrix

These are the current shipped values in `res://presets/vector_renderer/*.tres`.

| Setting | Clean | Medium | Oscilloscope | Blown-out Oscilloscope |
| --- | ---: | ---: | ---: | ---: |
| `decay_alpha` | `0.08` | `0.03` | `0.02` | `0.012` |
| `default_max_trail_samples` | `120` | `180` | `240` | `360` |
| `default_min_sample_motion` | `0.05` | `0.01` | `0.006` | `0.003` |
| `outer_soft_blur_passes` | `2` | `4` | `4` | `6` |
| `outer_soft_blur_width_step` | `0.35` | `0.65` | `0.9` | `1.2` |
| `outer_soft_blur_alpha_scale` | `0.08` | `0.28` | `0.32` | `0.5` |
| `ghost_blur_width_scale` | `1.55` | `2.8` | `3.7` | `5.2` |
| `ghost_blur_alpha_scale` | `0.06` | `0.20` | `0.28` | `0.45` |
| `ghost_jitter_pixels` | `0.15` | `0.8` | `1.2` | `2.0` |
| `ghost_jitter_stationary_scale` | `0.0` | `0.12` | `0.16` | `0.2` |
| `ghost_jitter_moving_scale` | `0.2` | `1.25` | `1.5` | `2.0` |
| `ghost_jitter_motion_min` | `2.0` | `2.0` | `1.5` | `1.0` |
| `ghost_jitter_motion_max` | `16.0` | `18.0` | `14.0` | `10.0` |
| `ghost_jitter_motion_response` | `0.12` | `0.18` | `0.24` | `0.3` |
| `ghost_jitter_max_rise_per_sample` | `0.05` | `0.08` | `0.12` | `0.16` |
| `retrace_dimming_strength` | `0.015` | `0.03` | `0.045` | `0.02` |

## 5) Command Contract (`VectorEntity -> VectorRenderer`)

Each command is a `Dictionary` with required and optional fields.

Required:
- `key: String`
- `points: PackedVector2Array` (minimum 2 points)

Optional:
- `style: VectorStyle`
- `intensity: float` (default `1.0`)
- `layer: int` (default `0`)
- `closed: bool` (default `false`)
- `draw_vertex_dots: bool` (default `true`)
- `trail_enabled: bool` (default `true`)
- `max_trail_samples: int` (defaults to renderer preset value)
- `decay_alpha: float` (per-command override; otherwise style or renderer fallback)
- `min_sample_motion: float` (override dedup motion threshold for this command)

Identity rule:
- `key` should be stable across frames for the same visual primitive.
- Changing keys every frame prevents persistence from accumulating.

## 6) Script API Reference

### 6.1 `VectorRenderer` (`res://scripts/vector_renderer.gd`)

Public/exported fields:
- `default_style`
- `renderer_preset`

Renderer tuning fields are intentionally not exported on `VectorRenderer` to avoid duplicate UI.
They are configured via `VectorRendererPreset` resources.

Public method:
- `submit_command(command: Dictionary) -> void`
  - Queues a draw command for ingestion.
- `apply_preset(preset: VectorRendererPreset) -> void`
  - Applies a preset programmatically at runtime.
- `snapshot_preset() -> VectorRendererPreset`
  - Returns a preset resource snapshot from current renderer values.

Internal methods:
- `_process(delta)`  
  Stores frame delta and requests redraw.
- `_draw()`  
  Executes full render pipeline: decay -> ingest -> cleanup -> draw.
- `_decay_trails(delta)`  
  Applies energy decay per trail state using `state.decay_alpha`.  
  Uses a per-frame cache of decay factors to avoid repeated `pow()` for identical decay values.
- `_ingest_commands()`  
  Merges submitted commands into trail state, including duplicate suppression by motion threshold.
- `_cleanup_dead_trails()`  
  Removes samples below threshold (`energy <= 0.01`).
- `_draw_layer(layer)` and `_draw_beam(...)`  
  Render layer-ordered samples with outer+inner beam and optional dots.
- `_draw_outer_halo(...)`  
  Draws softened multi-pass halo profile around the beam.
- `_resolve_decay_alpha(style)`  
  Chooses style decay or fallback renderer decay.
- `_compute_jitter_offset(...)`  
  Produces deterministic age-scaled jitter offset per sample.
- `_compute_motion_blend(...)`  
  Computes stationary-to-moving jitter blend factor with ramp control.
- `_build_retrace_point_factors(...)` and `_draw_polyline_with_factors(...)`  
  Apply retrace dimming to long segments using per-point color scaling.
- `_compute_corner_strength(...)`  
  Computes corner/endpoint dwell emphasis for vertex dots.

### 6.2 `VectorEntity` (`res://scripts/vector_entity.gd`)

Purpose:
- Base class for gameplay entities that submit vector commands.

Exports:
- `vector_renderer_path`
- `vector_style`
- `vector_shape`
- `intensity`
- `draw_layer`
- `trail_enabled`
- `max_trail_samples`
- `min_sample_motion` (`-1.0` means use renderer preset default)
- `command_key`

Core methods:
- `_process(_delta)`  
  Calls `build_draw_commands()`, injects defaults, submits commands.
- `build_draw_commands() -> Array[Dictionary]`  
  Default implementation builds one command from `vector_shape`.
  Override to submit multiple primitives per entity.
- `_to_world_points(points_local)`  
  Converts local geometry to world-space points.
- `_make_command_key(index)`  
  Creates stable command key.
- `_resolve_renderer()`  
  Resolves renderer by path first, then group (`vector_renderer`).

### 6.3 `BouncingBallEntity` (`res://scripts/bouncing_ball_entity.gd`)

Behavior:
- Procedural circle geometry (`circle_segments`).
- Screen-edge bounce physics.
- Uses base submission pipeline (`super._process(delta)`).

Key custom methods:
- `_rebuild_circle_shape()`

### 6.4 `PlayerShipEntity` (`res://scripts/player_ship_entity.gd`)

Behavior:
- Triangle-like ship geometry.
- Rendering-only ship visual submission (no movement or collision logic).

Key custom methods:
- `_rebuild_ship_shape()`

### 6.5 `PlayerShipController` (`res://scripts/player_ship_controller.gd`)

Behavior:
- `CharacterBody2D`-based ship movement and collision.
- Rotation + thrust + braking + damping.
- Uses `move_and_slide()` for wall response.

Input actions used:
- `ui_left`, `ui_right`, `ui_up`, `ui_down`

Key custom methods:
- `_physics_process(delta)`

### 6.6 `StaticVectorEntity` (`res://scripts/static_vector_entity.gd`)

Behavior:
- Procedural rectangle shape for walls/obstacles.
- No gameplay motion by default.
- Intended for static geometry; usually use `trail_enabled = false`.

Key custom method:
- `_rebuild_rect_shape()`

## 7) Scene Implementation Walkthroughs

### 7.1 `main.tscn` (Bouncing Circle Demo)

Scene intent:
- Minimal validation scene for renderer + dynamic entity.

Relevant nodes:
- `Main` (`Control`)
- `SubViewportContainer`
- `SubViewport` (`render_target_clear_mode = 1`, `render_target_update_mode = 4`)
- `WorldEnvironment` (glow enabled)
- `VectorRenderer` (default style + renderer preset)
- `BouncingBall` (`BouncingBallEntity`)

How it works:
1. Ball updates position and bounces.
2. Ball emits one closed polyline command (circle).
3. Renderer accumulates trail history by stable command key.
4. Renderer draws beam + dots with style settings.

### 7.2 `player_ship_walls_demo.tscn` (Player + Static Geometry Demo)

Scene intent:
- Demonstrate mixed dynamic and static entities sharing one renderer.

Relevant nodes:
- One `VectorRenderer`
- `PlayerShipBody` (`CharacterBody2D` with `PlayerShipController` + collider)
- `PlayerShipVisual` (`PlayerShipEntity`, trails disabled in this demo for clean silhouette)
- Multiple wall/obstacle `StaticBody2D` nodes with:
  - `CollisionShape2D`
  - `Visual` child (`StaticVectorEntity`, trails disabled)

How it works:
1. `PlayerShipController` handles movement and collision in physics.
2. `PlayerShipVisual` inherits body transform and submits ship draw commands.
3. Wall `StaticBody2D` nodes block the ship physically.
4. Wall visual children submit static rectangle commands to the same renderer.
5. Rendering and physics stay isolated while remaining transform-synchronized.

## 8) Demo Snippets

### 8.1 Overriding `build_draw_commands()` for multiple primitives

```gdscript
func build_draw_commands() -> Array[Dictionary]:
	var hull := _to_world_points(_hull_points_local)
	var thruster := _to_world_points(_thruster_points_local)
	return [
		{
			"key": "%s_hull" % command_key,
			"points": hull,
			"closed": true,
			"layer": 10
		},
		{
			"key": "%s_thruster" % command_key,
			"points": thruster,
			"closed": false,
			"draw_vertex_dots": false,
			"intensity": 1.3,
			"decay_alpha": 0.015
		}
	]
```

### 8.2 Projectile command with longer trail than player style

```gdscript
{
	"key": "projectile_%d" % projectile_id,
	"points": world_line,
	"closed": false,
	"style": projectile_style,
	"trail_enabled": true,
	"max_trail_samples": 140,
	"decay_alpha": 0.01
}
```

### 8.3 Static wall command (no persistence)

```gdscript
{
	"key": "arena_wall_north",
	"points": wall_points_world,
	"closed": true,
	"style": wall_style,
	"trail_enabled": false,
	"draw_vertex_dots": true
}
```

### 8.4 Switching presets at runtime

```gdscript
@onready var renderer: VectorRenderer = $SubViewportContainer/SubViewport/VectorRenderer

func _ready() -> void:
	var preset := load("res://presets/vector_renderer/oscilloscope.tres") as VectorRendererPreset
	renderer.apply_preset(preset)
```

### 8.5 Saving your own preset resource

Recommended workflow:
1. Duplicate one of the preset `.tres` files in `res://presets/vector_renderer/`.
2. Rename it (for example `my_arcade_mix.tres`).
3. Edit values in Inspector.
4. Assign it to `VectorRenderer.renderer_preset`.

Alternative workflow:
1. In Inspector, set `renderer_preset` to `New VectorRendererPreset`.
2. Tune values on the renderer.
3. Save the resource as a new `.tres` file.

Scripted workflow:
```gdscript
var preset := renderer.snapshot_preset()
ResourceSaver.save(preset, "res://presets/vector_renderer/my_custom_mix.tres")
```

## 9) Performance Notes

Expected costs scale with:
- Number of active command keys
- Samples per key (`max_trail_samples`)
- Points per sample

Current optimizations in code:
- Dead sample pruning (`energy > 0.01`)
- Per-frame decay factor cache by decay alpha value
- Near-duplicate sample suppression (`min_sample_motion`)
- Layer-based draw grouping

Recommended scaling strategy:
1. Disable trails for static objects.
2. Use fewer points for far/low-priority objects.
3. Cap trail samples by object category.
4. Reserve high `max_trail_samples` for player/projectiles only.

## 10) Extension Checklist

When adding a new vector object:
1. Create a `VectorEntity` subclass.
2. Build `VectorShape` local points (or procedural points).
3. Assign style resource (`VectorStyle`).
4. Set stable `command_key`.
5. Choose `trail_enabled`, `max_trail_samples`, `min_sample_motion`, and optional `decay_alpha` override.
6. Place entity in scene and link to renderer (`vector_renderer_path`) or rely on group resolution.

## 11) Troubleshooting

No glow:
- Ensure `viewport/hdr_2d=true` in project settings.
- Ensure scene has `WorldEnvironment` glow enabled.
- Ensure inner beam RGB values exceed `1.0`.

No persistence:
- Verify stable command keys.
- Lower `decay_alpha` (style or command-level).
- Ensure `trail_enabled = true` and adequate `max_trail_samples`.

Repeating grouped ghosts (e.g. several close copies then a gap):
- Cause: render-frame submission with physics-tick movement can produce repeated identical samples.
- Fix: increase `VectorRendererPreset.default_min_sample_motion` slightly (for example `0.01` to `0.5`) or pass `min_sample_motion` per command.
- Optional smoothing: enable and tune `ghost_blur_*` settings so older samples spread/fade more naturally.

Trails feel too noisy or unstable:
- Lower `ghost_jitter_pixels` and/or disable `ghost_jitter_enabled`.
- Reduce `ghost_blur_width_scale` and `ghost_blur_alpha_scale`.
- Lower `ghost_jitter_stationary_scale` to suppress jitter during subtle motion/rotation.
- Raise `ghost_jitter_moving_scale` or lower `ghost_jitter_motion_min` if fast movement looks too stable.
- Lower `ghost_jitter_motion_response` to smooth jitter ramps at movement start.
- Lower `ghost_jitter_max_rise_per_sample` to cap sudden jitter spikes when movement starts from rest.

Dots feel too flat or too harsh:
- Tune corner dwell (`corner_dwell_*`) to emphasize or soften corner persistence.

Long segments too bright:
- Increase `retrace_dimming_strength` or lower `retrace_reference_length`.

Long segments too dim:
- Lower `retrace_dimming_strength` (new default range is tuned for subtle values; start around `0.01` to `0.05`).

Outer beam edge looks too sharp:
- Increase `outer_soft_blur_passes` and/or `outer_soft_blur_alpha_scale`.
- Increase `outer_soft_blur_width_step` to push blur further beyond the core halo width.
- Reduce `beam_width_inner` or outer beam alpha if the center still reads too hard.

Static objects smearing:
- Set `trail_enabled = false` for static entities.

Path resolution issues:
- `vector_renderer_path` is optional; renderer auto-resolves by group `vector_renderer`.

SubViewport parent-path gotcha (important):
- If your `SubViewport` is under `SubViewportContainer`, nested node parents must include the full path, e.g.:
  - `SubViewportContainer/SubViewport/...`
- Using truncated parent paths (for example `SubViewport/...`) can cause Godot to auto-rewrite nodes as `SubViewport#...` and rehome children at root.
- Symptoms include:
  - `CollisionShape2D` warnings saying shapes are not children of physics bodies
  - objects rendering near `(0, 0)` / top-left unexpectedly
- Recovery:
  1. Fix parent paths in `.tscn`.
  2. Close scene tabs without saving.
  3. Reopen scene from FileSystem so Godot rebuilds the tree from disk.
