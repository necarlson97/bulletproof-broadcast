extends Node3D
class_name NarrativeSequencer

## Intro: \\f becomes an extra dialogue line (same as newline for [Officer.speak]).
const _INTRO_SPEECH := (
	"Get ready, the parade of loyalists (and traitors) comes.\f"
	+ "Remember, some sign flips are just synonyms, and thus innocuous -\n"
	+ "but watch for rebels trying to change the meaning."
)

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

var _intro_done: bool = false
var _game_failed: bool = false
var _collateral_rot_traitor: int = 0
var _collateral_rot_loyalist: int = 0


func _ready() -> void:
	add_to_group("narrative_sequencer")
	await get_tree().process_frame
	_officer = get_parent().get_node_or_null("Camera3D/Officer") as Officer
	_pause_menu = get_parent().get_node_or_null("PauseMenu") as CanvasLayer
	_gun_point = get_parent().get_node_or_null("Camera3D/Officer/Face") as Node3D
	_connect_parade_signals()
	_run_intro_and_game.call_deferred()


func _connect_parade_signals() -> void:
	var parades: Array[Node] = get_tree().get_nodes_in_group("parade")
	if parades.is_empty():
		push_error("NarrativeSequencer: no node in group 'parade'")
		return
	var parade: Parade = parades[0] as Parade
	if parade == null:
		return
	parade.main_parade_complete.connect(_on_main_parade_complete)
	for c: Node in parade.get_children():
		var pl: ParadeLine = c as ParadeLine
		if pl != null:
			pl.disloyal_present_at_check_z.connect(_on_disloyal_at_check)


func _run_intro_and_game() -> void:
	if _officer == null:
		push_error("NarrativeSequencer: Officer missing")
		return
	await _speak_async(_normalize_speech(_INTRO_SPEECH))
	_intro_done = true
	var parades: Array[Node] = get_tree().get_nodes_in_group("parade")
	if parades.is_empty():
		return
	var parade: Parade = parades[0] as Parade
	if parade != null:
		parade.begin_marches()


func _on_main_parade_complete() -> void:
	if _game_failed:
		return
	_run_victory_sequence.call_deferred()


func _run_victory_sequence() -> void:
	if _game_failed:
		return
	if bonus_section != null:
		bonus_section.visible = true
	print("[NarrativeSequencer] Bonus parade (stub)")
	await get_tree().create_timer(0.05).timeout
	if bonus_section != null:
		bonus_section.visible = false
	if _officer == null:
		return
	await _speak_async(_normalize_speech(_OUTRO_SPEECH))
	if _pause_menu != null and _pause_menu.has_method("open_pause_menu"):
		await _pause_menu.open_pause_menu()


func _on_disloyal_at_check() -> void:
	_handle_damage_tier.call_deferred()


func _handle_damage_tier() -> void:
	if _officer == null:
		return
	var n: int = GameStats.malcontents_broadcast
	match n:
		1:
			await _speak_async(_normalize_speech(_DMG_1))
		2:
			await _speak_async(_normalize_speech(_DMG_2))
			if _gun_point != null:
				_officer.set_gun_rest(_gun_point)
		3:
			await _speak_async(_normalize_speech(_DMG_3))
			_officer.set_sweating_active(true)
		4:
			_game_failed = true
			await _speak_async(_normalize_speech(_DMG_4))
			if _gun_point != null:
				_officer.shot_at(_gun_point)
				_officer.kill()
			if _pause_menu != null and _pause_menu.has_method("open_pause_menu"):
				await _pause_menu.open_pause_menu()
		_:
			pass


func notify_parader_shot(was_loyal: bool) -> void:
	if not _intro_done or _game_failed:
		return
	if _officer == null:
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
	var finished: Array[bool] = [false]
	_officer.speak(text, func(): finished[0] = true)
	while not finished[0]:
		await get_tree().process_frame
