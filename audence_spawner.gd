extends Node3D

## Distance between spectator grid points on X/Z (local to this spawner).
@export var spacing: float = 100.0

const _SPECTATOR_SCENE: PackedScene = preload("res://spectator.tscn")

@onready var _bounds_mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	var aabb: AABB = _bounds_mesh.get_aabb()
	var nx: int = maxi(1, int(floor(aabb.size.x / spacing)))
	var nz: int = maxi(1, int(floor(aabb.size.z / spacing)))
	var jitter: float = spacing * 0.25

	for i in range(nx):
		for j in range(nz):
			var lx: float = aabb.position.x + (i + 0.5) * spacing
			var lz: float = aabb.position.z + (j + 0.5) * spacing
			lx += randf_range(-jitter, jitter)
			lz += randf_range(-jitter, jitter)
			var ly: float = aabb.position.y + aabb.size.y

			var local_pt: Vector3 = _bounds_mesh.transform * Vector3(lx, ly, lz)
			var spec: Node3D = _SPECTATOR_SCENE.instantiate() as Node3D
			add_child(spec)
			spec.position = local_pt

	_bounds_mesh.visible = false
