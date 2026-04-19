extends Node

## Plays [grim-smirk, respite] in order, then loops forever. Non-spatial; Music bus only.

const _TRACKS: Array[AudioStream] = [
	preload("res://assets/music/chagrin.wav"),
	preload("res://assets/music/respite.wav"),
	preload("res://assets/music/grim-smirk.wav"),
	
]

var _track_index: int = 0

@onready var _player: AudioStreamPlayer = $MusicStream


func _ready() -> void:
	_player.bus = "Music"
	_player.finished.connect(_on_track_finished)
	_play_current()


func _on_track_finished() -> void:
	_track_index = (_track_index + 1) % _TRACKS.size()
	_play_current()


func _play_current() -> void:
	_player.stream = _TRACKS[_track_index]
	_player.play()
