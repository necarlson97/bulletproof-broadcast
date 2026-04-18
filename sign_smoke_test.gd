extends Node2D

@onready var _sign: Node2D = $Sign

const _FULL_TEXT := "this is a test one two three"


func _ready() -> void:
	_run()


func _run() -> void:
	for end: int in range(_FULL_TEXT.length() + 1):
		_sign.set_text(_FULL_TEXT.substr(0, end))
		if end < _FULL_TEXT.length():
			await get_tree().create_timer(0.5).timeout
