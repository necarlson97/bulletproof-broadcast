extends "res://people/person.gd"

## Idle crowd reaction level; drives bounce rate, bounce height, hand waggle, and hand height.
@export_range(0.0, 1.0) var excitement: float = 0.2

const _BOUNCE_HALF_DURATION: float = 0.2

## Shot reaction: delay before bounce scales from 0s at the origin to this many seconds at `_SHOT_REACTION_DIST_MAX`.
const _SHOT_REACTION_DELAY_MAX_SEC: float = 0.2
const _SHOT_REACTION_DIST_MAX: float = 1000.0

const _HAND_L_BASE_X: float = -14.4
const _HAND_R_BASE_X: float = 14.7

@onready var _hand_l: Sprite3D = $HandL
@onready var _hand_r: Sprite3D = $HandR

var _bounce_base_y: float = 0.0
var _wiggle_off_l: Vector2 = Vector2.ZERO
var _wiggle_off_r: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("spectator")
	_bounce_base_y = position.y
	_bounce_loop()
	_wiggle_loop()


func jump_on_shot() -> void:
	var dist: float = global_position.distance_to(Vector3.ZERO)
	var t: float = clampf(dist / _SHOT_REACTION_DIST_MAX, 0.0, 1.0)
	var delay_sec: float = lerpf(0.0, _SHOT_REACTION_DELAY_MAX_SEC, t)
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout
	await _bounce_once(50.0)


func _process(_delta: float) -> void:
	var e: float = clampf(excitement, 0.0, 1.0)
	var hand_y: float = lerpf(15.0, 35.0, e)
	_hand_l.position = Vector3(_HAND_L_BASE_X + _wiggle_off_l.x, hand_y + _wiggle_off_l.y, 0.0)
	_hand_r.position = Vector3(_HAND_R_BASE_X + _wiggle_off_r.x, hand_y + _wiggle_off_r.y, 0.0)


func _random_offset_in_disk(radius: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var a: float = randf() * TAU
	var d: float = sqrt(randf()) * radius
	return Vector2(cos(a) * d, sin(a) * d)


func _wiggle_loop() -> void:
	while is_inside_tree():
		var e: float = clampf(excitement, 0.0, 1.0)
		var r: float = lerpf(0.0, 6.0, e)

		var target_l: Vector2 = _random_offset_in_disk(r)
		var target_r: Vector2 = _random_offset_in_disk(r)
		var dur: float = lerpf(0.2, 0.1, e)
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "_wiggle_off_l", target_l, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(self, "_wiggle_off_r", target_r, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished


func _bounce_loop() -> void:
	while is_inside_tree():
		var e: float = clampf(excitement, 0.0, 1.0)
		var t_min: float = lerpf(4.0, 0.4, e)
		var t_max: float = lerpf(6.0, 0.6, e)
		await get_tree().create_timer(randf_range(t_min, t_max)).timeout
		if not is_inside_tree():
			return
		await _bounce_once()


func _bounce_once(max_height=15.0) -> void:
	var e: float = clampf(excitement, 0.0, 1.0)
	var height: float = lerpf(5.0, max_height, e)
	var up: Tween = create_tween()
	up.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_property(self, "position:y", _bounce_base_y + height, _BOUNCE_HALF_DURATION)
	await up.finished
	if not is_inside_tree():
		return
	var down: Tween = create_tween()
	down.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	down.tween_property(self, "position:y", _bounce_base_y, _BOUNCE_HALF_DURATION)
	await down.finished
