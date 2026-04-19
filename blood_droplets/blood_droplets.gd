extends Node

## Pool manager for falling blood droplets and ground spreading stains.
## Autoload name: [code]BloodDroplets[/code].

const BLOOD_COLOR := Color("c64e44ff")
const FALLING_SCENE := preload("res://blood_droplets/falling_droplet.tscn")
const SPREADING_SCENE := preload("res://blood_droplets/spreading_droplet.tscn")

const FALLING_POOL_INITIAL := 128
## Max spreading droplets in [b]growing[/b] or [b]full[/b] state; shrinking ones do not count.
const SPREADING_MAX_GROWING := 146
## Upper cap for random spread target radius (world units).
const SPREAD_MAX_WORLD := 28.0

const KILL_DROPLET_COUNT_MIN := 1
const KILL_DROPLET_COUNT_MAX := 3

var _container: Node3D

var _falling_idle: Array[FallingDroplet] = []
var _spreading_idle: Array[SpreadingDroplet] = []
var _spreading_fifo: Array[SpreadingDroplet] = []


func _ready() -> void:
	call_deferred("_ensure_container_and_prewarm")


func _ensure_container_and_prewarm() -> void:
	_ensure_container_sync()


func _ensure_container_sync() -> void:
	if _container != null and is_instance_valid(_container):
		return
	_falling_idle.clear()
	_spreading_idle.clear()
	_spreading_fifo.clear()
	_container = null
	var parent: Node3D = get_tree().root.get_node_or_null("Main") as Node3D
	if parent == null:
		var cs: Node = get_tree().current_scene
		if cs is Node3D:
			parent = cs as Node3D
	if parent == null:
		return
	var c := Node3D.new()
	c.name = "BloodDropletsRoot"
	parent.add_child(c)
	_container = c
	_prewarm_falling()


func _prewarm_falling() -> void:
	if _container == null:
		return
	for i in FALLING_POOL_INITIAL:
		var fd: FallingDroplet = FALLING_SCENE.instantiate() as FallingDroplet
		_container.add_child(fd)
		fd.deactivate()
		_falling_idle.append(fd)


func spawn_kill_spray(origin: Vector3) -> void:
	_ensure_container_sync()
	if _container == null or not is_instance_valid(_container):
		return
	var n: int = randi_range(KILL_DROPLET_COUNT_MIN, KILL_DROPLET_COUNT_MAX)
	for i in n:
		var fd: FallingDroplet = _acquire_falling()
		# Origin is bullet-hole world position (already torso height); only jitter — do not add large +Y
		# (that offset was for when origin was the person root near ground).
		var spawn_pos: Vector3 = origin + Vector3(
			randf_range(-4.0, 4.0),
			randf_range(-4.0, 4.0),
			randf_range(1.0, 4.0)
		)
		var vel: Vector3 = Vector3(
			randf_range(-14.0, 14.0),
			randf_range(6.0, 32.0),
			randf_range(10.0, 14.0)
		)
		var u: float = randf_range(0.3, 1.15)
		fd.activate(spawn_pos, vel, u)


func _acquire_falling() -> FallingDroplet:
	while not _falling_idle.is_empty():
		var raw: Variant = _falling_idle.pop_back()
		if is_instance_valid(raw):
			return raw as FallingDroplet
	var fresh: FallingDroplet = FALLING_SCENE.instantiate() as FallingDroplet
	_container.add_child(fresh)
	return fresh


func register_falling_landed(fd: FallingDroplet, ground_pos: Vector3, world_radius: float) -> void:
	if not is_instance_valid(fd):
		return
	_ensure_container_sync()
	if _container == null or not is_instance_valid(_container):
		return
	_release_falling(fd)
	_spawn_spreading(ground_pos, world_radius)


func _release_falling(fd: FallingDroplet) -> void:
	if not is_instance_valid(fd):
		return
	fd.deactivate()
	_falling_idle.append(fd)


func _spawn_spreading(ground_pos: Vector3, start_radius: float) -> void:
	while _spreading_fifo.size() >= SPREADING_MAX_GROWING:
		var raw_oldest: Variant = _spreading_fifo.pop_front()
		if is_instance_valid(raw_oldest):
			(raw_oldest as SpreadingDroplet).shrink()
	var sd: SpreadingDroplet = _acquire_spreading()
	sd.activate(ground_pos, start_radius)
	_spreading_fifo.append(sd)


func _acquire_spreading() -> SpreadingDroplet:
	while not _spreading_idle.is_empty():
		var raw: Variant = _spreading_idle.pop_back()
		if is_instance_valid(raw):
			return raw as SpreadingDroplet
	var fresh: SpreadingDroplet = SPREADING_SCENE.instantiate() as SpreadingDroplet
	_container.add_child(fresh)
	return fresh


func unregister_spreading_fifo(sd: SpreadingDroplet) -> void:
	var i: int = _spreading_fifo.find(sd)
	if i >= 0:
		_spreading_fifo.remove_at(i)


func return_spreading_to_pool(sd: SpreadingDroplet) -> void:
	if not is_instance_valid(sd):
		return
	sd.deactivate()
	_spreading_idle.append(sd)
