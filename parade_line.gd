extends Node3D
class_name ParadeLine

## Emitted once when this line first crosses [member check_z] with at least one disloyal parader still in line.
signal disloyal_present_at_check_z
## Emitted when the march tween completes (before the line is freed).
signal line_march_finished

const _DIGITS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const _PARADER_FLEE_SCRIPT: GDScript = preload("res://people/parader_flee.gd")
const _PIT_PREFABS: Array[PackedScene] = [
	preload("res://people/flag_holder.tscn"),
	preload("res://people/baton_holder.tscn"),
	preload("res://people/trumpet_holder.tscn"),
]

## Parade road width in line-local X; all horizontal spacing is derived from this.
const ROAD_WIDTH: float = 450.0


static func get_parader_personal_space_units(specs: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for spec: Dictionary in specs:
		var f: String = str(spec.get("front", ""))
		var b: String = str(spec.get("back", ""))
		if b.is_empty():
			out.append(f.length())
		else:
			out.append(maxi(f.length(), b.length()))
	return out


static func get_parader_personal_world_space(
	units: Array[int], road_width: float = ROAD_WIDTH
) -> Array[float]:
	var sum_u: int = 0
	for u: int in units:
		sum_u += u
	if sum_u <= 0:
		return []
	var out: Array[float] = []
	var per_unit: float = road_width / float(sum_u)
	for u: int in units:
		out.append(per_unit * float(u))
	return out


static func get_parader_center_x_targets(
	personal_world_space: Array[float], road_width: float = ROAD_WIDTH
) -> Array[float]:
	var n: int = personal_world_space.size()
	if n == 0:
		return []
	var halves: Array[float] = []
	for w: float in personal_world_space:
		halves.append(w * 0.5)
	var xs_from_left: Array[float] = []
	var x: float = 0.0
	for i: int in range(n):
		x += halves[i]
		if i > 0:
			x += halves[i - 1]
		xs_from_left.append(x)
	var left_offset: float = -road_width * 0.5
	var targets: Array[float] = []
	for xl: float in xs_from_left:
		targets.append(left_offset + xl)
	return targets


@export var parader_scene: PackedScene = preload("res://people/parader.tscn")

var line_string: String = ""
## Stable order among siblings; set by [Parade] when spawning (for [FocusedLine]).
var spawn_index: int = -1
var marching_speed: float = 300.0
var start_z: float = -1400.0
## March target (off screen); line is freed when reached.
var end_z: float = 300.0
## Along the march path: disloyal paraders still present are logged when the line crosses this Z.
var check_z: float = 100.0
## Clamped between [member start_z] and [member end_z]; first leg uses [member approach_speed], second [member marching_speed].
var fence_line_z: float = -700.0
## If not greater than [member marching_speed], the whole march uses [member marching_speed] only.
var approach_speed: float = 0.0

var _parader_nodes: Array[Node3D] = []
var _specs: Array[Dictionary] = []
var _march_tween: Tween
var _prev_march_z: float = 0.0
var _check_logged: bool = false
## March path Z from the line tween (authoritative for focus thresholds).
var _line_path_z: float = 0.0
var _had_disloyal_at_spawn: bool = false
## When true, this line was moved under [Parade]'s former-segments bucket; skip disloyal-at-check narrative.
var _retired_from_active_segment: bool = false
## Guard against duplicate delayed-free requests from multiple end paths.
var _free_requested: bool = false
## Hard cap so a looping/bugged audio node cannot keep a line alive forever.
const _AUDIO_TAIL_MAX_WAIT_SEC: float = 8.0


func retire_from_active_segment() -> void:
	_retired_from_active_segment = true


func _prune_freed_paraders() -> void:
	var i: int = 0
	while i < _parader_nodes.size():
		if is_instance_valid(_parader_nodes[i]):
			i += 1
		else:
			_parader_nodes.remove_at(i)


func setup(
	p_line: String,
	p_speed: float,
	p_start_z: float,
	p_end_z: float,
	p_check_z: float = 100.0,
	p_force_all_disloyal: bool = false,
	p_can_pit: bool = true
) -> void:
	line_string = p_line
	marching_speed = p_speed
	start_z = p_start_z
	end_z = p_end_z
	check_z = p_check_z
	_specs = ParadeLineSyntax.parse_line(line_string, p_can_pit)
	if p_force_all_disloyal:
		for s: Dictionary in _specs:
			if str(s.get("back", "")) == "pp":
				continue
			s["loyal"] = false
	_had_disloyal_at_spawn = _specs_has_any_disloyal()
	_line_path_z = start_z
	_build_paraders()
	_set_target_z(start_z)


## Text after `steps` transition events (see [ParadeLineSyntax]). -1 = full exhaustion.
func decompose(steps: int = 0) -> String:
	return ParadeLineSyntax.decompose(line_string, steps)


func _spawn_paraders() -> void:
	var count: int = _specs.size()
	var flipper_idx: int = 0
	var flip_z_lo: float = minf(lerpf(start_z, check_z, 0.5), lerpf(start_z, check_z, 0.75))
	var flip_z_hi: float = maxf(lerpf(start_z, check_z, 0.5), lerpf(start_z, check_z, 0.75))
	var chosen_pit_prefab: PackedScene = _PIT_PREFABS.pick_random()
	for idx: int in range(count):
		var spec: Dictionary = _specs[idx]
		var back: String = str(spec.get("back", ""))
		var front: String = str(spec.get("front", ""))
		var is_pit: bool = front.replace("p", "") == "" and front.length() > 0
		var flip: bool = not back.is_empty() and not is_pit
		var digit: String = ""
		if count <= 10:
			digit = _DIGITS[idx % 10]
		else:
			if flip:
				digit = _DIGITS[flipper_idx % 10]
				flipper_idx += 1
		var parader_prefab: PackedScene = parader_scene
		if is_pit:
			parader_prefab = chosen_pit_prefab
		var p: Node3D = parader_prefab.instantiate() as Node3D
		add_child(p)
		p.position = Vector3(0.0, 0.0, start_z)
		_parader_nodes.append(p)
		if is_pit:
			p.call("configure_parader", "", null, true, digit, INF)
		else:
			var back_variant: Variant = null
			if not back.is_empty():
				back_variant = back
			var flip_at_z: float = INF
			if flip:
				flip_at_z = randf_range(flip_z_lo, flip_z_hi)
			p.call("configure_parader", spec["front"], back_variant, spec["loyal"], digit, flip_at_z)


func _attach_parader_flee_scripts() -> void:
	var count: int = _specs.size()
	for idx: int in range(count):
		var spec_f: Dictionary = _specs[idx]
		if not spec_f.get("fleeing", false):
			continue
		var watched_idx: int = _nearest_disloyal_index(idx)
		if watched_idx < 0:
			continue
		var flee: Node3D = _PARADER_FLEE_SCRIPT.new() as Node3D
		flee.name = "ParaderFlee"
		var par_i: Node3D = _parader_nodes[idx]
		var par_w: Node3D = _parader_nodes[watched_idx]
		par_i.add_child(flee)
		flee.call("setup", self, par_i as Parader, par_w as Parader)


## Scales each parader's [code]SignScale[/code] so the sign's horizontal extent matches [param personal_world_space] for that index.
## Call only after sign text/layout is set ([method Parader.configure_parader] / [method Sign.set_text]).
func scale_signs(personal_world_space: Array[float] = []) -> void:
	var t: int = _parader_nodes.size()
	if t == 0:
		return
	var world: Array[float] = personal_world_space
	if world.is_empty():
		var units: Array[int] = get_parader_personal_space_units(_specs)
		world = get_parader_personal_world_space(units, ROAD_WIDTH)
	if world.size() != t:
		return
	for i: int in range(t):
		var pr: Parader = _parader_nodes[i] as Parader
		if pr != null and pr.inert_pit:
			continue
		var sign_scale: Node3D = _parader_nodes[i].get_node_or_null("SignScale") as Node3D
		var sign_node: Node3D = _parader_nodes[i].get_node_or_null("SignScale/Sign") as Node3D
		if sign_scale == null or sign_node == null:
			continue
		var board: Sign = sign_node as Sign
		if board == null:
			continue
		var target_w: float = world[i]
		var layout_w: float = board.get_layout_width()
		if layout_w <= 0.001:
			continue
		var cur_w: float = layout_w * absf(sign_scale.scale.x) * absf(sign_node.scale.x)
		if cur_w <= 0.001:
			continue
		var factor: float = target_w / cur_w
		sign_scale.scale *= Vector3(factor, factor, factor)


func _layout_paraders_x() -> void:
	var t: int = _parader_nodes.size()
	if t == 0:
		return
	var units: Array[int] = get_parader_personal_space_units(_specs)
	var world: Array[float] = get_parader_personal_world_space(units, ROAD_WIDTH)
	var targets: Array[float] = get_parader_center_x_targets(world, ROAD_WIDTH)
	if targets.size() != t:
		return
	for i: int in range(t):
		var pr_i: Parader = _parader_nodes[i] as Parader
		if pr_i != null:
			pr_i.set_parade_target(targets[i], _line_path_z)
		else:
			_parader_nodes[i].position.x = targets[i]


func _build_paraders() -> void:
	if _specs.is_empty():
		return

	_spawn_paraders()
	scale_signs()
	_attach_parader_flee_scripts()
	_layout_paraders_x()


func _specs_has_any_disloyal() -> bool:
	for s: Dictionary in _specs:
		if not s["loyal"]:
			return true
	return false


## Whether [FocusedLine] should move to the next spawned line: reached [member check_z], all disloyal
## eliminated past the halfway point to [member check_z], or no paraders left.
func should_release_focus() -> bool:
	_prune_freed_paraders()
	if _parader_nodes.is_empty():
		return true
	var z: float = _line_path_z
	if _passed_march_threshold(z, check_z):
		return true
	if _had_disloyal_at_spawn and _no_disloyal_alive() and _passed_march_threshold(
		z, lerpf(start_z, check_z, 0.9)
	):
		return true
	return false


func _passed_march_threshold(z: float, threshold: float) -> bool:
	if is_equal_approx(end_z, start_z):
		return is_equal_approx(z, threshold)
	if end_z > start_z:
		return z >= threshold
	return z <= threshold


func _no_disloyal_alive() -> bool:
	for p: Node3D in _parader_nodes:
		var pr: Parader = p as Parader
		if pr != null and not pr.loyal:
			return false
	return true


## True when no disloyal parader remains in this line (killed paraders are unregistered).
func all_disloyal_eliminated() -> bool:
	_prune_freed_paraders()
	return _no_disloyal_alive()


## Live paraders in line order, for [Limelighter] (empty if none).
func get_limelight_targets() -> Array[Node3D]:
	_prune_freed_paraders()
	var out: Array[Node3D] = []
	for p: Node3D in _parader_nodes:
		out.append(p)
	return out


func get_parader_by_digit(digit: String) -> Parader:
	if digit.is_empty():
		return null
	_prune_freed_paraders()
	for p: Node3D in _parader_nodes:
		var pr: Parader = p as Parader
		if pr == null:
			continue
		var lbl: Label3D = pr.get_node_or_null("Body/Label3D") as Label3D
		if lbl != null and lbl.text == digit:
			return pr
	return null


## Front-to-back sort key: largest Z is the line closest to the march end (positive Z).
func get_line_march_z() -> float:
	_prune_freed_paraders()
	if _parader_nodes.is_empty():
		return global_position.z
	return _parader_nodes[0].global_position.z


func get_focus_bounds_global() -> Variant:
	_prune_freed_paraders()
	if _parader_nodes.is_empty():
		return null
	var min_x: float = INF
	var max_x: float = -INF
	var sum_z: float = 0.0
	var sum_y: float = 0.0
	var n: int = 0
	for p: Node3D in _parader_nodes:
		var half: float = p.call("get_sign_half_width") as float
		var g: Vector3 = p.global_position
		min_x = minf(min_x, g.x - half)
		max_x = maxf(max_x, g.x + half)
		sum_z += g.z
		sum_y += g.y
		n += 1
	var cx: float = (min_x + max_x) * 0.5
	var cz: float = sum_z / float(n)
	var cy: float = sum_y / float(n) + 40.0
	var width: float = maxf(max_x - min_x, 10.0)
	return {
		"center": Vector3(cx, cy, cz),
		"size": Vector3(width + 48.0, 140.0, 90.0),
	}


## Re-centers survivors on X using [method _layout_paraders_x] only (sign scale is unchanged).
func _refit_line_formation_after_casualty() -> void:
	_prune_freed_paraders()
	if _parader_nodes.is_empty():
		return
	_layout_paraders_x()


func unregister_parader_from_march(parader: Node3D) -> void:
	var pr: Parader = parader as Parader
	if pr != null:
		pr.clear_parade_march_follow()
	var at: int = _parader_nodes.find(parader)
	if at < 0:
		return
	_parader_nodes.remove_at(at)
	if at >= 0 and at < _specs.size():
		_specs.remove_at(at)
	_refit_line_formation_after_casualty()


func _nearest_disloyal_index(flee_idx: int) -> int:
	var best: int = -1
	var best_dist: int = 2147483647
	for j: int in range(_specs.size()):
		if _specs[j]["loyal"]:
			continue
		var d: int = absi(j - flee_idx)
		if d < best_dist or (d == best_dist and j < best):
			best_dist = d
			best = j
	return best


func _set_target_z(z: float) -> void:
	_prune_freed_paraders()
	for p: Node3D in _parader_nodes:
		var pr: Parader = p as Parader
		if pr != null:
			pr.set_parade_line_z(z)
		else:
			p.position.z = z
	_update_disloyal_sweating_near_check()


func _update_disloyal_sweating_near_check() -> void:
	const NEAR_CHECK: float = 200.0
	for p: Node3D in _parader_nodes:
		var pr: Parader = p as Parader
		if pr == null or pr.loyal:
			continue
		var near: bool = absf(p.position.z - check_z) <= NEAR_CHECK
		pr.set_sweating_active(near)


func _crossed_z_marching(prev_z: float, cur_z: float, threshold: float) -> bool:
	if is_equal_approx(prev_z, cur_z):
		return false
	if end_z > start_z:
		return prev_z < threshold and cur_z >= threshold
	if end_z < start_z:
		return prev_z > threshold and cur_z <= threshold
	return false


func _log_disloyal_at_check() -> void:
	if _retired_from_active_segment:
		return
	_prune_freed_paraders()
	var any_disloyal: bool = false
	for i: int in _parader_nodes.size():
		var p: Node3D = _parader_nodes[i]
		var pr: Parader = p as Parader
		if pr == null:
			continue
		if pr.loyal:
			continue
		any_disloyal = true
		print("[ParadeLine] disloyal parader still in line at check_z=%s (index %d, node %s)" % [check_z, i, p.name])
	if any_disloyal:
		GameStats.malcontents_broadcast += 1
		disloyal_present_at_check_z.emit()


func _march_step(z: float) -> void:
	if not _check_logged and _crossed_z_marching(_prev_march_z, z, check_z):
		_check_logged = true
		_log_disloyal_at_check()
	_prev_march_z = z
	_line_path_z = z
	_set_target_z(z)


func _on_march_finished() -> void:
	line_march_finished.emit()
	_queue_free_after_audio_tail()


## Stops the march and frees the line without emitting [signal line_march_finished] (e.g. segment ended early).
func abort_march_without_completion() -> void:
	if _march_tween != null:
		_march_tween.kill()
		_march_tween = null
	_queue_free_after_audio_tail()


func _queue_free_after_audio_tail() -> void:
	if _free_requested:
		return
	_free_requested = true
	var active_audio: Array[Node] = []
	_collect_active_audio_children_recursive(self, active_audio)
	if active_audio.is_empty():
		queue_free()
		return
	var state: Dictionary = {
		"remaining": active_audio.size(),
		"finished": false,
	}
	var complete_free := func () -> void:
		if bool(state["finished"]):
			return
		state["finished"] = true
		queue_free()
	for n: Node in active_audio:
		if not is_instance_valid(n):
			state["remaining"] = int(state["remaining"]) - 1
			continue
		n.finished.connect(func () -> void:
			state["remaining"] = int(state["remaining"]) - 1
			if int(state["remaining"]) <= 0:
				complete_free.call()
		, CONNECT_ONE_SHOT)
	if int(state["remaining"]) <= 0:
		complete_free.call()
		return
	get_tree().create_timer(_AUDIO_TAIL_MAX_WAIT_SEC).timeout.connect(func () -> void:
		complete_free.call()
	, CONNECT_ONE_SHOT)


func _collect_active_audio_children_recursive(root: Node, out: Array[Node]) -> void:
	for child: Node in root.get_children():
		if _is_active_audio_player(child):
			out.append(child)
		_collect_active_audio_children_recursive(child, out)


func _is_active_audio_player(node: Node) -> bool:
	if (
		not (node is AudioStreamPlayer)
		and not (node is AudioStreamPlayer2D)
		and not (node is AudioStreamPlayer3D)
	):
		return false
	return bool(node.get("playing"))


func begin_march(delay_sec: float) -> void:
	if _march_tween != null:
		_march_tween.kill()
		_march_tween = null
	_check_logged = false
	_prev_march_z = start_z
	_line_path_z = start_z
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout
	var v_slow: float = maxf(marching_speed, 0.001)
	var v_fast: float = v_slow
	if approach_speed > v_slow * 1.001:
		v_fast = maxf(approach_speed, 0.001)
	var lo: float = minf(start_z, end_z)
	var hi: float = maxf(start_z, end_z)
	var fz: float = clampf(fence_line_z, lo, hi)
	var d1: float = absf(fz - start_z)
	var d2: float = absf(end_z - fz)
	_march_tween = create_tween()
	if is_equal_approx(v_fast, v_slow) or d1 < 1e-6:
		var dur_all: float = absf(end_z - start_z) / v_slow
		_march_tween.tween_method(_march_step, start_z, end_z, dur_all).set_trans(Tween.TRANS_LINEAR)
	elif d2 < 1e-6:
		var dur_one: float = d1 / v_fast
		_march_tween.tween_method(_march_step, start_z, end_z, dur_one).set_trans(Tween.TRANS_LINEAR)
	else:
		var t1: float = d1 / v_fast
		var t2: float = d2 / v_slow
		_march_tween.tween_method(_march_step, start_z, fz, t1).set_trans(Tween.TRANS_LINEAR)
		_march_tween.tween_method(_march_step, fz, end_z, t2).set_trans(Tween.TRANS_LINEAR)
	_march_tween.finished.connect(_on_march_finished, CONNECT_ONE_SHOT)
