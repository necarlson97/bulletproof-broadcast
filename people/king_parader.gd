extends Parader
class_name KingParader


func kill() -> void:
	var loop: AudioStreamPlayer3D = get_node_or_null("TankLoopSfx") as AudioStreamPlayer3D
	if loop != null:
		loop.stop()
	var tank: Node = get_node_or_null("tank")
	if tank != null and tank.has_method("halt_animation"):
		tank.call("halt_animation")
	super.kill()


func configure_parader(front: String, back: Variant, loyal_flag: bool, digit: String, p_flip_at_z: float = INF) -> void:
	super.configure_parader(front, back, loyal_flag, digit, p_flip_at_z)
	var ss: Node3D = get_node_or_null("SignScale") as Node3D
	if ss != null:
		ss.visible = false


func get_sign_half_width() -> float:
	return 28.0
