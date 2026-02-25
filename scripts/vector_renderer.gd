class_name VectorRenderer
extends Node2D

const TRAIL_ENERGY_CUTOFF := 0.01
const MOTION_RANGE_EPSILON := 0.0001
const VECTOR_LENGTH_EPSILON_SQ := 0.000001
const DECAY_REFERENCE_FPS := 60.0
const HASH_SEED_MODULO := 8192
const HASH_SEED_SCALE := 0.001

@export var default_style: VectorStyle

var _renderer_preset: VectorRendererPreset
var _active_preset: VectorRendererPreset = VectorRendererPreset.new()

@export var renderer_preset: VectorRendererPreset:
	get:
		return _renderer_preset
	set(value):
		_renderer_preset = value
		if is_node_ready():
			_refresh_active_preset()

var _submitted_commands: Array[VectorDrawCommand] = []
var _trail_states: Dictionary = {}
var _frame_delta: float = 1.0 / 60.0
var _time_accum: float = 0.0

func _ready() -> void:
	add_to_group("vector_renderer")
	_refresh_active_preset()

func apply_preset(preset: VectorRendererPreset) -> void:
	if preset == null:
		return
	renderer_preset = preset

func snapshot_preset() -> VectorRendererPreset:
	if _active_preset == null:
		return VectorRendererPreset.new()
	return _active_preset.duplicate(true) as VectorRendererPreset

func submit_command(command_data: Variant) -> void:
	var command := VectorDrawCommand.from_variant(command_data)
	if command == null:
		return
	if command.key.is_empty():
		return
	if command.points.size() < 2:
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
	draw_rect(Rect2(Vector2.ZERO, viewport_size), _active_preset.background_color, true)

	var layer_buckets := _build_layer_buckets()
	var layers: Array = layer_buckets.keys()
	layers.sort()
	for layer in layers:
		var states: Array = layer_buckets[int(layer)]
		_draw_layer(states)

func _refresh_active_preset() -> void:
	if _renderer_preset == null:
		_renderer_preset = VectorRendererPreset.new()
	_active_preset = _renderer_preset.normalized_copy()
	queue_redraw()

func _build_layer_buckets() -> Dictionary:
	var buckets: Dictionary = {}
	for state_variant in _trail_states.values():
		var state := state_variant as VectorTrailState
		if state == null:
			continue
		var layer: int = state.layer
		var states_for_layer: Array = buckets.get(layer, [])
		states_for_layer.append(state)
		buckets[layer] = states_for_layer
	return buckets

func _draw_layer(states: Array) -> void:
	for state_variant in states:
		var state := state_variant as VectorTrailState
		if state == null:
			continue
		if state.style == null:
			continue

		var sample_count := state.samples.size()
		for i in range(sample_count):
			var points: PackedVector2Array = state.samples[i]
			var energy: float = state.energies[i]
			var sample_motion_blend: float = state.motions[i] if i < state.motions.size() else 0.0
			var blur_factor := _compute_blur_factor(i, sample_count)

			if _active_preset.ghost_jitter_enabled and blur_factor > 0.0:
				points = _offset_points(points, _compute_jitter_offset(state, i, blur_factor, sample_motion_blend))

			_draw_beam(
				points,
				state.closed,
				state.draw_vertex_dots,
				state.style,
				energy,
				blur_factor
			)

func _compute_blur_factor(sample_index: int, sample_count: int) -> float:
	if sample_count <= 1:
		return 0.0
	# Older samples get larger blur to mimic phosphor smear.
	return 1.0 - (float(sample_index) / float(sample_count - 1))

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
	if _active_preset.retrace_dimming_enabled:
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

	if _active_preset.ghost_blur_enabled and blur_factor > 0.0:
		var blur_width_outer := style.beam_width_outer * lerpf(1.0, _active_preset.ghost_blur_width_scale, blur_factor)
		var blur_width_inner := style.beam_width_inner * lerpf(1.0, _active_preset.ghost_blur_width_scale * 0.75, blur_factor)
		var blur_alpha := _active_preset.ghost_blur_alpha_scale * blur_factor
		var blur_outer := Color(outer.r, outer.g, outer.b, outer.a * blur_alpha)
		var blur_inner := Color(inner.r, inner.g, inner.b, inner.a * blur_alpha * 0.65)
		_draw_polyline_with_factors(draw_points, blur_outer, blur_width_outer, point_factors)
		_draw_polyline_with_factors(draw_points, blur_inner, blur_width_inner, point_factors)

	_draw_polyline_with_factors(draw_points, inner, style.beam_width_inner, point_factors)

	if not draw_vertex_dots:
		return

	var dot_fade := maxf(0.0, 1.0 - blur_factor * _active_preset.ghost_dot_fade)
	var retrace_enabled := point_factors.size() == draw_points.size()

	for i in range(points.size()):
		var retrace_factor := 1.0
		if retrace_enabled:
			retrace_factor = point_factors[i]

		var dwell_factor := 1.0
		if _active_preset.corner_dwell_enabled:
			var corner_strength := _compute_corner_strength(points, i, closed)
			dwell_factor += _active_preset.corner_dwell_boost * pow(corner_strength, _active_preset.corner_dwell_power)

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

	if not _active_preset.outer_soft_blur_enabled or _active_preset.outer_soft_blur_passes <= 0 or _active_preset.outer_soft_blur_alpha_scale <= 0.0:
		_draw_polyline_with_factors(points, outer, outer_width, point_factors)
		return

	var core_width := maxf(0.5, outer_width * 0.68)
	var core_color := Color(outer.r, outer.g, outer.b, outer.a * 0.55)
	_draw_polyline_with_factors(points, core_color, core_width, point_factors)

	var mid_color := Color(outer.r, outer.g, outer.b, outer.a * 0.38)
	_draw_polyline_with_factors(points, mid_color, outer_width, point_factors)

	var blur_passes := maxi(1, _active_preset.outer_soft_blur_passes)
	var max_width := outer_width * (1.0 + _active_preset.outer_soft_blur_width_step)
	for pass_index in range(blur_passes):
		var t := float(pass_index + 1) / float(blur_passes)
		var width_t := pow(t, 0.75)
		var blur_width := lerpf(outer_width, max_width, width_t)
		var falloff := pow(1.0 - t, 1.6)
		var blur_alpha := outer.a * _active_preset.outer_soft_blur_alpha_scale * falloff
		if blur_alpha <= 0.0001:
			continue
		var blur_color := Color(outer.r, outer.g, outer.b, blur_alpha)
		_draw_polyline_with_factors(points, blur_color, blur_width, point_factors)

