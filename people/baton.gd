extends Node3D

@onready var _sprite: Sprite3D = $SpriteBaton

## Seconds for one full revolution around local Z.
const _SPIN_PERIOD_SEC: float = 2.5


func _ready() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_sprite, "rotation:z", TAU, _SPIN_PERIOD_SEC).as_relative().set_trans(Tween.TRANS_LINEAR)
