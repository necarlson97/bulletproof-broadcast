extends Node3D
class_name FocusedLine

var _limelighter: Limelighter
## Next [ParadeLine.spawn_index] to use for focus (advances on release or missing line).
var _focus_spawn_index: int = 0
## When set (and valid), [method get_current_parade_line] uses this instead of the parade group.
var _manual_parade_line: ParadeLine = null
@onready var _officer: Officer = get_parent().get_node("Camera3D/Officer") as Officer


func _ready() -> void:
	_limelighter = get_parent().get_node_or_null("Limelighter") as Limelighter


## Use a specific line (e.g. tutorial [ParadeLineFaux]). Pass [code]null[/code] to use automatic parade indexing again.
func set_parade_line(line: ParadeLine) -> void:
	_manual_parade_line = line


## Call when the active [Parade] spawns a new segment so focus returns to [code]spawn_index == 0[/code].
func begin_new_parade_segment() -> void:
	_focus_spawn_index = 0


## The line used for limelight and shooting: manual override if set, otherwise the active line from the first [code]"parade"[/code] group root.
func get_current_parade_line() -> ParadeLine:
	if _manual_parade_line != null:
		if not is_instance_valid(_manual_parade_line):
			_manual_parade_line = null
		else:
			return _manual_parade_line
	return _resolve_parade_mode_line()


func _resolve_parade_mode_line() -> ParadeLine:
	var parade: Node = _get_parade_root()
	if parade == null:
		return null
	_skip_missing_spawn_slots(parade)
	var pl: ParadeLine = _line_at_spawn_index(parade, _focus_spawn_index)
	while pl != null and pl.should_release_focus():
		_focus_spawn_index += 1
		_skip_missing_spawn_slots(parade)
		pl = _line_at_spawn_index(parade, _focus_spawn_index)
	if pl == null or not is_instance_valid(pl):
		return null
	return pl


func _process(_delta: float) -> void:
	if _limelighter == null:
		return
	var pl: ParadeLine = get_current_parade_line()
	if pl == null:
		_limelighter.set_targets([])
		return
	_limelighter.set_targets(pl.get_limelight_targets())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var d: String = _digit_from_keycode((event as InputEventKey).keycode)
	if d.is_empty():
		return
	var pl: ParadeLine = get_current_parade_line()
	if pl == null:
		return
	var target: Parader = pl.get_parader_by_digit(d)
	if target == null:
		return
	var was_loyal: bool = target.loyal
	if was_loyal:
		GameStats.loyalists_executed += 1
	else:
		GameStats.traitors_executed += 1
	if _officer != null:
		_officer.shot_at(target)
	_notify_narrative_collateral(was_loyal)
	target.kill()
	get_viewport().set_input_as_handled()


func _get_parade_root() -> Node:
	var parades: Array[Node] = get_tree().get_nodes_in_group("parade")
	if parades.is_empty():
		return null
	return parades[0]


func _line_at_spawn_index(parade: Node, index: int) -> ParadeLine:
	for c: Node in parade.get_children():
		var pl: ParadeLine = c as ParadeLine
		if pl == null:
			continue
		if pl.spawn_index == index and is_instance_valid(pl):
			return pl
	return null


func _any_parade_line_alive(parade: Node) -> bool:
	for c: Node in parade.get_children():
		if c is ParadeLine and is_instance_valid(c):
			return true
	return false


func _skip_missing_spawn_slots(parade: Node) -> void:
	var guard: int = 0
	while guard < 64:
		guard += 1
		if _line_at_spawn_index(parade, _focus_spawn_index) != null:
			return
		if not _any_parade_line_alive(parade):
			return
		_focus_spawn_index += 1


func _notify_narrative_collateral(was_loyal: bool) -> void:
	for n: Node in get_tree().get_nodes_in_group("narrative_sequencer"):
		if n.has_method("notify_parader_shot"):
			n.notify_parader_shot(was_loyal)
			return


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
