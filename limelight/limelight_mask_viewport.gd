extends SubViewport
class_name LimelightMaskViewport

const _MASK_LAYER: int = 1 << 9

@export var follow_camera: Camera3D
## Cameras that should not draw the mask layer (so mask geometry is only in this viewport).
@export var hide_mask_layer_on: Array[Camera3D] = []

@onready var _cam: Camera3D = $Camera3D


func _ready() -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sync_world_and_size()
	var w: Window = get_window()
	if not w.size_changed.is_connected(_sync_world_and_size):
		w.size_changed.connect(_sync_world_and_size)
	_cam.cull_mask = _MASK_LAYER
	_cam.current = true
	# Parents assign hide_mask_layer_on in their _ready after this node's _ready; apply when stack unwinds.
	call_deferred("_apply_layer_hide_from_cameras")
	if follow_camera == null:
		push_warning("LimelightMaskViewport: assign follow_camera (the main gameplay camera).")


func _apply_layer_hide_from_cameras() -> void:
	for c in hide_mask_layer_on:
		if c != null and is_instance_valid(c):
			c.cull_mask = c.cull_mask & ~_MASK_LAYER


func _sync_world_and_size() -> void:
	var w: Window = get_window()
	world_3d = w.world_3d
	var s: Vector2 = w.get_visible_rect().size
	size = Vector2i(maxi(1, int(s.x)), maxi(1, int(s.y)))


func _process(_delta: float) -> void:
	if follow_camera == null or not is_instance_valid(follow_camera):
		return
	_cam.global_transform = follow_camera.global_transform
	_cam.projection = follow_camera.projection
	_cam.fov = follow_camera.fov
	_cam.size = follow_camera.size
	_cam.frustum_offset = follow_camera.frustum_offset
	_cam.near = follow_camera.near
	_cam.far = follow_camera.far
	_cam.keep_aspect = follow_camera.keep_aspect
	_cam.h_offset = follow_camera.h_offset
	_cam.v_offset = follow_camera.v_offset
	_cam.cull_mask = _MASK_LAYER
