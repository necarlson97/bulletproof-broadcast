extends Node3D

const _PARADE_SCENE: PackedScene = preload("res://parade.tscn")
const _FOCUSED_LINE_SCENE: PackedScene = preload("res://focused_line.tscn")
const _KING_PARADER: PackedScene = preload("res://people/king.tscn")


func _ready() -> void:
	var cam: Camera3D = get_node("Camera3D") as Camera3D
	var mask_vp: Node = get_node("LimelightMaskViewport")
	mask_vp.set("follow_camera", cam)
	mask_vp.set("hide_mask_layer_on", [cam])
	var darken: Node3D = get_node("Camera3D/LimelightScreenDarkenOverlay") as Node3D
	darken.set("mask_viewport", mask_vp)
	darken.visible = true

	var lines_easy: Array[String] = [
		# Easyish
		"[Praise,kill] the king!",
		"{Order is} [maintained by,useless. Fuck] {the king.}",
		"<In this> [country,cage], {we are} (free,happy)!",
		"{The rebels} are (trying,working) {to destroy} <our> [freedom,chains]!",
		"<Only when> we [comply,resist], can <we> create!",
		"Rebellion {can only} [destroy,liberate]!",
		"Let them eat [cake,the rich]!"
	]
	var lines_medium: Array[String] = [	
		# Mediumish
		"We are all (united,joined) <in> [harmony,stupidity].",
		"The (monarch,crown) loves all <its> [citizens,traitors].",
		"[Look to,Hate] <your> (beloved,lovley) royalty <for> <their> [might,mistrust]!",
		"Our [Great,Awful] (King,Leader) is [protecting,ruining] your life.",
		"[You, Sheep] <must not> <fret -> we are forever [free,fools]!",
	]
	var lines_hard: Array[String] = [	
		# Hardish
		"Love the [king,rebel]! <Enjoy> <your> [parade,shackles]! [Obey,Fuck] <the> state!",
		"{The king} sacrifices [his time,our lives] <for> [all of us,no reason].",
		"{I am} weak, <but> [with,death to] the king, <I am> strong!",
		"Love your king? <Time> <for a> [banquet,guillotine]!",
	]
	
	var lines_protest: Array[String] = [	
		"Kill the king! ".repeat(3).strip_edges(),
		"Kill the king! ".repeat(3).strip_edges(),
		"KILL THE KING! ".repeat(3).strip_edges(),
	]
	
	var lines_retenue: Array[String] = [
		"(I AM,OBEY) {THE KING}."
	]
	var lines_king: Array[String] = [
		"{THE KING}"
	]

	var parade_schedule: Array[Dictionary] = _build_parade_schedule(
		lines_easy,
		lines_medium,
		lines_hard,
		lines_protest,
		lines_retenue,
		lines_king
	)

	var first_parade: Parade = _PARADE_SCENE.instantiate() as Parade
	first_parade.auto_start = false
	_apply_parade_segment_to_node(first_parade, parade_schedule[0])

	var narrative: NarrativeSequencer = NarrativeSequencer.new()
	narrative.parade_schedule = parade_schedule

	add_child(first_parade)
	add_child(_FOCUSED_LINE_SCENE.instantiate())
	add_child(narrative)


func _build_parade_schedule(
	lines_easy: Array[String],
	lines_medium: Array[String],
	lines_hard: Array[String],
	lines_protest: Array[String],
	lines_retenue: Array[String],
	lines_king: Array[String]
) -> Array[Dictionary]:
	return [
		{"lines": lines_easy + lines_medium},
		{
			"lines": lines_protest,
			"force_disloyal": true,
			"complete_when_last_line_releases_focus": true,
		},
		{"lines": lines_hard},
		{"lines": lines_retenue},
		{"lines": lines_king, "parader_scene": _KING_PARADER},
	]


func _apply_parade_segment_to_node(parade: Parade, seg: Dictionary) -> void:
	var lines: Array = seg.get("lines", [])
	var lines_typed: Array[String] = []
	for s: Variant in lines:
		lines_typed.append(str(s))
	parade.line_strings = lines_typed
	parade.force_all_paraders_disloyal = bool(seg.get("force_disloyal", false))
	var ps: Variant = seg.get("parader_scene", null)
	parade.parader_scene_override = null if ps == null else ps as PackedScene
