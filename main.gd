extends Node3D

const _PARADE_SCENE: PackedScene = preload("res://parade.tscn")
const _FOCUSED_LINE_SCENE: PackedScene = preload("res://focused_line.tscn")


func _ready() -> void:
	var cam: Camera3D = get_node("Camera3D") as Camera3D
	var mask_vp: Node = get_node("LimelightMaskViewport")
	mask_vp.set("follow_camera", cam)
	mask_vp.set("hide_mask_layer_on", [cam])
	var darken: Node3D = get_node("Camera3D/LimelightScreenDarkenOverlay") as Node3D
	darken.set("mask_viewport", mask_vp)
	darken.visible = true

	var parade: Parade = _PARADE_SCENE.instantiate() as Parade
	parade.auto_start = false
	var lines: Array[String] = [
		"Love the [king,rebel]! <Enjoy> <your> [parade,shackles]! [Obey,Fuck] <the> state!",
		"Order is [maintained by,useless. Fuck] the king.",
		"The rebels are (trying,working) to destroy <our> [freedom,chains]!",
		"<In> <this> [country,cage], we are (free,happy)!",
		"[You, Sheep] <must> <not> <fret -> we are forever [free,fools]!",
		"The king sacrificed [everything,everyone] <for> [all of us,no reason].",
		"The (state,govt) loves <all> [citizens,traitors].",
		"We are all (shared,joined) <in> [harmony,stupidity].",
		"Only [compliance,brutality] creates - rebellion [destroys,liberates]!",
		"[Look to,Hate] your [beloved,lovley] neighbor <for> <their> [strength,suspicion]!",
		"Our [Great,Awful] (King,Leader) is [protecting,ruining] your life.",
	]
	parade.line_strings = lines
	add_child(parade)
	add_child(_FOCUSED_LINE_SCENE.instantiate())
	add_child(NarrativeSequencer.new())
