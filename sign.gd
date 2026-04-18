extends Node2D

@onready var _sign_bg: Sprite2D = $SignBG
@onready var _panel: Panel = $Panel
@onready var _margin: MarginContainer = $Panel/MarginContainer
@onready var _label: Label = $Panel/MarginContainer/Label

const _TEXTURE_SHORT: Texture2D = preload("res://assets/sign short.png")
const _TEXTURE_MID: Texture2D = preload("res://assets/sign.png")
const _TEXTURE_LONG: Texture2D = preload("res://assets/sign long.png")

const _MAX_FONT_PROBE: int = 512


func _ready() -> void:
	if _label.label_settings:
		_label.label_settings = _label.label_settings.duplicate()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	set_text(_label.text)


func set_text(text: String) -> void:
	_label.text = text
	var n: int = text.length()
	var tex: Texture2D
	if n <= 3:
		tex = _TEXTURE_SHORT
	elif n <= 8:
		tex = _TEXTURE_MID
	else:
		tex = _TEXTURE_LONG
	_sign_bg.texture = tex
	var tex_size: Vector2 = tex.get_size() * _sign_bg.scale
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = -tex_size * 0.5
	_panel.size = tex_size
	_fit_label_font()


func _margin_inner_size() -> Vector2:
	var ml := float(_margin.get_theme_constant("margin_left"))
	var mt := float(_margin.get_theme_constant("margin_top"))
	var mr := float(_margin.get_theme_constant("margin_right"))
	var mb := float(_margin.get_theme_constant("margin_bottom"))
	# MarginContainer fills the panel; inner size is outer rect minus margins.
	return _panel.size - Vector2(ml + mr, mt + mb)


func _fit_label_font() -> void:
	var ls: LabelSettings = _label.label_settings
	if ls == null:
		return
	var max_sz: Vector2 = _margin_inner_size()
	if max_sz.x <= 0.0 or max_sz.y <= 0.0:
		return
	var font: Font = ls.font if ls.font else ThemeDB.fallback_font
	var text: String = _label.text
	if text.is_empty():
		ls.font_size = 1
		return
	var lo: int = 1
	var hi: int = _MAX_FONT_PROBE
	var best: int = 1
	while lo <= hi:
		var mid: int = (lo + hi) >> 1
		var sz: Vector2 = Vector2(
			font.get_multiline_string_size(
				text,
				HORIZONTAL_ALIGNMENT_CENTER,
				max_sz.x,
				mid
			)
		)
		if sz.x <= max_sz.x and sz.y <= max_sz.y:
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	ls.font_size = best
