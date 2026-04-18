extends Node3D
class_name ParadeLine

const _DIGITS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const _PARADER_FLEE_SCRIPT: GDScript = preload("res://parader_flee.gd")

@export var parader_scene: PackedScene = preload("res://parader.tscn")

var line_string: String = ""
var marching_speed: float = 300.0
var start_z: float = -1400.0
## March target (off screen); line is freed when reached.
var end_z: float = 300.0
## Along the march path: disloyal paraders still present are logged when the line crosses this Z.
var check_z: float = 100.0
## Total horizontal budget. spacing_per_char = line_width / sum of per-spec char counts
## (not raw line_string length, so punctuation/spaces do not shrink signs).
## Each parader's SignScale is set so sign width ≈ spacing_per_char * char count * sign_target_width_multiplier.
## Default > 1: gap = board halves + elastic (same size order); boards alone look small next to the air gap.
var line_width: float = 600.0
## Multiplies sign board target width only (parader spacing still uses resulting half-widths + elastic).
var sign_target_width_multiplier: float = 2.2

## For each adjacent pair (i, i+1): half_width(sign i) + half_width(sign i+1) in parader space.
var _parader_x_targets: Array[float] = []

var _parader_nodes: Array[Node3D] = []
var _specs: Array[Dictionary] = []
var _march_tween: Tween
var _prev_march_z: float = 0.0
var _check_logged: bool = false


func setup(
	p_line: String,
	p_speed: float,
	p_start_z: float,
	p_end_z: float,
	p_line_width: float = 800.0,
	p_check_z: float = 100.0,
	p_sign_target_width_multiplier: float = 2.2
) -> void:
	line_string = p_line
	marching_speed = p_speed
	start_z = p_start_z
	end_z = p_end_z
	line_width = p_line_width
	check_z = p_check_z
	sign_target_width_multiplier = p_sign_target_width_multiplier
	_specs = parse_parade_line(line_string)
	_build_paraders()
	_set_target_z(start_z)


