class_name SpreadingDroplet
extends Node3D

const _GROW_SPEED: float = 10.0
const _SHRINK_SEC: float = 0.22

enum _State { INACTIVE, GROWING, FULL, SHRINKING }

@onready var _sprite: Sprite3D = $Sprite3D

var _state: _State = _State.INACTIVE
var _current_radius: float = 1.0
var _target_radius: float = 1.0
var _shrink_tween: Tween


func _ready() -> void:
	deactivate()


func activate(ground_pos: Vector3, start_radius: float) -> void:
	if _shrink_tween != null and _shrink_tween.is_valid():
		_shrink_tween.kill()
		_shrink_tween = null
	_state = _State.GROWING
	visible = true
	_sprite.modulate = BloodDroplets.BLOOD_COLOR
	global_position = ground_pos
	_current_radius = start_radius
	var lo: float = minf(start_radius, BloodDroplets.SPREAD_MAX_WORLD)
	var hi: float = BloodDroplets.SPREAD_MAX_WORLD
	if lo >= hi - 0.001:
		_target_radius = lo
	else:
		_target_radius = randf_range(lo, hi)
	_apply_radius(_current_radius)
	set_process(true)


func deactivate() -> void:
	if _shrink_tween != null and _shrink_tween.is_valid():
		_shrink_tween.kill()
		_shrink_tween = null
	_state = _State.INACTIVE
	visible = false
	_sprite.scale = Vector3.ONE
	set_process(false)


func shrink() -> void:
	if _state == _State.INACTIVE or _state == _State.SHRINKING:
		return
	BloodDroplets.unregister_spreading_fifo(self)
	_state = _State.SHRINKING
	set_process(false)
	if _shrink_tween != null and _shrink_tween.is_valid():
		_shrink_tween.kill()
	_shrink_tween = create_tween()
	_shrink_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shrink_tween.tween_property(_sprite, "scale", Vector3.ZERO, _SHRINK_SEC)
	_shrink_tween.finished.connect(_on_shrink_finished, CONNECT_ONE_SHOT)


func _on_shrink_finished() -> void:
	_shrink_tween = null
	BloodDroplets.return_spreading_to_pool(self)


func _apply_radius(world_radius: float) -> void:
	var tex: Texture2D = _sprite.texture
	if tex == null:
		return
	var half_w: float = float(tex.get_width()) * _sprite.pixel_size * 0.5
	var s: float = world_radius / maxf(0.001, half_w)
	_sprite.scale = Vector3.ONE * s


func _process(delta: float) -> void:
	if _state != _State.GROWING:
		return
	_current_radius = move_toward(_current_radius, _target_radius, _GROW_SPEED * delta)
	_apply_radius(_current_radius)
	if absf(_current_radius - _target_radius) < 0.04:
		_current_radius = _target_radius
		_apply_radius(_current_radius)
		_state = _State.FULL
		set_process(false)
