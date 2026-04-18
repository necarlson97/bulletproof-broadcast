extends Node3D

const _LIMELIGHTER_SCENE: PackedScene = preload("res://limelighter.tscn")

var _limelighter: Limelighter


func _ready() -> void:
	var targets: Array[Node3D] = []
	for i in Limelighter.LIMELIGHT_COUNT:
		var m: Marker3D = Marker3D.new()
		m.name = "Target_%d" % i
		m.position = Vector3(float(i) * 25.0, 0.0, float(i % 3) * 8.0)
		add_child(m)
		targets.append(m)

	var node: Node = _LIMELIGHTER_SCENE.instantiate()
	if node is not Limelighter:
		push_error("limelighter.tscn root must be Limelighter")
		get_tree().quit(1)
		return
	_limelighter = node as Limelighter
	add_child(_limelighter)

	await get_tree().process_frame
	_limelighter.set_targets(targets)

	var timer: SceneTreeTimer = get_tree().create_timer(0.75, false, true, true)
	timer.timeout.connect(_on_verify_and_quit.bind(targets))


func _on_verify_and_quit(targets: Array[Node3D]) -> void:
	if _limelighter.get_limelight_count() != Limelighter.LIMELIGHT_COUNT:
		push_error("Expected %d limelights, got %d" % [Limelighter.LIMELIGHT_COUNT, _limelighter.get_limelight_count()])
		get_tree().quit(1)
		return

	for i in Limelighter.LIMELIGHT_COUNT:
		var L: Limelight = _limelighter.get_limelight(i)
		if not is_equal_approx(L.global_position.y, 0.0):
			push_error("Limelight %d Y should be 0, got %s" % [i, L.global_position])
			get_tree().quit(1)
			return
		if L.get_follow_target() != targets[i]:
			push_error("Limelight %d wrong target" % i)
			get_tree().quit(1)
			return

	var t: Node3D = targets[3]
	var prev: Vector3 = t.global_position
	t.global_position = Vector3(999.0, 50.0, -40.0)
	await get_tree().process_frame
	var L3: Limelight = _limelighter.get_limelight(3)
	if not is_equal_approx(L3.global_position.y, 0.0):
		push_error("After target moved, limelight Y should stay 0")
		get_tree().quit(1)
		return

	t.global_position = prev
	print("limelight_smoke_test: ok")
	#get_tree().quit(0)
