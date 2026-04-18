extends Person
class_name Officer

const _MUZZLE_FLASH_SEC := 0.1
## After a shot, hold that aim this long before easing back toward the gun rest point.
const _GUN_REST_RETURN_DELAY_SEC := 1.0
## How fast the hand eases toward the rest aim (higher = snappier).
const _GUN_REST_AIM_SLERP := 6.0
const _SMOKE_SCALE_START := 1.3
const _SMOKE_SCALE_END := 0.35

const _SHOT_CLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/shot.wav"),
]

## Typing speed for speech (visible characters per second).
const _SPEAK_CHARS_PER_SEC := 38.0
## After a line is fully shown, wait this long before auto-advancing (skip with click / space).
const _LINE_PAUSE_AFTER_TYPING_SEC := 2.0

const _SPEAK_SFX_CLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/heh-1.wav"),
	preload("res://assets/sfx/heh-2.wav"),
	preload("res://assets/sfx/heh-3.wav"),
	preload("res://assets/sfx/heh-4.wav"),
	preload("res://assets/sfx/heh-5.wav"),
	preload("res://assets/sfx/heh-6.wav"),
	preload("res://assets/sfx/heh-7.wav"),
]

@onready var _gun: Node3D = $HandL
@onready var _muzzle_flash: Node3D = $HandL/Gun/MuzzelFlash
@onready var _smoking: GPUParticles3D = $HandL/Gun/Smoking
@onready var _shot_sfx: AudioStreamPlayer3D = $ShotSfx

@onready var _dialog_box: Node3D = $DialogBox
@onready var _speech_label: RichTextLabel = $DialogBox/SubViewport/Control/Panel/Label
@onready var _speak_sfx: AudioStreamPlayer3D = $KilledSfx

var _muzzle_timer: Timer

var _dialogue_lines: Array[String] = []
var _line_index: int = 0
var _current_line: String = ""
var _chars_shown: int = 0
var _line_elapsed: float = 0.0
var _is_dialog_active: bool = false
var _line_typing_done: bool = false
var _line_pause_left: float = 0.0
var _on_speech_finished: Callable = Callable()

var _gun_rest_node: Node3D
var _aim_scratch: Node3D
var _gun_rest_return_timer: Timer
var _shot_aim_hold_active: bool = false
var _smoke_process_material: ParticleProcessMaterial
var _smoke_size_tween: Tween

func _ready() -> void:
	_muzzle_flash.visible = false
	_muzzle_timer = Timer.new()
	_muzzle_timer.one_shot = true
	_muzzle_timer.timeout.connect(_hide_muzzle_flash)
	add_child(_muzzle_timer)
	_aim_scratch = Node3D.new()
	_aim_scratch.name = "_AimScratch"
	add_child(_aim_scratch)
	_gun_rest_return_timer = Timer.new()
	_gun_rest_return_timer.one_shot = true
	_gun_rest_return_timer.wait_time = _GUN_REST_RETURN_DELAY_SEC
	_gun_rest_return_timer.timeout.connect(_on_shot_aim_hold_finished)
	add_child(_gun_rest_return_timer)
	if _smoking.process_material is ParticleProcessMaterial:
		_smoke_process_material = (_smoking.process_material as ParticleProcessMaterial).duplicate()
		_smoking.process_material = _smoke_process_material
	_dialog_box.visible = false
	_speech_label.text = ""
	_speech_label.visible_characters = -1
	set_process(false)
	set_physics_process(false)
	set_gun_rest($GunRest)

func _physics_process(delta: float) -> void:
	if _gun_rest_node == null or not is_instance_valid(_gun_rest_node):
		return
	if _shot_aim_hold_active:
		return
	var rest_aim: Vector3 = _gun_rest_node.global_position
	var cur_basis: Basis = _gun.global_transform.basis
	var q0: Quaternion = cur_basis.orthonormalized().get_rotation_quaternion()
	var q1: Quaternion = _basis_aiming_hand_at(rest_aim).orthonormalized().get_rotation_quaternion()
	var t: float = clampf(_GUN_REST_AIM_SLERP * delta, 0.0, 1.0)
	var q: Quaternion = q0.slerp(q1, t)
	var hand_scale: Vector3 = cur_basis.get_scale()
	_gun.global_transform.basis = Basis(q).scaled(hand_scale)


## Aim rest direction: the hand [param HandL] will ease toward pointing at this node's world position.
func set_gun_rest(node: Node3D) -> void:
	_gun_rest_node = node
	set_physics_process(node != null)


## World-space "up" for aiming so look_at matches a tilted officer/camera parent (not world Y only).
func _aim_up_world() -> Vector3:
	var up: Vector3 = global_transform.basis.y
	if up.length_squared() < 1e-10:
		return Vector3.UP
	return up.normalized()


func _basis_aiming_hand_at(world_aim: Vector3) -> Basis:
	var eye: Vector3 = _gun.global_position
	if (world_aim - eye).length_squared() < 1e-10:
		return _gun.global_transform.basis
	var up_w: Vector3 = _aim_up_world()
	_aim_scratch.global_transform = Transform3D(Basis(), eye)
	_aim_scratch.look_at(world_aim, up_w)
	# look_at aligns -Z to the target; gun art uses -X forward, so rotate -90° around local Y.
	_aim_scratch.rotate_object_local(Vector3.UP, -PI / 2.0)
	return _aim_scratch.global_transform.basis


