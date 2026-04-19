class_name FallingDroplet
extends CharacterBody3D

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _active: bool = false


func _ready() -> void:
	deactivate()


func activate(spawn_pos: Vector3, launch_velocity: Vector3, uniform_scale: float) -> void:
	_active = true
	visible = true
	collision_layer = 8
	collision_mask = 1
	up_direction = Vector3.UP
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(50.0)
	global_position = spawn_pos
	velocity = launch_velocity
	_sprite.modulate = BloodDroplets.BLOOD_COLOR
	_sprite.scale = Vector3.ONE * uniform_scale
	_sync_sphere_radius()
	set_physics_process(true)


func deactivate() -> void:
	_active = false
	visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	set_physics_process(false)


func get_world_radius() -> float:
	var tex: Texture2D = _sprite.texture
	if tex == null:
		return 1.0
	var half_w: float = float(tex.get_width()) * _sprite.pixel_size * 0.5
	return half_w * absf(_sprite.scale.x)


func _sync_sphere_radius() -> void:
	var sh: SphereShape3D = _collision.shape as SphereShape3D
	if sh != null:
		sh.radius = maxf(0.2, get_world_radius())


func _physics_process(delta: float) -> void:
	if not _active:
		return
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	velocity.y -= g * delta
	move_and_slide()
	for i in get_slide_collision_count():
		var col: KinematicCollision3D = get_slide_collision(i)
		if col.get_normal().y > 0.45:
			_finish_landing()
			return


func _finish_landing() -> void:
	if not _active:
		return
	_active = false
	set_physics_process(false)
	var pos: Vector3 = _ground_snap_position()
	var r: float = get_world_radius()
	BloodDroplets.register_falling_landed(self, pos, r)


func _ground_snap_position() -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * 8.0
	var to: Vector3 = global_position + Vector3.DOWN * 400.0
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(q)
	var pos: Vector3 = global_position
	if not hit.is_empty():
		pos = hit.position + Vector3.UP * 0.06
	return pos
