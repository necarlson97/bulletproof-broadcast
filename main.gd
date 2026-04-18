extends Node3D

const _PARADE_SCENE: PackedScene = preload("res://parade.tscn")


func _ready() -> void:
	var parade: Parade = _PARADE_SCENE.instantiate() as Parade
	parade.line_strings = [
		"Our [Great,Awful] (Leader,Cheif) is [protecting][ruining] your life",
	]
	parade.marching_speed = 300.0
	parade.line_spawn_spacing = 120.0
	add_child(parade)
