extends Node3D

@onready var _sound: Sprite3D = $SpriteSound


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_toggle_sound)
	add_child(timer)


func _toggle_sound() -> void:
	_sound.visible = not _sound.visible
