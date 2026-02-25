class_name VectorRendererPreset
extends Resource

@export_range(0.0, 1.0, 0.001) var decay_alpha: float = 0.03
@export_range(1, 4096, 1) var default_max_trail_samples: int = 180
@export_range(0.0, 64.0, 0.001) var default_min_sample_motion: float = 0.01

@export var outer_soft_blur_enabled: bool = true
@export_range(0, 16, 1) var outer_soft_blur_passes: int = 3
@export_range(0.0, 8.0, 0.01) var outer_soft_blur_width_step: float = 0.65
@export_range(0.0, 1.0, 0.001) var outer_soft_blur_alpha_scale: float = 0.22

@export var ghost_blur_enabled: bool = true
@export_range(0.0, 10.0, 0.01) var ghost_blur_width_scale: float = 2.8
@export_range(0.0, 1.0, 0.001) var ghost_blur_alpha_scale: float = 0.20
@export_range(0.0, 1.0, 0.01) var ghost_dot_fade: float = 0.85

@export var ghost_jitter_enabled: bool = true
@export_range(0.0, 12.0, 0.01) var ghost_jitter_pixels: float = 0.8
@export_range(0.0, 20.0, 0.01) var ghost_jitter_speed: float = 1.9
@export_range(0.0, 8.0, 0.01) var ghost_jitter_age_scale: float = 1.0
@export_range(0.0, 8.0, 0.01) var ghost_jitter_stationary_scale: float = 0.18
@export_range(0.0, 8.0, 0.01) var ghost_jitter_moving_scale: float = 1.25
@export_range(0.0, 64.0, 0.01) var ghost_jitter_motion_min: float = 2.0
@export_range(0.0, 64.0, 0.01) var ghost_jitter_motion_max: float = 18.0
@export_range(0.01, 1.0, 0.01) var ghost_jitter_motion_response: float = 0.22
@export_range(0.0, 1.0, 0.01) var ghost_jitter_max_rise_per_sample: float = 0.08

@export var corner_dwell_enabled: bool = true
@export_range(0.0, 8.0, 0.01) var corner_dwell_boost: float = 1.35
@export_range(0.01, 8.0, 0.01) var corner_dwell_power: float = 1.2
@export_range(0.0, 2.0, 0.01) var corner_endpoint_boost: float = 0.10

@export var retrace_dimming_enabled: bool = true
@export_range(0.001, 4096.0, 0.01) var retrace_reference_length: float = 32.0
@export_range(0.0, 0.20, 0.001) var retrace_dimming_strength: float = 0.03

@export var two_stage_decay_enabled: bool = true
@export_range(0.0, 1.0, 0.001) var two_stage_knee_energy: float = 0.22
@export_range(0.0, 1.0, 0.001) var two_stage_tail_alpha_multiplier: float = 0.35

@export var background_color: Color = Color(0, 0, 0, 1)

func normalized_copy() -> VectorRendererPreset:
	var normalized := VectorRendererPreset.new()

	normalized.decay_alpha = clampf(decay_alpha, 0.0, 1.0)
	normalized.default_max_trail_samples = maxi(1, default_max_trail_samples)
	normalized.default_min_sample_motion = maxf(0.0, default_min_sample_motion)

	normalized.outer_soft_blur_enabled = outer_soft_blur_enabled
	normalized.outer_soft_blur_passes = maxi(0, outer_soft_blur_passes)
	normalized.outer_soft_blur_width_step = maxf(0.0, outer_soft_blur_width_step)
	normalized.outer_soft_blur_alpha_scale = maxf(0.0, outer_soft_blur_alpha_scale)

	normalized.ghost_blur_enabled = ghost_blur_enabled
	normalized.ghost_blur_width_scale = maxf(0.0, ghost_blur_width_scale)
	normalized.ghost_blur_alpha_scale = maxf(0.0, ghost_blur_alpha_scale)
	normalized.ghost_dot_fade = clampf(ghost_dot_fade, 0.0, 1.0)

	normalized.ghost_jitter_enabled = ghost_jitter_enabled
	normalized.ghost_jitter_pixels = maxf(0.0, ghost_jitter_pixels)
	normalized.ghost_jitter_speed = maxf(0.0, ghost_jitter_speed)
	normalized.ghost_jitter_age_scale = maxf(0.0, ghost_jitter_age_scale)
	normalized.ghost_jitter_stationary_scale = maxf(0.0, ghost_jitter_stationary_scale)
	normalized.ghost_jitter_moving_scale = maxf(0.0, ghost_jitter_moving_scale)
	normalized.ghost_jitter_motion_min = maxf(0.0, ghost_jitter_motion_min)
	normalized.ghost_jitter_motion_max = maxf(0.0, ghost_jitter_motion_max)
	normalized.ghost_jitter_motion_response = clampf(ghost_jitter_motion_response, 0.01, 1.0)
	normalized.ghost_jitter_max_rise_per_sample = maxf(0.0, ghost_jitter_max_rise_per_sample)

	normalized.corner_dwell_enabled = corner_dwell_enabled
	normalized.corner_dwell_boost = maxf(0.0, corner_dwell_boost)
	normalized.corner_dwell_power = maxf(0.01, corner_dwell_power)
	normalized.corner_endpoint_boost = maxf(0.0, corner_endpoint_boost)

	normalized.retrace_dimming_enabled = retrace_dimming_enabled
	normalized.retrace_reference_length = maxf(0.001, retrace_reference_length)
	normalized.retrace_dimming_strength = maxf(0.0, retrace_dimming_strength)

	normalized.two_stage_decay_enabled = two_stage_decay_enabled
	normalized.two_stage_knee_energy = clampf(two_stage_knee_energy, 0.0, 1.0)
	normalized.two_stage_tail_alpha_multiplier = clampf(two_stage_tail_alpha_multiplier, 0.0, 1.0)

	normalized.background_color = background_color
	return normalized
