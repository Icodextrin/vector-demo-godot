class_name PlayerShipController
extends CharacterBody2D

@export_range(0.0, 1080.0, 1.0) var turn_speed_deg: float = 220.0
@export_range(0.0, 4000.0, 1.0) var thrust: float = 900.0
@export_range(0.0, 4000.0, 1.0) var brake_force: float = 700.0
@export_range(0.0, 4000.0, 1.0) var max_speed: float = 900.0
@export_range(0.0, 1.0, 0.001) var linear_damping: float = 0.985

func _physics_process(delta: float) -> void:
	var turn_input := Input.get_axis("ui_left", "ui_right")
	rotation += deg_to_rad(turn_speed_deg) * turn_input * delta

	var forward := Vector2.UP.rotated(rotation)
	if Input.is_action_pressed("ui_up"):
		velocity += forward * thrust * delta
	if Input.is_action_pressed("ui_down"):
		velocity = velocity.move_toward(Vector2.ZERO, brake_force * delta)

	velocity = velocity.limit_length(max_speed)
	velocity *= pow(linear_damping, delta * 60.0)
	move_and_slide()
