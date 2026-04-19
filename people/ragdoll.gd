class_name Ragdoll
extends Object

## Builds cardboard-style ragdoll pieces from [param root]: one [RigidBody3D] per direct child.
## A direct child using [code]tank.gd[/code] is handled recursively so its own children split off.
## [Sprite3D] nodes and nested [MeshInstance3D] (not direct children of the piece) are merged into one box collider.
## Each [MeshInstance3D] that is a direct child of the piece gets its own convex collider. The original [param root] is freed.

const DEFAULT_MIN_THICKNESS: float = 1.0
const DEFAULT_RANDOM_LINEAR_MAX: float = 1.5
const DEFAULT_RANDOM_ANGULAR_MAX: float = 2.0

const _TANK_SCRIPT: Script = preload("res://tank.gd")

## Seconds each piece stays fully visible before fading (independent of parade line lifetime).
const LIFETIME_BEFORE_FADE_SEC: float = 300.0
## Fade duration: scale + sprite alpha tweened to zero, then the body is freed.
const FADE_OUT_SEC: float = 6.0


static func create_ragdoll(
	root: Node3D,
	min_thickness: float = DEFAULT_MIN_THICKNESS,
	random_linear_max: float = DEFAULT_RANDOM_LINEAR_MAX,
	random_angular_max: float = DEFAULT_RANDOM_ANGULAR_MAX,
) -> void:
	var parent: Node = root.get_parent()
	if parent == null:
		push_error("Ragdoll.create_ragdoll: root has no parent; cannot spawn ragdoll.")
		return

	var scene_root: Node = parent.get_tree().current_scene

	var anchor_xf: Array[Transform3D] = []
	var merged_local: Array[AABB] = []
	var dup_sources: Array[Node] = []

	for child in root.get_children():
		if not child is Node3D:
			continue
		if _is_tank_script(child):
			create_ragdoll(child as Node3D, min_thickness, random_linear_max, random_angular_max)
			continue
		var anchor: Node3D = child as Node3D
		var sprites: Array[Sprite3D] = _find_sprite3ds_under(anchor)
		var nested_meshes: Array[MeshInstance3D] = _find_nested_mesh_instances(anchor)
		var direct_meshes: Array[MeshInstance3D] = _find_direct_mesh_instances(anchor)
		if sprites.is_empty() and nested_meshes.is_empty() and direct_meshes.is_empty():
			continue
		var merged: AABB = _merged_joined_bounds_in_anchor_space(anchor, sprites, nested_meshes, min_thickness)
		anchor_xf.append(anchor.global_transform)
		merged_local.append(merged)
		dup_sources.append(anchor)

	if dup_sources.is_empty():
		_detach_killed_sfx_before_root_freed(root, scene_root)
		root.queue_free()
		return

	for i in dup_sources.size():
		var rb := RigidBody3D.new()
		parent.add_child(rb)
		rb.global_transform = anchor_xf[i]

		var dup: Node = dup_sources[i].duplicate()
		_copy_sprite3d_state_from_original(dup_sources[i], dup)
		rb.add_child(dup)
		dup.global_transform = dup_sources[i].global_transform

		var joined: AABB = merged_local[i]
		if joined.size != Vector3.ZERO:
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = joined.size
			cs.shape = box
			rb.add_child(cs)
			cs.position = joined.get_center()

		for dm: MeshInstance3D in _find_direct_mesh_instances(dup_sources[i] as Node3D):
			if dm.mesh == null:
				continue
			var convex: Shape3D = dm.mesh.create_convex_shape(true, false)
			if convex == null:
				continue
			var mcs := CollisionShape3D.new()
			mcs.shape = convex
			mcs.transform = dm.transform
			rb.add_child(mcs)

		rb.linear_velocity = Vector3(
			randf_range(-random_linear_max, random_linear_max),
			randf_range(-random_linear_max, random_linear_max),
			randf_range(-random_linear_max, random_linear_max),
		)
		rb.angular_velocity = Vector3(
			randf_range(-random_angular_max, random_angular_max),
			randf_range(-random_angular_max, random_angular_max),
			randf_range(-random_angular_max, random_angular_max),
		)

		if scene_root != null:
			_reparent_keep_global(rb, scene_root)
		_schedule_piece_fade_and_free(rb)

	_detach_killed_sfx_before_root_freed(root, scene_root)
	root.queue_free()


## [param root] is queued for freeing; move [KilledSfx] out first so one-shots keep playing.
static func _detach_killed_sfx_before_root_freed(root: Node3D, new_parent: Node) -> void:
	if new_parent == null:
		return
	var ap: AudioStreamPlayer3D = root.get_node_or_null("KilledSfx") as AudioStreamPlayer3D
	if ap == null:
		return
	var xf: Transform3D = ap.global_transform
	root.remove_child(ap)
	new_parent.add_child(ap)
	ap.global_transform = xf
	ap.finished.connect(
		func () -> void:
			if is_instance_valid(ap):
				ap.queue_free()
	, CONNECT_ONE_SHOT,
	)


