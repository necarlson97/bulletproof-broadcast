class_name Person
extends Node3D

@onready var _eyes = $Face/Eyes


func set_sweating_active(active: bool) -> void:
	var sweat: GPUParticles3D = get_node_or_null("Sweating") as GPUParticles3D
	if sweat != null:
		sweat.emitting = active


func kill() -> void:
	_eyes.kill()
	var pl: Node = get_parent()
	# Duck-type ParadeLine so person.gd does not reference class_name ParadeLine at parse time.
	# Otherwise: parade_line.gd preloads parader.tscn before ParadeLine is registered → load failure.
	if pl != null and pl.has_method("unregister_parader_from_march"):
		pl.call("unregister_parader_from_march", self)
	Ragdoll.create_ragdoll(self)
