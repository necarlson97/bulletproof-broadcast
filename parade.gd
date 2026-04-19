extends Node3D
class_name Parade

## If false, [method begin_marches] must be called (e.g. after intro dialogue).
@export var auto_start: bool = true

@export var parade_line_scene: PackedScene = preload("res://parade_line.tscn")
@export var line_strings: Array[String] = []
@export var marching_speed: float = 300.0
@export var start_z: float = -1400.0
@export var end_z: float = 300.0
@export var check_z: float = 100.0
## Along the march path: lines use [member approach_speed] until this Z, then [member marching_speed]. Clamped between [member start_z] and [member end_z].
@export var fence_line_z: float = -700.0
## March speed from [member start_z] up to [member fence_line_z]. If not greater than [member marching_speed], the entire route uses marching speed only.
@export var approach_speed: float = 900.0
## World-Z gap between consecutive lines when each starts; stagger follows the same fast-then-slow timing as each line's march.
@export var line_spawn_spacing: float = 1000.0
## Horizontal budget for each parade line; spacing_per_char = line_width / sum of spec char counts.
@export var line_width: float = 50.0
## Scales sign board target width (see ParadeLine.sign_target_width_multiplier).
@export var sign_target_width_multiplier: float = 10.0
## When set, spawned [ParadeLine]s use this instead of each line's default [member ParadeLine.parader_scene].
@export var parader_scene_override: PackedScene
## Overrides parsed loyalty: every parader is disloyal (e.g. protest wave).
@export var force_all_paraders_disloyal: bool = false
## Passed to each spawned [ParadeLine] (band bookends).
@export var pit_paraders_enabled: bool = true
@export var min_line_width_for_pit_paraders: float = 450.0

var _march_delays: Array[float] = []
## Holds prior segments' [ParadeLine]s so they can finish marching after [method load_from_template].
var _former_segments: Node3D


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


func _march_time_for_world_distance(distance: float) -> float:
	if distance <= 0.0:
		return 0.0
	var lo: float = minf(start_z, end_z)
	var hi: float = maxf(start_z, end_z)
	var fz: float = clampf(fence_line_z, lo, hi)
	var v_slow: float = maxf(marching_speed, 0.001)
	var v_fast: float = v_slow
	if approach_speed > v_slow * 1.001:
		v_fast = maxf(approach_speed, 0.001)
	var d_fast_leg: float = absf(fz - start_z)
	if is_equal_approx(v_fast, v_slow):
		return distance / v_slow
	if distance <= d_fast_leg + 1e-6:
		return distance / v_fast
	return d_fast_leg / v_fast + (distance - d_fast_leg) / v_slow


func _spawn_lines() -> void:
	_march_delays.clear()
	var stagger: float = _march_time_for_world_distance(line_spawn_spacing)
	for i: int in range(line_strings.size()):
		var pl: ParadeLine = parade_line_scene.instantiate() as ParadeLine
		pl.spawn_index = i
		if parader_scene_override != null:
			pl.parader_scene = parader_scene_override
		pl.fence_line_z = fence_line_z
		pl.approach_speed = approach_speed
		pl.pit_paraders_enabled = pit_paraders_enabled
		pl.min_line_width_for_pit_paraders = min_line_width_for_pit_paraders
		pl.setup(
			line_strings[i],
			marching_speed,
			start_z,
			end_z,
			line_width,
			check_z,
			sign_target_width_multiplier,
			force_all_paraders_disloyal
		)
		add_child(pl)
		_march_delays.append(stagger * float(i))
	if auto_start:
		begin_marches()


## Copies segment fields from another [Parade] (e.g. an off-tree template). Does not spawn lines.
func apply_segment_config_from(source: Parade) -> void:
	if source == null:
		return
	line_strings = source.line_strings.duplicate()
	marching_speed = source.marching_speed
	approach_speed = source.approach_speed
	fence_line_z = source.fence_line_z
	start_z = source.start_z
	end_z = source.end_z
	check_z = source.check_z
	line_spawn_spacing = source.line_spawn_spacing
	line_width = source.line_width
	sign_target_width_multiplier = source.sign_target_width_multiplier
	force_all_paraders_disloyal = source.force_all_paraders_disloyal
	pit_paraders_enabled = source.pit_paraders_enabled
	min_line_width_for_pit_paraders = source.min_line_width_for_pit_paraders
	parader_scene_override = source.parader_scene_override
	if source.parade_line_scene != null:
		parade_line_scene = source.parade_line_scene


func _ensure_former_segments() -> void:
	if _former_segments != null and is_instance_valid(_former_segments):
		return
	_former_segments = Node3D.new()
	_former_segments.name = "FormerParadeLines"
	add_child(_former_segments)
	move_child(_former_segments, 0)


## Moves active [ParadeLine] children under [member _former_segments] so they keep marching off-screen,
## then applies [param template] and spawns the next segment as direct children.
func load_from_template(template: Parade) -> void:
	_ensure_former_segments()
	var to_reparent: Array[Node] = []
	for c: Node in get_children():
		if c == _former_segments:
			continue
		if c is ParadeLine:
			to_reparent.append(c)
	for c: Node in to_reparent:
		(c as ParadeLine).retire_from_active_segment()
		c.reparent(_former_segments)
	apply_segment_config_from(template)
	await get_tree().process_frame
	_spawn_lines()


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


## Frees every [ParadeLine] (active direct children and any under [member _former_segments]).
func abort_all_parade_lines() -> void:
	for c: Node in get_children():
		var pl: ParadeLine = c as ParadeLine
		if pl != null:
			pl.abort_march_without_completion()
	if _former_segments != null and is_instance_valid(_former_segments):
		var linger: Array[Node] = _former_segments.get_children()
		for c: Node in linger:
			var pl2: ParadeLine = c as ParadeLine
			if pl2 != null:
				pl2.abort_march_without_completion()
