extends Node3D
class_name Limelighter

const LIMELIGHT_COUNT: int = 10

@export var limelight_scene: PackedScene = preload("res://limelight/limelight.tscn")

var _limelights: Array[Limelight] = []


func _ready() -> void:
	_spawn_limelights()


func _spawn_limelights() -> void:
	for i in LIMELIGHT_COUNT:
		var node: Node = limelight_scene.instantiate()
		if node is Limelight:
			add_child(node)
			_limelights.append(node as Limelight)
		else:
			push_error("limelight_scene root must be a Limelight")


## Assigns targets in order; if there are fewer than 10 targets, indices wrap (i % targets.size()).
func set_targets(targets: Array[Node3D]) -> void:
	if targets.is_empty():
		for L in _limelights:
			L.clear_target()
		return
	for i in _limelights.size():
		var t: Node3D = targets[i % targets.size()]
		if is_instance_valid(t):
			_limelights[i].set_target(t)
		else:
			_limelights[i].clear_target()


func get_limelight(index: int) -> Limelight:
	return _limelights[index]


func get_limelight_count() -> int:
	return _limelights.size()
