extends Node3D

@onready var _sound: Sprite3D = $SpriteSound
@onready var _trumpet_sfx: AudioStreamPlayer3D = $TrumpetSFX


func _ready() -> void:
	_sound.visible = false
	TrumpetSfx.register_trumpet(self, _trumpet_sfx)
	_trumpet_sfx.finished.connect(_on_trumpet_sfx_finished)


func _exit_tree() -> void:
	if _trumpet_sfx != null:
		TrumpetSfx.unregister_trumpet(_trumpet_sfx)


func on_trumpet_sfx_play() -> void:
	_sound.visible = true


func _on_trumpet_sfx_finished() -> void:
	_sound.visible = false
