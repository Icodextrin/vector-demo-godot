# Vector-Test

Proof of concept Vectrex-style vector rendering pipeline for **Godot 4.6**.

This project explores how to recreate classic vector display aesthetics in a modern engine:
- Line-based geometry rendering
- Beam core + halo layering
- Vertex dwell dots
- Phosphor-like persistence trails
- HDR/glow-based bloom

## Status

This is an experimental baseline intended for iteration and extension into a full game pipeline.

## Included Demos

- `res://scenes/main.tscn`  
  Bouncing vector circle demo using the shared renderer/entity architecture.

- `res://scenes/player_ship_walls_demo.tscn`  
  Player-controlled triangle ship plus static rectangle walls/obstacles, using `CharacterBody2D` + `StaticBody2D` collision while keeping vector rendering in separate visual entity scripts.

## Core Scripts

- `res://scripts/vector_renderer.gd` - centralized vector beam renderer and trail persistence.
- `res://scripts/vector_renderer_preset.gd` - reusable renderer preset resource type.
- `res://scripts/vector_entity.gd` - base entity interface for submitting vector draw commands.
- `res://scripts/vector_style.gd` - shared visual style resource (beam widths/colors/decay).
- `res://scripts/vector_shape.gd` - local-space shape resource for reusable geometry.

## Renderer Presets

Included presets:
- `res://presets/vector_renderer/clean_vector.tres`
- `res://presets/vector_renderer/medium_vector.tres`
- `res://presets/vector_renderer/oscilloscope.tres`
- `res://presets/vector_renderer/blown_out_oscilloscope.tres`

You can duplicate any preset file, tune values, and assign your custom preset to `VectorRenderer.renderer_preset`.
Renderer tuning controls are intentionally centralized in the preset resource to avoid duplicate Inspector options on `VectorRenderer`.

## Documentation

See:
- `res://docs/vector_beam_gameplay_guide.md`

for detailed technical documentation, API notes, and extension guidelines.
