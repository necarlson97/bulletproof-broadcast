extends Node

## Global 5s cadence: every living [Trumpet] plays the same clip, then the clip index advances.

const INTERVAL_SEC := 5.0

## [method Trumpet.on_trumpet_sfx_play] on each registered trumpet root (SpriteSound visible while audio plays).
const _TRUMPET_PLAY_METHOD := &"on_trumpet_sfx_play"

const _CLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/trumpet-1.wav"),
	preload("res://assets/sfx/trumpet-2.wav"),
	preload("res://assets/sfx/trumpet-3.wav"),
	preload("res://assets/sfx/trumpet-4.wav"),
]

var _clip_index: int = 0
var _entries: Array[Dictionary] = []


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = INTERVAL_SEC
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_on_trumpet_tick)


func register_trumpet(root: Node3D, player: AudioStreamPlayer3D) -> void:
	if root == null or player == null:
		return
	for e: Dictionary in _entries:
		if e["player"] == player:
			return
	_entries.append({"root": root, "player": player})


func unregister_trumpet(player: AudioStreamPlayer3D) -> void:
	if player == null:
		return
	var next: Array[Dictionary] = []
	for e: Dictionary in _entries:
		if e["player"] != player:
			next.append(e)
	_entries = next


func _on_trumpet_tick() -> void:
	if _CLIPS.is_empty():
		return
	var stream: AudioStream = _CLIPS[_clip_index % _CLIPS.size()]
	_clip_index += 1
	var next: Array[Dictionary] = []
	for e: Dictionary in _entries:
		var root: Node3D = e["root"]
		var p: AudioStreamPlayer3D = e["player"]
		if not is_instance_valid(root) or not root.is_inside_tree():
			continue
		if not is_instance_valid(p) or not p.is_inside_tree():
			continue
		if root.has_method(_TRUMPET_PLAY_METHOD):
			root.call(_TRUMPET_PLAY_METHOD)
		p.stream = stream
		p.play()
		next.append(e)
	_entries = next
