extends Node2D

@onready var _sign_bg: Sprite2D = $SignBG
@onready var _panel: Panel = $Panel
@onready var _margin: MarginContainer = $Panel/MarginContainer
@onready var _label: Label = $Panel/MarginContainer/Label

const _TEXTURE_SHORT: Texture2D = preload("res://assets/sign short.png")
const _TEXTURE_MID: Texture2D = preload("res://assets/sign.png")
const _TEXTURE_LONG: Texture2D = preload("res://assets/sign long.png")

const _WRAP_MEASURE_WIDTH: float = 100_000.0

var _fixed_font_size: int = 0


func _ready() -> void:
	var flip: int = randi() % 4
	_sign_bg.flip_h = (flip & 1) != 0
	_sign_bg.flip_v = (flip & 2) != 0
	if _label.label_settings:
		_label.label_settings = _label.label_settings.duplicate()
	_fixed_font_size = _label.label_settings.font_size if _label.label_settings else 16
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	set_text(_label.text)


func set_text(text: String) -> void:
	_label.text = text
	if _label.label_settings:
		_label.label_settings.font_size = _fixed_font_size

	var n: int = text.length()
	var tex: Texture2D
	if n <= 3:
		tex = _TEXTURE_SHORT
	elif n <= 8:
		tex = _TEXTURE_MID
	else:
		tex = _TEXTURE_LONG
	_sign_bg.texture = tex

	var tex_base: Vector2 = tex.get_size()
	var ml := float(_margin.get_theme_constant("margin_left"))
	var mt := float(_margin.get_theme_constant("margin_top"))
	var mr := float(_margin.get_theme_constant("margin_right"))
	var mb := float(_margin.get_theme_constant("margin_bottom"))

	var inner: Vector2 = _measure_text_pixel_size()
	if inner.x <= 0.0 or inner.y <= 0.0:
		inner = Vector2(1.0, 1.0)

	var outer: Vector2 = Vector2(inner.x + ml + mr, inner.y + mt + mb)
	var sx: float = outer.x / tex_base.x if tex_base.x > 0.0 else 1.0
	var sy: float = outer.y / tex_base.y if tex_base.y > 0.0 else 1.0
	_sign_bg.scale = Vector2(sx, sy)

	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = -outer * 0.5
	_panel.size = outer


func _measure_text_pixel_size() -> Vector2:
	var ls: LabelSettings = _label.label_settings
	if ls == null:
		return Vector2.ZERO
	var font: Font = ls.font if ls.font else ThemeDB.fallback_font
	var text: String = _label.text
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
