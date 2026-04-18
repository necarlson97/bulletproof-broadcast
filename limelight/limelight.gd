extends Node3D
class_name Limelight

const _MASK_FILL_MATERIAL: Material = preload("res://limelight/materials/limelight_mask_fill_material.tres")

## Ground plane (Y=0) orbit around an assigned target. Retarget uses a tweened blend toward
## the new goal, then continuous lerp while the target moves.
## Mask mesh: LimelightRender mask layer + limelight_mask_fill material (white into mask RT).
## Put any extra geometry on that layer with the same material to add holes (no shader array).

@export var orbit_radius: float = 12.0
@export var orbit_speed: float = 0.35
@export var retarget_duration: float = 1.25
@export var follow_lerp: float = 6.0

var _orbit_center: Vector3 = Vector3.ZERO
var _orbit_angle: float = 0.0
var _target: Node3D
var _retarget_start: Vector3 = Vector3.ZERO
var _in_retarget: bool = false
var _retarget_tween: Tween


func _ready() -> void:
	_orbit_angle = randf() * TAU
	global_position.y = 0.0
	var mi: MeshInstance3D = $MeshInstance3D
	mi.material_override = _MASK_FILL_MATERIAL
	# Layer 10 — must match LimelightRender.MASK_RENDER_LAYER in limelight_render.gd
	mi.layers = 1 << 9


func _process(delta: float) -> void:
	if _target != null and is_instance_valid(_target) and not _in_retarget:
		var goal: Vector3 = _flatten_xz(_target.global_position)
		var k: float = clampf(follow_lerp * delta, 0.0, 1.0)
		_orbit_center = _orbit_center.lerp(goal, k)

	_orbit_angle = fmod(_orbit_angle + orbit_speed * delta, TAU)
	var offset: Vector3 = Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * orbit_radius
	var p: Vector3 = _orbit_center + offset
	p.y = 0.0
	global_position = p


func set_target(new_target: Node3D) -> void:
	if _retarget_tween != null and is_instance_valid(_retarget_tween):
		_retarget_tween.kill()
		_retarget_tween = null

	_target = new_target
	if new_target == null or not is_instance_valid(new_target):
		_in_retarget = false
		return

	_retarget_start = _orbit_center
	_in_retarget = true
	_retarget_tween = create_tween()
	_retarget_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_retarget_tween.tween_method(_apply_retarget_blend, 0.0, 1.0, retarget_duration)
	_retarget_tween.finished.connect(_on_retarget_finished, CONNECT_ONE_SHOT)


func clear_target() -> void:
	if _retarget_tween != null and is_instance_valid(_retarget_tween):
		_retarget_tween.kill()
		_retarget_tween = null
	_target = null
	_in_retarget = false


func get_follow_target() -> Node3D:
	return _target


func _apply_retarget_blend(t: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var goal: Vector3 = _flatten_xz(_target.global_position)
	_orbit_center = _retarget_start.lerp(goal, t)


func _on_retarget_finished() -> void:
	_retarget_tween = null
	_in_retarget = false


static func _flatten_xz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
