extends "res://person.gd"

## Idle crowd reaction level; drives bounce rate, bounce height, hand orbit, and hand height.
@export_range(0.0, 1.0) var excitement: float = 0.5

const _BOUNCE_HALF_DURATION: float = 0.2

const _HAND_L_BASE_X: float = -14.4
const _HAND_R_BASE_X: float = 14.7

@onready var _hand_l: Sprite3D = $HandL
@onready var _hand_r: Sprite3D = $HandR

var _bounce_base_y: float = 0.0
var _wiggle_angle: float = 0.0


func _ready() -> void:
	_bounce_base_y = position.y
	_bounce_loop()


func _process(delta: float) -> void:
	var e: float = clampf(excitement, 0.0, 1.0)
	var r: float = lerpf(0.0, 20.0, e)
	var hand_y: float = lerpf(15.0, 35.0, e)
	var spin: float = lerpf(0.0, 10.0, e)
	_wiggle_angle += spin * delta
	var ox: float = cos(_wiggle_angle) * r
	var oy: float = sin(_wiggle_angle) * r
	_hand_l.position = Vector3(_HAND_L_BASE_X + ox, hand_y + oy, 0.0)
	_hand_r.position = Vector3(_HAND_R_BASE_X + ox, hand_y + oy, 0.0)


func _bounce_loop() -> void:
	while is_inside_tree():
		var e: float = clampf(excitement, 0.0, 1.0)
		var t_min: float = lerpf(4.0, 0.4, e)
		var t_max: float = lerpf(6.0, 0.6, e)
		await get_tree().create_timer(randf_range(t_min, t_max)).timeout
		if not is_inside_tree():
			return
		await _bounce_once()


func _bounce_once() -> void:
	var e: float = clampf(excitement, 0.0, 1.0)
	var height: float = lerpf(10.0, 50.0, e)
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
