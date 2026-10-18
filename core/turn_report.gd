class_name TurnReport
extends RefCounted

## spec: T-09. Runtime coordinates and enums stay typed for gameplay callers.
var inflow: float = 0.0
var to_sea: float = 0.0
var from_sea: float = 0.0
var absorbed: float = 0.0
var evaporated: float = 0.0
var destroyed: Array[Dictionary] = []
var paddies_died: Array[Vector2i] = []
var paddy_gains: Array[Vector2i] = []
var fish_food: int = 0
var hall_wet: bool = false
var outcome: int = C.Outcome.NONE
var levels_before: PackedInt32Array = PackedInt32Array()
var levels_after: PackedInt32Array = PackedInt32Array()
var snapshots: Array[PackedFloat32Array] = []

# Transient presentation data. Like snapshots, these do not enter GameState,
# checkpoint envelopes or the session's compact turn history.
# Each iteration has tile_count * 6 directed transfers in Hex.DIRECTIONS order.
var flow_edges: Array[PackedFloat32Array] = []
var wheel_transfers: Array[Dictionary] = []
var fish_food_by_tile: Dictionary = {}

# Irrigation consumes water after simulation and its ordinary water sinks.
var dry_paddy_water_used: float = 0.0


func to_dict() -> Dictionary:
	var destroyed_data: Array[Dictionary] = []
	for entry: Dictionary in destroyed:
		var coord: Vector2i = entry["coord"]
		var pair: Array[int] = [coord.x, coord.y]
		destroyed_data.append({
			"coord": pair,
			"building": C.enum_name(C.Building, int(entry["building"])),
		})
	var before_data: Array[int] = []
	var after_data: Array[int] = []
	for level: int in levels_before:
		before_data.append(level)
	for level: int in levels_after:
		after_data.append(level)
	var snapshot_data: Array = []
	for snapshot: PackedFloat32Array in snapshots:
		var water: Array[float] = []
		for depth: float in snapshot:
			water.append(depth)
		snapshot_data.append(water)
	return {
		"inflow": inflow,
		"to_sea": to_sea,
		"from_sea": from_sea,
		"absorbed": absorbed,
		"evaporated": evaporated,
		"destroyed": destroyed_data,
		"paddies_died": _coord_data(paddies_died),
		"paddy_gains": _coord_data(paddy_gains),
		"fish_food": fish_food,
		"hall_wet": hall_wet,
		"outcome": C.enum_name(C.Outcome, outcome),
		"levels_before": before_data,
		"levels_after": after_data,
		"snapshots": snapshot_data,
		"dry_paddy_water_used": dry_paddy_water_used,
	}


static func _coord_data(coords: Array[Vector2i]) -> Array:
	var result: Array = []
	for coord: Vector2i in coords:
		var pair: Array[int] = [coord.x, coord.y]
		result.append(pair)
	return result
