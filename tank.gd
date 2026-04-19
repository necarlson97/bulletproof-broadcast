extends Node3D

## Idle animation for imported tank: body rumble, wheel spin, turret yaw + barrel pitch (random local euler).
## Expects hierarchy: tank/body/(turret/barrel, wheels*, mudflap).

@export var rumble_enabled: bool = true
## Max random offset per axis (local space, same units as the scene).
@export var rumble_amount: float = 0.04
@export var rumble_interval: float = 0.1

@export var wheels_enabled: bool = true
@export var wheel_spin_speed: float = 4.0
## Axle axis in each wheel's local space (often Vector3.RIGHT for side wheels).
@export var wheel_spin_axis: Vector3 = Vector3.UP

@export var aim_enabled: bool = true
@export var distraction_enabled: bool = true
## Idle loop: wait, then tween turret/barrel to new random angles (degrees from scene rest pose).
@export var distraction_wait_min: float = 4.0
@export var distraction_wait_max: float = 6.0
@export var aim_tween_duration_min: float = 4.0
@export var aim_tween_duration_max: float = 6.0
## Random yaw is local Y on the turret, +/- this many degrees from its starting rotation.
@export var aim_turret_range_deg: float = 90.0
## Random pitch is local X on the barrel, +/- this many degrees from its starting rotation.
@export var aim_barrel_range_deg: float = 10.0

@onready var _body: Node3D = $body
@onready var _turret: Node3D = $body/turret
@onready var _barrel: Node3D = $body/turret/barrel
@onready var _wheels: Array[Node3D] = []

var _body_base_position: Vector3
var _rumble_tween: Tween
var _rumble_timer: Timer
var _halted: bool = false

var _base_turret_y: float
var _base_barrel_x: float


func _ready() -> void:
	_body_base_position = _body.position
	_base_turret_y = _turret.rotation.y
	_base_barrel_x = _barrel.rotation.x
	for wheel_name in ["body/wheel", "body/wheel_001", "body/wheel_002"]:
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


func _distraction_loop() -> void:
	while is_inside_tree() and distraction_enabled and aim_enabled and not _halted:
		await _wait_seconds_or_halt(randf_range(distraction_wait_min, distraction_wait_max))
		if _halted or not is_inside_tree() or not distraction_enabled or not aim_enabled:
			return
		var target_y := _base_turret_y + deg_to_rad(randf_range(-aim_turret_range_deg, aim_turret_range_deg))
		var target_x := _base_barrel_x + deg_to_rad(randf_range(-aim_barrel_range_deg, aim_barrel_range_deg))
		var dur := randf_range(aim_tween_duration_min, aim_tween_duration_max)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_turret, ^"rotation:y", target_y, dur)
		tw.tween_property(_barrel, ^"rotation:x", target_x, dur)
		await _await_tween_or_halt(tw)


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
