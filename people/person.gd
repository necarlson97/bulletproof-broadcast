class_name Person
extends Node3D

const _SFX_PITCH_JITTER := 0.1

const _KILLED_CLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/oof-1.wav"),
	preload("res://assets/sfx/oof-2.wav"),
	preload("res://assets/sfx/oof-3.wav"),
	preload("res://assets/sfx/oof-4.wav"),
	preload("res://assets/sfx/oof-5.wav"),
]

@onready var _eyes = $Face/Eyes
@onready var _killed_sfx: AudioStreamPlayer3D = $KilledSfx


func set_sweating_active(active: bool) -> void:
	var sweat: GPUParticles3D = get_node_or_null("Sweating") as GPUParticles3D
	if sweat != null:
		sweat.emitting = active


func kill() -> void:
	_play_sfx_grab_bag(_killed_sfx, _KILLED_CLIPS)
	_eyes.kill()
	var pl: Node = get_parent()
	# Duck-type ParadeLine so person.gd does not reference class_name ParadeLine at parse time.
	# Otherwise: parade_line.gd preloads parader.tscn before ParadeLine is registered → load failure.
	if pl != null and pl.has_method("unregister_parader_from_march"):
		pl.call("unregister_parader_from_march", self)
	Ragdoll.create_ragdoll(self)


func _play_sfx_grab_bag(player: AudioStreamPlayer3D, clips: Array[AudioStream]) -> void:
	if player == null or clips.is_empty():
		return
	player.stop()
	player.stream = clips.pick_random()
	player.pitch_scale = randf_range(1.0 - _SFX_PITCH_JITTER, 1.0 + _SFX_PITCH_JITTER)
	player.play()
