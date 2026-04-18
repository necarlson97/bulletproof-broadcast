extends Node3D
class_name Parade

@export var parade_line_scene: PackedScene = preload("res://parade_line.tscn")
@export var line_strings: Array[String] = []
@export var marching_speed: float = 300.0
@export var start_z: float = -1400.0
@export var end_z: float = 100.0
## Distance along Z between consecutive line spawns; spawn interval = line_spawn_spacing / marching_speed.
@export var line_spawn_spacing: float = 120.0


func _ready() -> void:
	_spawn_lines()


func _spawn_lines() -> void:
	var speed: float = maxf(marching_speed, 0.001)
	var stagger: float = line_spawn_spacing / speed
	for i: int in range(line_strings.size()):
		var pl: ParadeLine = parade_line_scene.instantiate() as ParadeLine
		pl.setup(line_strings[i], marching_speed, start_z, end_z)
		add_child(pl)
		pl.begin_march(stagger * float(i))
