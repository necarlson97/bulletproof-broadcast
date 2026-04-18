class_name Person
extends Node2D

@onready var _eyes = $Face/Eyes


func kill() -> void:
	_eyes.kill()
