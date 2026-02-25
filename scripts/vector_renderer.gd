class_name VectorRenderer
extends Node2D

@export var default_style: VectorStyle
var _renderer_preset: VectorRendererPreset
@export var renderer_preset: VectorRendererPreset:
	get:
		return _renderer_preset
	set(value):
		_renderer_preset = value
		if is_node_ready() and _renderer_preset != null:
			_apply_preset(_renderer_preset)

# Runtime values are sourced from renderer_preset.
var decay_alpha: float = 0.03
var default_max_trail_samples: int = 180
var default_min_sample_motion: float = 0.01
var outer_soft_blur_enabled: bool = true
var outer_soft_blur_passes: int = 3
var outer_soft_blur_width_step: float = 0.65
var outer_soft_blur_alpha_scale: float = 0.22
var ghost_blur_enabled: bool = true
var ghost_blur_width_scale: float = 2.8
var ghost_blur_alpha_scale: float = 0.20
var ghost_dot_fade: float = 0.85
var ghost_jitter_enabled: bool = true
var ghost_jitter_pixels: float = 0.8
var ghost_jitter_speed: float = 1.9
var ghost_jitter_age_scale: float = 1.0
var ghost_jitter_stationary_scale: float = 0.18
var ghost_jitter_moving_scale: float = 1.25
var ghost_jitter_motion_min: float = 2.0
var ghost_jitter_motion_max: float = 18.0
var ghost_jitter_motion_response: float = 0.22
var ghost_jitter_max_rise_per_sample: float = 0.08
var corner_dwell_enabled: bool = true
var corner_dwell_boost: float = 1.35
var corner_dwell_power: float = 1.2
var corner_endpoint_boost: float = 0.10
var retrace_dimming_enabled: bool = true
var retrace_reference_length: float = 32.0
var retrace_dimming_strength: float = 0.03
var two_stage_decay_enabled: bool = true
var two_stage_knee_energy: float = 0.22
var two_stage_tail_alpha_multiplier: float = 0.35
var background_color: Color = Color(0, 0, 0, 1)

var _submitted_commands: Array[Dictionary] = []
var _trail_states: Dictionary = {}
var _frame_delta: float = 1.0 / 60.0
var _time_accum: float = 0.0

func _ready() -> void:
	add_to_group("vector_renderer")
	if _renderer_preset == null:
		_renderer_preset = VectorRendererPreset.new()
	_apply_preset(_renderer_preset)

func apply_preset(preset: VectorRendererPreset) -> void:
	if preset == null:
		return
	_renderer_preset = preset
	_apply_preset(preset)

func snapshot_preset() -> VectorRendererPreset:
	var preset: VectorRendererPreset = VectorRendererPreset.new()
	preset.decay_alpha = decay_alpha
	preset.default_max_trail_samples = default_max_trail_samples
	preset.default_min_sample_motion = default_min_sample_motion
	preset.outer_soft_blur_enabled = outer_soft_blur_enabled
	preset.outer_soft_blur_passes = outer_soft_blur_passes
	preset.outer_soft_blur_width_step = outer_soft_blur_width_step
	preset.outer_soft_blur_alpha_scale = outer_soft_blur_alpha_scale
	preset.ghost_blur_enabled = ghost_blur_enabled
	preset.ghost_blur_width_scale = ghost_blur_width_scale
	preset.ghost_blur_alpha_scale = ghost_blur_alpha_scale
	preset.ghost_dot_fade = ghost_dot_fade
	preset.ghost_jitter_enabled = ghost_jitter_enabled
	preset.ghost_jitter_pixels = ghost_jitter_pixels
	preset.ghost_jitter_speed = ghost_jitter_speed
	preset.ghost_jitter_age_scale = ghost_jitter_age_scale
	preset.ghost_jitter_stationary_scale = ghost_jitter_stationary_scale
	preset.ghost_jitter_moving_scale = ghost_jitter_moving_scale
	preset.ghost_jitter_motion_min = ghost_jitter_motion_min
	preset.ghost_jitter_motion_max = ghost_jitter_motion_max
	preset.ghost_jitter_motion_response = ghost_jitter_motion_response
	preset.ghost_jitter_max_rise_per_sample = ghost_jitter_max_rise_per_sample
	preset.corner_dwell_enabled = corner_dwell_enabled
	preset.corner_dwell_boost = corner_dwell_boost
	preset.corner_dwell_power = corner_dwell_power
	preset.corner_endpoint_boost = corner_endpoint_boost
	preset.retrace_dimming_enabled = retrace_dimming_enabled
	preset.retrace_reference_length = retrace_reference_length
	preset.retrace_dimming_strength = retrace_dimming_strength
	preset.two_stage_decay_enabled = two_stage_decay_enabled
	preset.two_stage_knee_energy = two_stage_knee_energy
	preset.two_stage_tail_alpha_multiplier = two_stage_tail_alpha_multiplier
	preset.background_color = background_color
	return preset

