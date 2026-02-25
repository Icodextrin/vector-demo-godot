class_name VectorEntity
extends Node2D

@export var vector_renderer_path: NodePath
@export var vector_style: VectorStyle
@export var vector_shape: VectorShape
@export var intensity: float = 1.0
@export var draw_layer: int = 0
@export var trail_enabled: bool = true
@export var max_trail_samples: int = 180
@export var min_sample_motion: float = -1.0
@export var command_key: String = ""

var _vector_renderer: VectorRenderer

func _ready() -> void:
	_resolve_renderer()

func _process(_delta: float) -> void:
	if _vector_renderer == null:
		_resolve_renderer()
	if _vector_renderer == null:
		return

	var commands := build_draw_commands()
	for i in range(commands.size()):
		var command: Dictionary = commands[i]
		if not command.has("points"):
			continue
		if not command.has("key"):
			command.key = _make_command_key(i)
		if not command.has("style"):
			command.style = vector_style
		if not command.has("intensity"):
			command.intensity = intensity
		if not command.has("layer"):
			command.layer = draw_layer
		if not command.has("trail_enabled"):
			command.trail_enabled = trail_enabled
		if not command.has("max_trail_samples"):
			command.max_trail_samples = max_trail_samples
		if min_sample_motion >= 0.0 and not command.has("min_sample_motion"):
			command.min_sample_motion = min_sample_motion
		if not command.has("draw_vertex_dots"):
			command.draw_vertex_dots = true
		_vector_renderer.submit_command(command)

func build_draw_commands() -> Array[Dictionary]:
	if vector_shape == null:
		return []
	var points_world := _to_world_points(vector_shape.points_local)
	return [{
		"points": points_world,
		"closed": vector_shape.closed,
		"draw_vertex_dots": vector_shape.draw_vertex_dots
	}]

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

func _resolve_renderer() -> void:
	if vector_renderer_path != NodePath():
		var candidate := get_node_or_null(vector_renderer_path)
		if candidate is VectorRenderer:
			_vector_renderer = candidate as VectorRenderer
			return

	var in_group := get_tree().get_first_node_in_group("vector_renderer")
	if in_group is VectorRenderer:
		_vector_renderer = in_group as VectorRenderer
