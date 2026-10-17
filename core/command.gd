class_name Command
extends RefCounted
## A player action. Validation and state changes live in CommandRules.

var id: String = ""
var coord: Vector2i = Vector2i.ZERO
var param: int = -1


func _init(command_id: String = "", coordinate: Vector2i = Vector2i.ZERO, parameter: int = -1) -> void:
	id = command_id
	coord = coordinate
	param = parameter