func _aim_hand_at_world(world_aim: Vector3) -> void:
	if (world_aim - _gun.global_position).length_squared() < 1e-10:
		return
	_gun.look_at(world_aim, _aim_up_world())
	# look_at aligns -Z to the target; gun art uses -X forward, so rotate -90° around local Y.
	_gun.rotate_object_local(Vector3.UP, -PI / 2.0)


func _on_shot_aim_hold_finished() -> void:
	_shot_aim_hold_active = false


func _process(delta: float) -> void:
	if not _is_dialog_active:
		return
	if not _line_typing_done:
		_line_elapsed += delta
		var total_chars: int = _speech_label.get_total_character_count()
		var target_shown: int = mini(
			floori(_line_elapsed * _SPEAK_CHARS_PER_SEC),
			total_chars
		)
		if target_shown > _chars_shown:
			for i in range(_chars_shown, target_shown):
				var ch: String = _current_line[i]
				if ch != " " and ch != "\t":
					if i % 3 == 0:
						_play_speak_blip()
			_chars_shown = target_shown
			_speech_label.visible_characters = _chars_shown
		if _chars_shown >= total_chars:
			_line_typing_done = true
			_line_pause_left = _LINE_PAUSE_AFTER_TYPING_SEC
		return
	if _line_pause_left > 0.0:
		_line_pause_left = maxf(0.0, _line_pause_left - delta)
		if _line_pause_left <= 0.0:
			_start_next_line()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_dialog_active:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		if (event as InputEventKey).keycode == KEY_SPACE:
			_advance_speech()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_advance_speech()
			get_viewport().set_input_as_handled()


## Shows the dialog, types out [param text] (newline-separated lines). Optional [param on_finished]
## runs when the last line has been read and dismissed. Space or left-click skips typing, skips the
## pause after a line, or advances early after the line pause.
func speak(text: String, on_finished: Callable = Callable()) -> void:
	_abort_speech_silent()
	_dialogue_lines.clear()
	for block: String in text.split("\n"):
		var s: String = block.strip_edges()
		if not s.is_empty():
			_dialogue_lines.append(s)
	if _dialogue_lines.is_empty():
		if on_finished.is_valid():
			on_finished.call()
		return
	_on_speech_finished = on_finished
	_is_dialog_active = true
	_dialog_box.visible = true
	_line_index = 0
	set_process(true)
	_start_next_line()


func _abort_speech_silent() -> void:
	_is_dialog_active = false
	_on_speech_finished = Callable()
	_dialog_box.visible = false
	_speech_label.visible_characters = -1
	set_process(false)


func _start_next_line() -> void:
	if _line_index >= _dialogue_lines.size():
		_finish_speech()
		return
	_current_line = _dialogue_lines[_line_index]
	_line_index += 1
	_chars_shown = 0
	_line_elapsed = 0.0
	_line_typing_done = false
	_line_pause_left = 0.0
	_speech_label.text = _current_line
	_speech_label.visible_characters = 0


func _advance_speech() -> void:
	if not _is_dialog_active:
		return
	if not _line_typing_done:
		_chars_shown = _speech_label.get_total_character_count()
		_speech_label.visible_characters = -1
		_line_typing_done = true
		_line_pause_left = _LINE_PAUSE_AFTER_TYPING_SEC
		return
	_start_next_line()


func _finish_speech() -> void:
	var cb: Callable = _on_speech_finished
	_abort_speech_silent()
	if cb.is_valid():
		cb.call()


func _play_speak_blip() -> void:
	_play_sfx_grab_bag(_speak_sfx, _SPEAK_SFX_CLIPS)


func shot_at(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var aim: Vector3 = target.global_position
	if (aim - _gun.global_position).length_squared() < 1e-10:
		return
	_aim_hand_at_world(aim)
	if _gun_rest_node != null and is_instance_valid(_gun_rest_node):
		_shot_aim_hold_active = true
		_gun_rest_return_timer.start()
	_muzzle_flash.visible = true
	_muzzle_timer.stop()
	_muzzle_timer.wait_time = _MUZZLE_FLASH_SEC
	_muzzle_timer.start()
	_play_smoking_one_shot()
	_play_sfx_grab_bag(_shot_sfx, _SHOT_CLIPS)
	get_tree().call_group("spectator", "jump_on_shot")


func _hide_muzzle_flash() -> void:
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false


func _play_smoking_one_shot() -> void:
	if not is_instance_valid(_smoking):
		return
	if _smoke_process_material != null:
		if _smoke_size_tween != null and is_instance_valid(_smoke_size_tween):
			_smoke_size_tween.kill()
		_smoke_process_material.scale_min = _SMOKE_SCALE_START
		_smoke_process_material.scale_max = _SMOKE_SCALE_START
		_smoke_size_tween = create_tween()
		_smoke_size_tween.tween_property(
			_smoke_process_material,
			"scale_min",
			_SMOKE_SCALE_END,
			_smoking.lifetime
		)
		_smoke_size_tween.parallel().tween_property(
			_smoke_process_material,
			"scale_max",
			_SMOKE_SCALE_END,
			_smoking.lifetime
		)
	_smoking.restart()
	_smoking.emitting = true
