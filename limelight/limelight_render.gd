extends RefCounted
class_name LimelightRender

## Cone mask: render layer [member MASK_RENDER_LAYER_CONE]. Disk mask: [member MASK_RENDER_LAYER_DISK].
## Two separate SubViewports render each layer; [LimelightScreenDarkenOverlay] composites them (disk wins over cone for lift).
## Mask RTs encode normalized linear depth in R (see mask shaders). The mask SubViewports do not draw the rest of the scene —
## screen-space depth is combined in [LimelightScreenDarkenOverlay].
## Gameplay cameras should exclude both mask layers so mask meshes are not visible in the main pass.
##
## **Web + GL Compatibility only:** [LimelightScreenDarkenOverlay] is a 3D spatial fullscreen pass
## ([code]hint_screen_texture[/code] / [code]hint_depth_texture[/code]). It runs with opaque / early 3D ordering.
## True alpha-blended meshes render later; with depth prepass they can sort wrong or disappear under this quad.
## **Post-transparent compositor passes are not available** on the Compatibility renderer (including HTML5 export),
## so there is no engine hook here to run the darken after all translucency. **Practical approach:** use
## **alpha scissor / cutout** for content that must coexist with this overlay; accept the limitation for full blend.
const MASK_RENDER_LAYER: int = 10
const MASK_RENDER_LAYER_CONE: int = 10
const MASK_RENDER_LAYER_DISK: int = 11

## Outside the limelight mask, scene is multiplied by `(1.0 - this)`. Single project-wide default.
const LIMELIGHT_SCREEN_DARKNESS: float = 0.1


static func mask_layer_cone_mask() -> int:
	return 1 << (MASK_RENDER_LAYER_CONE - 1)


static func mask_layer_disk_mask() -> int:
	return 1 << (MASK_RENDER_LAYER_DISK - 1)


## Bitmask of every layer used by limelight mask geometry (cone + disk). Use to hide mask meshes from gameplay cameras.
static func mask_layers_all_mask() -> int:
	return mask_layer_cone_mask() | mask_layer_disk_mask()


## Back-compat alias for [member mask_layers_all_mask].
static func mask_layer_mask() -> int:
	return mask_layers_all_mask()


static func hide_mask_layer_from_camera(cam: Camera3D) -> void:
	if cam == null:
		return
	cam.cull_mask = cam.cull_mask & ~mask_layers_all_mask()


## [code]false[/code] under [code]gl_compatibility[/code] (e.g. HTML5). Compositor POST_TRANSPARENT is not on GLES.
static func compositor_post_transparent_supported() -> bool:
	var m: String = String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"))
	return m != "gl_compatibility"
