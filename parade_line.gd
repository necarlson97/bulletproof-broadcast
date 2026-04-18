extends Node3D
class_name ParadeLine

const _DIGITS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

@export var parader_scene: PackedScene = preload("res://parader.tscn")
@export var parader_spacing: float = 48.0

var line_string: String = ""
var marching_speed: float = 300.0
var start_z: float = -1400.0
var end_z: float = 100.0

var _parader_nodes: Array[Node3D] = []
var _specs: Array[Dictionary] = []
var _march_tween: Tween


func setup(p_line: String, p_speed: float, p_start_z: float, p_end_z: float) -> void:
	line_string = p_line
	marching_speed = p_speed
	start_z = p_start_z
	end_z = p_end_z
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
		else:
			var start_w: int = i
			while i < n and not s[i] in " \t\n\r([)]":
				i += 1
			var word: String = s.substr(start_w, i - start_w).strip_edges()
			if not word.is_empty():
				result.append({"loyal": true, "front": word, "back": ""})
	return result


func _build_paraders() -> void:
	var count: int = _specs.size()
	if count == 0:
		return
	var total_width: float = (count - 1) * parader_spacing
	var x0: float = -total_width * 0.5
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
		var p: Parader = parader_scene.instantiate() as Parader
		add_child(p)
		p.position = Vector3(x0 + idx * parader_spacing, 0.0, start_z)
		_parader_nodes.append(p)
		var back_variant: Variant = null if back.is_empty() else back
		p.configure_parader(spec["front"], back_variant, spec["loyal"], digit)


func _set_target_z(z: float) -> void:
	for p: Node3D in _parader_nodes:
		p.position.z = z


func begin_march(delay_sec: float) -> void:
	if _march_tween != null:
		_march_tween.kill()
		_march_tween = null
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout
	var dist: float = absf(end_z - start_z)
	var speed: float = maxf(marching_speed, 0.001)
	var duration: float = dist / speed
	_march_tween = create_tween()
	(
		_march_tween.tween_method(_set_target_z, start_z, end_z, duration)
		. set_trans(Tween.TRANS_LINEAR)
		. set_ease(Tween.EASE_LINEAR)
	)
