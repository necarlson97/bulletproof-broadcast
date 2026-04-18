extends Node3D
class_name Parade

@export var parade_line_scene: PackedScene = preload("res://parade_line.tscn")
@export var line_strings: Array[String] = []
@export var marching_speed: float = 300.0
@export var start_z: float = -1400.0
@export var end_z: float = 300.0
@export var check_z: float = 100.0
## Distance along Z between consecutive line spawns; spawn interval = line_spawn_spacing / marching_speed.
@export var line_spawn_spacing: float = 1000.0
## Horizontal budget for each parade line; spacing_per_char = line_width / sum of spec char counts.
@export var line_width: float = 800.0
## Scales sign board target width (see ParadeLine.sign_target_width_multiplier).
@export var sign_target_width_multiplier: float = 2.2


func _ready() -> void:
	add_to_group("parade")
	_spawn_lines()


func _spawn_lines() -> void:
	var speed: float = maxf(marching_speed, 0.001)
	var stagger: float = line_spawn_spacing / speed
	for i: int in range(line_strings.size()):
		var pl: Node = parade_line_scene.instantiate()
		pl.setup(
			line_strings[i],
			marching_speed,
			start_z,
			end_z,
			line_width,
			check_z,
			sign_target_width_multiplier
		)
		add_child(pl)
		pl.begin_march(stagger * float(i))
