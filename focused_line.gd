extends Node3D
class_name FocusedLine

@onready var _highlight: MeshInstance3D = $HighlightCube
@onready var _officer: Officer = get_parent().get_node("Camera3D/Officer") as Officer

func _ready() -> void:
	if _highlight != null:
		_highlight.visible = false


func _process(_delta: float) -> void:
	var focused_line: ParadeLine = _pick_foremost_line()
	if _highlight == null:
		return
	if focused_line == null or not is_instance_valid(focused_line):
		_highlight.visible = false
		return
	var bounds: Variant = focused_line.get_focus_bounds_global()
	if bounds == null:
		_highlight.visible = false
		return
	var center: Vector3 = bounds["center"]
	var size: Vector3 = bounds["size"]
	_highlight.visible = true
	_highlight.global_position = center
	_highlight.global_rotation = Vector3.ZERO
	_highlight.scale = size


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var d: String = _digit_from_keycode((event as InputEventKey).keycode)
	if d.is_empty():
		return
	var pl: ParadeLine = _pick_foremost_line()
	if pl == null or not is_instance_valid(pl):
		return
	var target: Parader = pl.get_parader_by_digit(d)
	if target == null:
		return
	if _officer != null:
		_officer.shot_at(target)
	target.kill()
	get_viewport().set_input_as_handled()


func _pick_foremost_line() -> ParadeLine:
	var parades: Array[Node] = get_tree().get_nodes_in_group("parade")
	if parades.is_empty():
		return null
	var parade: Node = parades[0]
	var best: ParadeLine = null
	var best_z: float = -INF
	for c: Node in parade.get_children():
		var pl: ParadeLine = c as ParadeLine
		if pl == null:
			continue
		var z: float = pl.get_line_march_z()
		if z > best_z:
			best_z = z
			best = pl
	return best


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
