extends CanvasLayer

const MAIN_SCENE := "res://main.tscn"
const MAIN_MENU_SCENE := "res://menus/main_menu.tscn"

const _TWEEN_SEC := 0.35

const _OVERVIEW_COLOR_SAFE := "2E3A3F"
const _OVERVIEW_COLOR_DANGER := "D8C36A"
const _OVERVIEW_COLOR_DEAD := "A13A32"

const _SPEAK_SFX_PREVIEW_CLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/heh-1.wav"),
	preload("res://assets/sfx/heh-2.wav"),
	preload("res://assets/sfx/heh-3.wav"),
	preload("res://assets/sfx/heh-4.wav"),
	preload("res://assets/sfx/heh-5.wav"),
	preload("res://assets/sfx/heh-6.wav"),
	preload("res://assets/sfx/heh-7.wav"),
]

@onready var _dimmer: ColorRect = $Dimmer
@onready var _panel: PanelContainer = $Panel
@onready var _label_overview: RichTextLabel = $Panel/MarginContainer/VBox/LabelOverview
@onready var _label_parade: Label = $Panel/MarginContainer/VBox/LabelParadeLines
@onready var _label_malcontents: Label = $Panel/MarginContainer/VBox/LabelMalcontents
@onready var _label_loyalists: Label = $Panel/MarginContainer/VBox/LabelLoyalists
@onready var _label_traitors: Label = $Panel/MarginContainer/VBox/LabelTraitors
@onready var _btn_resume: Button = $Panel/MarginContainer/VBox/BtnResume
@onready var _btn_retry: Button = $Panel/MarginContainer/VBox/BtnRetry
@onready var _btn_main_menu: Button = $Panel/MarginContainer/VBox/BtnMainMenu
@onready var _slider_sfx: HSlider = $Panel/MarginContainer/VBox/RowSfx/HSliderSfx
@onready var _slider_music: HSlider = $Panel/MarginContainer/VBox/RowMusic/HSliderMusic
@onready var _volume_preview: AudioStreamPlayer = $VolumePreviewSfx

## Autoload singleton (see project.godot).
@onready var _stats: Node = get_node("/root/GameStats")

var _paused: bool = false
var _saved_time_scale: float = 1.0
var _panel_tween: Tween

var _sfx_bus: int = -1
var _music_bus: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_bus = AudioServer.get_bus_index("SFX")
	_music_bus = AudioServer.get_bus_index("Music")
	_dimmer.visible = false
	_panel.visible = false
	_slider_sfx.min_value = 0.0
	_slider_sfx.max_value = 1.0
	_slider_sfx.step = 0.01
	_slider_music.min_value = 0.0
	_slider_music.max_value = 1.0
	_slider_music.step = 0.01
	_slider_sfx.value = _linear_from_bus_index(_sfx_bus)
	_slider_music.value = _linear_from_bus_index(_music_bus)
	_slider_sfx.value_changed.connect(_on_sfx_slider_changed)
	_slider_music.value_changed.connect(_on_music_slider_changed)
	_slider_sfx.drag_ended.connect(_on_volume_slider_drag_ended)
	_slider_music.drag_ended.connect(_on_volume_slider_drag_ended)
	_btn_resume.pressed.connect(_on_resume_pressed)
	_btn_retry.pressed.connect(_on_retry_pressed)
	_btn_main_menu.pressed.connect(_on_main_menu_pressed)


func toggle_pause(_button_id: String = "") -> void:
	if _paused:
		_close_pause()
	else:
		_open_pause()


## Opens the pause overlay with current stats. If already paused, refreshes labels only.
func open_pause_menu() -> void:
	if _paused:
		_refresh_stats()
		return
	await _open_pause()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE:
		return
	toggle_pause()
	get_viewport().set_input_as_handled()


func _kill_panel_tween() -> void:
	if _panel_tween != null and is_instance_valid(_panel_tween):
		_panel_tween.kill()
	_panel_tween = null


