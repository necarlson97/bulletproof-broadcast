extends "res://person.gd"
class_name Parader

const _SHIRT_LOYAL_A := Color("#444A32")
const _SHIRT_LOYAL_B := Color("#2E3A3F")
const _SHIRT_DISLOYAL_A := Color("#5A3232")
const _SHIRT_DISLOYAL_B := Color("#3F2E2E")

@onready var _sign: SignFlippable = $Sign
@onready var _digit_label: Label3D = $Body/Label3D

var loyal: bool = true


func _enter_tree() -> void:
	_apply_shirt_colors()


func _apply_shirt_colors() -> void:
	if loyal:
		$PersonColor.shirt_start = _SHIRT_LOYAL_A
		$PersonColor.shirt_end = _SHIRT_LOYAL_B
	else:
		$PersonColor.shirt_start = _SHIRT_DISLOYAL_A
		$PersonColor.shirt_end = _SHIRT_DISLOYAL_B


func configure_parader(front: String, back: Variant, loyal_flag: bool, digit: String) -> void:
	loyal = loyal_flag
	_apply_shirt_colors()
	if back == null or str(back).is_empty():
		_sign.set_contents(front, null)
	else:
		_sign.set_contents(front, back)
	_digit_label.text = digit
	_digit_label.visible = not digit.is_empty()
