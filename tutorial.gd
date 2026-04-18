extends Node3D

const _TUTORIAL_SEQUENCER := preload("res://tutorial_narrative_sequencer.gd")


func _ready() -> void:
	var cam: Camera3D = get_node("Camera3D") as Camera3D
	var mask_vp: Node = get_node("LimelightMaskViewport")
	mask_vp.set("follow_camera", cam)
	mask_vp.set("hide_mask_layer_on", [cam])

	var pl: Node3D = get_node_or_null("ParadeLine") as Node3D
	if pl != null:
		var parade := Node3D.new()
		parade.name = "Parade"
		add_child(parade)
		pl.reparent(parade)
		parade.add_to_group("parade")

	add_child(_TUTORIAL_SEQUENCER.new())
