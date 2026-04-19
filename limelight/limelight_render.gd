extends RefCounted
class_name LimelightRender

## Render layer (1..20) for geometry that writes the limelight mask (RGB = normalized view depth; see mask shaders).
## The mask SubViewport does not draw the rest of the scene — screen-space depth is combined in [LimelightScreenDarkenOverlay].
## Gameplay cameras should exclude this layer so mask meshes are not visible in the main pass.
const MASK_RENDER_LAYER: int = 10

## Outside the limelight mask, scene is multiplied by `(1.0 - this)`. Single project-wide default.
const LIMELIGHT_SCREEN_DARKNESS: float = 0.1


static func mask_layer_mask() -> int:
	return 1 << (MASK_RENDER_LAYER - 1)


static func hide_mask_layer_from_camera(cam: Camera3D) -> void:
	if cam == null:
		return
	cam.cull_mask = cam.cull_mask & ~mask_layer_mask()
