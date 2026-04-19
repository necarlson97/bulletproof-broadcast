extends Node3D

## Idle animation for imported tank: body rumble, wheel spin, turret yaw + barrel pitch toward active Camera3D.

@export var rumble_enabled: bool = true
## Max random offset per axis (local space, same units as the scene).
@export var rumble_amount: float = 0.04
@export var rumble_interval: float = 0.1

@export var wheels_enabled: bool = true
@export var wheel_spin_speed: float = 4.0
## Axle axis in each wheel's local space (often Vector3.RIGHT for side wheels).
@export var wheel_spin_axis: Vector3 = Vector3.UP

@export var aim_enabled: bool = true
## Added to computed yaw if the mesh forward axis does not match +Z on XZ.
@export var turret_yaw_offset: float = 0.0
## Extra twist around barrel local X after aiming (radians); mesh uses +Y as bore axis at rest.
@export var barrel_pitch_offset: float = 0.0

@onready var _body: Node3D = $body
@onready var _turret: Node3D = $turret
@onready var _barrel: Node3D = $barrel
@onready var _wheels: Array[Node3D] = []

var _body_base_position: Vector3
var _rumble_tween: Tween
var _rumble_timer: Timer


func _ready() -> void:
	_body_base_position = _body.position
	for wheel_name in ["wheel", "wheel_001", "wheel_002"]:
		var w := get_node_or_null(wheel_name) as Node3D
		if w != null:
			_wheels.append(w)
	if rumble_enabled:
		_rumble_timer = Timer.new()
		_rumble_timer.wait_time = rumble_interval
		_rumble_timer.timeout.connect(_on_rumble_tick)
		_rumble_timer.autostart = true
		add_child(_rumble_timer)
		_on_rumble_tick()


func _process(delta: float) -> void:
	if wheels_enabled:
		var step := wheel_spin_speed * delta
		for w in _wheels:
			w.rotate_object_local(wheel_spin_axis.normalized(), step)
	if aim_enabled:
		_apply_aim()


func _apply_aim() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cam_pos := cam.global_position
	# Horizontal yaw from turret position (XZ plane).
	var to_cam_xz := Vector3(cam_pos.x - _turret.global_position.x, 0.0, cam_pos.z - _turret.global_position.z)
	if to_cam_xz.length_squared() < 1e-8:
		return
	to_cam_xz = to_cam_xz.normalized()
	var yaw := atan2(to_cam_xz.x, to_cam_xz.z) + turret_yaw_offset
	_turret.rotation.y = yaw
	# Rest pose: barrel points along local +Y (vertical). Aim by aligning +Y toward camera, then optional X tweak.
	var to_barrel := cam_pos - _barrel.global_position
	if to_barrel.length_squared() < 1e-8:
		return
	var dir_world := to_barrel.normalized()
	var basis_world := _basis_with_y_aligned_to(dir_world)
	basis_world = basis_world * Basis.from_euler(Vector3(barrel_pitch_offset, 0.0, 0.0))
	var parent := _barrel.get_parent_node_3d() as Node3D
	if parent == null:
		return
	var basis_local := parent.global_transform.basis.inverse() * basis_world
	var scl := _barrel.basis.get_scale()
	_barrel.basis = basis_local.orthonormalized().scaled_local(scl)


## Rest pose: local +Y is the bore axis. Builds a rotation-only basis whose +Y matches [dir] (world space).
func _basis_with_y_aligned_to(dir: Vector3, up_ref: Vector3 = Vector3.UP) -> Basis:
	var y_axis := dir.normalized()
	var x_axis := up_ref.cross(y_axis)
	if x_axis.length_squared() < 1e-10:
		x_axis = Vector3.RIGHT.cross(y_axis)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _on_rumble_tick() -> void:
	if _rumble_tween != null:
		_rumble_tween.kill()
	_rumble_tween = create_tween()
	var jitter := Vector3(
		randf_range(-rumble_amount, rumble_amount),
		randf_range(-rumble_amount, rumble_amount),
		randf_range(-rumble_amount, rumble_amount)
	)
	_rumble_tween.tween_property(_body, ^"position", _body_base_position + jitter, rumble_interval)
