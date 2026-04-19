extends Node
## Counters for pause menu / future HUD. Gameplay systems increment these.

var malcontents_broadcast: int = 0
var loyalists_executed: int = 0
var traitors_executed: int = 0
## Set when the player shoots [KingParader] on the final parade (win path).
var king_killed: bool = false


func reset() -> void:
	malcontents_broadcast = 0
	loyalists_executed = 0
	traitors_executed = 0
	king_killed = false
