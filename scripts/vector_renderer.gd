class_name VectorRenderer
extends Node2D

@export var default_style: VectorStyle
# Fallback used when a command/style does not provide one.
@export_range(0.0, 1.0, 0.001) var decay_alpha: float = 0.03
@export var default_max_trail_samples: int = 180
@export var default_min_sample_motion: float = 0.01
@export var ghost_blur_enabled: bool = true
@export var ghost_blur_width_scale: float = 2.8
@export var ghost_blur_alpha_scale: float = 0.20
@export_range(0.0, 1.0, 0.01) var ghost_dot_fade: float = 0.85
@export var background_color: Color = Color(0, 0, 0, 1)

var _submitted_commands: Array[Dictionary] = []
var _trail_states: Dictionary = {}
var _frame_delta: float = 1.0 / 60.0

func _ready() -> void:
	add_to_group("vector_renderer")

func submit_command(command: Dictionary) -> void:
	if not command.has("key"):
		return
	if not command.has("points"):
		return
	_submitted_commands.append(command)

func _process(delta: float) -> void:
	_frame_delta = delta
	queue_redraw()

func _draw() -> void:
	_decay_trails(_frame_delta)
	_ingest_commands()
	_cleanup_dead_trails()
	_submitted_commands.clear()

	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), background_color, true)

	var layers := _collect_layers()
	layers.sort()
	for layer in layers:
		_draw_layer(int(layer))

func _collect_layers() -> Array:
	var seen := {}
	for state in _trail_states.values():
		seen[int(state.layer)] = true
	return seen.keys()

func _draw_layer(layer: int) -> void:
	for state in _trail_states.values():
		if int(state.layer) != layer:
			continue
		var style := state.style as VectorStyle
		if style == null:
			continue
		var samples: Array = state.samples
		var energies: Array = state.energies
		var sample_count := samples.size()
		for i in range(samples.size()):
			var points := samples[i] as PackedVector2Array
			var energy := float(energies[i])
			var blur_factor := 0.0
			if sample_count > 1:
				# Older samples get larger blur to mimic phosphor smear.
				blur_factor = 1.0 - (float(i) / float(sample_count - 1))
			_draw_beam(
				points,
				bool(state.closed),
				bool(state.draw_vertex_dots),
				style,
				energy,
				blur_factor
			)

func _draw_beam(
	points: PackedVector2Array,
	closed: bool,
	draw_vertex_dots: bool,
	style: VectorStyle,
	energy: float,
	blur_factor: float
) -> void:
	if points.size() < 2:
		return

	var draw_points := points
	if closed and points[0] != points[points.size() - 1]:
		draw_points = points.duplicate()
		draw_points.append(points[0])

	var outer := Color(
		style.beam_color_outer.r * energy,
		style.beam_color_outer.g * energy,
		style.beam_color_outer.b * energy,
		style.beam_color_outer.a * energy
	)
	var inner := Color(
		style.beam_color_inner.r * energy,
		style.beam_color_inner.g * energy,
		style.beam_color_inner.b * energy,
		style.beam_color_inner.a * energy
	)
	var dot := Color(
		style.vertex_dot_color.r * energy,
		style.vertex_dot_color.g * energy,
		style.vertex_dot_color.b * energy,
		style.vertex_dot_color.a * energy
	)

	if ghost_blur_enabled and blur_factor > 0.0:
		var blur_width_outer := style.beam_width_outer * lerpf(1.0, ghost_blur_width_scale, blur_factor)
		var blur_width_inner := style.beam_width_inner * lerpf(1.0, ghost_blur_width_scale * 0.75, blur_factor)
		var blur_alpha := ghost_blur_alpha_scale * blur_factor
		var blur_outer := Color(outer.r, outer.g, outer.b, outer.a * blur_alpha)
		var blur_inner := Color(inner.r, inner.g, inner.b, inner.a * blur_alpha * 0.65)
		draw_polyline(draw_points, blur_outer, blur_width_outer, true)
		draw_polyline(draw_points, blur_inner, blur_width_inner, true)

	draw_polyline(draw_points, outer, style.beam_width_outer, true)
	draw_polyline(draw_points, inner, style.beam_width_inner, true)

	if not draw_vertex_dots:
		return

	var dot_fade := maxf(0.0, 1.0 - blur_factor * ghost_dot_fade)
	dot = Color(dot.r, dot.g, dot.b, dot.a * dot_fade)

	for i in range(points.size()):
		draw_circle(points[i], style.vertex_dot_radius, dot)

