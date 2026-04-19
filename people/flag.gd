extends Node3D

const _ROCK_DEG: float = 10.0
const _HALF_CYCLE_SEC: float = 1.2

var _wind_mat: ShaderMaterial
var _wind_time: float = 0.0


func _ready() -> void:
	var sprite: Sprite3D = $SpriteFlag
	var mat: ShaderMaterial = sprite.material_override as ShaderMaterial
	if mat != null:
		mat = mat.duplicate() as ShaderMaterial
		sprite.material_override = mat
	_wind_mat = mat
	if mat != null:
		mat.set_shader_parameter("pixel_size", sprite.pixel_size)
		var tex: Texture2D = sprite.texture
		if tex != null:
			var w_px: int = int(sprite.region_rect.size.x) if sprite.region_enabled else tex.get_width()
			mat.set_shader_parameter("flag_world_width", float(w_px) * sprite.pixel_size)
	# Ragdoll duplicates this node under RigidBody3D; do not re-run march animation on corpse pieces.
	if get_parent() is RigidBody3D:
		if mat != null:
			mat.set_shader_parameter("wind_speed", 0.0)
		return
	var base_z: float = rotation_degrees.z
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees:z", base_z + _ROCK_DEG, _HALF_CYCLE_SEC)
	tween.tween_property(self, "rotation_degrees:z", base_z - _ROCK_DEG, _HALF_CYCLE_SEC)


func _process(delta: float) -> void:
	if _wind_mat == null:
		return
	_wind_time += delta
	_wind_mat.set_shader_parameter("wind_time", _wind_time)
