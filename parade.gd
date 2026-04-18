extends Node3D
class_name Parade

## If false, [method begin_marches] must be called (e.g. after intro dialogue).
@export var auto_start: bool = true

signal main_parade_complete

@export var parade_line_scene: PackedScene = preload("res://parade_line.tscn")
@export var line_strings: Array[String] = []
@export var marching_speed: float = 300.0
@export var start_z: float = -1400.0
@export var end_z: float = 300.0
@export var check_z: float = 100.0
## Distance along Z between consecutive line spawns; spawn interval = line_spawn_spacing / marching_speed.
@export var line_spawn_spacing: float = 1000.0
## Horizontal budget for each parade line; spacing_per_char = line_width / sum of spec char counts.
@export var line_width: float = 800.0
## Scales sign board target width (see ParadeLine.sign_target_width_multiplier).
@export var sign_target_width_multiplier: float = 2.2

var _march_delays: Array[float] = []
var _lines_finished: int = 0


func _ready() -> void:
	add_to_group("parade")
	_spawn_lines()


func _process(_delta: float) -> void:
	var e: float = _compute_crowd_excitement_from_disloyal()
	for n: Node in get_tree().get_nodes_in_group("spectator"):
		if not is_instance_valid(n):
			continue
		if "excitement" in n:
			n.set("excitement", e)


## Maps the disloyal parader closest to [member check_z] along Z to [0, 1]: [member start_z] → 0, [member check_z] → 1.
func _compute_crowd_excitement_from_disloyal() -> float:
	var best_z: float = 0.0
	var best_dist: float = INF
	var found: bool = false
	for n: Node in get_tree().get_nodes_in_group("parader"):
		if not is_instance_valid(n):
			continue
		var pr: Parader = n as Parader
		if pr == null or pr.loyal:
			continue
		var zz: float = pr.global_position.z
		var dist: float = absf(zz - check_z)
		if not found or dist < best_dist or (is_equal_approx(dist, best_dist) and zz > best_z):
			found = true
			best_dist = dist
			best_z = zz
	if not found:
		return 0.0
	if is_equal_approx(check_z, start_z):
		return 1.0 if is_equal_approx(best_z, check_z) else 0.0
	return clampf(inverse_lerp(start_z, check_z, best_z), 0.0, 1.0)


func _spawn_lines() -> void:
	_march_delays.clear()
	_lines_finished = 0
	var speed: float = maxf(marching_speed, 0.001)
	var stagger: float = line_spawn_spacing / speed
	for i: int in range(line_strings.size()):
		var pl: ParadeLine = parade_line_scene.instantiate() as ParadeLine
		pl.spawn_index = i
		pl.setup(
			line_strings[i],
			marching_speed,
			start_z,
			end_z,
			line_width,
			check_z,
			sign_target_width_multiplier
		)
		pl.line_march_finished.connect(_on_line_march_finished, CONNECT_ONE_SHOT)
		add_child(pl)
		_march_delays.append(stagger * float(i))
	if auto_start:
		begin_marches()


func begin_marches() -> void:
	var idx: int = 0
	for c: Node in get_children():
		var pl: ParadeLine = c as ParadeLine
		if pl == null:
			continue
		if idx >= _march_delays.size():
			push_warning("Parade.begin_marches: delay index out of range")
			break
		pl.begin_march(_march_delays[idx])
		idx += 1


func _on_line_march_finished() -> void:
	_lines_finished += 1
	if _lines_finished >= line_strings.size():
		main_parade_complete.emit()
