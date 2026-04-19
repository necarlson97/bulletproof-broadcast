extends Node3D
## Headless: run this scene; non-zero exit if any assertion fails ([method SceneTree.quit] with exit code).
## Uses [member ParadeLine.sign_target_width_multiplier] = 1 and [member ParadeLine.sign_gap_elastic_scale] = 0
## so formation targets match closed-form spacing (compare [method Parader.get_formation_target_x], not [member Node3D.position]).

const _EPS: float = 0.05


func _ready() -> void:
	var failed: int = 0
	failed += _run_case(
		"aa aa aa @ 600",
		"aa aa aa",
		600.0,
		[-200.0, 0.0, 200.0]
	)
	failed += _run_case(
		"a a a a a @ 500",
		"a a a a a",
		500.0,
		[-200.0, -100.0, 0.0, 100.0, 200.0]
	)
	failed += _run_case(
		"a a a a @ 400",
		"a a a a",
		400.0,
		[-150.0, -50.0, 50.0, 150.0]
	)
	failed += _run_case(
		"aaa aaa aaa aaa @ 600",
		"aaa aaa aaa aaa",
		600.0,
		[-225.0, -75.0, 75.0, 225.0]
	)
	failed += _run_case(
		"a aa aa a @ 600",
		"a aa aa a",
		600.0,
		[-250.0, -100.0, 100.0, 250.0]
	)
	failed += _run_case(
		"aa aaaaaa aa @ 600",
		"aa aaaaaa aa",
		600.0,
		[-240.0, 0.0, 240.0]
	)
	print("--- ParadeLine layout math smoke test: ", failed, " failure(s) ---")
	get_tree().quit(1 if failed > 0 else 0)


func _run_case(case_name: String, line: String, width: float, expected_x: Array[float]) -> int:
	var pl: ParadeLine = preload("res://parade_line.tscn").instantiate() as ParadeLine
	pl.pit_paraders_enabled = false
	pl.sign_gap_elastic_scale = 0.0
	pl.sign_target_width_multiplier = 1.0
	add_child(pl)
	pl.setup(line, 300.0, 0.0, 300.0, width, 100.0, 1.0)

	var targets: Array[float] = []
	for p: Node3D in pl.get_limelight_targets():
		var pr: Parader = p as Parader
		if pr == null or pr.inert_pit:
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
