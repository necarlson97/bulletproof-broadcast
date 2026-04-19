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
## Looped: wait 1–2s → tween 5s to a random point → wait 1–2s → tween 1–2s back toward camera.
@export var distraction_enabled: bool = true
## Random look target is this far from the turret (world units).
@export var distraction_target_distance: float = 35.0
@export var distraction_target_distance_jitter: float = 15.0
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
var _halted: bool = false

## When true, _process does not drive aim (tween_method does). When false and not following camera, _aim_hold_point is used.
var _aim_in_tween: bool = false
var _aim_follow_camera: bool = true
var _aim_hold_point: Vector3


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
	if not _halted and aim_enabled and distraction_enabled:
		_distraction_loop()


func halt_animation() -> void:
	_halted = true
	set_process(false)
	if _rumble_timer != null and is_instance_valid(_rumble_timer):
		_rumble_timer.stop()
	if _rumble_tween != null:
		_rumble_tween.kill()
		_rumble_tween = null
	for child in get_children():
		if child.get_class() == "Tween":
			child.call(&"kill")


func _process(_delta: float) -> void:
	if _halted:
		return
	if wheels_enabled:
		var step := wheel_spin_speed * _delta
		for w in _wheels:
			w.rotate_object_local(wheel_spin_axis.normalized(), step)
	if not aim_enabled or _aim_in_tween:
		return
	if _aim_follow_camera:
		_apply_aim()
	else:
		_apply_aim_to_point(_aim_hold_point)


func _apply_aim() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_apply_aim_to_point(cam.global_position)


func _apply_aim_to_point(target_world: Vector3) -> void:
	# Horizontal yaw from turret position (XZ plane).
	var to_tgt_xz := Vector3(
		target_world.x - _turret.global_position.x,
		0.0,
		target_world.z - _turret.global_position.z
	)
	if to_tgt_xz.length_squared() < 1e-8:
		return
	to_tgt_xz = to_tgt_xz.normalized()
	var yaw := atan2(to_tgt_xz.x, to_tgt_xz.z) + turret_yaw_offset
	_turret.rotation.y = yaw
	# Rest pose: barrel points along local +Y (vertical). Aim by aligning +Y toward target, then optional X tweak.
	var to_barrel := target_world - _barrel.global_position
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


func _wait_seconds_or_halt(seconds: float) -> void:
	var tree := get_tree()
	var until_ms := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until_ms:
		if _halted or not is_inside_tree():
			return
		await tree.process_frame


## Tween.kill does not emit finished; do not await tween.finished if tweens may be killed.
func _await_tween_or_halt(tw: Tween) -> void:
	var tree := get_tree()
	while is_instance_valid(tw) and tw.is_running():
		if _halted:
			tw.kill()
			return
		await tree.process_frame


func _random_look_target_point() -> Vector3:
	var origin := _turret.global_position
	var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-0.15, 0.95), randf_range(-1.0, 1.0))
	if dir.length_squared() < 1e-6:
		dir = Vector3(1, 0.3, -0.5)
	dir = dir.normalized()
	var dist := distraction_target_distance + randf_range(-distraction_target_distance_jitter, distraction_target_distance_jitter)
	return origin + dir * maxf(5.0, dist)


func _distraction_loop() -> void:
	while is_inside_tree() and distraction_enabled and aim_enabled and not _halted:
		await _wait_seconds_or_halt(randf_range(4.0, 6.0))
		if _halted or not is_inside_tree() or not distraction_enabled or not aim_enabled:
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			continue
		var from_pt := cam.global_position
		var to_pt := _random_look_target_point()
		_aim_follow_camera = false
		_aim_in_tween = true
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(func(w: float) -> void: _aim_lerp_points(from_pt, to_pt, w), 0.0, 1.0, 5.0)
		await _await_tween_or_halt(tw)
		if _halted or not is_inside_tree():
			return
		_aim_in_tween = false
		_aim_hold_point = to_pt
		await _wait_seconds_or_halt(randf_range(4.0, 6.0))
		if _halted or not is_inside_tree() or not distraction_enabled or not aim_enabled:
			return
		_aim_in_tween = true
		var return_dur := randf_range(5.0, 6.0)
		tw = create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(func(w: float) -> void: _aim_lerp_to_live_camera(to_pt, w), 0.0, 1.0, return_dur)
		await _await_tween_or_halt(tw)
		if _halted or not is_inside_tree():
			return
		_aim_in_tween = false
		_aim_follow_camera = true


func _aim_lerp_points(from_pt: Vector3, to_pt: Vector3, w: float) -> void:
	_apply_aim_to_point(from_pt.lerp(to_pt, w))


func _aim_lerp_to_live_camera(from_pt: Vector3, w: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_apply_aim_to_point(from_pt.lerp(cam.global_position, w))


func _on_rumble_tick() -> void:
	if _halted:
		return
	if _rumble_tween != null:
		_rumble_tween.kill()
	_rumble_tween = create_tween()
	var jitter := Vector3(
		randf_range(-rumble_amount, rumble_amount),
		randf_range(-rumble_amount, rumble_amount),
		randf_range(-rumble_amount, rumble_amount)
	)
	_rumble_tween.tween_property(_body, ^"position", _body_base_position + jitter, rumble_interval)
