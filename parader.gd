extends "res://person.gd"
class_name Parader

const _SHIRT_LOYAL_A := Color("#444A32")
const _SHIRT_LOYAL_B := Color("#2E3A3F")
const _SHIRT_DISLOYAL_A := Color("#5A3232")
const _SHIRT_DISLOYAL_B := Color("#3F2E2E")

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
	# Parent may call before our _ready(); @onready is not set yet.
	var flippable: SignFlippable = $SignScale/Sign as SignFlippable
	if back == null or str(back).is_empty():
		flippable.set_contents(front, null)
	else:
		flippable.set_contents(front, back)
	var digit_label: Label3D = $Body/Label3D as Label3D
	digit_label.text = digit
	digit_label.visible = not digit.is_empty()


func get_sign_half_width() -> float:
	var scale_n: Node3D = $SignScale as Node3D
	var sn: Node3D = $SignScale/Sign as Node3D
	var board: Sign = sn as Sign
	var w: float = board.get_layout_width() * absf(scale_n.scale.x) * absf(sn.scale.x)
	return w * 0.5
