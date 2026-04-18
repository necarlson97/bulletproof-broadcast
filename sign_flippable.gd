extends Sign
class_name SignFlippable

var _front_text: String = ""
var _back_text: String = ""
var _has_back: bool = false
var _showing_back: bool = false

var _flipping: bool = false
var _flip_tween: Tween


func _pivot() -> Node3D:
	return $FlipPivot as Node3D


func _lbl_back() -> Label3D:
	return $FlipPivot/LabelBack as Label3D


func _ready() -> void:
	super._ready()
	_lbl_back().visible = _has_back


func set_text(text: String) -> void:
	_front_text = text
	if not _has_back:
		super.set_text(text)
		_lbl_back().visible = false
	else:
		_apply_both_faces()


func _apply_both_faces() -> void:
	if _fixed_font_size <= 0:
		var l: Label3D = $FlipPivot/Label3D as Label3D
		_fixed_font_size = l.font_size
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var inner_front: Vector2 = _measure_inner_for_string(_front_text)
	var inner_back: Vector2 = _measure_inner_for_string(_back_text)
	var inner: Vector2 = Vector2(maxf(inner_front.x, inner_back.x), maxf(inner_front.y, inner_back.y))
	if inner.x <= 0.0 or inner.y <= 0.0:
		inner = Vector2(1.0, 1.0)
	var n_tex: int = maxi(maxi(_front_text.length(), _back_text.length()), 1)

	var label: Label3D = $FlipPivot/Label3D as Label3D
	var label_back: Label3D = _lbl_back()
	label.text = _front_text
	label_back.text = _back_text
	label.font_size = _fixed_font_size
	label_back.font_size = _fixed_font_size

	_apply_sign_geometry(inner, n_tex)
	var w: float = maxf(inner.x * label.pixel_size, 0.01)
	label.width = w
	label_back.width = w
	label_back.visible = _has_back and not _back_text.is_empty()


func set_contents(front_text: String, back_text: Variant = null) -> void:
	if _flip_tween != null:
		_flip_tween.kill()
		_flip_tween = null
	_flipping = false

	_front_text = front_text
	if back_text == null:
		_has_back = false
		_back_text = ""
	else:
		_has_back = true
		_back_text = str(back_text)

	_showing_back = false
	scale = Vector3(1.0, 1.0, 1.0)
	_pivot().rotation.y = 0.0
	set_text(_front_text)


func flip(flip_time: float = 1.0) -> bool:
	if not _has_back:
		return false
	if _flipping:
		return false

	var target_y: float = PI if not _showing_back else 0.0
	var pivot: Node3D = _pivot()

	if flip_time <= 0.0:
		pivot.rotation.y = target_y
		_showing_back = not _showing_back
		return true

	if _flip_tween != null:
		_flip_tween.kill()

	_flipping = true
	var from_y: float = pivot.rotation.y
	_flip_tween = create_tween()
	(
		_flip_tween.tween_method(
			func(v: float) -> void:
				pivot.rotation.y = v,
			from_y,
			target_y,
			flip_time
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	_flip_tween.tween_callback(
		func() -> void:
			_showing_back = not _showing_back
			_flipping = false
			_flip_tween = null
	)
	return true
