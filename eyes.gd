extends Sprite3D

const _TEXTURE_OPEN: Texture2D = preload("res://assets/eyes.png")
const _TEXTURE_BLINK: Texture2D = preload("res://assets/eyes blink.png")
const _TEXTURE_DEAD: Texture2D = preload("res://assets/eyes dead.png")

@export var look_offset: float = 4.0

var _dead: bool = false
var _neutral_x: float = 0.0


func _ready() -> void:
	texture = _TEXTURE_OPEN
	_neutral_x = position.x
	_blink_loop()
	_look_loop()


func kill() -> void:
	_dead = true
	texture = _TEXTURE_DEAD


func _blink_loop() -> void:
	while not _dead:
		await get_tree().create_timer(randf_range(3.0, 6.0)).timeout
		if _dead:
			return
		await _blink_once()


func _blink_once() -> void:
	if _dead:
		return
	texture = _TEXTURE_BLINK
	await get_tree().create_timer(0.5).timeout
	if _dead:
		return
	texture = _TEXTURE_OPEN


func _look_loop() -> void:
	while not _dead:
		await get_tree().create_timer(randf_range(8.0, 12.0)).timeout
		if _dead:
			return
		_apply_random_look()


func _apply_random_look() -> void:
	if _dead:
		return
	var shift: float = [ -look_offset, 0.0, look_offset ].pick_random()
	position.x = _neutral_x + shift
