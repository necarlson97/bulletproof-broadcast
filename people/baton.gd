extends Node3D

## Seconds for one full revolution around local Z.
const _SPIN_PERIOD_SEC: float = 2.5


func _ready() -> void:
	# Ragdoll duplicates this node under RigidBody3D; do not re-run spin on corpse pieces.
	if get_parent() is RigidBody3D:
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(self, "rotation:z", TAU, _SPIN_PERIOD_SEC).as_relative().set_trans(Tween.TRANS_LINEAR)
