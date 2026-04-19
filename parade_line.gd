extends Node3D
class_name ParadeLine

## Emitted once when this line first crosses [member check_z] with at least one disloyal parader still in line.
signal disloyal_present_at_check_z
## Emitted when the march tween completes (before the line is freed).
signal line_march_finished

const _DIGITS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const _PARADER_FLEE_SCRIPT: GDScript = preload("res://people/parader_flee.gd")
const _PIT_HOLDER_SCENES: Array[PackedScene] = [
	preload("res://people/flag_holder.tscn"),
	preload("res://people/baton_holder.tscn"),
	preload("res://people/trumpet_holder.tscn"),
]

@export var parader_scene: PackedScene = preload("res://people/parader.tscn")
## Bookend band paraders (flag / baton / trumpet); need horizontal budget — see [member min_line_width_for_pit_paraders].
@export var pit_paraders_enabled: bool = true
@export var min_line_width_for_pit_paraders: float = 450.0

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
## Total horizontal budget. spacing_per_char = line_width / decompose(0).length()
## (visible text at step 0, including spaces between pieces).
## Each parader's SignScale is set so sign width ≈ spacing_per_char * char count * sign_target_width_multiplier.
## Default > 1: gap = board halves + elastic (same size order); boards alone look small next to the air gap.
var line_width: float = 600.0
## Multiplies sign board target width only (parader spacing still uses resulting half-widths + elastic).
var sign_target_width_multiplier: float = 4

## For each adjacent pair (i, i+1): half_width(sign i) + half_width(sign i+1) in parader space.
var _parader_x_targets: Array[float] = []

var _parader_nodes: Array[Node3D] = []
var _specs: Array[Dictionary] = []
var _pit_start: Node3D = null
var _pit_end: Node3D = null
var _march_tween: Tween
var _prev_march_z: float = 0.0
var _check_logged: bool = false
## March path Z from the line tween (authoritative for focus thresholds).
var _line_path_z: float = 0.0
var _had_disloyal_at_spawn: bool = false
## When true, this line was moved under [Parade]'s former-segments bucket; skip disloyal-at-check narrative.
var _retired_from_active_segment: bool = false


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
	p_line_width: float = 800.0,
	p_check_z: float = 100.0,
	p_sign_target_width_multiplier: float = 2.2,
	p_force_all_disloyal: bool = false
) -> void:
	line_string = p_line
	marching_speed = p_speed
	start_z = p_start_z
	end_z = p_end_z
	line_width = p_line_width
	check_z = p_check_z
	sign_target_width_multiplier = p_sign_target_width_multiplier
	_specs = ParadeLineSyntax.parse_line(line_string)
	if p_force_all_disloyal:
		for s: Dictionary in _specs:
			s["loyal"] = false
	_had_disloyal_at_spawn = _specs_has_any_disloyal()
	_line_path_z = start_z
	_build_paraders()
	_set_target_z(start_z)


## Text after `steps` transition events (see [ParadeLineSyntax]). -1 = full exhaustion.
func decompose(steps: int = 0) -> String:
	return ParadeLineSyntax.decompose(line_string, steps)


static func _spec_char_count(spec: Dictionary) -> int:
	var f: String = spec["front"]
	var b: String = spec["back"]
	if b.is_empty():
		return f.length()
	return maxi(f.length(), b.length())


func _spacing_per_char() -> float:
	var visible_len: int = maxi(ParadeLineSyntax.visible_text_length(_specs, 0), 1)
	return line_width / float(visible_len)


func _spawn_paraders() -> void:
	var count: int = _specs.size()
	var flipper_idx: int = 0
	var flip_z_lo: float = minf(lerpf(start_z, check_z, 0.5), lerpf(start_z, check_z, 0.75))
	var flip_z_hi: float = maxf(lerpf(start_z, check_z, 0.5), lerpf(start_z, check_z, 0.75))
	for idx: int in range(count):
		var spec: Dictionary = _specs[idx]
		var back: String = spec["back"]
		var flip: bool = not back.is_empty()
		var digit: String = ""
		if count <= 10:
			digit = _DIGITS[idx % 10]
		else:
			if flip:
				digit = _DIGITS[flipper_idx % 10]
				flipper_idx += 1
		var p: Node3D = parader_scene.instantiate() as Node3D
		add_child(p)
		p.position = Vector3(0.0, 0.0, start_z)
		_parader_nodes.append(p)
		var back_variant: Variant = null
		if not back.is_empty():
			back_variant = back
		var flip_at_z: float = INF
		if flip:
			flip_at_z = randf_range(flip_z_lo, flip_z_hi)
		p.call("configure_parader", spec["front"], back_variant, spec["loyal"], digit, flip_at_z)


func _sign_parader_offset() -> int:
	return 1 if _pit_start != null else 0


func _take_unused_digit(used: Dictionary) -> String:
	for d: String in _DIGITS:
		if not used.has(d):
			used[d] = true
			return d
	return "0"


