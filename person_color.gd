extends Node3D

@export var shirt_start: Color = Color("#A13A32")
@export var shirt_end: Color = Color("#C15A4A")
@export var skin_start: Color = Color("#6B4423")
@export var skin_end: Color = Color("#F1C27D")


func _ready() -> void:
	var skin_color: Color = skin_start.lerp(skin_end, randf())
	var shirt_color: Color = shirt_start.lerp(shirt_end, randf())
	var person: Node = get_parent()
	person.get_node("Face").modulate = skin_color
	person.get_node("HandL").modulate = skin_color
	person.get_node("HandR").modulate = skin_color
	person.get_node("Body").modulate = shirt_color
