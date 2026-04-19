class_name Person
extends Node3D

## Delay before the hit reaction SFX so it reads after the gunshot.
var _KILLED_SFX_DELAY_SEC := 0.4

@onready var _eyes = $Face/Eyes
@onready var _blood_droplet_emitter: Node3D = $Body/BloodDropletEmitter


func set_sweating_active(active: bool) -> void:
	var sweat: GPUParticles3D = get_node_or_null("Sweating") as GPUParticles3D
	if sweat != null:
		sweat.emitting = active


func kill() -> void:
	_show_bullet_hole_on_kill()
	if _blood_droplet_emitter != null and _blood_droplet_emitter.visible:
		BloodDroplets.spawn_kill_spray(_get_kill_spray_origin())
	# Do not use a lambda that captures self/$KilledSfx: Ragdoll.create_ragdoll queue_frees this node,
	# so a timer callable tied to this instance becomes invalid before the delay elapses.
	var killed_sfx: AudioStreamPlayer3D = $KilledSfx
	var tree := get_tree()
	if tree != null:
		tree.create_timer(_KILLED_SFX_DELAY_SEC).timeout.connect(
			Person._play_killed.bind(killed_sfx),
			CONNECT_ONE_SHOT,
		)
	else:
		Person._play_killed(killed_sfx)
	_eyes.kill()
	var pl: Node = get_parent()
	# Duck-type ParadeLine so person.gd does not reference class_name ParadeLine at parse time.
	# Otherwise: parade_line.gd preloads parader.tscn before ParadeLine is registered → load failure.
	if pl != null and pl.has_method("unregister_parader_from_march"):
		pl.call("unregister_parader_from_march", self)
	Ragdoll.create_ragdoll(self)


func _show_bullet_hole_on_kill() -> void:
	var bh: Sprite3D = _get_bullet_hole_for_kill()
	if bh == null:
		return
	bh.visible = true
	bh.rotation_degrees.z = randf_range(0.0, 360.0)


func _get_bullet_hole_for_kill() -> Sprite3D:
	return get_node_or_null("Body/BulletHole") as Sprite3D


func _get_kill_spray_origin() -> Vector3:
	if _blood_droplet_emitter != null and is_instance_valid(_blood_droplet_emitter):
		return _blood_droplet_emitter.global_position
	var bh: Sprite3D = _get_bullet_hole_for_kill()
	if bh != null:
		return bh.global_position
	return global_position


static func _play_killed(player: AudioStreamPlayer3D) -> void:
	if player == null:
		return
	player.stop()
	player.play()
