extends Node2D

@export var ball_radius: float = 150.0
@export var beam_width_outer: float = 19.0
@export var beam_width_inner: float = 1.0
@export var vertex_dot_radius: float = 3.1
@export var circle_segments: int = 16
@export_range(0.0, 1.0, 0.001) var decay_alpha: float = 0.08
@export var speed: float = 320.0
@export var max_trail_samples: int = 180

# Overbright values rely on HDR 2D + glow.
@export var beam_color_outer: Color = Color(0.8, 0.8, 0.8, 0.20)
@export var beam_color_inner: Color = Color(3.6, 3.6, 3.6, 1.0)
@export var vertex_dot_color: Color = Color(6.0, 6.0, 6.0, 1.0)

var _position: Vector2
var _velocity: Vector2
var _trail_positions: Array[Vector2] = []
var _trail_energy: Array[float] = []

func _ready() -> void:
	var size := get_viewport_rect().size
	_position = size * 0.5
	_velocity = Vector2(1.0, 0.73).normalized() * speed
	queue_redraw()

func _process(delta: float) -> void:
	var size := get_viewport_rect().size
	_position += _velocity * delta

	if _position.x <= ball_radius:
		_position.x = ball_radius
		_velocity.x = absf(_velocity.x)
	elif _position.x >= size.x - ball_radius:
		_position.x = size.x - ball_radius
		_velocity.x = -absf(_velocity.x)

	if _position.y <= ball_radius:
		_position.y = ball_radius
		_velocity.y = absf(_velocity.y)
	elif _position.y >= size.y - ball_radius:
		_position.y = size.y - ball_radius
		_velocity.y = -absf(_velocity.y)

	_update_trail(delta)
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size

	# Force a hard black background every frame.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1), true)

	# Draw trail from oldest to newest for phosphor-like persistence.
	for i in range(_trail_positions.size()):
		_draw_vector_circle(_trail_positions[i], _trail_energy[i])

func _update_trail(delta: float) -> void:
	var frame_decay := pow(clampf(1.0 - decay_alpha, 0.0, 1.0), delta * 60.0)

	for i in range(_trail_energy.size()):
		_trail_energy[i] *= frame_decay

	var keep_positions: Array[Vector2] = []
	var keep_energy: Array[float] = []
	for i in range(_trail_positions.size()):
		if _trail_energy[i] > 0.01:
			keep_positions.append(_trail_positions[i])
			keep_energy.append(_trail_energy[i])
	_trail_positions = keep_positions
	_trail_energy = keep_energy

	_trail_positions.append(_position)
	_trail_energy.append(1.0)

	while _trail_positions.size() > max_trail_samples:
		_trail_positions.remove_at(0)
		_trail_energy.remove_at(0)

func _draw_vector_circle(center: Vector2, energy: float) -> void:
	var points := PackedVector2Array()
	points.resize(circle_segments + 1)
	for i in range(circle_segments):
		var angle := TAU * float(i) / float(circle_segments)
		points[i] = center + Vector2(cos(angle), sin(angle)) * ball_radius
	points[circle_segments] = points[0]

	# Draw a soft halo plus sharp core for beam-like lines.
	var outer := Color(
		beam_color_outer.r * energy,
		beam_color_outer.g * energy,
		beam_color_outer.b * energy,
		beam_color_outer.a * energy
	)
	var inner := Color(
		beam_color_inner.r * energy,
		beam_color_inner.g * energy,
		beam_color_inner.b * energy,
		beam_color_inner.a * energy
	)
	var dot := Color(
		vertex_dot_color.r * energy,
		vertex_dot_color.g * energy,
		vertex_dot_color.b * energy,
		vertex_dot_color.a * energy
	)

	draw_polyline(points, outer, beam_width_outer, true)
	draw_polyline(points, inner, beam_width_inner, true)

	# Vertex dwell: brighter dots at each vector vertex.
	for i in range(circle_segments):
		draw_circle(points[i], vertex_dot_radius, dot)