func _apply_preset(preset: VectorRendererPreset) -> void:
	decay_alpha = clampf(preset.decay_alpha, 0.0, 1.0)
	default_max_trail_samples = maxi(1, preset.default_max_trail_samples)
	default_min_sample_motion = maxf(0.0, preset.default_min_sample_motion)
	outer_soft_blur_enabled = preset.outer_soft_blur_enabled
	outer_soft_blur_passes = maxi(0, preset.outer_soft_blur_passes)
	outer_soft_blur_width_step = maxf(0.0, preset.outer_soft_blur_width_step)
	outer_soft_blur_alpha_scale = maxf(0.0, preset.outer_soft_blur_alpha_scale)
	ghost_blur_enabled = preset.ghost_blur_enabled
	ghost_blur_width_scale = maxf(0.0, preset.ghost_blur_width_scale)
	ghost_blur_alpha_scale = maxf(0.0, preset.ghost_blur_alpha_scale)
	ghost_dot_fade = clampf(preset.ghost_dot_fade, 0.0, 1.0)
	ghost_jitter_enabled = preset.ghost_jitter_enabled
	ghost_jitter_pixels = maxf(0.0, preset.ghost_jitter_pixels)
	ghost_jitter_speed = maxf(0.0, preset.ghost_jitter_speed)
	ghost_jitter_age_scale = maxf(0.0, preset.ghost_jitter_age_scale)
	ghost_jitter_stationary_scale = maxf(0.0, preset.ghost_jitter_stationary_scale)
	ghost_jitter_moving_scale = maxf(0.0, preset.ghost_jitter_moving_scale)
	ghost_jitter_motion_min = maxf(0.0, preset.ghost_jitter_motion_min)
	ghost_jitter_motion_max = maxf(0.0, preset.ghost_jitter_motion_max)
	ghost_jitter_motion_response = clampf(preset.ghost_jitter_motion_response, 0.01, 1.0)
	ghost_jitter_max_rise_per_sample = maxf(0.0, preset.ghost_jitter_max_rise_per_sample)
	corner_dwell_enabled = preset.corner_dwell_enabled
	corner_dwell_boost = maxf(0.0, preset.corner_dwell_boost)
	corner_dwell_power = maxf(0.01, preset.corner_dwell_power)
	corner_endpoint_boost = maxf(0.0, preset.corner_endpoint_boost)
	retrace_dimming_enabled = preset.retrace_dimming_enabled
	retrace_reference_length = maxf(0.001, preset.retrace_reference_length)
	retrace_dimming_strength = maxf(0.0, preset.retrace_dimming_strength)
	two_stage_decay_enabled = preset.two_stage_decay_enabled
	two_stage_knee_energy = clampf(preset.two_stage_knee_energy, 0.0, 1.0)
	two_stage_tail_alpha_multiplier = clampf(preset.two_stage_tail_alpha_multiplier, 0.0, 1.0)
	background_color = preset.background_color
	queue_redraw()

func submit_command(command: Dictionary) -> void:
	if not command.has("key"):
		return
	if not command.has("points"):
		return
	_submitted_commands.append(command)

func _process(delta: float) -> void:
	_frame_delta = delta
	_time_accum += delta
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
	var seen: Dictionary = {}
	for state in _trail_states.values():
		seen[int(state.layer)] = true
	return seen.keys()

