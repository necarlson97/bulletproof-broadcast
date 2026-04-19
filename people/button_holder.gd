extends Parader
class_name ButtonHolder

## Logical id for menu code (also passed to [signal pressed]). Display text is set with [method set_button_text].
@export var button_name: String = ""

## Thickness of the clickable box along the parader’s forward axis (Z in local space).
@export var hit_depth: float = 12.0

## Body + face bounce while the pointer hovers the hit area (same idea as parade walk bounce on [member Parader._body]).
const _HOVER_BODY_BOUNCE_HALF_DUR: float = 0.12
const _HOVER_BODY_BOUNCE_HEIGHT: float = 4.0

signal pressed(button_id: String, holder: ButtonHolder)
## Emitted when the pointer begins hovering this holder’s hit area (for menu officer aim).
signal hover_began(holder: ButtonHolder)

@onready var _area: Area3D = $Area3D
@onready var _collision: CollisionShape3D = $Area3D/CollisionShape3D
@onready var _face: Sprite3D = $Face

var _face_bounce_base_y: float = 0.0

var _hovering: bool = false
var _hover_loop_running: bool = false
var _hover_tween: Tween


func _ready() -> void:
	super._ready()
	remove_from_group("parader")
	clear_parade_march_follow()
	set_process(false)
	_area.input_ray_pickable = true
	_area.monitoring = true
	_area.monitorable = true
	if not _area.input_event.is_connected(_on_area_input_event):
		_area.input_event.connect(_on_area_input_event)
	if not _area.mouse_entered.is_connected(_on_area_mouse_entered):
		_area.mouse_entered.connect(_on_area_mouse_entered)
	if not _area.mouse_exited.is_connected(_on_area_mouse_exited):
		_area.mouse_exited.connect(_on_area_mouse_exited)
	_face_bounce_base_y = _face.position.y
	_refresh_hit_shape()
	set_button_text(button_name)


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


## World aim point for the officer gun (face / head).
func get_head_node() -> Node3D:
	return $Face as Node3D


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
			print("%s clicked" % button_name)
			pressed.emit(button_name, self)


func _on_area_mouse_entered() -> void:
	hover_began.emit(self)
	_hovering = true
	if _hover_loop_running:
		return
	_hover_loop_running = true
	_play_hover_segment(true)


func _on_area_mouse_exited() -> void:
	_hovering = false
	_hover_loop_running = false
	_stop_hover_tween()
	_reset_hover_pose()


func _stop_hover_tween() -> void:
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = null


func _play_hover_segment(go_up: bool) -> void:
	if not _hovering or not is_inside_tree() or not is_instance_valid(_body) or not is_instance_valid(_face):
		_finish_hover_bounce()
		return
	_stop_hover_tween()
	_hover_tween = create_tween().set_parallel(true)
	if go_up:
		_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(
			_body,
			"position:y",
			_body_bounce_base_y + _HOVER_BODY_BOUNCE_HEIGHT,
			_HOVER_BODY_BOUNCE_HALF_DUR
		)
		_hover_tween.tween_property(
			_face,
			"position:y",
			_face_bounce_base_y + _HOVER_BODY_BOUNCE_HEIGHT,
			_HOVER_BODY_BOUNCE_HALF_DUR
		)
	else:
		_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_hover_tween.tween_property(
			_body,
			"position:y",
			_body_bounce_base_y,
			_HOVER_BODY_BOUNCE_HALF_DUR
		)
		_hover_tween.tween_property(
			_face,
			"position:y",
			_face_bounce_base_y,
			_HOVER_BODY_BOUNCE_HALF_DUR
		)
	_hover_tween.finished.connect(_on_hover_segment_finished.bind(go_up), CONNECT_ONE_SHOT)


func _on_hover_segment_finished(was_going_up: bool) -> void:
	_hover_tween = null
	if not _hovering:
		_finish_hover_bounce()
		return
	_play_hover_segment(not was_going_up)


func _finish_hover_bounce() -> void:
	_hover_loop_running = false
	_stop_hover_tween()
	_reset_hover_pose()


func _reset_hover_pose() -> void:
	if is_instance_valid(_body):
		_body.position.y = _body_bounce_base_y
	if is_instance_valid(_face):
		_face.position.y = _face_bounce_base_y
