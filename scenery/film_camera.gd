extends Node3D

@onready var _wheel: Sprite3D = $Wheel

## Seconds for one full revolution.
const _ROTATION_PERIOD_SEC: float = 10.0


func _ready() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_wheel, "rotation:z", -TAU, _ROTATION_PERIOD_SEC).as_relative().set_trans(Tween.TRANS_LINEAR)
