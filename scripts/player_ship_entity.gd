class_name PlayerShipEntity
extends VectorEntity

@export var ship_length: float = 64.0
@export var ship_width: float = 40.0

func _ready() -> void:
	_rebuild_ship_shape()
	super._ready()

func _rebuild_ship_shape() -> void:
	if vector_shape == null:
		vector_shape = VectorShape.new()

	var half_length := ship_length * 0.5
	var half_width := ship_width * 0.5
	vector_shape.points_local = PackedVector2Array([
		Vector2(0.0, -half_length),
		Vector2(half_width, half_length),
		Vector2(0.0, half_length * 0.35),
		Vector2(-half_width, half_length)
	])
	vector_shape.closed = true
	vector_shape.draw_vertex_dots = true
