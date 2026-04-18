extends Node3D

@export var shirt_start: Color = Color("#A13A32")
@export var shirt_end: Color = Color("#C15A4A")
@export var skin_start: Color = Color("#6B4423")
@export var skin_end: Color = Color("#F1C27D")


func _ready() -> void:
	var skin_color: Color = skin_start.lerp(skin_end, randf())
	var shirt_color: Color = shirt_start.lerp(shirt_end, randf())
	var person: Node = get_parent()
	_apply_sprite_tint_overlay(person.get_node("Face") as Sprite3D, skin_color)
	var eyes: Sprite3D = person.get_node("Face/Eyes") as Sprite3D
	_apply_sprite_tint_overlay(eyes, skin_color)
	eyes.texture_changed.connect(_on_eyes_texture_changed.bind(eyes))
	_apply_sprite_tint_overlay(person.get_node("HandL") as Sprite3D, skin_color)
	_apply_sprite_tint_overlay(person.get_node("HandR") as Sprite3D, skin_color)
	_apply_sprite_tint_overlay(person.get_node("Body") as Sprite3D, shirt_color)


func _on_eyes_texture_changed(eyes: Sprite3D) -> void:
	var m: StandardMaterial3D = eyes.material_override as StandardMaterial3D
	if m == null:
		return
	m.albedo_texture = eyes.texture


## Per-sprite tint via [member Sprite3D.material_override] so child nodes (labels, nested sprites) are not multiplied.
static func _apply_sprite_tint_overlay(sprite: Sprite3D, tint: Color) -> void:
	sprite.modulate = Color.WHITE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = sprite.texture
	m.albedo_color = tint
	m.texture_filter = sprite.texture_filter
	m.billboard_mode = sprite.billboard as BaseMaterial3D.BillboardMode
	match sprite.alpha_cut:
		Sprite3D.ALPHA_CUT_DISABLED:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		Sprite3D.ALPHA_CUT_DISCARD:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = sprite.alpha_scissor_threshold
			m.alpha_antialiasing_mode = sprite.alpha_antialiasing_mode
		Sprite3D.ALPHA_CUT_OPAQUE_PREPASS:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = sprite.alpha_scissor_threshold
	sprite.material_override = m
