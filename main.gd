extends Node3D

const _PARADE_SCENE: PackedScene = preload("res://parade.tscn")
const _FOCUSED_LINE_SCENE: PackedScene = preload("res://focused_line.tscn")


func _ready() -> void:
	var cam: Camera3D = get_node("Camera3D") as Camera3D
	var mask_vp: Node = get_node("LimelightMaskViewport")
	mask_vp.set("follow_camera", cam)
	mask_vp.set("hide_mask_layer_on", [cam])
	get_node("Camera3D/LimelightScreenDarkenOverlay").set("mask_viewport", mask_vp)

	var parade: Node = _PARADE_SCENE.instantiate()
	var lines: Array[String] = [
		"[You, Sheep] <must> <not> <fret -> we are forever [free,fools]!",
		"The king sacrificed [everything,everyone] <for> [all of us,himself].",
		"The (state,govt) loves <all> [citizens,traitors].",
		"We are all (shared,joined) <in> [harmony,stupidity].",
		"Only [compliance,brutality] creates - rebellion [destroys,liberates]!",
		"(Look to,Watch) your [beloved,nosy] neighbor <for> [strength,suspicion]!",
		"Order (persists,remains) [maintained,broken] <by> [the state,chaos].",
		"Our [Great,Awful] (King,Leader) is [protecting,ruining] your life.",
	]
	parade.line_strings = lines
	add_child(parade)
	add_child(_FOCUSED_LINE_SCENE.instantiate())
