extends Node3D

@onready var _camera: Camera3D = $Camera3D
@onready var _mask_vp: LimelightMaskViewport = $LimelightMaskViewport
@onready var _overlay: LimelightShadowOverlay = $Camera3D/LimelightShadowOverlay


func _ready() -> void:
	_mask_vp.follow_camera = _camera
	_mask_vp.hide_mask_layer_on = [_camera]
	_overlay.mask_viewport = _mask_vp
	_camera.current = true
	await get_tree().create_timer(0.15).timeout
	print("limelight_shadow_render_smoke_test: ok")
	get_tree().quit(0)
