class_name Tile
extends RefCounted
## A map cell. Coordinates are fixed when the tile is constructed.

const Constants = preload("res://core/constants.gd")

var _q: int = 0
var _r: int = 0
var q: int:
	get:
		return _q
	set(_value):
		push_error("Tile coordinates cannot change after construction.")
var r: int:
	get:
		return _r
	set(_value):
		push_error("Tile coordinates cannot change after construction.")
var coord: Vector2i:
	get:
		return Vector2i(_q, _r)

var elevation: int = 0
var water: float = 0.0
var feature: int = Constants.Feature.NONE
var building: int = Constants.Building.NONE
var gate_open: bool = true
var wheel_dir: int = -1
var is_source: bool = false
var is_sea: bool = false
var is_river: bool = false
var paddy_yield: int = 0
var paddy_dead: bool = false
var paddy_rain_turns: int = 0
var start_house: bool = false
var brace_turns: int = 0


func _init(initial_q: int = 0, initial_r: int = 0) -> void:
	_q = initial_q
	_r = initial_r


func to_dict(include_bracing: bool = false) -> Dictionary:
	var data: Dictionary = {
		"q": q,
		"r": r,
		"elevation": elevation,
		"water": water,
		"feature": Constants.enum_name(Constants.Feature, feature),
		"building": Constants.enum_name(Constants.Building, building),
		"gate_open": gate_open,
		"wheel_dir": wheel_dir,
		"is_source": is_source,
		"is_sea": is_sea,
		"is_river": is_river,
		"paddy_yield": paddy_yield,
		"paddy_dead": paddy_dead,
		"paddy_rain_turns": paddy_rain_turns,
		"start_house": start_house,
	}
	if include_bracing:
		data["brace_turns"] = brace_turns
	return data


static func from_dict(data: Dictionary) -> Tile:
	var tile: Tile = Tile.new(int(data.get("q", 0)), int(data.get("r", 0)))
	tile.elevation = int(data.get("elevation", 0))
	tile.water = float(data.get("water", 0.0))
	tile.feature = Constants.enum_value(Constants.Feature, String(data.get("feature", "none")))
	tile.building = Constants.enum_value(Constants.Building, String(data.get("building", "none")))
	tile.gate_open = bool(data.get("gate_open", true))
	tile.wheel_dir = int(data.get("wheel_dir", -1))
	tile.is_source = bool(data.get("is_source", false))
	tile.is_sea = bool(data.get("is_sea", false))
	tile.is_river = bool(data.get("is_river", false))
	tile.paddy_yield = int(data.get("paddy_yield", 0))
	tile.paddy_dead = bool(data.get("paddy_dead", false))
	tile.paddy_rain_turns = int(data.get("paddy_rain_turns", 0))
	tile.start_house = bool(data.get("start_house", false))
	tile.brace_turns = int(data.get("brace_turns", 0))
	return tile
