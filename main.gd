extends Node3D

const _PARADE_SCENE: PackedScene = preload("res://parade.tscn")
const _FOCUSED_LINE_SCENE: PackedScene = preload("res://focused_line.tscn")


func _ready() -> void:
	var parade: Node = _PARADE_SCENE.instantiate()
	var lines: Array[String] = [
		"Our [Great,Awful] (King,Leader) is [protecting,ruining] your life.",
		"(Remember,Recall) the [truth,lie] <of> [order,chaos].",
	]
	parade.line_strings = lines
	add_child(parade)
	add_child(_FOCUSED_LINE_SCENE.instantiate())
