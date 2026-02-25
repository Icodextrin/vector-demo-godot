extends VectorEntity

@export_range(1.0, 2000.0, 1.0) var ball_radius: float = 150.0
@export_range(3, 256, 1) var circle_segments: int = 16
@export_range(1.0, 5000.0, 1.0) var speed: float = 1000.0

var _velocity: Vector2

func _ready() -> void:
	_velocity = Vector2(1.0, 0.73).normalized() * speed
	_rebuild_circle_shape()
	super._ready()

func _process(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	position += _velocity * delta

	if position.x <= ball_radius:
		position.x = ball_radius
		_velocity.x = absf(_velocity.x)
	elif position.x >= viewport_size.x - ball_radius:
		position.x = viewport_size.x - ball_radius
		_velocity.x = -absf(_velocity.x)

	if position.y <= ball_radius:
		position.y = ball_radius
		_velocity.y = absf(_velocity.y)
	elif position.y >= viewport_size.y - ball_radius:
		position.y = viewport_size.y - ball_radius
		_velocity.y = -absf(_velocity.y)

	super._process(delta)

func _rebuild_circle_shape() -> void:
	if vector_shape == null:
		vector_shape = VectorShape.new()

	var segment_count := maxi(3, circle_segments)
	var points := PackedVector2Array()
	points.resize(segment_count)
	for i in range(segment_count):
		var angle := TAU * float(i) / float(segment_count)
		points[i] = Vector2(cos(angle), sin(angle)) * ball_radius

	vector_shape.points_local = points
	vector_shape.closed = true
	vector_shape.draw_vertex_dots = true
