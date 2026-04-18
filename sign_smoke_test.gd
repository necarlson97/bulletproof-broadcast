extends Node3D

@onready var _sign: Sign = $Sign
@onready var _sign_flippable: SignFlippable = $SignFlippable

const _FULL_TEXT := "this is a test one two three"


func _ready() -> void:
	_run()


func _run() -> void:
	_sign_flippable.set_contents("good text", "bad text")
	_flip_after_delay()
	_grow_sign_text()


func _flip_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	_sign_flippable.flip()


func _grow_sign_text() -> void:
	for end: int in range(_FULL_TEXT.length() + 1):
		_sign.set_text(_FULL_TEXT.substr(0, end))
		if end < _FULL_TEXT.length():
			await get_tree().create_timer(0.5).timeout
