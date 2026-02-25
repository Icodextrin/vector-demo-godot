class_name PlayerShipEntity
extends VectorEntity

@export var ship_length: float = 64.0
@export var ship_width: float = 40.0
@export var turn_speed_deg: float = 220.0
@export var thrust: float = 900.0
@export var brake_force: float = 700.0
@export var max_speed: float = 900.0
@export var linear_damping: float = 0.985
@export var screen_wrap: bool = true
@export var wrap_margin: float = 30.0

var _velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_rebuild_ship_shape()
	super._ready()

func _physics_process(delta: float) -> void:
	var turn_input := Input.get_axis("ui_left", "ui_right")
	rotation += deg_to_rad(turn_speed_deg) * turn_input * delta

	var forward := Vector2.UP.rotated(rotation)
	if Input.is_action_pressed("ui_up"):
		_velocity += forward * thrust * delta
	if Input.is_action_pressed("ui_down"):
		_velocity = _velocity.move_toward(Vector2.ZERO, brake_force * delta)

	_velocity = _velocity.limit_length(max_speed)
	_velocity *= pow(linear_damping, delta * 60.0)
	position += _velocity * delta

	if screen_wrap:
		_wrap_to_viewport()

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

func _wrap_to_viewport() -> void:
	var size := get_viewport_rect().size
	if position.x < -wrap_margin:
		position.x = size.x + wrap_margin
	elif position.x > size.x + wrap_margin:
		position.x = -wrap_margin

	if position.y < -wrap_margin:
		position.y = size.y + wrap_margin
	elif position.y > size.y + wrap_margin:
		position.y = -wrap_margin
