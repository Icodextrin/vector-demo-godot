class_name StaticVectorEntity
extends VectorEntity

@export var rect_size: Vector2 = Vector2(260.0, 40.0)
@export var centered: bool = true

func _ready() -> void:
	_rebuild_rect_shape()
	super._ready()

func _rebuild_rect_shape() -> void:
	if vector_shape == null:
		vector_shape = VectorShape.new()

	var points := PackedVector2Array()
	if centered:
		var half := rect_size * 0.5
		points = PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y)
		])
	else:
		points = PackedVector2Array([
			Vector2.ZERO,
			Vector2(rect_size.x, 0.0),
			Vector2(rect_size.x, rect_size.y),
			Vector2(0.0, rect_size.y)
		])

	vector_shape.points_local = points
	vector_shape.closed = true
	vector_shape.draw_vertex_dots = true
