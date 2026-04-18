extends "res://sign.gd"

var _good_text: String = ""
var _bad_text: String = ""
var _has_bad: bool = false
var _showing_bad: bool = false

var _flipping: bool = false
var _flip_tween: Tween

## Horizontal flip multiplier for layout (±1 at rest). Animated through 0 during flip.
var _sign_bg_flip_x: float = 1.0
## Last layout scale from set_text() before applying _sign_bg_flip_x.
var _base_sign_scale: Vector2 = Vector2.ONE

var _flip_anim_start_m: float = 1.0
var _flip_anim_end_m: float = -1.0


func set_text(text: String) -> void:
	super.set_text(text)
	_base_sign_scale = _sign_bg.scale
	_apply_sign_bg_flip()


func set_contents(good_text: String, bad_text: Variant = null) -> void:
	if _flip_tween != null:
		_flip_tween.kill()
		_flip_tween = null
	_flipping = false

	_good_text = good_text
	if bad_text == null:
		_has_bad = false
		_bad_text = ""
	else:
		_has_bad = true
		_bad_text = str(bad_text)

	_showing_bad = false
	scale = Vector2(1.0, 1.0)
	_sign_bg_flip_x = 1.0
	_panel.scale = Vector2(1.0, 1.0)
	set_text(_good_text)


func flip(flip_time: float = 1.0) -> bool:
	if not _has_bad:
		return false
	if _flipping:
		return false

	if flip_time <= 0.0:
		_showing_bad = not _showing_bad
		_sign_bg_flip_x = -1.0 if _showing_bad else 1.0
		set_text(_bad_text if _showing_bad else _good_text)
		_panel.scale = Vector2(1.0, 1.0)
		return true

	if _flip_tween != null:
		_flip_tween.kill()

	_flipping = true
	var half: float = flip_time * 0.5
	_flip_anim_start_m = _sign_bg_flip_x
	if absf(_flip_anim_start_m) < 0.0001:
		_flip_anim_start_m = 1.0
	_flip_anim_end_m = -_flip_anim_start_m

	_flip_tween = create_tween()
	_flip_tween.tween_method(_flip_first_half_progress, 0.0, 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip_tween.tween_callback(_on_flip_midpoint)
	_flip_tween.tween_method(_flip_second_half_progress, 0.0, 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_callback(_finish_flip)
	return true


func _apply_sign_bg_flip() -> void:
	_sign_bg.scale = Vector2(_base_sign_scale.x * _sign_bg_flip_x, _base_sign_scale.y)


func _set_sign_flip_m(m: float) -> void:
	_sign_bg_flip_x = m
	_sign_bg.scale = Vector2(_base_sign_scale.x * m, _base_sign_scale.y)


func _flip_first_half_progress(t: float) -> void:
	var m: float = lerpf(_flip_anim_start_m, 0.0, t)
	var px: float = lerpf(1.0, 0.0, t)
	_set_sign_flip_m(m)
	_panel.scale.x = px
	_panel.scale.y = 1.0


func _flip_second_half_progress(t: float) -> void:
	var m: float = lerpf(0.0, _flip_anim_end_m, t)
	var px: float = lerpf(0.0, 1.0, t)
	_set_sign_flip_m(m)
	_panel.scale.x = px
	_panel.scale.y = 1.0


func _on_flip_midpoint() -> void:
	_showing_bad = not _showing_bad
	set_text(_bad_text if _showing_bad else _good_text)


func _finish_flip() -> void:
	_sign_bg_flip_x = _flip_anim_end_m
	_set_sign_flip_m(_flip_anim_end_m)
	_panel.scale = Vector2(1.0, 1.0)
	_flipping = false
	_flip_tween = null