static func _reparent_keep_global(node: Node3D, new_parent: Node) -> void:
	var xf: Transform3D = node.global_transform
	var op: Node = node.get_parent()
	if op != null:
		op.remove_child(node)
	new_parent.add_child(node)
	node.global_transform = xf


static func _schedule_piece_fade_and_free(rb: RigidBody3D) -> void:
	var tree: SceneTree = rb.get_tree()
	if tree == null:
		return
	tree.create_timer(LIFETIME_BEFORE_FADE_SEC).timeout.connect(
		func () -> void:
			_fade_out_and_free_piece(rb)
	)


static func _fade_out_and_free_piece(rb: RigidBody3D) -> void:
	if not is_instance_valid(rb) or not rb.is_inside_tree():
		return
	rb.freeze = true
	var tween: Tween = rb.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(rb, "scale", Vector3.ZERO, FADE_OUT_SEC)
	for s: Sprite3D in _find_sprite3ds_under(rb):
		var end: Color = s.modulate
		end.a = 0.0
		tween.tween_property(s, "modulate", end, FADE_OUT_SEC)
	tween.finished.connect(func (): rb.queue_free(), CONNECT_ONE_SHOT)


## Ensures each duplicated [Sprite3D] matches the live original (texture, etc.) before [method Node._ready] runs.
static func _copy_sprite3d_state_from_original(orig_root: Node, copy_root: Node) -> void:
	if orig_root is Sprite3D and copy_root is Sprite3D:
		var o: Sprite3D = orig_root as Sprite3D
		var c: Sprite3D = copy_root as Sprite3D
		c.texture = o.texture
		c.modulate = o.modulate
		c.region_enabled = o.region_enabled
		c.region_rect = o.region_rect
		if o.material_override != null:
			c.material_override = o.material_override.duplicate()
	var n: int = mini(orig_root.get_child_count(), copy_root.get_child_count())
	for i in n:
		_copy_sprite3d_state_from_original(orig_root.get_child(i), copy_root.get_child(i))


static func _is_tank_script(node: Node) -> bool:
	return node.get_script() == _TANK_SCRIPT


static func _find_sprite3ds_under(node: Node) -> Array[Sprite3D]:
	var out: Array[Sprite3D] = []
	if node is Sprite3D:
		out.append(node as Sprite3D)
	for c in node.get_children():
		for s in _find_sprite3ds_under(c):
			out.append(s)
	return out


static func _find_direct_mesh_instances(anchor: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in anchor.get_children():
		if c is MeshInstance3D:
			out.append(c as MeshInstance3D)
	return out


## [MeshInstance3D] under [param anchor] that are not direct children (joined into one box with sprites).
static func _find_nested_mesh_instances(anchor: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in anchor.get_children():
		if c is MeshInstance3D:
			for ch: Node in c.get_children():
				_collect_mesh_instances_under(ch, out)
		else:
			_collect_mesh_instances_under(c, out)
	return out


static func _collect_mesh_instances_under(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for ch: Node in node.get_children():
		_collect_mesh_instances_under(ch, out)


## Merged box for all [Sprite3D] and nested meshes (see [method _find_nested_mesh_instances]).
static func _merged_joined_bounds_in_anchor_space(
	anchor: Node3D,
	sprites: Array[Sprite3D],
	nested_meshes: Array[MeshInstance3D],
	min_thickness: float,
) -> AABB:
	var inv: Transform3D = anchor.global_transform.affine_inverse()
	var merged: AABB = AABB()
	var first: bool = true
	for s: Sprite3D in sprites:
		var la: AABB = s.get_aabb()
		for ci in range(8):
			var pt: Vector3 = inv * s.global_transform * la.get_endpoint(ci)
			if first:
				merged = AABB(pt, Vector3.ZERO)
				first = false
			else:
				merged = merged.expand(pt)
	for m: MeshInstance3D in nested_meshes:
		if m.mesh == null:
			continue
		var la: AABB = m.get_aabb()
		for ci in range(8):
			var pt: Vector3 = inv * m.global_transform * la.get_endpoint(ci)
			if first:
				merged = AABB(pt, Vector3.ZERO)
				first = false
			else:
				merged = merged.expand(pt)
	if first:
		return AABB()

	var center: Vector3 = merged.get_center()
	var half: Vector3 = Vector3(
		maxf(merged.size.x * 0.5, min_thickness * 0.5),
		maxf(merged.size.y * 0.5, min_thickness * 0.5),
		maxf(merged.size.z * 0.5, min_thickness * 0.5),
	)
	return AABB(center - half, half * 2.0)
