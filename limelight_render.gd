extends RefCounted
class_name LimelightRender

## Render layer index (1..20) used only for limelight mask geometry. Main gameplay cameras should
## exclude this layer so spheres are not drawn in the main pass (holes come from the mask texture).
const MASK_RENDER_LAYER: int = 10


static func mask_layer_mask() -> int:
	return 1 << (MASK_RENDER_LAYER - 1)


static func hide_mask_layer_from_camera(cam: Camera3D) -> void:
	if cam == null:
		return
	cam.cull_mask = cam.cull_mask & ~mask_layer_mask()