func _draw_layer(layer: int) -> void:
	for key in _trail_states.keys():
		var state: Dictionary = _trail_states[key]
		if int(state.layer) != layer:
			continue
		var style: VectorStyle = state.style as VectorStyle
		if style == null:
			continue
		var samples: Array = state.samples
		var energies: Array = state.energies
		var motions: Array = state.get("motions", [])
		var sample_count := samples.size()
		for i in range(samples.size()):
			var points := samples[i] as PackedVector2Array
			var energy := float(energies[i])
			var sample_motion_blend := 0.0
			if i < motions.size():
				sample_motion_blend = float(motions[i])
			var blur_factor := 0.0
			if sample_count > 1:
				# Older samples get larger blur to mimic phosphor smear.
				blur_factor = 1.0 - (float(i) / float(sample_count - 1))
			if ghost_jitter_enabled and blur_factor > 0.0:
				points = _offset_points(points, _compute_jitter_offset(str(key), i, blur_factor, sample_motion_blend))
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

	var point_factors := PackedFloat32Array()
	if retrace_dimming_enabled:
		point_factors = _build_retrace_point_factors(draw_points)

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

	_draw_outer_halo(draw_points, outer, style.beam_width_outer, point_factors)

	if ghost_blur_enabled and blur_factor > 0.0:
		var blur_width_outer := style.beam_width_outer * lerpf(1.0, ghost_blur_width_scale, blur_factor)
		var blur_width_inner := style.beam_width_inner * lerpf(1.0, ghost_blur_width_scale * 0.75, blur_factor)
		var blur_alpha := ghost_blur_alpha_scale * blur_factor
		var blur_outer := Color(outer.r, outer.g, outer.b, outer.a * blur_alpha)
		var blur_inner := Color(inner.r, inner.g, inner.b, inner.a * blur_alpha * 0.65)
		_draw_polyline_with_factors(draw_points, blur_outer, blur_width_outer, point_factors)
		_draw_polyline_with_factors(draw_points, blur_inner, blur_width_inner, point_factors)

	_draw_polyline_with_factors(draw_points, inner, style.beam_width_inner, point_factors)

	if not draw_vertex_dots:
		return

	var dot_fade := maxf(0.0, 1.0 - blur_factor * ghost_dot_fade)
	var retrace_enabled := point_factors.size() == draw_points.size()

	for i in range(points.size()):
		var retrace_factor := 1.0
		if retrace_enabled:
			retrace_factor = point_factors[i]

		var dwell_factor := 1.0
		if corner_dwell_enabled:
			var corner_strength := _compute_corner_strength(points, i, closed)
			dwell_factor += corner_dwell_boost * pow(corner_strength, corner_dwell_power)

		var dot_color := Color(
			dot.r * retrace_factor * dwell_factor,
			dot.g * retrace_factor * dwell_factor,
			dot.b * retrace_factor * dwell_factor,
			dot.a * dot_fade
		)
		draw_circle(points[i], style.vertex_dot_radius, dot_color)

func _draw_outer_halo(
	points: PackedVector2Array,
	outer: Color,
	outer_width: float,
	point_factors: PackedFloat32Array
) -> void:
	if outer.a <= 0.0 or outer_width <= 0.0:
		return

	if not outer_soft_blur_enabled or outer_soft_blur_passes <= 0 or outer_soft_blur_alpha_scale <= 0.0:
		_draw_polyline_with_factors(points, outer, outer_width, point_factors)
		return

	var core_width: float = maxf(0.5, outer_width * 0.68)
	var core_color: Color = Color(outer.r, outer.g, outer.b, outer.a * 0.55)
	_draw_polyline_with_factors(points, core_color, core_width, point_factors)

	var mid_color: Color = Color(outer.r, outer.g, outer.b, outer.a * 0.38)
	_draw_polyline_with_factors(points, mid_color, outer_width, point_factors)

	var blur_passes: int = maxi(1, outer_soft_blur_passes)
	var max_width: float = outer_width * (1.0 + outer_soft_blur_width_step)
	for pass_index in range(blur_passes):
		var t: float = float(pass_index + 1) / float(blur_passes)
		var width_t: float = pow(t, 0.75)
		var blur_width: float = lerpf(outer_width, max_width, width_t)
		var falloff: float = pow(1.0 - t, 1.6)
		var blur_alpha: float = outer.a * outer_soft_blur_alpha_scale * falloff
		if blur_alpha <= 0.0001:
			continue
		var blur_color: Color = Color(outer.r, outer.g, outer.b, blur_alpha)
		_draw_polyline_with_factors(points, blur_color, blur_width, point_factors)

