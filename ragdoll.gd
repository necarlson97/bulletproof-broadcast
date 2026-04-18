class_name Ragdoll
extends Object

## Builds cardboard-style ragdoll pieces from [param root]: one [RigidBody3D] per direct child,
## with all [Sprite3D] under that child grouped into a single box collider. The original [param root] is freed.

const DEFAULT_MIN_THICKNESS: float = 0.01
const DEFAULT_RANDOM_LINEAR_MAX: float = 1.5
const DEFAULT_RANDOM_ANGULAR_MAX: float = 2.0


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

	var anchor_xf: Array[Transform3D] = []
	var merged_local: Array[AABB] = []
	var dup_sources: Array[Node] = []

	for child in root.get_children():
		if not child is Node3D:
			continue
		var anchor: Node3D = child as Node3D
		var sprites: Array[Sprite3D] = _find_sprite3ds_under(child)
		if sprites.is_empty():
			continue
		var merged: AABB = _merged_sprite_aabb_in_anchor_space(anchor, sprites, min_thickness)
		if merged.size == Vector3.ZERO:
			continue
		anchor_xf.append(anchor.global_transform)
		merged_local.append(merged)
		dup_sources.append(anchor)

	if dup_sources.is_empty():
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

		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = merged_local[i].size
		cs.shape = box
		rb.add_child(cs)
		cs.position = merged_local[i].get_center()

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

	root.queue_free()


## Ensures each duplicated [Sprite3D] matches the live original (texture, etc.) before [method Node._ready] runs.
static func _copy_sprite3d_state_from_original(orig_root: Node, copy_root: Node) -> void:
	if orig_root is Sprite3D and copy_root is Sprite3D:
		var o: Sprite3D = orig_root as Sprite3D
		var c: Sprite3D = copy_root as Sprite3D
		c.texture = o.texture
		c.modulate = o.modulate
		c.region_enabled = o.region_enabled
		c.region_rect = o.region_rect
	var n: int = mini(orig_root.get_child_count(), copy_root.get_child_count())
	for i in n:
		_copy_sprite3d_state_from_original(orig_root.get_child(i), copy_root.get_child(i))


static func _find_sprite3ds_under(node: Node) -> Array[Sprite3D]:
	var out: Array[Sprite3D] = []
	if node is Sprite3D:
		out.append(node as Sprite3D)
	for c in node.get_children():
		for s in _find_sprite3ds_under(c):
			out.append(s)
	return out


static func _merged_sprite_aabb_in_anchor_space(
	anchor: Node3D,
	sprites: Array[Sprite3D],
	min_thickness: float,
) -> AABB:
	var inv: Transform3D = anchor.global_transform.affine_inverse()
	var merged: AABB = AABB()
	var first: bool = true
	for s in sprites:
		var la: AABB = s.get_aabb()
		for ci in range(8):
			var pt: Vector3 = inv * s.global_transform * la.get_endpoint(ci)
			if first:
				merged = AABB(pt, Vector3.ZERO)
				first = false
			else:
				merged = merged.expand(pt)

	var center: Vector3 = merged.get_center()
	var half: Vector3 = Vector3(
		maxf(merged.size.x * 0.5, min_thickness * 0.5),
		maxf(merged.size.y * 0.5, min_thickness * 0.5),
		maxf(merged.size.z * 0.5, min_thickness * 0.5),
	)
	return AABB(center - half, half * 2.0)
