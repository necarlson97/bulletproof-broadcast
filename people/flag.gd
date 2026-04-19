extends Node3D

const _ROCK_DEG: float = 10.0
const _HALF_CYCLE_SEC: float = 1.2


func _ready() -> void:
	var base_z: float = rotation_degrees.z
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees:z", base_z + _ROCK_DEG, _HALF_CYCLE_SEC)
	tween.tween_property(self, "rotation_degrees:z", base_z - _ROCK_DEG, _HALF_CYCLE_SEC)
