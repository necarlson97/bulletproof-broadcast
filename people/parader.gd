extends "res://people/person.gd"
class_name Parader

@export var _SHIRT_LOYAL_A := Color("#444A32")
@export var _SHIRT_LOYAL_B := Color("#2E3A3F")
const _SHIRT_DISLOYAL_A := Color("#444A32")
const _SHIRT_DISLOYAL_B := Color("#3F2E2E")

## Horizontal slack before the parader walks to catch the line (parade local XZ).
const _COMFORT_DIST_MIN: float = 60.0
const _COMFORT_DIST_MAX: float = 80.0
## Body-only bounce while walking (see spectator bounce; applied to [member Body] only).
const _WALK_BODY_BOUNCE_HALF_DUR: float = 0.12
const _WALK_BODY_BOUNCE_HEIGHT: float = 2.0
## Time to tween back onto the formation target once outside the comfort zone.
const _COMFORT_CORRECT_SEC: float = 0.5

var loyal: bool = true
## March Z at which this parader auto-flips (SignFlippable). `INF` = no scheduled flip.
var flip_at_z: float = INF

var _march_flip_done: bool = false
var _prev_z_for_flip: float = NAN

var _parade_march_follow: bool = false
## Formation goal in parade-line local space (XZ); [ParadeLine] sets via [method set_parade_target] / [method set_parade_line_z].
var _target_x: float = 0.0
var _target_z: float = 0.0
var _comfort_radius: float = 45.0
var _comfort_corr_active: bool = false
var _comfort_corr_elapsed: float = 0.0
var _comfort_corr_start_pos: Vector3 = Vector3.ZERO

@export var start_text: String = ""

@onready var _body: Sprite3D = $Body
var _body_bounce_base_y: float = 0.0
var _march_needs_walk_bounce: bool = false


func _ready() -> void:
	add_to_group("parader")
	_body_bounce_base_y = _body.position.y
	_walk_bounce_driver()
	if start_text != "":
		var sign: Sign = $SignScale/Sign
		sign.set_text(start_text)

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


## Full formation target (column X and line Z). Does not move the node — [method _process] uses comfort + tween.
func set_parade_target(target_x: float, target_z: float) -> void:
	_target_x = target_x
	_target_z = target_z
	_parade_march_follow = true


## Updates only line Z (march path); keeps current target X from the last [method set_parade_target].
func set_parade_line_z(line_z: float) -> void:
	_target_z = line_z


func clear_parade_march_follow() -> void:
	_parade_march_follow = false
	_march_needs_walk_bounce = false
	_comfort_corr_active = false
	if is_instance_valid(_body):
		_body.position.y = _body_bounce_base_y


func _process(delta: float) -> void:
	if _parade_march_follow:
		var dist_xz: float = Vector2(position.x - _target_x, position.z - _target_z).length()
		if dist_xz <= _comfort_radius:
			_comfort_corr_active = false
			_march_needs_walk_bounce = false
		else:
			if not _comfort_corr_active:
				_comfort_corr_active = true
				_comfort_corr_elapsed = 0.0
				_comfort_corr_start_pos = position
			_comfort_corr_elapsed += delta
			var t: float = minf(1.0, _comfort_corr_elapsed / _COMFORT_CORRECT_SEC)
			var ideal_now: Vector3 = Vector3(_target_x, _comfort_corr_start_pos.y, _target_z)
			position = _comfort_corr_start_pos.lerp(ideal_now, t)
			if t >= 1.0:
				_comfort_corr_active = false
				position.x = _target_x
				position.z = _target_z
			_march_needs_walk_bounce = true

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
