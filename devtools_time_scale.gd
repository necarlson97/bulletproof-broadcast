extends Node3D

## Dev: `[` halves `Engine.time_scale`, `]` doubles it. Overlay when scale ≠ 1.

const _MIN_SCALE := 1.0 / 16384.0
const _MAX_SCALE := 64.0

var _label: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_label = Label.new()
	_label.visible = false
	_label.position = Vector2(12, 10)
	_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(_label)
	_refresh_label()


func _refresh_label() -> void:
	var ts := Engine.time_scale
	if is_equal_approx(ts, 1.0):
		_label.visible = false
	else:
		_label.visible = true
		# GDScript `%` only supports `f` for floats, not `g` (see docs: GDScript format strings).
		var s: String = "%.4f" % ts
		if s.contains("."):
			s = s.rstrip("0").rstrip(".")
		_label.text = "×" + s


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.keycode:
		KEY_BRACKETRIGHT:
			Engine.time_scale = clampf(Engine.time_scale * 2.0, _MIN_SCALE, _MAX_SCALE)
			_refresh_label()
			get_viewport().set_input_as_handled()
		KEY_BRACKETLEFT:
			Engine.time_scale = clampf(Engine.time_scale * 0.5, _MIN_SCALE, _MAX_SCALE)
			_refresh_label()
			get_viewport().set_input_as_handled()
