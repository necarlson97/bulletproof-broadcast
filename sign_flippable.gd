extends Sign
class_name SignFlippable

@onready var _flip_pivot: Node3D = $FlipPivot
@onready var _label_back: Label3D = $FlipPivot/LabelBack

var _good_text: String = ""
var _bad_text: String = ""
var _has_bad: bool = false
var _showing_bad: bool = false

var _flipping: bool = false
var _flip_tween: Tween


func _ready() -> void:
	super._ready()
	_label_back.visible = _has_bad


func set_text(text: String) -> void:
	_good_text = text
	if not _has_bad:
		super.set_text(text)
		if _label_back != null:
			_label_back.visible = false
	else:
		_apply_both_faces()


func _apply_both_faces() -> void:
	var inner_g: Vector2 = _measure_inner_for_string(_good_text)
	var inner_b: Vector2 = _measure_inner_for_string(_bad_text)
	var inner: Vector2 = Vector2(maxf(inner_g.x, inner_b.x), maxf(inner_g.y, inner_b.y))
	if inner.x <= 0.0 or inner.y <= 0.0:
		inner = Vector2(1.0, 1.0)
	var n_tex: int = maxi(maxi(_good_text.length(), _bad_text.length()), 1)

	_label.text = _good_text
	_label_back.text = _bad_text
	_label.font_size = _fixed_font_size
	_label_back.font_size = _fixed_font_size

	_apply_sign_geometry(inner, n_tex)
	var w: float = maxf(inner.x * _label.pixel_size, 0.01)
	_label.width = w
	_label_back.width = w
	_label_back.visible = _has_bad and not _bad_text.is_empty()


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
	scale = Vector3(1.0, 1.0, 1.0)
	_flip_pivot.rotation.y = 0.0
	set_text(_good_text)


func flip(flip_time: float = 1.0) -> bool:
	if not _has_bad:
		return false
	if _flipping:
		return false

	var target_y: float = PI if not _showing_bad else 0.0

	if flip_time <= 0.0:
		_flip_pivot.rotation.y = target_y
		_showing_bad = not _showing_bad
		return true

	if _flip_tween != null:
		_flip_tween.kill()

	_flipping = true
	var from_y: float = _flip_pivot.rotation.y
	_flip_tween = create_tween()
	(
		_flip_tween.tween_method(
			func(v: float) -> void:
				_flip_pivot.rotation.y = v,
			from_y,
			target_y,
			flip_time
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	_flip_tween.tween_callback(
		func() -> void:
			_showing_bad = not _showing_bad
			_flipping = false
			_flip_tween = null
	)
	return true
