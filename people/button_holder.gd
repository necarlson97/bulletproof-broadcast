extends Parader
class_name ButtonHolder

## Logical id for menu code (also passed to [signal pressed]). Display text is set with [method set_button_text].
@export var button_name: String = ""

## Thickness of the clickable box along the parader’s forward axis (Z in local space).
@export var hit_depth: float = 12.0

signal pressed(button_id: String)

@onready var _area: Area3D = $Area3D
@onready var _collision: CollisionShape3D = $Area3D/CollisionShape3D


func _ready() -> void:
	super._ready()
	remove_from_group("parader")
	clear_parade_march_follow()
	set_process(false)
	_area.input_ray_pickable = true
	if not _area.input_event.is_connected(_on_area_input_event):
		_area.input_event.connect(_on_area_input_event)
	_refresh_hit_shape()


func configure_parader(front: String, back: Variant, loyal_flag: bool, digit: String, p_flip_at_z: float = INF) -> void:
	super.configure_parader(front, back, loyal_flag, digit, p_flip_at_z)
	_refresh_hit_shape()


## Sets the sign label and resizes the [Area3D] hit box to match the laid-out board (same basis as [method Parader.get_sign_half_width]).
func set_button_text(text: String) -> void:
	var flippable: SignFlippable = $SignScale/Sign as SignFlippable
	flippable.set_text(text)
	refresh_hit_area()


## Call after changing the sign directly (for example [method Sign.set_text] on [code]SignScale/Sign[/code]).
func refresh_hit_area() -> void:
	_refresh_hit_shape()


func _refresh_hit_shape() -> void:
	var box: BoxShape3D = _collision.shape as BoxShape3D
	if box == null:
		return
	var half_w: float = get_sign_half_width()
	var scale_n: Node3D = $SignScale as Node3D
	var board: Sign = $SignScale/Sign as Sign
	var sn: Node3D = board as Node3D
	var w: float = half_w * 2.0
	var h: float = board.get_layout_height() * absf(scale_n.scale.y) * absf(sn.scale.y)
	box.size = Vector3(maxf(w, 1.0), maxf(h, 1.0), maxf(hit_depth, 1.0))
	var sign_node: Node3D = $SignScale/Sign as Node3D
	_collision.global_position = sign_node.global_position


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit(button_name)
