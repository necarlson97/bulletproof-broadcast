extends Node3D
class_name NarrativeSequencer

## Intro: \\f becomes an extra dialogue line (same as newline for [Officer.speak]).
const _INTRO_SPEECH := (
       "Get ready, the parade of loyalists (and traitors) comes.\f"
	   + "(click/space to sped up my speech).\n"
	   + "Remember, some sign flips are just synonyms, and thus innocuous -\n"   
	   + "but watch for rebels trying to change the meaning."
)

const _PROTEST_REACTION_SPEECH := (
	"Oh god. Protestors! No!\f"
	+ "Take them all out! Quickly!"
)

const _POST_PROTEST_SPEECH := (
	"Whew! And just in time...\f"
	+ "His majesty must be on his way."
)

const _PRE_RETENUE_SPEECH := "He's... He's here..."

const _OUTRO_SPEECH := "You did it!\nYour gruel will be waiting for you in your cell. Congratulations."

const _DMG_1 := (
	"Ah! A malcontent was shown on broadcast!\n"
	+ "If you keep letting that happen, it will be over for us."
)
const _DMG_2 := "Don't let any more traitors reach the camera - please!"
const _DMG_3 := "Another tratior made it! Please! I'm Scared!"
const _DMG_4 := "You have failed us."

@export var collateral_traitor_lines: Array[String] = ["Excellent!"]
@export var collateral_loyalist_lines: Array[String] = ["Ah. That was a loyalist. Oh well."]
## Optional: shown during the bonus-parade stub; hidden again after.
@export var bonus_section: Node3D

var _officer: Officer
var _pause_menu: CanvasLayer
var _gun_point: Node3D
var _parade: Parade
var _focused_line: FocusedLine

## Queue from [member Main.build_parade_schedule]: keys [code]lines[/code], optional [code]force_disloyal[/code], [code]parader_scene[/code].
var parade_schedule: Array[Dictionary] = []

var _parades_completed: int = 0
## Matches [member parade_schedule] index while that segment's lines are active.
var _active_schedule_index: int = 0
var _intro_done: bool = false
var _game_failed: bool = false
## Prevents double [method _advance_after_parade_segment] from normal vs early completion.
var _resolving_parade_segment: bool = false
var _collateral_rot_traitor: int = 0
var _collateral_rot_loyalist: int = 0


func _ready() -> void:
	add_to_group("narrative_sequencer")
	await get_tree().process_frame
	_officer = get_parent().get_node_or_null("Camera3D/Officer") as Officer
	_pause_menu = get_parent().get_node_or_null("PauseMenu") as CanvasLayer
	_gun_point = get_parent().get_node_or_null("Camera3D/Officer/Face") as Node3D
	_parade = get_tree().get_first_node_in_group("parade") as Parade
	if _parade == null:
		push_error("NarrativeSequencer: no node in group 'parade'")
		return
	_focused_line = get_parent().get_node_or_null("FocusedLine") as FocusedLine
	_parade.main_parade_complete.connect(_on_main_parade_complete)
	_connect_disloyal_signals_on_parade_lines(_parade)
	for seg: Dictionary in parade_schedule:
		if bool(seg.get("complete_when_last_line_releases_focus", false)):
			set_process(true)
			break
	_run_intro_and_game.call_deferred()


func _process(_delta: float) -> void:
	if not _intro_done or _game_failed or _resolving_parade_segment:
		return
	if not is_instance_valid(_parade):
		return
	if not _segment_wants_early_last_line_complete(_active_schedule_index):
		return
	var last_pl: ParadeLine = _get_last_parade_line_by_spawn_index(_parade)
	if last_pl == null or not last_pl.should_release_focus():
		return
	_parade.abort_all_parade_lines()
	_schedule_parade_advance()


func _segment_wants_early_last_line_complete(schedule_idx: int) -> bool:
	if parade_schedule.is_empty() or schedule_idx < 0 or schedule_idx >= parade_schedule.size():
		return false
	return bool(parade_schedule[schedule_idx].get("complete_when_last_line_releases_focus", false))


func _get_last_parade_line_by_spawn_index(parade: Parade) -> ParadeLine:
	var best: ParadeLine = null
	var best_i: int = -999999
	for c: Node in parade.get_children():
		var pl: ParadeLine = c as ParadeLine
		if pl == null:
			continue
		if pl.spawn_index > best_i:
			best_i = pl.spawn_index
			best = pl
	return best


func _connect_disloyal_signals_on_parade_lines(parade: Parade) -> void:
	for c: Node in parade.get_children():
		var pl: ParadeLine = c as ParadeLine
		if pl != null:
			pl.disloyal_present_at_check_z.connect(_on_disloyal_at_check)


func _run_intro_and_game() -> void:
	if _officer == null:
		push_error("NarrativeSequencer: Officer missing")
		return
	await _speak_async(_normalize_speech(_INTRO_SPEECH))
	if not is_inside_tree() or not is_instance_valid(_officer):
		return
	_intro_done = true
	if _parade != null:
		_parade.begin_marches()


