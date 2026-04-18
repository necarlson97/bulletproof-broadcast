extends Person
class_name Officer

const _MUZZLE_FLASH_SEC := 0.1

const _SHOT_CLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/shot.wav"),
]

@onready var _gun: Node3D = $HandL
@onready var _muzzle_flash: Node3D = $HandL/Gun/MuzzelFlash
@onready var _shot_sfx: AudioStreamPlayer3D = $ShotSfx

var _muzzle_timer: Timer


func _ready() -> void:
	_muzzle_flash.visible = false
	_muzzle_timer = Timer.new()
	_muzzle_timer.one_shot = true
	_muzzle_timer.timeout.connect(_hide_muzzle_flash)
	add_child(_muzzle_timer)


func shot_at(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var aim: Vector3 = target.global_position
	if (aim - _gun.global_position).length_squared() < 1e-10:
		return
	_gun.look_at(aim, Vector3.UP)
	# look_at aligns -Z to the target; gun art uses -X forward, so rotate -90° around local Y.
	_gun.rotate_object_local(Vector3.UP, -PI / 2.0)
	_muzzle_flash.visible = true
	_muzzle_timer.stop()
	_muzzle_timer.wait_time = _MUZZLE_FLASH_SEC
	_muzzle_timer.start()
	_play_sfx_grab_bag(_shot_sfx, _SHOT_CLIPS)
	get_tree().call_group("spectator", "jump_on_shot")


func _hide_muzzle_flash() -> void:
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false