func _decay_trails(delta: float) -> void:
	var frame_decay_cache: Dictionary = {}
	for key in _trail_states.keys():
		var state: Dictionary = _trail_states[key]
		var state_decay_alpha := float(state.get("decay_alpha", decay_alpha))
		state_decay_alpha = clampf(state_decay_alpha, 0.0, 1.0)
		var energies: Array = state.energies
		for i in range(energies.size()):
			var sample_decay_alpha := state_decay_alpha
			if two_stage_decay_enabled and float(energies[i]) <= two_stage_knee_energy:
				sample_decay_alpha *= two_stage_tail_alpha_multiplier
			sample_decay_alpha = clampf(sample_decay_alpha, 0.0, 1.0)

			var frame_decay := float(frame_decay_cache.get(sample_decay_alpha, -1.0))
			if frame_decay < 0.0:
				frame_decay = pow(1.0 - sample_decay_alpha, delta * 60.0)
				frame_decay_cache[sample_decay_alpha] = frame_decay

			energies[i] = float(energies[i]) * frame_decay
		state.energies = energies
		_trail_states[key] = state

func _ingest_commands() -> void:
	for command in _submitted_commands:
		var key: String = str(command.key)
		var state: Dictionary = _trail_states.get(key, {})

		var style: VectorStyle = command.get("style", default_style) as VectorStyle
		if style == null:
			continue

		var points: PackedVector2Array = command.points as PackedVector2Array
		if points.size() < 2:
			continue

		var energy: float = float(command.get("intensity", 1.0))
		var layer: int = int(command.get("layer", 0))
		var closed: bool = bool(command.get("closed", false))
		var draw_vertex_dots: bool = bool(command.get("draw_vertex_dots", true))
		var trail_enabled: bool = bool(command.get("trail_enabled", true))
		var max_samples: int = int(command.get("max_trail_samples", default_max_trail_samples))
		var state_decay_alpha: float = float(command.get("decay_alpha", _resolve_decay_alpha(style)))
		var min_sample_motion: float = maxf(0.0, float(command.get("min_sample_motion", default_min_sample_motion)))

		var samples: Array = state.get("samples", [])
		var energies: Array = state.get("energies", [])
		var motions: Array = state.get("motions", [])

		if trail_enabled:
			var appended: bool = false
			if samples.is_empty():
				samples.append(points)
				energies.append(energy)
				motions.append(0.0)
				state.motion_blend = 0.0
				appended = true
			else:
				var last_points: PackedVector2Array = samples[samples.size() - 1] as PackedVector2Array
				var motion_distance: float = _centroid_distance(last_points, points)
				var previous_blend: float = float(state.get("motion_blend", 0.0))
				var target_blend: float = _compute_motion_blend(motion_distance)
				var smoothed_blend: float = lerpf(previous_blend, target_blend, ghost_jitter_motion_response)
				smoothed_blend = minf(smoothed_blend, previous_blend + ghost_jitter_max_rise_per_sample)
				if _points_are_near(last_points, points, min_sample_motion):
					var last_index: int = energies.size() - 1
					# Keep head sample aligned with latest transform while still suppressing duplicates.
					samples[last_index] = points
					energies[last_index] = maxf(float(energies[last_index]), energy)
					if last_index < motions.size():
						motions[last_index] = smoothed_blend
					state.motion_blend = smoothed_blend
				else:
					samples.append(points)
					energies.append(energy)
					motions.append(smoothed_blend)
					state.motion_blend = smoothed_blend
					appended = true

			if appended:
				while samples.size() > max_samples:
					samples.remove_at(0)
					energies.remove_at(0)
					motions.remove_at(0)
		else:
			samples = [points]
			energies = [energy]
			motions = [0.0]
			state.motion_blend = 0.0

		state.style = style
		state.layer = layer
		state.closed = closed
		state.draw_vertex_dots = draw_vertex_dots
		state.samples = samples
		state.energies = energies
		state.motions = motions
		state.trail_enabled = trail_enabled
		state.decay_alpha = state_decay_alpha
		_trail_states[key] = state