func _on_main_parade_complete() -> void:
	if _game_failed:
		return
	_advance_after_parade_segment.call_deferred()


func _advance_after_parade_segment() -> void:
	if _game_failed or not is_instance_valid(_parade):
		return
	_parades_completed += 1
	match _parades_completed:
		1:
			await _speak_async(_normalize_speech(_PROTEST_REACTION_SPEECH))
			if _game_failed or not is_instance_valid(_parade):
				return
			await _load_schedule_segment(1)
		2:
			await _speak_async(_normalize_speech(_POST_PROTEST_SPEECH))
			if _game_failed or not is_instance_valid(_parade):
				return
			await _load_schedule_segment(2)
		3:
			await _speak_async(_normalize_speech(_PRE_RETENUE_SPEECH))
			if _game_failed or not is_instance_valid(_parade):
				return
			await _load_schedule_segment(3)
		4:
			await _load_schedule_segment(4)
		5:
			_run_victory_sequence.call_deferred()
		_:
			push_warning("NarrativeSequencer: unexpected parade segment index %d" % _parades_completed)


func _load_schedule_segment(schedule_idx: int) -> void:
	if parade_schedule.is_empty() or schedule_idx < 0 or schedule_idx >= parade_schedule.size():
		push_error("NarrativeSequencer: bad parade_schedule index %d" % schedule_idx)
		return
	var seg: Dictionary = parade_schedule[schedule_idx]
	var lines: Array = seg.get("lines", [])
	var lines_typed: Array[String] = []
	for s: Variant in lines:
		lines_typed.append(str(s))
	var force_d: bool = bool(seg.get("force_disloyal", false))
	var ps: Variant = seg.get("parader_scene", null)
	var parader_override: PackedScene = null if ps == null else ps as PackedScene
	await _parade.load_segment(lines_typed, force_d, parader_override)
	if _game_failed or not is_instance_valid(_parade):
		return
	if is_instance_valid(_focused_line):
		_focused_line.begin_new_parade_segment()
	_connect_disloyal_signals_on_parade_lines(_parade)
	_parade.begin_marches()


func _run_victory_sequence() -> void:
	if _game_failed:
		return
	if bonus_section != null:
		bonus_section.visible = true
	print("[NarrativeSequencer] Bonus parade (stub)")
	await get_tree().create_timer(0.05).timeout
	if bonus_section != null:
		bonus_section.visible = false
	if not is_instance_valid(_officer):
		return
	await _speak_async(_normalize_speech(_OUTRO_SPEECH))
	if is_instance_valid(_pause_menu) and _pause_menu.has_method("open_pause_menu"):
		await _pause_menu.open_pause_menu()


func _on_disloyal_at_check() -> void:
	_handle_damage_tier.call_deferred()


func _handle_damage_tier() -> void:
	if not is_instance_valid(_officer):
		return
	var n: int = GameStats.malcontents_broadcast
	match n:
		1:
			await _speak_async(_normalize_speech(_DMG_1))
		2:
			await _speak_async(_normalize_speech(_DMG_2))
			if is_instance_valid(_officer) and _gun_point != null:
				_officer.set_gun_rest(_gun_point)
		3:
			await _speak_async(_normalize_speech(_DMG_3))
			if is_instance_valid(_officer):
				_officer.set_sweating_active(true)
		4:
			_game_failed = true
			await _speak_async(_normalize_speech(_DMG_4))
			if is_instance_valid(_officer) and _gun_point != null:
				_officer.shot_at(_gun_point)
				_officer.kill()
			if is_instance_valid(_pause_menu) and _pause_menu.has_method("open_pause_menu"):
				await _pause_menu.open_pause_menu()
		_:
			pass


func notify_parader_shot(was_loyal: bool) -> void:
	if not _intro_done or _game_failed:
		return
	if not is_instance_valid(_officer):
		return
	var line: String
	if was_loyal:
		if collateral_loyalist_lines.is_empty():
			return
		line = collateral_loyalist_lines[_collateral_rot_loyalist % collateral_loyalist_lines.size()]
		_collateral_rot_loyalist += 1
	else:
		if collateral_traitor_lines.is_empty():
			return
		line = collateral_traitor_lines[_collateral_rot_traitor % collateral_traitor_lines.size()]
		_collateral_rot_traitor += 1
	_officer.speak(_normalize_speech(line))


func _normalize_speech(s: String) -> String:
	return s.replace("\f", "\n")


func _speak_async(text: String) -> void:
	if not is_instance_valid(_officer):
		return
	var finished: Array[bool] = [false]
	_officer.speak(text, func(): finished[0] = true)
	while not finished[0]:
		# Scene change removes us from the tree; officer may be freed while speech runs.
		if not is_inside_tree() or not is_instance_valid(_officer):
			return
		await get_tree().process_frame
