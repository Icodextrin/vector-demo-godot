class_name VectorTrailState
extends RefCounted

var style: VectorStyle
var command_key: String = ""
var layer: int = 0
var closed: bool = false
var draw_vertex_dots: bool = true
var trail_enabled: bool = true
var decay_alpha: float = 0.03
var motion_blend: float = 0.0

var samples: Array[PackedVector2Array] = []
var energies: Array[float] = []
var motions: Array[float] = []

func reset_single_sample(points: PackedVector2Array, energy: float) -> void:
	samples = [points]
	energies = [energy]
	motions = [0.0]
	motion_blend = 0.0

func refresh_last_sample(points: PackedVector2Array, energy: float, motion: float) -> void:
	if samples.is_empty():
		append_sample(points, energy, motion, 1)
		return

	var last_index := samples.size() - 1
	samples[last_index] = points
	energies[last_index] = maxf(energies[last_index], energy)
	if last_index < motions.size():
		motions[last_index] = motion
	motion_blend = motion

func append_sample(points: PackedVector2Array, energy: float, motion: float, max_samples: int) -> void:
	samples.append(points)
	energies.append(energy)
	motions.append(motion)
	motion_blend = motion

	var safe_max_samples := maxi(1, max_samples)
	while samples.size() > safe_max_samples:
		samples.remove_at(0)
		energies.remove_at(0)
		motions.remove_at(0)

func prune_dead_samples(min_energy: float) -> bool:
	var keep_samples: Array[PackedVector2Array] = []
	var keep_energies: Array[float] = []
	var keep_motions: Array[float] = []

	for i in range(samples.size()):
		if energies[i] <= min_energy:
			continue
		keep_samples.append(samples[i])
		keep_energies.append(energies[i])
		keep_motions.append(motions[i] if i < motions.size() else 0.0)

	samples = keep_samples
	energies = keep_energies
	motions = keep_motions
	if not motions.is_empty():
		motion_blend = motions[motions.size() - 1]
	else:
		motion_blend = 0.0

	return not samples.is_empty()
