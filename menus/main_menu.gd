extends Node3D

const TUTORIAL_SCENE := "res://tutorial.tscn"
const MAIN_SCENE := "res://main.tscn"

## After [method Officer.shot_at], wait this long before running the menu action (scene change, settings, etc.).
@export var menu_action_delay_sec: float = 0.45

@onready var _officer: Officer = $Officer
@onready var _pause_menu: CanvasLayer = $MainMenuPause
@onready var _tutorial_holder: ButtonHolder = $TutorialHolder
@onready var _start_holder: ButtonHolder = $StartHolder
@onready var _settings_holder: ButtonHolder = $SettingsHolder
@onready var _settings_spawner: SettingsHolderSpawner = $SettingsHolderSpawner

var _gun_rest_target: Node3D
var _last_hovered: ButtonHolder
var _action_timer: Timer
var _pending_button_id: String = ""


func _ready() -> void:
	_gun_rest_target = Node3D.new()
	_gun_rest_target.name = "MenuGunRestTarget"
	add_child(_gun_rest_target)
	_last_hovered = _start_holder
	_sync_gun_rest_to_face(_last_hovered)
	_officer.set_gun_rest(_gun_rest_target)
	set_physics_process(true)

	_action_timer = Timer.new()
	_action_timer.one_shot = true
	_action_timer.timeout.connect(_on_menu_action_delay_finished)
	add_child(_action_timer)

	var holders: Array[ButtonHolder] = [_tutorial_holder, _start_holder, _settings_holder]
	for h: ButtonHolder in holders:
		if not h.hover_began.is_connected(_on_holder_hover_began):
			h.hover_began.connect(_on_holder_hover_began)
		if not h.pressed.is_connected(_on_holder_pressed):
			h.pressed.connect(_on_holder_pressed)

	if not _settings_spawner.settings_holder_changed.is_connected(_on_settings_holder_changed):
		_settings_spawner.settings_holder_changed.connect(_on_settings_holder_changed)


func _physics_process(_delta: float) -> void:
	if _last_hovered != null and is_instance_valid(_last_hovered):
		_sync_gun_rest_to_face(_last_hovered)


func _on_settings_holder_changed(holder: ButtonHolder) -> void:
	_settings_holder = holder
	if not holder.hover_began.is_connected(_on_holder_hover_began):
		holder.hover_began.connect(_on_holder_hover_began)
	if not holder.pressed.is_connected(_on_holder_pressed):
		holder.pressed.connect(_on_holder_pressed)


func _on_holder_hover_began(holder: ButtonHolder) -> void:
	_last_hovered = holder


func _sync_gun_rest_to_face(holder: ButtonHolder) -> void:
	var head: Node3D = holder.get_head_node()
	if head != null and is_instance_valid(head):
		_gun_rest_target.global_position = head.global_position


func _on_holder_pressed(button_id: String, holder: ButtonHolder) -> void:
	var head: Node3D = holder.get_head_node()
	var aim: Node3D = head if head != null and is_instance_valid(head) else holder
	_officer.shot_at(aim)
	holder.kill()
	if _last_hovered == holder:
		_last_hovered = null
	_pending_button_id = button_id
	_action_timer.stop()
	_action_timer.wait_time = maxf(menu_action_delay_sec, 0.05)
	_action_timer.start()


func _on_menu_action_delay_finished() -> void:
	var id: String = _pending_button_id
	_pending_button_id = ""
	match id:
		"Tutorial":
			get_tree().change_scene_to_file(TUTORIAL_SCENE)
		"Start Parade":
			get_tree().change_scene_to_file(MAIN_SCENE)
		"Settings":
			_pause_menu.open_pause_menu()
		_:
			pass
