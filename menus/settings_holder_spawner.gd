extends Node3D
class_name SettingsHolderSpawner

## Path to the initial menu [ButtonHolder] for Settings (sibling under the same parent as this node).
@export var settings_holder_path: NodePath = ^"../SettingsHolder"
## Duration for tweening the respawned holder from the spawner pose back to the saved start transform.
@export var respawn_tween_sec: float = 1.0
@export var settings_button_name: String = "Settings"

const _BUTTON_HOLDER_SCENE := "res://people/button_holder.tscn"

signal settings_holder_changed(holder: ButtonHolder)

var _settings_holder_start_transform: Transform3D
var _holder_packed: PackedScene
var _respawn_tween: Tween
## Local transforms from the menu instance (SignScale / Sign differ from [code]button_holder.tscn[/code]).
var _sign_scale_transform: Transform3D
var _sign_transform: Transform3D
var _has_saved_sign_layout: bool = false


func _ready() -> void:
	var initial: ButtonHolder = get_node_or_null(settings_holder_path) as ButtonHolder
	if initial == null:
		push_error("SettingsHolderSpawner: no ButtonHolder at %s" % settings_holder_path)
		return

	_settings_holder_start_transform = initial.global_transform
	_capture_sign_layout(initial)

	var scene_path: String = initial.scene_file_path
	if scene_path.is_empty():
		scene_path = _BUTTON_HOLDER_SCENE
	_holder_packed = load(scene_path) as PackedScene
	if _holder_packed == null:
		push_error("SettingsHolderSpawner: failed to load %s" % scene_path)
		return

	_watch_holder(initial)


func _capture_sign_layout(holder: ButtonHolder) -> void:
	var ss: Node3D = holder.get_node_or_null("SignScale") as Node3D
	if ss == null:
		return
	_sign_scale_transform = ss.transform
	var sign_nd: Node3D = ss.get_node_or_null("Sign") as Node3D
	if sign_nd != null:
		_sign_transform = sign_nd.transform
	_has_saved_sign_layout = true


func _apply_sign_layout(holder: ButtonHolder) -> void:
	if not _has_saved_sign_layout:
		return
	var ss: Node3D = holder.get_node_or_null("SignScale") as Node3D
	if ss == null:
		return
	ss.transform = _sign_scale_transform
	var sign_nd: Node3D = ss.get_node_or_null("Sign") as Node3D
	if sign_nd != null:
		sign_nd.transform = _sign_transform
	# [method ButtonHolder._ready] already ran [method ButtonHolder.set_button_text] with default SignScale.
	holder.set_button_text(holder.button_name)


func _watch_holder(holder: ButtonHolder) -> void:
	if not holder.killed.is_connected(_on_settings_holder_killed):
		holder.killed.connect(_on_settings_holder_killed)


func _on_settings_holder_killed() -> void:
	call_deferred("_spawn_replacement")


func _spawn_replacement() -> void:
	if _holder_packed == null:
		return
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var parent: Node = get_parent()
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return

	var new_holder: ButtonHolder = _holder_packed.instantiate() as ButtonHolder
	if new_holder == null:
		push_error("SettingsHolderSpawner: instantiate() did not return ButtonHolder")
		return

	new_holder.name = "SettingsHolder"
	new_holder.button_name = settings_button_name
	parent.add_child(new_holder)
	_apply_sign_layout(new_holder)
	new_holder.global_transform = global_transform

	if _respawn_tween != null:
		_respawn_tween.kill()
		_respawn_tween = null

	var tw: Tween = new_holder.create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(
		new_holder,
		"global_transform",
		_settings_holder_start_transform,
		maxf(respawn_tween_sec, 0.01),
	)
	_respawn_tween = tw

	_watch_holder(new_holder)
	settings_holder_changed.emit(new_holder)
