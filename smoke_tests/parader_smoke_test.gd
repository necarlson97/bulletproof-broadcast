extends Node3D

@onready var _parader: Person = $Parader


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_parader.kill()
