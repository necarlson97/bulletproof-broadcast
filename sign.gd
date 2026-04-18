extends Node3D
class_name Sign

@onready var _sign_bg: Sprite3D = $FlipPivot/SignBG
@onready var _label: Label3D = $FlipPivot/Label3D

const _TEXTURE_SHORT: Texture2D = preload("res://assets/sign short.png")
const _TEXTURE_MID: Texture2D = preload("res://assets/sign.png")
const _TEXTURE_LONG: Texture2D = preload("res://assets/sign long.png")

const _MARGIN_LEFT: float = 40.0
const _MARGIN_TOP: float = 40.0
const _MARGIN_RIGHT: float = 40.0
const _MARGIN_BOTTOM: float = 40.0

const _WRAP_MEASURE_WIDTH: float = 100_000.0

var _fixed_font_size: int = 0


func _ready() -> void:
	var flip: int = randi() % 4
	_sign_bg.flip_h = (flip & 1) != 0
	_sign_bg.flip_v = (flip & 2) != 0
	_fixed_font_size = _label.font_size
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	set_text(_label.text)


func _texture_for_length(n: int) -> Texture2D:
	if n <= 3:
		return _TEXTURE_SHORT
	elif n <= 8:
		return _TEXTURE_MID
	return _TEXTURE_LONG


func _measure_inner_for_string(text: String) -> Vector2:
	var font: Font = _label.font if _label.font else ThemeDB.fallback_font
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
	_sign_bg.texture = tex
	var tex_base: Vector2 = tex.get_size()
	if inner.x <= 0.0 or inner.y <= 0.0:
		inner = Vector2(1.0, 1.0)
	var outer: Vector2 = Vector2(
		inner.x + _MARGIN_LEFT + _MARGIN_RIGHT,
		inner.y + _MARGIN_TOP + _MARGIN_BOTTOM
	)
	var sx: float = outer.x / tex_base.x if tex_base.x > 0.0 else 1.0
	var sy: float = outer.y / tex_base.y if tex_base.y > 0.0 else 1.0
	_sign_bg.scale = Vector3(sx, sy, 1.0)
	var ps: float = _label.pixel_size
	_label.width = maxf(inner.x * ps, 0.01)


func set_text(text: String) -> void:
	_label.text = text
	_label.font_size = _fixed_font_size
	var inner: Vector2 = _measure_inner_for_string(text)
	if inner.x <= 0.0 or inner.y <= 0.0:
		inner = Vector2(1.0, 1.0)
	_apply_sign_geometry(inner, text.length())
