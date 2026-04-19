extends Node3D
## Headless: run this scene; non-zero exit if any assertion fails ([method SceneTree.quit] with exit code).
## Formation targets use [constant ParadeLine.ROAD_WIDTH] and [method ParadeLine.get_parader_center_x_targets].

const _EPS: float = 0.05


func _ready() -> void:
	var failed: int = 0
	failed += _run_case(
		"aa aa aa",
		"aa aa aa",
		[-200.0, 0.0, 200.0]
	)
	failed += _run_case(
		"a a a a a",
		"a a a a a",
		[-240.0, -120.0, 0.0, 120.0, 240.0]
	)
	failed += _run_case(
		"a a a a",
		"a a a a",
		[-225.0, -75.0, 75.0, 225.0]
	)
	failed += _run_case(
		"aaa aaa aaa aaa",
		"aaa aaa aaa aaa",
		[-225.0, -75.0, 75.0, 225.0]
	)
	failed += _run_case(
		"a aa aa a",
		"a aa aa a",
		[-250.0, -100.0, 100.0, 250.0]
	)
	failed += _run_case(
		"aa aaaaaa aa",
		"aa aaaaaa aa",
		[-240.0, 0.0, 240.0]
	)
	print("--- ParadeLine layout math smoke test: ", failed, " failure(s) ---")
	get_tree().quit(1 if failed > 0 else 0)


func _run_case(case_name: String, line: String, expected_x: Array[float]) -> int:
	var pl: ParadeLine = preload("res://parade_line.tscn").instantiate() as ParadeLine
	add_child(pl)
	pl.setup(line, 300.0, 0.0, 300.0, 100.0, false, false)

	var targets: Array[float] = []
	for p: Node3D in pl.get_limelight_targets():
		var pr: Parader = p as Parader
		if pr == null:
			continue
		targets.append(pr.get_formation_target_x())

	pl.queue_free()

	if targets.size() != expected_x.size():
		push_error(
			"[FAIL] ",
			case_name,
			": expected ",
			expected_x.size(),
			" sign paraders, got ",
			targets.size()
		)
		return 1

	for i: int in range(expected_x.size()):
		if not _approx_eq(targets[i], expected_x[i]):
			push_error(
				"[FAIL] ",
				case_name,
				" parader ",
				i,
				": formation_target_x=",
				targets[i],
				" expected ",
				expected_x[i]
			)
			return 1

	print("[PASS] ", case_name)
	return 0


static func _approx_eq(a: float, b: float) -> bool:
	return absf(a - b) <= _EPS
