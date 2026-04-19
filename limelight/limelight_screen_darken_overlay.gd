extends MeshInstance3D
class_name LimelightScreenDarkenOverlay

@export var mask_viewport: SubViewport

## World-space tolerance for depth test (large maps / buffer precision).
@export var depth_test_slop_m: float = 8.0:
	set(v):
		depth_test_slop_m = v
		_apply_projection_and_depth_params()

## Scales slop with distance (fraction of reconstructed scene depth).
@export var depth_test_slop_ratio: float = 0.002:
	set(v):
		depth_test_slop_ratio = v
		_apply_projection_and_depth_params()

## Driven by [member LimelightRender.LIMELIGHT_SCREEN_DARKNESS] on load; [NarrativeSequencer] may tween toward 0 for outro.
var darkness: float = LimelightRender.LIMELIGHT_SCREEN_DARKNESS:
	set(v):
		darkness = v
		_apply_darkness()


func _ready() -> void:
	darkness = LimelightRender.LIMELIGHT_SCREEN_DARKNESS
	extra_cull_margin = 16384.0
	if material_override:
		material_override = material_override.duplicate()
	_apply_projection_and_depth_params()
	await get_tree().process_frame
	_bind_mask_texture()
	_apply_darkness()
	_apply_projection_and_depth_params()
	if mask_viewport == null:
		push_warning("LimelightScreenDarkenOverlay: assign mask_viewport (LimelightMaskViewport).")


func _process(_delta: float) -> void:
	_apply_projection_and_depth_params()


func _apply_projection_and_depth_params() -> void:
	var sm: ShaderMaterial = material_override as ShaderMaterial
	if sm == null:
		return
	var cam := get_parent() as Camera3D
	if cam != null:
		sm.set_shader_parameter("inv_projection_matrix", cam.get_camera_projection().inverse())
	sm.set_shader_parameter("depth_test_slop_m", depth_test_slop_m)
	sm.set_shader_parameter("depth_test_slop_ratio", depth_test_slop_ratio)


func _bind_mask_texture() -> void:
	var sm: ShaderMaterial = material_override as ShaderMaterial
	if sm == null or mask_viewport == null:
		return
	sm.set_shader_parameter("limelight_mask", mask_viewport.get_texture())


func _apply_darkness() -> void:
	var sm: ShaderMaterial = material_override as ShaderMaterial
	if sm:
		sm.set_shader_parameter("darkness", darkness)
