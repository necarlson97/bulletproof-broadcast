extends MeshInstance3D
class_name LimelightShadowOverlay

@export var mask_viewport: SubViewport

@export_range(0.0, 1.0, 0.01) var darkness: float = 0.65:
	set(v):
		darkness = v
		_apply_darkness()


func _ready() -> void:
	extra_cull_margin = 16384.0
	if material_override:
		material_override = material_override.duplicate()
	await get_tree().process_frame
	_bind_mask_texture()
	_apply_darkness()
	if mask_viewport == null:
		push_warning("LimelightShadowOverlay: assign mask_viewport (LimelightMaskViewport).")


func _bind_mask_texture() -> void:
	var sm: ShaderMaterial = material_override as ShaderMaterial
	if sm == null or mask_viewport == null:
		return
	sm.set_shader_parameter("limelight_mask", mask_viewport.get_texture())


func _apply_darkness() -> void:
	var sm: ShaderMaterial = material_override as ShaderMaterial
	if sm:
		sm.set_shader_parameter("darkness", darkness)
