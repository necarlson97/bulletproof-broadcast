extends Node3D

## Ten loyal flippers; digit keys match the usual 1–9,0 labels (first parader = 1, tenth = 0).
const _LINE := "(a,A)(b,B)(c,C)(d,D)(e,E)(f,F)(g,G)(h,H)(i,I)(j,J)"

@onready var _line: ParadeLine = $ParadeLine


func _ready() -> void:
	_line.setup(_LINE, 300.0, 0.0, 300.0, 100.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var d: String = _digit_from_keycode((event as InputEventKey).keycode)
	if d.is_empty():
		return
	var target: Parader = _line.get_parader_by_digit(d)
	if target == null:
		return
	var flippable: SignFlippable = target.get_node("SignScale/Sign") as SignFlippable
	flippable.flip()
	get_viewport().set_input_as_handled()


static func _digit_from_keycode(k: int) -> String:
	match k:
		KEY_0, KEY_KP_0:
			return "0"
		KEY_1, KEY_KP_1:
			return "1"
		KEY_2, KEY_KP_2:
			return "2"
		KEY_3, KEY_KP_3:
			return "3"
		KEY_4, KEY_KP_4:
			return "4"
		KEY_5, KEY_KP_5:
			return "5"
		KEY_6, KEY_KP_6:
			return "6"
		KEY_7, KEY_KP_7:
			return "7"
		KEY_8, KEY_KP_8:
			return "8"
		KEY_9, KEY_KP_9:
			return "9"
		_:
			return ""
