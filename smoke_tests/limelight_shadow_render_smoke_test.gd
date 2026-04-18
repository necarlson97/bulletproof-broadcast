extends Node3D

@onready var _camera: Camera3D = $Camera3D
@onready var _mask_vp: Node = $LimelightMaskViewport
@onready var _overlay: Node = $Camera3D/LimelightScreenDarkenOverlay


func _ready() -> void:
	_mask_vp.set("follow_camera", _camera)
	_mask_vp.set("hide_mask_layer_on", [_camera])
	_overlay.set("mask_viewport", _mask_vp)
	_camera.current = true
	await get_tree().create_timer(0.15).timeout
	print("limelight_mask_viewport_smoke_test: ok")
	get_tree().quit(0)
