extends RefCounted
class_name LimelightRender

## Render layer (1..20) for geometry that writes the limelight mask (white = hole in darkness).
## Gameplay cameras should exclude this layer so mask meshes are not visible in the main pass.
const MASK_RENDER_LAYER: int = 10


static func mask_layer_mask() -> int:
	return 1 << (MASK_RENDER_LAYER - 1)


static func hide_mask_layer_from_camera(cam: Camera3D) -> void:
	if cam == null:
		return
	cam.cull_mask = cam.cull_mask & ~mask_layer_mask()
