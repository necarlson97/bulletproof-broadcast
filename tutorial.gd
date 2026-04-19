extends Node3D

const _TUTORIAL_SEQUENCER := preload("res://tutorial_narrative_sequencer.gd")


func _ready() -> void:
	var cam: Camera3D = get_node("Camera3D") as Camera3D
	LimelightRender.hide_mask_layer_from_camera(cam)
	var mask_vp_cone: Node = get_node("LimelightMaskViewport")
	var mask_vp_disk: Node = get_node("LimelightMaskViewportDisk")
	mask_vp_cone.set("follow_camera", cam)
	mask_vp_disk.set("follow_camera", cam)
	mask_vp_cone.set("hide_mask_layer_on", [cam])
	mask_vp_disk.set("hide_mask_layer_on", [cam])
	var darken: Node = get_node("Camera3D/LimelightScreenDarkenOverlay")
	darken.set("mask_viewport_cone", mask_vp_cone)
	darken.set("mask_viewport_disk", mask_vp_disk)

	var pl: Node3D = get_node_or_null("ParadeLine") as Node3D
	if pl != null:
		var parade := Node3D.new()
		parade.name = "Parade"
		add_child(parade)
		pl.reparent(parade)
		parade.add_to_group("parade")

	add_child(_TUTORIAL_SEQUENCER.new())
