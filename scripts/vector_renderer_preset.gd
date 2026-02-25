class_name VectorRendererPreset
extends Resource

@export_range(0.0, 1.0, 0.001) var decay_alpha: float = 0.03
@export var default_max_trail_samples: int = 180
@export var default_min_sample_motion: float = 0.01

@export var outer_soft_blur_enabled: bool = true
@export var outer_soft_blur_passes: int = 3
@export var outer_soft_blur_width_step: float = 0.65
@export var outer_soft_blur_alpha_scale: float = 0.22

@export var ghost_blur_enabled: bool = true
@export var ghost_blur_width_scale: float = 2.8
@export var ghost_blur_alpha_scale: float = 0.20
@export_range(0.0, 1.0, 0.01) var ghost_dot_fade: float = 0.85

@export var ghost_jitter_enabled: bool = true
@export var ghost_jitter_pixels: float = 0.8
@export var ghost_jitter_speed: float = 1.9
@export var ghost_jitter_age_scale: float = 1.0
@export var ghost_jitter_stationary_scale: float = 0.18
@export var ghost_jitter_moving_scale: float = 1.25
@export var ghost_jitter_motion_min: float = 2.0
@export var ghost_jitter_motion_max: float = 18.0
@export_range(0.01, 1.0, 0.01) var ghost_jitter_motion_response: float = 0.22
@export_range(0.0, 1.0, 0.01) var ghost_jitter_max_rise_per_sample: float = 0.08

@export var corner_dwell_enabled: bool = true
@export var corner_dwell_boost: float = 1.35
@export var corner_dwell_power: float = 1.2
@export var corner_endpoint_boost: float = 0.10

@export var retrace_dimming_enabled: bool = true
@export var retrace_reference_length: float = 32.0
@export_range(0.0, 0.20, 0.001) var retrace_dimming_strength: float = 0.03

@export var two_stage_decay_enabled: bool = true
@export_range(0.0, 1.0, 0.001) var two_stage_knee_energy: float = 0.22
@export_range(0.0, 1.0, 0.001) var two_stage_tail_alpha_multiplier: float = 0.35

@export var background_color: Color = Color(0, 0, 0, 1)
