extends Node3D
class_name Limelighter

const LIMELIGHT_COUNT: int = 10
const MANUAL_FOCUS_CHILD_NAME: String = "ManualFocus"

@export var limelight_scene: PackedScene = preload("res://limelight/limelight.tscn")
## Limelight cone tips are spaced along local X of each tower's [LimelightSource], from [code]source.x - width/2[/code] in steps of [code]width / (LIMELIGHT_COUNT / 2)[/code].
@export var tower_limelight_spread_width: float = 120.0

var _limelights: Array[Limelight] = []
@onready var _limelights_container: Node3D = $Limelights
@onready var _tower1_limelight_source: Node3D = $Tower1/LimelightSource
@onready var _tower2_limelight_source: Node3D = $Tower2/LimelightSource


func _ready() -> void:
	_spawn_limelights()
	_apply_manual_focus_if_present()


func _spawn_limelights() -> void:
	var tip_anchors: Array[Node3D] = _create_tower_tip_anchors()
	for i in LIMELIGHT_COUNT:
		var node: Node = limelight_scene.instantiate()
		if node is Limelight:
			var L: Limelight = node as Limelight
			_limelights_container.add_child(L)
			_limelights.append(L)
			L.set_tip_anchor(tip_anchors[i])
		else:
			push_error("limelight_scene root must be a Limelight")


func _create_tower_tip_anchors() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var lights_per_tower: int = LIMELIGHT_COUNT / 2
	if LIMELIGHT_COUNT % 2 != 0:
		push_warning("Limelighter: LIMELIGHT_COUNT should be even; using floor(LIMELIGHT_COUNT/2) lights per tower.")
	var w: float = tower_limelight_spread_width
	var half_w: float = w * 0.5
	var step: float = w / float(lights_per_tower) if lights_per_tower > 0 else w
	for tower_src: Node3D in [_tower1_limelight_source, _tower2_limelight_source]:
		var x: float = tower_src.position.x - half_w
		for j in lights_per_tower:
			var anchor := Node3D.new()
			anchor.name = "TipAnchor_%d" % out.size()
			tower_src.add_child(anchor)
			anchor.position = Vector3(x, 0.0, 0.0)
			out.append(anchor)
			x += step
	return out


func _apply_manual_focus_if_present() -> void:
	var n: Node = get_node_or_null(MANUAL_FOCUS_CHILD_NAME)
	if n is Node3D:
		var focus: Node3D = n as Node3D
		for L: Limelight in _limelights:
			L.set_orbit_focus(focus)


## Assigns targets in order; if there are fewer than 10 targets, indices wrap (i % targets.size()).
## Skips [method Limelight.set_target] when the slot already tracks the same node (safe to call each frame).
func set_targets(targets: Array[Node3D]) -> void:
	if targets.is_empty():
		for L in _limelights:
			L.clear_target()
		return
	for i in _limelights.size():
		var t: Node3D = targets[i % targets.size()]
		var L: Limelight = _limelights[i]
		if not is_instance_valid(t):
			L.clear_target()
			continue
		var cur: Node3D = L.get_follow_target()
		if cur == t and is_instance_valid(cur):
			continue
		L.set_target(t)


func get_limelight(index: int) -> Limelight:
	return _limelights[index]


func get_limelight_count() -> int:
	return _limelights.size()


## Show or hide spawned limelight mask meshes only ([member _limelights_container]). Tower visuals stay visible.
func set_limelight_meshes_visible(show_meshes: bool) -> void:
	if is_instance_valid(_limelights_container):
		_limelights_container.visible = show_meshes
