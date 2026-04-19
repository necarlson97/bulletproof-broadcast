extends MeshInstance3D
class_name LimelightScreenDarkenOverlay

enum DebugView {
	NORMAL = 0,
	## B/W: limelight hole after scene depth test (matches gameplay darken).
	OCCLUSION_MASK = 1,
	SCENE_DEPTH = 2,
	MASK_DEPTH = 3,
	DEPTH_OK = 4,
	## B/W: raw cone from mask SubViewport only (full silhouette; ignores sprites).
	CONE_SILHOUETTE = 5,
	RAW_Z = 6,
}

@export var mask_viewport: SubViewport

## When not Normal, replaces the darken output to isolate mask vs depth (see shader enum order).
@export var debug_view: DebugView = DebugView.NORMAL:
	set(v):
		debug_view = v
		_apply_debug_params()

## Meters; grayscale for Scene_depth / Mask_depth debug modes.
@export var debug_depth_vis_scale: float = 500.0:
	set(v):
		debug_depth_vis_scale = v
		_apply_debug_params()

## Must match encoding in [code]limelight_mask_*.gdshader[/code] (ENC_FAR_M).
@export var mask_depth_decode_scale: float = 1500.0:
	set(v):
		mask_depth_decode_scale = v
		_apply_debug_params()

## World-space tolerance for depth test (large maps / buffer precision).
@export var depth_test_slop_m: float = 8.0:
	set(v):
		depth_test_slop_m = v
		_apply_depth_params()

## Scales slop with distance (fraction of reconstructed scene depth).
@export var depth_test_slop_ratio: float = 0.002:
	set(v):
		depth_test_slop_ratio = v
		_apply_depth_params()

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
	_apply_depth_params()
	await get_tree().process_frame
	_bind_mask_texture()
	_apply_darkness()
	_apply_debug_params()
	_apply_depth_params()
	if mask_viewport == null:
		push_warning("LimelightScreenDarkenOverlay: assign mask_viewport (LimelightMaskViewport).")


func _process(_delta: float) -> void:
	# Keep gameplay camera from drawing mask-layer geometry (order-independent; idempotent).
	var cam := get_parent() as Camera3D
	if cam != null:
		LimelightRender.hide_mask_layer_from_camera(cam)


func _apply_depth_params() -> void:
	var sm: ShaderMaterial = material_override as ShaderMaterial
	if sm == null:
		return
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


func _apply_debug_params() -> void:
	var sm: ShaderMaterial = material_override as ShaderMaterial
	if sm == null:
		return
	sm.set_shader_parameter("debug_view", int(debug_view))
	sm.set_shader_parameter("debug_depth_vis_scale", debug_depth_vis_scale)
	sm.set_shader_parameter("mask_depth_decode_scale", mask_depth_decode_scale)
