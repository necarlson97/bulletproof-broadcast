extends ParadeLine
class_name ParadeLineFaux

## Parsed like a normal [ParadeLine] ([ParadeLineSyntax]); applied in [method _ready] if non-empty.
@export var parade_line_string: String = ""

## Next parader index to try in [method flip_next] (after the last successful flip).
var _flip_next_index: int = 0


func _ready() -> void:
	if not parade_line_string.is_empty():
		setup(
			parade_line_string,
			marching_speed,
			-300,
			end_z,
			60.0,
			check_z,
			8
		)


func _build_paraders() -> void:
	super._build_paraders()
	for p: Node3D in _parader_nodes:
		var pr: Parader = p as Parader
		if pr == null:
			continue
		pr.flip_at_z = INF
		pr.clear_parade_march_follow()
		pr._comfort_radius = 10
	
	var spacing: float = _spacing_per_char()
	_layout_paraders_x(spacing)
	_scale_signs(spacing)


func begin_march(_delay_sec: float) -> void:
	pass


## Walks paraders from [member _flip_next_index] onward; flips the first whose sign [method SignFlippable.flip] returns true, then sets the cursor to the next index. Skips signs that cannot flip (no back, or already animating).
func flip_next() -> void:
	_prune_freed_paraders()
	var n: int = _parader_nodes.size()
	if n == 0:
		return
	var i: int = _flip_next_index
	if i >= n:
		i = 0
	while i < n:
		var pr: Parader = _parader_nodes[i] as Parader
		if pr != null and pr.inert_pit:
			i += 1
			continue
		var fl: SignFlippable = _parader_nodes[i].get_node_or_null("SignScale/Sign") as SignFlippable
		if fl != null and fl.flip():
			_flip_next_index = i + 1
			return
		i += 1
	_flip_next_index = 0
