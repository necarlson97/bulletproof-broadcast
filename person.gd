class_name Person
extends Node3D

@onready var _eyes = $Face/Eyes


func kill() -> void:
	_eyes.kill()
