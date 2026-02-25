class_name VectorDrawCommand
extends RefCounted

const LAYER_UNSET := -2147483648

var key: String = ""
var points: PackedVector2Array = PackedVector2Array()
var style: VectorStyle
var intensity: float = NAN
var layer: int = LAYER_UNSET
var closed: bool = false
var draw_vertex_dots: bool = true
var trail_enabled: bool = true
var max_trail_samples: int = -1
var decay_alpha: float = -1.0
var min_sample_motion: float = -1.0

static func from_variant(data: Variant) -> VectorDrawCommand:
	if data is VectorDrawCommand:
		return data as VectorDrawCommand
	if data is Dictionary:
		return from_dictionary(data as Dictionary)
	return null

static func from_dictionary(data: Dictionary) -> VectorDrawCommand:
	if not data.has("points"):
		return null

	if not (data.points is PackedVector2Array):
		return null

	var command := VectorDrawCommand.new()
	if data.has("key"):
		command.key = str(data.key)
	command.points = data.points as PackedVector2Array
	if data.has("style"):
		command.style = data.style as VectorStyle
	if data.has("intensity"):
		command.intensity = float(data.intensity)
	if data.has("layer"):
		command.layer = int(data.layer)
	if data.has("closed"):
		command.closed = bool(data.closed)
	if data.has("draw_vertex_dots"):
		command.draw_vertex_dots = bool(data.draw_vertex_dots)
	if data.has("trail_enabled"):
		command.trail_enabled = bool(data.trail_enabled)
	if data.has("max_trail_samples"):
		command.max_trail_samples = int(data.max_trail_samples)
	if data.has("decay_alpha"):
		command.decay_alpha = float(data.decay_alpha)
	if data.has("min_sample_motion"):
		command.min_sample_motion = float(data.min_sample_motion)
	return command