func _decay_trails(delta: float) -> void:
	var frame_decay_cache := {}
	for key in _trail_states.keys():
		var state: Dictionary = _trail_states[key]
		var state_decay_alpha := float(state.get("decay_alpha", decay_alpha))
		state_decay_alpha = clampf(state_decay_alpha, 0.0, 1.0)
		var frame_decay := float(frame_decay_cache.get(state_decay_alpha, -1.0))
		if frame_decay < 0.0:
			frame_decay = pow(1.0 - state_decay_alpha, delta * 60.0)
			frame_decay_cache[state_decay_alpha] = frame_decay
		var energies: Array = state.energies
		for i in range(energies.size()):
			energies[i] = float(energies[i]) * frame_decay
		state.energies = energies
		_trail_states[key] = state

func _ingest_commands() -> void:
	for command in _submitted_commands:
		var key := str(command.key)
		var state: Dictionary = _trail_states.get(key, {})

		var style := command.get("style", default_style) as VectorStyle
		if style == null:
			continue

		var points := command.points as PackedVector2Array
		if points.size() < 2:
			continue

		var energy := float(command.get("intensity", 1.0))
		var layer := int(command.get("layer", 0))
		var closed := bool(command.get("closed", false))
		var draw_vertex_dots := bool(command.get("draw_vertex_dots", true))
		var trail_enabled := bool(command.get("trail_enabled", true))
		var max_samples := int(command.get("max_trail_samples", default_max_trail_samples))
		var state_decay_alpha := float(command.get("decay_alpha", _resolve_decay_alpha(style)))
		var min_sample_motion := maxf(0.0, float(command.get("min_sample_motion", default_min_sample_motion)))

		var samples: Array = state.get("samples", [])
		var energies: Array = state.get("energies", [])

		if trail_enabled:
			var appended := false
			if samples.is_empty():
				samples.append(points)
				energies.append(energy)
				appended = true
			else:
				var last_points := samples[samples.size() - 1] as PackedVector2Array
				if _points_are_near(last_points, points, min_sample_motion):
					var last_index := energies.size() - 1
					energies[last_index] = maxf(float(energies[last_index]), energy)
				else:
					samples.append(points)
					energies.append(energy)
					appended = true

			if appended:
				while samples.size() > max_samples:
					samples.remove_at(0)
					energies.remove_at(0)
		else:
			samples = [points]
			energies = [energy]

		state.style = style
		state.layer = layer
		state.closed = closed
		state.draw_vertex_dots = draw_vertex_dots
		state.samples = samples
		state.energies = energies
		state.trail_enabled = trail_enabled
		state.decay_alpha = state_decay_alpha
		_trail_states[key] = state

func _cleanup_dead_trails() -> void:
	var dead_keys: Array = []
	for key in _trail_states.keys():
		var state: Dictionary = _trail_states[key]
		var samples: Array = state.get("samples", [])
		var energies: Array = state.get("energies", [])
		var keep_samples: Array = []
		var keep_energies: Array = []
		for i in range(samples.size()):
			if float(energies[i]) > 0.01:
				keep_samples.append(samples[i])
				keep_energies.append(energies[i])
		state.samples = keep_samples
		state.energies = keep_energies
		_trail_states[key] = state

		if keep_samples.is_empty():
			dead_keys.append(key)

	for key in dead_keys:
		_trail_states.erase(key)

func _resolve_decay_alpha(style: VectorStyle) -> float:
	if style != null:
		return clampf(style.decay_alpha, 0.0, 1.0)
	return clampf(decay_alpha, 0.0, 1.0)

func _points_are_near(a: PackedVector2Array, b: PackedVector2Array, max_distance: float) -> bool:
	if a.size() != b.size():
		return false

	var max_dist_sq := max_distance * max_distance
	for i in range(a.size()):
		if a[i].distance_squared_to(b[i]) > max_dist_sq:
			return false
	return true
