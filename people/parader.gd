extends "res://people/person.gd"
class_name Parader

const _SHIRT_LOYAL_A := Color("#444A32")
const _SHIRT_LOYAL_B := Color("#2E3A3F")
const _SHIRT_DISLOYAL_A := Color("#5A3232")
const _SHIRT_DISLOYAL_B := Color("#3F2E2E")

## Horizontal slack before the parader walks to catch the line (parade local XZ).
const _COMFORT_DIST_MIN: float = 30.0
const _COMFORT_DIST_MAX: float = 60.0
## Body-only bounce while walking (see spectator bounce; applied to [member Body] only).
const _WALK_BODY_BOUNCE_HALF_DUR: float = 0.12
const _WALK_BODY_BOUNCE_HEIGHT: float = 5.0

var loyal: bool = true
## March Z at which this parader auto-flips (SignFlippable). `INF` = no scheduled flip.
var flip_at_z: float = INF

var _march_flip_done: bool = false
var _prev_z_for_flip: float = NAN

var _parade_march_follow: bool = false
var _parade_target_x: float = 0.0
var _parade_march_target_z: float = 0.0
var _line_marching_speed: float = 300.0
var _comfort_radius: float = 45.0

@onready var _body: Sprite3D = $Body
var _body_bounce_base_y: float = 0.0
var _march_needs_walk_bounce: bool = false


func _ready() -> void:
	add_to_group("parader")
	_body_bounce_base_y = _body.position.y
	_walk_bounce_driver()


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
	_comfort_radius = randf_range(_COMFORT_DIST_MIN, _COMFORT_DIST_MAX)
	set_process(true)
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


## Called by [ParadeLine] after horizontal layout so march slack is relative to the line column.
func set_parade_column_x(column_x: float) -> void:
	_parade_target_x = column_x
	_parade_march_follow = true


func set_parade_march_speed(line_speed: float) -> void:
	_line_marching_speed = maxf(line_speed, 0.001)


func set_parade_march_target_z(line_z: float) -> void:
	_parade_march_target_z = line_z


func clear_parade_march_follow() -> void:
	_parade_march_follow = false
	_march_needs_walk_bounce = false
	if is_instance_valid(_body):
		_body.position.y = _body_bounce_base_y


func _walk_speed() -> float:
	# Faster than the line so lagging paraders can close the gap.
	return maxf(_line_marching_speed * 1.5, _line_marching_speed + 120.0)


func _process(delta: float) -> void:
	if _parade_march_follow:
		var ideal: Vector3 = Vector3(_parade_target_x, position.y, _parade_march_target_z)
		var dist_xz: float = Vector2(position.x - _parade_target_x, position.z - _parade_march_target_z).length()
		if dist_xz > _comfort_radius:
			position = position.move_toward(ideal, _walk_speed() * delta)
		else:
			position.x = _parade_target_x
			position.z = _parade_march_target_z
		var dist_after: float = Vector2(position.x - _parade_target_x, position.z - _parade_march_target_z).length()
		_march_needs_walk_bounce = dist_after > _comfort_radius

	if _march_flip_done or is_inf(flip_at_z):
		return
	var z: float = position.z
	if is_nan(_prev_z_for_flip):
		_prev_z_for_flip = z
		return
	if _crossed_march_z(_prev_z_for_flip, z, flip_at_z):
		_march_flip_done = true
		var flippable: SignFlippable = $SignScale/Sign as SignFlippable
		flippable.flip()
		return
	_prev_z_for_flip = z


func _walk_bounce_driver() -> void:
	while is_inside_tree():
		while is_inside_tree() and not _march_needs_walk_bounce:
			await get_tree().process_frame
		while is_inside_tree() and _march_needs_walk_bounce:
			var up: Tween = create_tween()
			up.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			up.tween_property(_body, "position:y", _body_bounce_base_y + _WALK_BODY_BOUNCE_HEIGHT, _WALK_BODY_BOUNCE_HALF_DUR)
			await up.finished
			if not is_inside_tree():
				return
			var down: Tween = create_tween()
			down.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			down.tween_property(_body, "position:y", _body_bounce_base_y, _WALK_BODY_BOUNCE_HALF_DUR)
			await down.finished
		if is_inside_tree():
			_body.position.y = _body_bounce_base_y


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
