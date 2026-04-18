extends "res://people/person.gd"
class_name Parader

const _SHIRT_LOYAL_A := Color("#444A32")
const _SHIRT_LOYAL_B := Color("#2E3A3F")
const _SHIRT_DISLOYAL_A := Color("#5A3232")
const _SHIRT_DISLOYAL_B := Color("#3F2E2E")

var loyal: bool = true
## March Z at which this parader auto-flips (SignFlippable). `INF` = no scheduled flip.
var flip_at_z: float = INF

var _march_flip_done: bool = false
var _prev_z_for_flip: float = NAN


func _enter_tree() -> void:
	_apply_shirt_colors()


func _apply_shirt_colors() -> void:
	if loyal:
		$PersonColor.shirt_start = _SHIRT_LOYAL_A
		$PersonColor.shirt_end = _SHIRT_LOYAL_B
	else:
		$PersonColor.shirt_start = _SHIRT_DISLOYAL_A
		$PersonColor.shirt_end = _SHIRT_DISLOYAL_B


func configure_parader(front: String, back: Variant, loyal_flag: bool, digit: String, p_flip_at_z: float = INF) -> void:
	loyal = loyal_flag
	flip_at_z = p_flip_at_z
	_march_flip_done = false
	_prev_z_for_flip = NAN
	set_process(not is_inf(flip_at_z))
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


func _process(_delta: float) -> void:
	if _march_flip_done or is_inf(flip_at_z):
		return
	var z: float = position.z
	if is_nan(_prev_z_for_flip):
		_prev_z_for_flip = z
		return
	if _crossed_march_z(_prev_z_for_flip, z, flip_at_z):
		_march_flip_done = true
		set_process(false)
		var flippable: SignFlippable = $SignScale/Sign as SignFlippable
		flippable.flip()
		return
	_prev_z_for_flip = z


func _crossed_march_z(prev_z: float, cur_z: float, threshold: float) -> bool:
	if is_equal_approx(prev_z, cur_z):
		return false
	var increasing: bool = true
	var parent_line: Node = get_parent()
	if parent_line != null:
		var sz: Variant = parent_line.get("start_z")
		var ez: Variant = parent_line.get("end_z")
		if sz != null and ez != null:
			increasing = float(ez) > float(sz)
	if increasing:
		return prev_z < threshold and cur_z >= threshold
	return prev_z > threshold and cur_z <= threshold


func get_sign_half_width() -> float:
	var scale_n: Node3D = $SignScale as Node3D
	var sn: Node3D = $SignScale/Sign as Node3D
	var board: Sign = sn as Sign
	var w: float = board.get_layout_width() * absf(scale_n.scale.x) * absf(sn.scale.x)
	return w * 0.5
