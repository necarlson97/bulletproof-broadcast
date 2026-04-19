extends Sprite3D

## Waggle amplitude on Z (degrees).
@export var wiggle_degrees: float = 10.0
## Angular speed for the wiggle (radians/sec scaling of time).
@export var wiggle_speed: float = 1.0
## Scale pulse: multiplier varies ±this amount around 1.0 (e.g. 0.1 → 0.9–1.1).
@export var pulse_amount: float = 0.1
## Speed for the scale pulse (can match wiggle_speed for coherence).
@export var pulse_speed: float = 1.0
## Phase offset (radians) so scale leads/lags the wiggle.
@export var pulse_phase: float = 0.8

var _t: float = 0.0
var _base_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	_base_scale = scale


func _process(delta: float) -> void:
	_t += delta
	rotation_degrees.z = sin(_t * wiggle_speed) * wiggle_degrees
	var pulse := 1.0 + sin(_t * pulse_speed + pulse_phase) * pulse_amount
	scale = _base_scale * pulse