func _decay_trails(delta: float) -> void:
	var frame_decay_cache: Dictionary = {}
	for state_variant in _trail_states.values():
		var state := state_variant as VectorTrailState
		if state == null:
			continue
		var state_decay_alpha := clampf(state.decay_alpha, 0.0, 1.0)
		for i in range(state.energies.size()):
			var sample_decay_alpha := state_decay_alpha
			if _active_preset.two_stage_decay_enabled and state.energies[i] <= _active_preset.two_stage_knee_energy:
				sample_decay_alpha *= _active_preset.two_stage_tail_alpha_multiplier
			sample_decay_alpha = clampf(sample_decay_alpha, 0.0, 1.0)

			var frame_decay := float(frame_decay_cache.get(sample_decay_alpha, -1.0))
			if frame_decay < 0.0:
				frame_decay = pow(1.0 - sample_decay_alpha, delta * DECAY_REFERENCE_FPS)
				frame_decay_cache[sample_decay_alpha] = frame_decay

			state.energies[i] *= frame_decay

func _ingest_commands() -> void:
	for command in _submitted_commands:
		if command == null:
			continue

		var style := command.style if command.style != null else default_style
		if style == null:
			continue
		if command.points.size() < 2:
			continue

		var key := command.key
		var state := _trail_states.get(key) as VectorTrailState
		if state == null:
			state = VectorTrailState.new()

		var energy := _resolve_intensity(command.intensity)
		var layer := _resolve_layer(command.layer)
		var max_samples := _resolve_max_samples(command.max_trail_samples)
		var min_sample_motion := _resolve_min_sample_motion(command.min_sample_motion)
		var state_decay_alpha := _resolve_decay_alpha(command.decay_alpha, style)

		if command.trail_enabled:
			_ingest_trail_sample(state, command.points, energy, max_samples, min_sample_motion)
		else:
			state.reset_single_sample(command.points, energy)

		state.style = style
		state.command_key = key
		state.layer = layer
		state.closed = command.closed
		state.draw_vertex_dots = command.draw_vertex_dots
		state.trail_enabled = command.trail_enabled
		state.decay_alpha = state_decay_alpha
		_trail_states[key] = state

func _ingest_trail_sample(
	state: VectorTrailState,
	points: PackedVector2Array,
	energy: float,
	max_samples: int,
	min_sample_motion: float
) -> void:
	if state.samples.is_empty():
		state.append_sample(points, energy, 0.0, max_samples)
		state.motion_blend = 0.0
		return

	var last_points := state.samples[state.samples.size() - 1]
	var motion_distance := _centroid_distance(last_points, points)
	var target_blend := _compute_motion_blend(motion_distance)
	var smoothed_blend := lerpf(state.motion_blend, target_blend, _active_preset.ghost_jitter_motion_response)
	smoothed_blend = minf(smoothed_blend, state.motion_blend + _active_preset.ghost_jitter_max_rise_per_sample)

	if _points_are_near(last_points, points, min_sample_motion):
		# Keep head sample aligned with latest transform while still suppressing duplicates.
		state.refresh_last_sample(points, energy, smoothed_blend)
		return

	state.append_sample(points, energy, smoothed_blend, max_samples)

func _cleanup_dead_trails() -> void:
	var dead_keys: Array = []
	for key in _trail_states.keys():
		var state := _trail_states[key] as VectorTrailState
		if state == null:
			dead_keys.append(key)
			continue
		if not state.prune_dead_samples(TRAIL_ENERGY_CUTOFF):
			dead_keys.append(key)

	for key in dead_keys:
		_trail_states.erase(key)

