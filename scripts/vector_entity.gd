class_name VectorEntity
extends Node2D

@export var vector_renderer_path: NodePath
@export var vector_style: VectorStyle
@export var vector_shape: VectorShape
@export_range(0.0, 16.0, 0.01) var intensity: float = 1.0
@export_range(-1024, 1024, 1) var draw_layer: int = 0
@export var trail_enabled: bool = true
@export_range(1, 2048, 1) var max_trail_samples: int = 180
@export_range(-1.0, 64.0, 0.001) var min_sample_motion: float = -1.0
@export var command_key: String = ""

var _vector_renderer: VectorRenderer

func _ready() -> void:
	_resolve_renderer()

func _process(_delta: float) -> void:
	if _vector_renderer == null:
		_resolve_renderer()
	if _vector_renderer == null:
		return

	var commands: Array = build_draw_commands()
	for i in range(commands.size()):
		var command := VectorDrawCommand.from_variant(commands[i])
		if command == null:
			continue
		if command.points.size() < 2:
			continue
		_apply_default_command_values(command, i)
		_vector_renderer.submit_command(command)

func build_draw_commands() -> Array:
	if vector_shape == null:
		return []

	var points_world := _to_world_points(vector_shape.points_local)
	var command := VectorDrawCommand.new()
	command.points = points_world
	command.closed = vector_shape.closed
	command.draw_vertex_dots = vector_shape.draw_vertex_dots
	return [command]

func _to_world_points(points_local: PackedVector2Array) -> PackedVector2Array:
	var points_world := PackedVector2Array()
	points_world.resize(points_local.size())
	for i in range(points_local.size()):
		points_world[i] = global_transform * points_local[i]
	return points_world

func _make_command_key(index: int) -> String:
	if not command_key.is_empty():
		return "%s:%d" % [command_key, index]
	return "entity_%d:%d" % [get_instance_id(), index]

func _apply_default_command_values(command: VectorDrawCommand, index: int) -> void:
	if command.key.is_empty():
		command.key = _make_command_key(index)
	if command.style == null and vector_style != null:
		command.style = vector_style
	if is_nan(command.intensity):
		command.intensity = intensity
	if command.layer == VectorDrawCommand.LAYER_UNSET:
		command.layer = draw_layer
	if command.max_trail_samples < 1:
		command.max_trail_samples = max_trail_samples
	if min_sample_motion >= 0.0 and command.min_sample_motion < 0.0:
		command.min_sample_motion = min_sample_motion

func _resolve_renderer() -> void:
	if vector_renderer_path != NodePath():
		var candidate := get_node_or_null(vector_renderer_path)
		if candidate is VectorRenderer:
			_vector_renderer = candidate as VectorRenderer
			return

	var in_group := get_tree().get_first_node_in_group("vector_renderer")
	if in_group is VectorRenderer:
		_vector_renderer = in_group as VectorRenderer