func _maybe_spawn_pits() -> void:
	_pit_start = null
	_pit_end = null
	if not pit_paraders_enabled:
		return
	if _specs.is_empty():
		return
	if line_width < min_line_width_for_pit_paraders:
		return
	var used: Dictionary = {}
	for i: int in range(_specs.size()):
		var lbl: Label3D = _parader_nodes[i].get_node_or_null("Body/Label3D") as Label3D
		if lbl != null and not lbl.text.is_empty():
			used[lbl.text] = true
	var d0: String = _take_unused_digit(used)
	var d1: String = _take_unused_digit(used)
	var scene_a: PackedScene = _PIT_HOLDER_SCENES[randi() % _PIT_HOLDER_SCENES.size()]
	var scene_b: PackedScene = _PIT_HOLDER_SCENES[randi() % _PIT_HOLDER_SCENES.size()]
	var pit_a: Node3D = scene_a.instantiate() as Node3D
	var pit_b: Node3D = scene_b.instantiate() as Node3D
	add_child(pit_a)
	move_child(pit_a, 0)
	add_child(pit_b)
	pit_a.position = Vector3(0.0, 0.0, start_z)
	pit_b.position = Vector3(0.0, 0.0, start_z)
	_parader_nodes.insert(0, pit_a)
	_parader_nodes.append(pit_b)
	_pit_start = pit_a
	_pit_end = pit_b
	var pr_a: Parader = pit_a as Parader
	var pr_b: Parader = pit_b as Parader
	if pr_a != null:
		pr_a.configure_parader("", null, true, d0, INF)
	if pr_b != null:
		pr_b.configure_parader("", null, true, d1, INF)


func _char_count_for_parader_index(par_idx: int) -> int:
	var t: int = _parader_nodes.size()
	if _pit_start != null and par_idx == 0:
		return 0
	if _pit_end != null and par_idx == t - 1:
		return 0
	var spec_i: int = par_idx - (1 if _pit_start != null else 0)
	return _spec_char_count(_specs[spec_i])


func _scale_signs(spacing_per_char: float) -> void:
	var count: int = _specs.size()
	var off: int = _sign_parader_offset()
	for idx: int in range(count):
		var spec_sc: Dictionary = _specs[idx]
		var cc: int = _spec_char_count(spec_sc)
		var par: Node3D = _parader_nodes[off + idx]
		var sign_scale: Node3D = par.get_node("SignScale") as Node3D
		var sign_node: Sign = par.get_node("SignScale/Sign") as Sign
		var base_w: float = sign_node.get_layout_width() * absf(sign_node.scale.x)
		if base_w > 0.001:
			var target_w: float = spacing_per_char * float(cc) * sign_target_width_multiplier
			var s: float = target_w / base_w
			sign_scale.scale = Vector3(s, s, s)


func _attach_parader_flee_scripts() -> void:
	var count: int = _specs.size()
	var off: int = _sign_parader_offset()
	for idx: int in range(count):
		var spec_f: Dictionary = _specs[idx]
		if not spec_f.get("fleeing", false):
			continue
		var watched_idx: int = _nearest_disloyal_index(idx)
		if watched_idx < 0:
			continue
		var flee: Node3D = _PARADER_FLEE_SCRIPT.new() as Node3D
		flee.name = "ParaderFlee"
		var par_i: Node3D = _parader_nodes[off + idx]
		var par_w: Node3D = _parader_nodes[off + watched_idx]
		par_i.add_child(flee)
		flee.call("setup", self, par_i as Parader, par_w as Parader)


func _layout_paraders_x(spacing_per_char: float) -> void:
	var t: int = _parader_nodes.size()
	var half_widths: Array[float] = []
	for idx: int in range(t):
		var p: Node3D = _parader_nodes[idx]
		half_widths.append(p.call("get_sign_half_width") as float)

	_parader_x_targets.clear()
	var gaps: Array[float] = []
	for k: int in range(t - 1):
		var base: float = half_widths[k] + half_widths[k + 1]
		_parader_x_targets.append(base)
		var c0: int = _char_count_for_parader_index(k)
		var c1: int = _char_count_for_parader_index(k + 1)
		gaps.append(base + spacing_per_char * float(c0 + c1))

	if t == 1:
		var pr_one: Parader = _parader_nodes[0] as Parader
		if pr_one != null:
			pr_one.set_parade_target(0.0, _line_path_z)
		else:
			_parader_nodes[0].position.x = 0.0
		return

	var sum_gaps: float = 0.0
	for g: float in gaps:
		sum_gaps += g

	var x: float = -sum_gaps * 0.5
	for i: int in range(t):
		var pr_i: Parader = _parader_nodes[i] as Parader
		if pr_i != null:
			pr_i.set_parade_target(x, _line_path_z)
		else:
			_parader_nodes[i].position.x = x
		if i < gaps.size():
			x += gaps[i]


func _build_paraders() -> void:
	if _specs.is_empty():
		return

	_spawn_paraders()
	_maybe_spawn_pits()
	var spacing: float = _spacing_per_char()
	_scale_signs(spacing)
	_attach_parader_flee_scripts()
	_layout_paraders_x(spacing)


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


## Re-centers survivors on X using current sign sizes; does not rescale signs (only [_scale_signs] in [_build_paraders]).
func _refit_line_formation_after_casualty() -> void:
	_prune_freed_paraders()
	if _parader_nodes.is_empty():
		return
	var spacing: float = _spacing_per_char()
	_layout_paraders_x(spacing)


func unregister_parader_from_march(parader: Node3D) -> void:
	var pr: Parader = parader as Parader
	if pr != null:
		pr.clear_parade_march_follow()
	var at: int = _parader_nodes.find(parader)
	if at < 0:
		return
	_parader_nodes.remove_at(at)
	if parader == _pit_start:
		_pit_start = null
	elif parader == _pit_end:
		_pit_end = null
	else:
		var sign_idx: int = at - (1 if _pit_start != null else 0)
		if sign_idx >= 0 and sign_idx < _specs.size():
			_specs.remove_at(sign_idx)
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
	queue_free()


## Stops the march and frees the line without emitting [signal line_march_finished] (e.g. segment ended early).
func abort_march_without_completion() -> void:
	if _march_tween != null:
		_march_tween.kill()
		_march_tween = null
	queue_free()


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
