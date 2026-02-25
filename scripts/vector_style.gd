class_name VectorStyle
extends Resource

@export_range(0.0, 128.0, 0.1) var beam_width_outer: float = 19.0
@export_range(0.0, 64.0, 0.1) var beam_width_inner: float = 1.0
@export_range(0.0, 64.0, 0.1) var vertex_dot_radius: float = 3.1
@export_range(0.0, 1.0, 0.001) var decay_alpha: float = 0.03
@export var beam_color_outer: Color = Color(0.8, 0.8, 0.8, 0.20)
@export var beam_color_inner: Color = Color(3.6, 3.6, 3.6, 1.0)
@export var vertex_dot_color: Color = Color(6.0, 6.0, 6.0, 1.0)
