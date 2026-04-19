extends Node3D

const _PARADE_SCENE: PackedScene = preload("res://parade.tscn")
const _FOCUSED_LINE_SCENE: PackedScene = preload("res://focused_line.tscn")
const _KING_PARADER: PackedScene = preload("res://people/king.tscn")


func _ready() -> void:
	GameStats.reset()
	var cam: Camera3D = get_node("Camera3D") as Camera3D
	LimelightRender.hide_mask_layer_from_camera(cam)
	var mask_vp: Node = get_node("LimelightMaskViewport")
	mask_vp.set("follow_camera", cam)
	mask_vp.set("hide_mask_layer_on", [cam])
	var darken: Node3D = get_node("Camera3D/LimelightScreenDarkenOverlay") as Node3D
	darken.set("mask_viewport", mask_vp)
	darken.visible = true

	var lines_easy: Array[String] = [
		# Easyish
		"[Praise,kill] the king!",
		"{Order is} [maintained by,useless. End] {the monarchy.}",
		"<In this> [country,cage], {we are} (free,happy)!",
		"{The rebels} are (trying,working) {to destroy} <our> [freedom,chains]!",
		"<Only when> we [comply,resist], can <we> (create,flourish)!",
		"Rebellion is insolent, <it can> <only> [destroy,liberate]!",
		"Let them eat [cake,the rich]!"
	]
	var lines_medium: Array[String] = [	
		# Mediumish
		"We are all (united,joined) <in> [harmony,stupidity].",
		"The (monarch,crown) (loves,guards) all <its> [citizens,traitors].",
		"[Look to,Hate] <your> (beloved,lovley) royalty <for> <their> [might,mistrust]!",
		"Our [Great,Awful] (King,Leader) is [protecting,ruining] your (life,future).",
		"[You, Sheep] <must not> <fret -> we are forever [free,fools]!",
	]
	var lines_hard: Array[String] = [	
		# Hardish
		"Love the [king,rebel]! <Enjoy> <your> [parade,shackles]! [Obey,Fuck] <the> state!",
		"{The king} sacrifices [his time,our lives] <for> [all of us,no reason].",
		"{I am} weak, <but> [with,death to] the king, <I am> strong!",
		"(Love,Adore) your king? <Time> <for a> [banquet,guillotine]!",
	]
	
	var lines_protest: Array[String] = [	
		"Kill the king! ".repeat(3).strip_edges(),
		"Kill the king! ".repeat(3).strip_edges(),
		"KILL THE KING! ".repeat(3).strip_edges(),
	]
	
	var lines_retenue: Array[String] = [
		"pppp pppp pppp pppp pppp pppp",
		"(I AM,OBEY) {THE KING}.",
		"pppp pppp pppp pppp pppp pppp",
	]
	var lines_king: Array[String] = [
		"{THE KING}"
	]

	var parade_schedule: Array[Parade] = _build_parade_schedule(
		lines_easy,
		lines_medium,
		lines_hard,
		lines_protest,
		lines_retenue,
		lines_king
	)

	var narrative: NarrativeSequencer = NarrativeSequencer.new()
	narrative.parade_schedule = parade_schedule

	add_child(parade_schedule[0])
	add_child(_FOCUSED_LINE_SCENE.instantiate())
	add_child(narrative)


func _build_parade(lines: Array[String]) -> Parade:
	var p: Parade = _PARADE_SCENE.instantiate() as Parade
	p.auto_start = false
	p.line_strings = lines
	return p


func _build_parade_schedule(
	lines_easy: Array[String],
	lines_medium: Array[String],
	lines_hard: Array[String],
	lines_protest: Array[String],
	lines_retenue: Array[String],
	lines_king: Array[String]
) -> Array[Parade]:
	var first_parade: Parade = _build_parade(lines_easy + lines_medium)
	var second_parade: Parade = _build_parade(lines_protest)
	second_parade.force_all_paraders_disloyal = true
	second_parade.marching_speed = 150.0
	second_parade.approach_speed = 300.0
	second_parade.line_spawn_spacing = 400.0
	var third_parade: Parade = _build_parade(lines_hard)
	var fourth_parade: Parade = _build_parade(lines_retenue)
	fourth_parade.marching_speed = 150.0
	fourth_parade.line_spawn_spacing = 200
	var fifth_parade: Parade = _build_parade(lines_king)
	fifth_parade.marching_speed = 175.0
	fifth_parade.parader_scene_override = _KING_PARADER
	fifth_parade.check_z += 200
	fifth_parade.end_z += 400
	return [first_parade, second_parade, third_parade, fourth_parade, fifth_parade]