static func parse_parade_line(s: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var i: int = 0
	var n: int = s.length()
	while i < n:
		while i < n and s[i] in " \t\n\r":
			i += 1
		if i >= n:
			break
		if s[i] == "(":
			i += 1
			var start_paren: int = i
			while i < n and s[i] != ")":
				i += 1
			var inner: String = s.substr(start_paren, i - start_paren).strip_edges()
			if i < n:
				i += 1
			var comma: int = inner.find(",")
			var front: String = inner
			var back: String = ""
			if comma >= 0:
				front = inner.substr(0, comma).strip_edges()
				back = inner.substr(comma + 1).strip_edges()
			result.append({"loyal": true, "front": front, "back": back})
		elif s[i] == "[":
			i += 1
			var start_br: int = i
			while i < n and s[i] != "]":
				i += 1
			var inner_b: String = s.substr(start_br, i - start_br).strip_edges()
			if i < n:
				i += 1
			var comma_b: int = inner_b.find(",")
			var front_b: String = inner_b
			var back_b: String = ""
			if comma_b >= 0:
				front_b = inner_b.substr(0, comma_b).strip_edges()
				back_b = inner_b.substr(comma_b + 1).strip_edges()
			result.append({"loyal": false, "front": front_b, "back": back_b})
		elif s[i] == "<":
			i += 1
			var start_lt: int = i
			while i < n and s[i] != ">":
				i += 1
			var inner_lt: String = s.substr(start_lt, i - start_lt).strip_edges()
			if i < n:
				i += 1
			var comma_lt: int = inner_lt.find(",")
			var front_lt: String = inner_lt
			var back_lt: String = ""
			if comma_lt >= 0:
				front_lt = inner_lt.substr(0, comma_lt).strip_edges()
				back_lt = inner_lt.substr(comma_lt + 1).strip_edges()
			result.append({"loyal": true, "front": front_lt, "back": back_lt, "fleeing": true})
		else:
			var start_w: int = i
			while i < n and not s[i] in " \t\n\r([)]<>":
				i += 1
			var word: String = s.substr(start_w, i - start_w).strip_edges()
			if not word.is_empty():
				result.append({"loyal": true, "front": word, "back": ""})
	return result


static func _spec_char_count(spec: Dictionary) -> int:
	var f: String = spec["front"]
	var b: String = spec["back"]
	if b.is_empty():
		return f.length()
	return maxi(f.length(), b.length())


static func _total_spec_char_count(specs: Array[Dictionary]) -> int:
	var n: int = 0
	for spec: Dictionary in specs:
		n += _spec_char_count(spec)
	return n


func _build_paraders() -> void:
	var count: int = _specs.size()
	if count == 0:
		return

	var flipper_idx: int = 0
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
		p.call("configure_parader", spec["front"], back_variant, spec["loyal"], digit)

	var total_chars: int = _total_spec_char_count(_specs)
	var spacing_per_char: float = line_width / float(maxi(total_chars, 1))
	# Board width at scale 1 is get_layout_width(); scale so it matches the line's char budget.
	for idx: int in range(count):
		var spec_sc: Dictionary = _specs[idx]
		var cc: int = _spec_char_count(spec_sc)
		var par: Node3D = _parader_nodes[idx]
		var sign_scale: Node3D = par.get_node("SignScale") as Node3D
		var sign_node: Sign = par.get_node("SignScale/Sign") as Sign
		var base_w: float = sign_node.get_layout_width() * absf(sign_node.scale.x)
		if base_w > 0.001:
			var target_w: float = spacing_per_char * float(cc) * sign_target_width_multiplier
			var s: float = target_w / base_w
			sign_scale.scale = Vector3(s, s, s)

	for idx: int in range(count):
		var spec_f: Dictionary = _specs[idx]
		if not spec_f.get("fleeing", false):
			continue
		var watched_idx: int = _nearest_disloyal_index(idx)
		if watched_idx < 0:
			continue
		var flee: Node3D = _PARADER_FLEE_SCRIPT.new() as Node3D
		flee.name = "ParaderFlee"
		_parader_nodes[idx].add_child(flee)
		flee.call("setup", self, _parader_nodes[idx] as Parader, _parader_nodes[watched_idx] as Parader)

	var half_widths: Array[float] = []
	var char_counts: Array[int] = []
	for idx: int in range(count):
		var p: Node3D = _parader_nodes[idx]
		half_widths.append(p.call("get_sign_half_width") as float)
		char_counts.append(_spec_char_count(_specs[idx]))

	_parader_x_targets.clear()
	for i: int in range(count - 1):
		var pair: float = half_widths[i] + half_widths[i + 1]
		_parader_x_targets.append(pair)

	if count == 1:
		_parader_nodes[0].position.x = 0.0
		return

	var gaps: Array[float] = []
	for i: int in range(count - 1):
		var gap: float = (
			_parader_x_targets[i] + spacing_per_char * float(char_counts[i] + char_counts[i + 1])
		)
		gaps.append(gap)

	var sum_gaps: float = 0.0
	for g: float in gaps:
		sum_gaps += g

	var x: float = -sum_gaps * 0.5
	for i: int in range(count):
		_parader_nodes[i].position.x = x
		if i < gaps.size():
			x += gaps[i]


func get_parader_by_digit(digit: String) -> Parader:
	if digit.is_empty():
		return null
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
	if _parader_nodes.is_empty():
		return global_position.z
	return _parader_nodes[0].global_position.z


func get_focus_bounds_global() -> Variant:
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


func unregister_parader_from_march(parader: Node3D) -> void:
	var at: int = _parader_nodes.find(parader)
	if at >= 0:
		_parader_nodes.remove_at(at)


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
	for p: Node3D in _parader_nodes:
		p.position.z = z


func _crossed_z_marching(prev_z: float, cur_z: float, threshold: float) -> bool:
	if is_equal_approx(prev_z, cur_z):
		return false
	if end_z > start_z:
		return prev_z < threshold and cur_z >= threshold
	if end_z < start_z:
		return prev_z > threshold and cur_z <= threshold
	return false


func _log_disloyal_at_check() -> void:
	for i: int in _parader_nodes.size():
		var p: Node3D = _parader_nodes[i]
		var pr: Parader = p as Parader
		if pr == null:
			continue
		if pr.loyal:
			continue
		print("[ParadeLine] disloyal parader still in line at check_z=%s (index %d, node %s)" % [check_z, i, p.name])


func _march_step(z: float) -> void:
	if not _check_logged and _crossed_z_marching(_prev_march_z, z, check_z):
		_check_logged = true
		_log_disloyal_at_check()
	_prev_march_z = z
	_set_target_z(z)


func _on_march_finished() -> void:
	queue_free()


func begin_march(delay_sec: float) -> void:
	if _march_tween != null:
		_march_tween.kill()
		_march_tween = null
	_check_logged = false
	_prev_march_z = start_z
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout
	var dist: float = absf(end_z - start_z)
	var speed: float = maxf(marching_speed, 0.001)
	var duration: float = dist / speed
	_march_tween = create_tween()
	_march_tween.tween_method(_march_step, start_z, end_z, duration).set_trans(Tween.TRANS_LINEAR)
	_march_tween.finished.connect(_on_march_finished, CONNECT_ONE_SHOT)
