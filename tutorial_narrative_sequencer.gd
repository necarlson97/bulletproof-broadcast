extends NarrativeSequencer
class_name TutorialNarrativeSequencer

const _FOCUSED_LINE_SCENE: PackedScene = preload("res://focused_line.tscn")

## Main menu after "Ready?"
const MAIN_MENU_SCENE := "res://menus/main_menu.tscn"

const _WRONG_SHOT_HINT := "Hrm. Not quite. Try another?"

## Tween duration between [CameraPositions] waypoints (nodes named "0", "1", … — tree order does not matter).
@export var camera_tween_sec: float = 1.25
## Default flip animation is 1s; allow a short buffer before the next line.
@export var flip_pause_sec: float = 1.05

var _camera: Camera3D
var _camera_positions: Node3D
var _faux: ParadeLineFaux

var _cam_tween: Tween

var _waiting_for_tutorial_shot: bool = false
var _tutorial_shot_done: bool = false


func _ready() -> void:
	add_to_group("narrative_sequencer")
	await get_tree().process_frame
	_officer = get_parent().get_node_or_null("Camera3D/Officer") as Officer
	_camera = get_parent().get_node_or_null("Camera3D") as Camera3D
	_camera_positions = get_parent().get_node_or_null("CameraPositions") as Node3D
	_faux = get_parent().get_node_or_null("Parade/ParadeLine") as ParadeLineFaux
	_limelight_overlay = get_parent().get_node_or_null("Camera3D/LimelightScreenDarkenOverlay") as LimelightScreenDarkenOverlay
	_limelighter = get_parent().get_node_or_null("Limelighter") as Limelighter
	if is_instance_valid(_faux):
		_faux.visible = false
	_intro_done = true
	_run_tutorial.call_deferred()


func _run_tutorial() -> void:
	if not is_instance_valid(_officer) or not is_instance_valid(_camera):
		push_error("TutorialNarrativeSequencer: missing Officer or Camera3D")
		return

	_snap_camera_to_waypoint("0")

	await _speak_async(
		"Greetings broadcaster.\nToday is going to be a wonderful parade, full of great love for the king."
	)
	if not is_inside_tree():
		return
	await _speak_async(
		"(click/space to make me speak faster)"
	)
	if not is_inside_tree():
		return
	await _speak_async(
		"I've heard some… Disloyal subjects have snuck into the parade.\nThat is why I am here."
	)
	if not is_inside_tree():
		return

	await _tween_camera_to_waypoint("1")
	if not is_inside_tree():
		return
	if is_instance_valid(_faux):
		_faux.visible = true
	await _speak_async(
		"The paraders will come down this road, bearing signs, heading towards our camera."
	)
	if not is_inside_tree():
		return

	await _tween_camera_to_waypoint("2")
	if not is_inside_tree():
		return
	await _speak_async("We will read their signs as they come.\nSome will flip their signs.")
	if not is_inside_tree():
		return

	if is_instance_valid(_faux):
		_faux.flip_next()
		if not is_inside_tree():
			return
		await get_tree().create_timer(flip_pause_sec).timeout
	if not is_inside_tree():
		return
	await _speak_async("This is fine - the king loves variety.\nBut a traitor might try to change the sentiment!")
	if not is_inside_tree():
		return

	if is_instance_valid(_faux):
		_faux.flip_next()
		if not is_inside_tree():
			return
		await get_tree().create_timer(flip_pause_sec).timeout
	if not is_inside_tree():
		return
	await _speak_async("We must ensure no such agitators are broadcast!")
	if not is_inside_tree():
		return

	await _setup_focused_line_for_shooting()
	if not is_inside_tree():
		return
	_tutorial_shot_done = false
	_waiting_for_tutorial_shot = true
	await _speak_async(
		"You see the numbers on their shirt? Press the key to tell me which one to shoot."
	)
	if not is_inside_tree():
		return
	while not _tutorial_shot_done:
		if not is_inside_tree():
			return
		if is_instance_valid(_faux) and _faux.all_disloyal_eliminated():
			_tutorial_shot_done = true
			break
		await get_tree().process_frame
	if not is_inside_tree():
		return
	_waiting_for_tutorial_shot = false
	_teardown_focused_line()
	if not is_inside_tree():
		return

	await _speak_async("Simple as that.")
	if not is_inside_tree():
		return

	await _tween_camera_to_waypoint("3")
	if not is_inside_tree():
		return
	await _speak_async("If any malcontents reach the camera… Well…")
	if not is_inside_tree():
		return
	await _speak_async("We will be visiting the king's 'private office', as they say.")
	if not is_inside_tree():
		return

	await _tween_camera_to_waypoint("6")
	if not is_inside_tree():
		return
	await _speak_async("Watch the crowd - they'll get more rowdy if a traitor gets close")
	if not is_inside_tree():
		return

	await _tween_camera_to_waypoint("4")
	if not is_inside_tree():
		return
	await _speak_async("Certain rebels may even have a 'tell'.")
	if not is_inside_tree():
		return

	await _tween_camera_to_waypoint("5")
	if not is_inside_tree():
		return
	await _speak_async("But mostly - read their signs.")
	if not is_inside_tree():
		return
	await _speak_async("If we are fast, and brutal…")
	if not is_inside_tree():
		return
	await _speak_async("We might just make it home okay.")
	if not is_inside_tree():
		return
	await _speak_async("Ready?")

	if is_inside_tree():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _snap_camera_to_waypoint(child_name: String) -> void:
	var wp: Node3D = _get_waypoint(child_name)
	if wp == null or not is_instance_valid(_camera):
		return
	_camera.global_transform = wp.global_transform


func _tween_camera_to_waypoint(child_name: String) -> void:
	var wp: Node3D = _get_waypoint(child_name)
	if wp == null or not is_instance_valid(_camera):
		return
	if _cam_tween != null and is_instance_valid(_cam_tween):
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(_camera, "global_transform", wp.global_transform, camera_tween_sec)
	await _cam_tween.finished


func _get_waypoint(child_name: String) -> Node3D:
	if _camera_positions == null:
		return null
	return _camera_positions.get_node_or_null(child_name) as Node3D


func notify_parader_shot(was_loyal: bool, _target: Parader = null) -> void:
	if not _waiting_for_tutorial_shot:
		return
	if was_loyal and is_instance_valid(_officer):
		_officer.speak(_normalize_speech(_WRONG_SHOT_HINT))


func _setup_focused_line_for_shooting() -> void:
	if _focused_line != null and is_instance_valid(_focused_line):
		return
	if not is_instance_valid(_faux):
		push_warning("TutorialNarrativeSequencer: no faux parade line for shooting")
		return
	var fl: FocusedLine = _FOCUSED_LINE_SCENE.instantiate() as FocusedLine
	_focused_line = fl
	get_parent().add_child(fl)
	fl.set_parade_line(_faux)
	await get_tree().process_frame
	if not is_inside_tree():
		return


func _teardown_focused_line() -> void:
	if _focused_line != null and is_instance_valid(_focused_line):
		_focused_line.set_parade_line(null)
		_focused_line.queue_free()
	_focused_line = null