func _open_pause() -> void:
	_kill_panel_tween()
	_saved_time_scale = Engine.time_scale
	Engine.time_scale = 0.0
	_paused = true
	_refresh_stats()
	_dimmer.visible = true
	_panel.visible = true
	await get_tree().process_frame
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = _panel.size.x
	var h: float = _panel.size.y
	var end_x: float = (vp.x - w) * 0.5
	var end_y: float = (vp.y - h) * 0.5
	_panel.position = Vector2(end_x, -h - 80.0)
	_panel_tween = create_tween()
	_panel_tween.set_ignore_time_scale(true)
	_panel_tween.tween_property(_panel, "position", Vector2(end_x, end_y), _TWEEN_SEC).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	await _panel_tween.finished
	_panel_tween = null


func _close_pause() -> void:
	if not _paused:
		return
	_kill_panel_tween()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = _panel.size.x
	var h: float = _panel.size.y
	var start_x: float = (vp.x - w) * 0.5
	var end_y: float = -h - 80.0
	_panel_tween = create_tween()
	_panel_tween.set_ignore_time_scale(true)
	_panel_tween.tween_property(_panel, "position", Vector2(start_x, end_y), _TWEEN_SEC).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_IN)
	await _panel_tween.finished
	_panel_tween = null
	_dimmer.visible = false
	_panel.visible = false
	Engine.time_scale = _saved_time_scale
	_paused = false


func _refresh_stats() -> void:
	var mal: int = int(_stats.get("malcontents_broadcast"))
	var overview_hex: String = _OVERVIEW_COLOR_SAFE
	var overview_msg: String = "You are safe"
	if mal >= 4:
		overview_hex = _OVERVIEW_COLOR_DEAD
		overview_msg = "You are dead"
	elif mal >= 1:
		overview_hex = _OVERVIEW_COLOR_DANGER
		overview_msg = "You are in danger"
	_label_overview.text = "[color=#%s]%s[/color]" % [overview_hex, overview_msg]

	var pt: Vector2i = _parade_lines_progress()
	_label_parade.text = "%d of %d parade lines cleansed" % [pt.x, pt.y]
	_label_malcontents.text = "%d malcontents broadcast" % mal
	_label_loyalists.text = "%d loyalists executed" % int(_stats.get("loyalists_executed"))
	_label_traitors.text = "%d traitors executed" % int(_stats.get("traitors_executed"))


func _parade_lines_progress() -> Vector2i:
	var parades: Array[Node] = get_tree().get_nodes_in_group("parade")
	if parades.is_empty():
		return Vector2i(0, 0)
	var parade: Parade = parades[0] as Parade
	var total: int = 0
	if parade != null:
		total = parade.line_strings.size()
	var alive: int = 0
	for c: Node in parades[0].get_children():
		if c is ParadeLine:
			alive += 1
	var cleansed: int = maxi(0, total - alive)
	return Vector2i(cleansed, total)


func _linear_from_bus_index(bus_idx: int) -> float:
	if bus_idx < 0:
		return 1.0
	if AudioServer.is_bus_mute(bus_idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))


func _set_bus_linear(bus_idx: int, linear: float) -> void:
	if bus_idx < 0:
		return
	if linear <= 0.0001:
		AudioServer.set_bus_mute(bus_idx, true)
		AudioServer.set_bus_volume_db(bus_idx, -80.0)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_linear(bus_idx, linear)


func _on_sfx_slider_changed(value: float) -> void:
	_set_bus_linear(_sfx_bus, value)


func _on_music_slider_changed(value: float) -> void:
	_set_bus_linear(_music_bus, value)


func _on_volume_slider_drag_ended(_value_changed: bool) -> void:
	_play_speech_sfx_volume_preview()


func _play_speech_sfx_volume_preview() -> void:
	if _volume_preview == null or _SPEAK_SFX_PREVIEW_CLIPS.is_empty():
		return
	_volume_preview.stream = _SPEAK_SFX_PREVIEW_CLIPS.pick_random()
	_volume_preview.pitch_scale = randf_range(0.92, 1.08)
	_volume_preview.play()


func _on_resume_pressed() -> void:
	if not _paused:
		return
	await _close_pause()


func _on_retry_pressed() -> void:
	_kill_panel_tween()
	Engine.time_scale = 1.0
	_paused = false
	_dimmer.visible = false
	_panel.visible = false
	GameStats.reset()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_main_menu_pressed() -> void:
	_kill_panel_tween()
	Engine.time_scale = 1.0
	_paused = false
	_dimmer.visible = false
	_panel.visible = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_settings_holder_pressed(button_id: String) -> void:
	open_pause_menu()
