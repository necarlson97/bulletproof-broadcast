extends Node3D
class_name Sign

const _TEXTURE_SHORT: Texture2D = preload("res://assets/sign short.png")
const _TEXTURE_MID: Texture2D = preload("res://assets/sign.png")
const _TEXTURE_LONG: Texture2D = preload("res://assets/sign long.png")

const _MARGIN_LEFT: float = 40.0
const _MARGIN_TOP: float = 40.0
const _MARGIN_RIGHT: float = 40.0
const _MARGIN_BOTTOM: float = 40.0

const _WRAP_MEASURE_WIDTH: float = 100_000.0

var _fixed_font_size: int = 0
## Horizontal extent of the sign board after last layout (Sign local space, before parent scale).
var _layout_width: float = 0.0


func _lbl() -> Label3D:
	return $FlipPivot/Label3D as Label3D


func _bg() -> Sprite3D:
	return $FlipPivot/SignBG as Sprite3D


func _ready() -> void:
	var bg: Sprite3D = _bg()
	var flip: int = randi() % 4
	bg.flip_h = (flip & 1) != 0
	bg.flip_v = (flip & 2) != 0
	_fixed_font_size = _lbl().font_size
	_lbl().autowrap_mode = TextServer.AUTOWRAP_OFF
	set_text(_lbl().text)


func _texture_for_length(n: int) -> Texture2D:
	if n <= 3:
		return _TEXTURE_SHORT
	elif n <= 8:
		return _TEXTURE_MID
	return _TEXTURE_LONG


func _measure_inner_for_string(text: String) -> Vector2:
	var label: Label3D = _lbl()
	var font: Font = label.font if label.font else ThemeDB.fallback_font
	var fs: int = _fixed_font_size
	if text.is_empty():
		return Vector2.ZERO
	if "\n" in text:
		return Vector2(
			font.get_multiline_string_size(
				text,
				HORIZONTAL_ALIGNMENT_CENTER,
				_WRAP_MEASURE_WIDTH,
				fs
			)
		)
	return Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs))


func _apply_sign_geometry(inner: Vector2, n_for_texture: int) -> void:
	var tex: Texture2D = _texture_for_length(n_for_texture)
	var bg: Sprite3D = _bg()
	var label: Label3D = _lbl()
	bg.texture = tex
	var tex_base: Vector2 = tex.get_size()
	if inner.x <= 0.0 or inner.y <= 0.0:
		inner = Vector2(1.0, 1.0)
	var outer: Vector2 = Vector2(
		inner.x + _MARGIN_LEFT + _MARGIN_RIGHT,
		inner.y + _MARGIN_TOP + _MARGIN_BOTTOM
	)
	var sx: float = outer.x / tex_base.x if tex_base.x > 0.0 else 1.0
	var sy: float = outer.y / tex_base.y if tex_base.y > 0.0 else 1.0
	bg.scale = Vector3(sx, sy, 1.0)
	var ps: float = label.pixel_size
	label.width = maxf(inner.x * ps, 0.01)
	_layout_width = outer.x * bg.pixel_size


func set_text(text: String) -> void:
	var label: Label3D = _lbl()
	if _fixed_font_size <= 0:
		_fixed_font_size = label.font_size
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = text
	label.font_size = _fixed_font_size
	var inner: Vector2 = _measure_inner_for_string(text)
	if inner.x <= 0.0 or inner.y <= 0.0:
		inner = Vector2(1.0, 1.0)
	_apply_sign_geometry(inner, text.length())


func get_layout_width() -> float:
	return _layout_width