func _resolve_intensity(raw_intensity: float) -> float:
	if is_nan(raw_intensity):
		return 1.0
	return maxf(0.0, raw_intensity)

func _resolve_layer(raw_layer: int) -> int:
	if raw_layer == VectorDrawCommand.LAYER_UNSET:
		return 0
	return raw_layer

func _resolve_max_samples(raw_max_samples: int) -> int:
	if raw_max_samples >= 1:
		return raw_max_samples
	return _active_preset.default_max_trail_samples

func _resolve_min_sample_motion(raw_min_sample_motion: float) -> float:
	if raw_min_sample_motion >= 0.0:
		return raw_min_sample_motion
	return _active_preset.default_min_sample_motion

func _resolve_decay_alpha(raw_decay_alpha: float, style: VectorStyle) -> float:
	if raw_decay_alpha >= 0.0:
		return clampf(raw_decay_alpha, 0.0, 1.0)
	if style != null:
		return clampf(style.decay_alpha, 0.0, 1.0)
	return _active_preset.decay_alpha

func _points_are_near(a: PackedVector2Array, b: PackedVector2Array, max_distance: float) -> bool:
	if a.size() != b.size():
		return false

	var max_dist_sq := max_distance * max_distance
	for i in range(a.size()):
		if a[i].distance_squared_to(b[i]) > max_dist_sq:
			return false
	return true

func _compute_jitter_offset(
	state: VectorTrailState,
	sample_index: int,
	blur_factor: float,
	sample_motion_blend: float
) -> Vector2:
	var motion_t := clampf(sample_motion_blend, 0.0, 1.0)
	var motion_scale := lerpf(_active_preset.ghost_jitter_stationary_scale, _active_preset.ghost_jitter_moving_scale, motion_t)
	var magnitude := _active_preset.ghost_jitter_pixels * blur_factor * _active_preset.ghost_jitter_age_scale * motion_scale
	if magnitude <= 0.0:
		return Vector2.ZERO

	var seed := float(abs(hash(state.command_key)) % HASH_SEED_MODULO) * HASH_SEED_SCALE
	var t := _time_accum * _active_preset.ghost_jitter_speed
	return Vector2(
		sin(t + seed + float(sample_index) * 0.73),
		cos(t * 1.17 + seed * 1.31 + float(sample_index) * 0.41)
	) * magnitude

func _compute_motion_blend(sample_motion: float) -> float:
	var min_motion := minf(_active_preset.ghost_jitter_motion_min, _active_preset.ghost_jitter_motion_max)
	var max_motion := maxf(_active_preset.ghost_jitter_motion_min, _active_preset.ghost_jitter_motion_max)
	if max_motion - min_motion < MOTION_RANGE_EPSILON:
		return 1.0 if sample_motion >= max_motion else 0.0
	return clampf((sample_motion - min_motion) / (max_motion - min_motion), 0.0, 1.0)

func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	shifted.resize(points.size())
	for i in range(points.size()):
		shifted[i] = points[i] + offset
	return shifted

func _centroid_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if a.is_empty() or b.is_empty():
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

	var ref_len := maxf(0.001, _active_preset.retrace_reference_length)
	for i in range(points.size() - 1):
		var seg_len := points[i].distance_to(points[i + 1])
		var over := maxf(0.0, (seg_len / ref_len) - 1.0)
		var dim := 1.0 / (1.0 + over * _active_preset.retrace_dimming_strength)
		factors[i] = minf(factors[i], dim)
		factors[i + 1] = minf(factors[i + 1], dim)

	return factors

func _draw_polyline_with_factors(
	points: PackedVector2Array,
	base_color: Color,
	width: float,
	point_factors: PackedFloat32Array
) -> void:
	if _active_preset.retrace_dimming_enabled and point_factors.size() == points.size():
		var colors := PackedColorArray()
		colors.resize(points.size())
		for i in range(points.size()):
			var factor := point_factors[i]
			colors[i] = Color(
				base_color.r * factor,
				base_color.g * factor,
				base_color.b * factor,
				base_color.a * factor
			)
		draw_polyline_colors(points, colors, width, true)
		return

	draw_polyline(points, base_color, width, true)

func _compute_corner_strength(points: PackedVector2Array, index: int, closed: bool) -> float:
	var count := points.size()
	if count < 2:
		return 0.0

	if not closed and (index == 0 or index == count - 1):
		return _active_preset.corner_endpoint_boost

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
	if v_in.length_squared() < VECTOR_LENGTH_EPSILON_SQ or v_out.length_squared() < VECTOR_LENGTH_EPSILON_SQ:
		return 0.0

	var turn_dot := clampf(v_in.normalized().dot(v_out.normalized()), -1.0, 1.0)
	var turn_angle := acos(turn_dot)
	return clampf(turn_angle / PI, 0.0, 1.0)
