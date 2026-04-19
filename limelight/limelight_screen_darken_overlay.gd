extends MeshInstance3D
class_name LimelightScreenDarkenOverlay

## Fullscreen 3D pass: see [LimelightRender] (web + Compatibility; alpha cutout when you need clean layering).

enum DebugView {
	NORMAL = 0,
	## B/W: limelight hole after scene depth test (matches gameplay darken).
	OCCLUSION_MASK = 1,
	SCENE_DEPTH = 2,
	## Grayscale: cone mask RT depth (R channel).
	MASK_DEPTH = 3,
	DEPTH_OK = 4,
	## B/W: raw cone silhouette from cone mask SubViewport (before scene depth test).
	CONE_SILHOUETTE = 5,
	RAW_Z = 6,
	## Raw normalized R from cone mask texture.
	CONE_MASK_BUFFER = 7,
	## Raw normalized R from disk mask texture.
	DISK_MASK_BUFFER = 8,
}

@export var mask_viewport_cone: SubViewport
@export var mask_viewport_disk: SubViewport

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

## [0..1] mix toward full brightness where the cone mask RT passes the depth test.
@export_range(0.0, 1.0, 0.01) var cone_hole_lift: float = 0.8:
	set(v):
		cone_hole_lift = v
		_apply_lift_params()

## [0..1] mix toward full brightness where the disk mask RT passes the depth test (wins over cone).
@export_range(0.0, 1.0, 0.01) var target_hole_lift: float = 1.0:
	set(v):
		target_hole_lift = v
		_apply_lift_params()

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
	_apply_lift_params()
	_apply_depth_params()
	if mask_viewport_cone == null or mask_viewport_disk == null:
		push_warning("LimelightScreenDarkenOverlay: assign mask_viewport_cone and mask_viewport_disk (LimelightMaskViewport).")


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
	if sm == null or mask_viewport_cone == null or mask_viewport_disk == null:
		return
	sm.set_shader_parameter("limelight_mask_cone", mask_viewport_cone.get_texture())
	sm.set_shader_parameter("limelight_mask_disk", mask_viewport_disk.get_texture())


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


func _apply_lift_params() -> void:
	var sm: ShaderMaterial = material_override as ShaderMaterial
	if sm == null:
		return
	sm.set_shader_parameter("cone_hole_lift", cone_hole_lift)
	sm.set_shader_parameter("target_hole_lift", target_hole_lift)
