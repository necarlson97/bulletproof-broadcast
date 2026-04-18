extends Node3D

const TUTORIAL_SCENE := "res://tutorial.tscn"
const MAIN_SCENE := "res://main.tscn"

@onready var _tutorial_holder: ButtonHolder = $TutorialHolder
@onready var _start_holder: ButtonHolder = $StartHolder


func _ready() -> void:
	if not _tutorial_holder.pressed.is_connected(_on_parade_menu_button_pressed):
		_tutorial_holder.pressed.connect(_on_parade_menu_button_pressed)
	if not _start_holder.pressed.is_connected(_on_parade_menu_button_pressed):
		_start_holder.pressed.connect(_on_parade_menu_button_pressed)


func _on_parade_menu_button_pressed(button_id: String) -> void:
	match button_id:
		"Tutorial":
			get_tree().change_scene_to_file(TUTORIAL_SCENE)
		"Start Parade":
			get_tree().change_scene_to_file(MAIN_SCENE)
		_:
			pass
