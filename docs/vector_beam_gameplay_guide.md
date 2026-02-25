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
3. Remove dead samples (energy threshold).
4. Clear to black.
5. Draw each layer in ascending order.
6. For each sample:
   - Draw outer beam polyline
   - Draw inner core polyline
   - Draw optional vertex dots

Persistence model:
- Each submitted command appends a sample when `trail_enabled = true`.
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
- `max_trail_samples: int` (default renderer export)
- `decay_alpha: float` (per-command override; otherwise style or renderer fallback)

Identity rule:
- `key` should be stable across frames for the same visual primitive.
- Changing keys every frame prevents persistence from accumulating.

## 6) Script API Reference

### 6.1 `VectorRenderer` (`res://scripts/vector_renderer.gd`)

Public/exported fields:
- `default_style`
- `decay_alpha` (global fallback only)
- `default_max_trail_samples`
- `background_color`

Public method:
- `submit_command(command: Dictionary) -> void`
  - Queues a draw command for ingestion.

Internal methods:
- `_process(delta)`  
  Stores frame delta and requests redraw.
- `_draw()`  
  Executes full render pipeline: decay -> ingest -> cleanup -> draw.
- `_decay_trails(delta)`  
  Applies energy decay per trail state using `state.decay_alpha`.  
  Uses a per-frame cache of decay factors to avoid repeated `pow()` for identical decay values.
- `_ingest_commands()`  
  Merges submitted commands into trail state.
- `_cleanup_dead_trails()`  
  Removes samples below threshold (`energy <= 0.01`).
- `_draw_layer(layer)` and `_draw_beam(...)`  
  Render layer-ordered samples with outer+inner beam and optional dots.
- `_resolve_decay_alpha(style)`  
  Chooses style decay or fallback renderer decay.

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
- `VectorRenderer` (default style + decay fallback)
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
- `PlayerShipVisual` (`PlayerShipEntity`, trails enabled)
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

## 9) Performance Notes

Expected costs scale with:
- Number of active command keys
- Samples per key (`max_trail_samples`)
- Points per sample

Current optimizations in code:
- Dead sample pruning (`energy > 0.01`)
- Per-frame decay factor cache by decay alpha value
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
5. Choose `trail_enabled`, `max_trail_samples`, and optional `decay_alpha` override.
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
