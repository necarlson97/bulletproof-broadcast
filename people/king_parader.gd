extends Parader
class_name KingParader


func configure_parader(front: String, back: Variant, loyal_flag: bool, digit: String, p_flip_at_z: float = INF) -> void:
	super.configure_parader(front, back, loyal_flag, digit, p_flip_at_z)
	var ss: Node3D = get_node_or_null("SignScale") as Node3D
	if ss != null:
		ss.visible = false


func get_sign_half_width() -> float:
	return 28.0
