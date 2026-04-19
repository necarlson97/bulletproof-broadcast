extends Node3D
class_name Limelight

const _CONE_MASK_MATERIAL: ShaderMaterial = preload("res://limelight/materials/limelight_mask_cone_anchor_material.tres")

## Ground plane (Y=0) orbit around an assigned target. Retarget uses a tweened blend toward
## the new goal, then continuous lerp while the target moves.
## Mask mesh: LimelightRender mask layer + limelight_mask_fill material (white into mask RT).
## Put any extra geometry on that layer with the same material to add holes (no shader array).

@export var orbit_radius: float = 12.0
@export var orbit_speed: float = 0.35
@export var retarget_duration: float = 1.25
@export var follow_lerp: float = 6.0
## Half-size in X/Z for idle wander when there is no follow target and no [member _orbit_focus] (2000×2000 at default 1000).
@export var wander_half_extent: float = 500.0
@export_range(0.05, 120.0, 0.05, "or_greater") var wander_step_duration_min: float = 8.0
@export_range(0.05, 120.0, 0.05, "or_greater") var wander_step_duration_max: float = 10.0

var _orbit_center: Vector3 = Vector3.ZERO
var _orbit_angle: float = 0.0
var _target: Node3D
var _retarget_start: Vector3 = Vector3.ZERO
var _in_retarget: bool = false
var _retarget_tween: Tween
var _wander_tween: Tween

var _tip_anchor: Node3D
var _tip_local: Vector3 = Vector3.ZERO
var _shader_mat: ShaderMaterial

## When set (e.g. by [Limelighter] child [code]ManualFocus[/code]), orbit center follows this node if there is no [member _target].
var _orbit_focus: Node3D


func _ready() -> void:
	_orbit_angle = randf() * TAU
	var mi: MeshInstance3D = $MeshInstance3D
	_shader_mat = _CONE_MASK_MATERIAL.duplicate() as ShaderMaterial
	mi.material_override = _shader_mat
	# Apex is moved in the mask shader; inflate AABB so frustum culling matches visible geometry.
	mi.extra_cull_margin = 16384.0
	# Layer 10 — must match LimelightRender.MASK_RENDER_LAYER in limelight_render.gd
	mi.layers = 1 << 9
	_orbit_center = global_position
	_cache_cone_tip_local(mi.mesh)
	_update_cone_anchor_shader()


func _cache_cone_tip_local(mesh: Mesh) -> void:
	## CylinderMesh with top_radius == 0: cone tip at y = +height/2 (mesh is centered on origin).
	if mesh is CylinderMesh:
		var c: CylinderMesh = mesh as CylinderMesh
		if is_equal_approx(c.top_radius, 0.0) and c.height > 0.0:
			_tip_local = Vector3(0.0, c.height * 0.5, 0.0)
			_shader_mat.set_shader_parameter("tip_local", _tip_local)
			_shader_mat.set_shader_parameter("tip_snap_epsilon", maxf(0.02, c.height * 1e-4))
			return
	push_warning("Limelight: expected CylinderMesh cone (top_radius 0) for apex pinning; tip shader may miss vertices.")


func set_tip_anchor(node: Node3D) -> void:
	_tip_anchor = node


func get_tip_anchor() -> Node3D:
	return _tip_anchor


func set_orbit_focus(focus: Node3D) -> void:
	if focus != null and is_instance_valid(focus):
		_kill_wander_tween()
	_orbit_focus = focus


func get_orbit_focus() -> Node3D:
	return _orbit_focus


func _process(delta: float) -> void:
	# Priority: explicit follow target → ManualFocus → idle wander in a square around origin.
	if _target != null and is_instance_valid(_target):
		_kill_wander_tween()
		if not _in_retarget:
			var goal_t: Vector3 = _flatten_xz(_target.global_position)
			var kt: float = clampf(follow_lerp * delta, 0.0, 1.0)
			_orbit_center = _orbit_center.lerp(goal_t, kt)
	elif _orbit_focus != null and is_instance_valid(_orbit_focus):
		_kill_wander_tween()
		var goal_focus: Vector3 = _flatten_xz(_orbit_focus.global_position)
		var kf: float = clampf(follow_lerp * delta, 0.0, 1.0)
		_orbit_center = _orbit_center.lerp(goal_focus, kf)
	else:
		_advance_wander_if_idle()

	_orbit_angle = fmod(_orbit_angle + orbit_speed * delta, TAU)
	var offset: Vector3 = Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * orbit_radius
	var p: Vector3 = _orbit_center + offset
	#p.y = 0.0
	global_position = p
	_update_cone_anchor_shader()


func _update_cone_anchor_shader() -> void:
	if _shader_mat == null:
		return
	var mi: MeshInstance3D = $MeshInstance3D
	var tip_world: Vector3 = mi.global_transform * _tip_local
	if _tip_anchor != null and is_instance_valid(_tip_anchor):
		tip_world = _tip_anchor.global_position
	_shader_mat.set_shader_parameter("tip_world", tip_world)
	_shader_mat.set_shader_parameter("inv_model_matrix", mi.global_transform.affine_inverse())


func set_target(new_target: Node3D) -> void:
	_kill_wander_tween()
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
	# Wander resumes next frame in _process when there is no ManualFocus.


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


func _kill_wander_tween() -> void:
	if _wander_tween != null and is_instance_valid(_wander_tween):
		_wander_tween.kill()
	_wander_tween = null


func _advance_wander_if_idle() -> void:
	if _wander_tween != null and is_instance_valid(_wander_tween):
		return
	var h: float = wander_half_extent
	var goal: Vector3 = Vector3(
		randf_range(-h, h),
		0.0,
		-h + randf_range(-h, h),
	)
	var start: Vector3 = _orbit_center
	var lo: float = minf(wander_step_duration_min, wander_step_duration_max)
	var hi: float = maxf(wander_step_duration_min, wander_step_duration_max)
	var step_sec: float = randf_range(lo, hi)
	_wander_tween = create_tween()
	_wander_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wander_tween.tween_method(_apply_wander_blend.bind(start, goal), 0.0, 1.0, step_sec)
	_wander_tween.finished.connect(_on_wander_leg_finished, CONNECT_ONE_SHOT)


func _apply_wander_blend(t: float, start: Vector3, goal: Vector3) -> void:
	_orbit_center = start.lerp(goal, t)


func _on_wander_leg_finished() -> void:
	_wander_tween = null


static func _flatten_xz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
