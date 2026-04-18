extends Node3D
class_name ParaderFlee

## Horizontal bands (parade local space) to run off-screen; z target at ground line.
const _FLEE_X_LEFT_MAX: float = -1500.0
const _FLEE_X_LEFT_MIN: float = -2000.0
const _FLEE_X_RIGHT_MIN: float = 1500.0
const _FLEE_X_RIGHT_MAX: float = 2000.0

@export var flee_duration_sec: float = 2.2

var _parade_line: ParadeLine
var _fleer: Parader
var _watched: Parader


func setup(parade_line: ParadeLine, fleer: Parader, watched: Parader) -> void:
	_parade_line = parade_line
	_fleer = fleer
	_watched = watched
	if _watched != null:
		_watched.tree_exiting.connect(_on_watched_exiting, CONNECT_ONE_SHOT)


func _on_watched_exiting() -> void:
	if _parade_line == null or not is_instance_valid(_fleer):
		return
	_parade_line.unregister_parader_from_march(_fleer)
	_fleer.set_sweating_active(true)
	var x: float
	if randf() < 0.5:
		x = randf_range(_FLEE_X_LEFT_MIN, _FLEE_X_LEFT_MAX)
	else:
		x = randf_range(_FLEE_X_RIGHT_MIN, _FLEE_X_RIGHT_MAX)
	var target: Vector3 = Vector3(x, _fleer.position.y, 0.0)
	var tw: Tween = create_tween()
	tw.tween_property(_fleer, "position", target, flee_duration_sec).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tw.finished.connect(_on_flee_tween_finished, CONNECT_ONE_SHOT)


func _on_flee_tween_finished() -> void:
	if is_instance_valid(_fleer):
		_fleer.set_sweating_active(false)