func _cleanup_dead_trails() -> void:
	var dead_keys: Array = []
	for key in _trail_states.keys():
		var state: Dictionary = _trail_states[key]
		var samples: Array = state.get("samples", [])
		var energies: Array = state.get("energies", [])
		var motions: Array = state.get("motions", [])
		var keep_samples: Array = []
		var keep_energies: Array = []
		var keep_motions: Array = []
		for i in range(samples.size()):
			if float(energies[i]) > 0.01:
				keep_samples.append(samples[i])
				keep_energies.append(energies[i])
				if i < motions.size():
					keep_motions.append(motions[i])
				else:
					keep_motions.append(0.0)
		state.samples = keep_samples
		state.energies = keep_energies
		state.motions = keep_motions
		if not keep_motions.is_empty():
			state.motion_blend = float(keep_motions[keep_motions.size() - 1])
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

func _compute_jitter_offset(
	state_key: String,
	sample_index: int,
	blur_factor: float,
	sample_motion_blend: float
) -> Vector2:
	var motion_t := clampf(sample_motion_blend, 0.0, 1.0)
	var motion_scale := lerpf(ghost_jitter_stationary_scale, ghost_jitter_moving_scale, motion_t)
	var magnitude := ghost_jitter_pixels * blur_factor * ghost_jitter_age_scale * motion_scale
	if magnitude <= 0.0:
		return Vector2.ZERO

	var seed := float(abs(hash(state_key)) % 8192) * 0.001
	var t := _time_accum * ghost_jitter_speed
	return Vector2(
		sin(t + seed + float(sample_index) * 0.73),
		cos(t * 1.17 + seed * 1.31 + float(sample_index) * 0.41)
	) * magnitude

func _compute_motion_blend(sample_motion: float) -> float:
	var min_m := minf(ghost_jitter_motion_min, ghost_jitter_motion_max)
	var max_m := maxf(ghost_jitter_motion_min, ghost_jitter_motion_max)
	if max_m - min_m < 0.0001:
		return 1.0 if sample_motion >= max_m else 0.0
	return clampf((sample_motion - min_m) / (max_m - min_m), 0.0, 1.0)

func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	shifted.resize(points.size())
	for i in range(points.size()):
		shifted[i] = points[i] + offset
	return shifted

func _centroid_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if a.size() == 0 or b.size() == 0:
		return 0.0
	return _compute_centroid(a).distance_to(_compute_centroid(b))

func _compute_centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for i in range(points.size()):
		sum += points[i]
	return sum / float(points.size())

func _build_retrace_point_factors(points: PackedVector2Array) -> PackedFloat32Array:
	var factors := PackedFloat32Array()
	factors.resize(points.size())
	for i in range(points.size()):
		factors[i] = 1.0

	if points.size() < 2:
		return factors

	var ref_len := maxf(0.001, retrace_reference_length)
	for i in range(points.size() - 1):
		var seg_len := points[i].distance_to(points[i + 1])
		var over := maxf(0.0, (seg_len / ref_len) - 1.0)
		var dim := 1.0 / (1.0 + over * retrace_dimming_strength)
		factors[i] = minf(factors[i], dim)
		factors[i + 1] = minf(factors[i + 1], dim)

	return factors

func _draw_polyline_with_factors(
	points: PackedVector2Array,
	base_color: Color,
	width: float,
	point_factors: PackedFloat32Array
) -> void:
	if retrace_dimming_enabled and point_factors.size() == points.size():
		var colors := PackedColorArray()
		colors.resize(points.size())
		for i in range(points.size()):
			var f := point_factors[i]
			colors[i] = Color(
				base_color.r * f,
				base_color.g * f,
				base_color.b * f,
				base_color.a * f
			)
		draw_polyline_colors(points, colors, width, true)
		return

	draw_polyline(points, base_color, width, true)

func _compute_corner_strength(points: PackedVector2Array, index: int, closed: bool) -> float:
	var count := points.size()
	if count < 2:
		return 0.0

	if not closed and (index == 0 or index == count - 1):
		return corner_endpoint_boost

	if count < 3:
		return 0.0

	var prev_index := index - 1
	var next_index := index + 1
	if closed:
		prev_index = (index - 1 + count) % count
		next_index = (index + 1) % count

	if prev_index < 0 or next_index >= count:
		return 0.0

	var v_in := points[index] - points[prev_index]
	var v_out := points[next_index] - points[index]
	if v_in.length_squared() < 0.000001 or v_out.length_squared() < 0.000001:
		return 0.0

	var dot := clampf(v_in.normalized().dot(v_out.normalized()), -1.0, 1.0)
	var turn_angle := acos(dot)
	return clampf(turn_angle / PI, 0.0, 1.0)
