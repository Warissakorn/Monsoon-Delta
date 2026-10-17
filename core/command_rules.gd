class_name CommandRules
extends RefCounted
## Deterministic player commands, following the validation order in CM-02.

const DEFS: Dictionary = {
	"dig": {"labor": "dig_labor"},
	"fill": {"labor": "fill_labor"},
	"paddy": {"labor": "paddy_labor", "dry_only": true},
	"house": {"labor": "house_labor", "wood": "house_wood", "building": C.Building.HOUSE},
	"stilt_house": {"labor": "stilt_labor", "wood": "stilt_wood", "building": C.Building.STILT_HOUSE},
	"raft_house": {"labor": "raft_labor", "wood": "raft_wood", "building": C.Building.RAFT_HOUSE, "unlock": "unlock_raft_house"},
	"chop": {"labor": "chop_labor"},
	"plant": {"labor": "plant_labor", "dry_only": true},
	"gate": {"labor": "gate_labor", "wood": "gate_wood", "building": C.Building.GATE},
	"toggle_gate": {},
	"reservoir": {"labor": "reservoir_labor", "dry_only": true, "building": C.Building.RESERVOIR},
	"fish_trap": {"labor": "fish_trap_labor", "wood": "fish_trap_wood", "building": C.Building.FISH_TRAP},
	"granary": {"labor": "granary_labor", "wood": "granary_wood", "building": C.Building.GRANARY},
	"waterwheel": {"labor": "wheel_labor", "wood": "wheel_wood", "building": C.Building.WATERWHEEL, "unlock": "unlock_waterwheel"},
	"demolish": {"labor": "demolish_labor"},
}


static func check(s: GameState, cmd: Command) -> String:
	if s.phase != C.Phase.PLANNING:
		return "err.phase"
	if not DEFS.has(cmd.id):
		return "err.unknown"
	var definition: Dictionary = DEFS[cmd.id]
	var unlock: String = String(definition.get("unlock", ""))
	if not unlock.is_empty() and _count(s, unlock) <= 0:
		return "err.locked"
	var tile: Tile = s.get_tile(cmd.coord)
	if tile == null:
		return "err.no_tile"
	if bool(definition.get("dry_only", false)) and s.is_rain():
		return "err.season"
	if not _target_matches(tile, cmd.id):
		return "err.target"
	var level: int = s.level_of(tile)
	if cmd.id in ["paddy", "house", "stilt_house", "plant", "reservoir", "granary"] and level != 0:
		return "err.water"
	if cmd.id == "raft_house" and level < 1:
		return "err.water"
	if cmd.id == "waterwheel":
		if cmd.param < 0 or cmd.param >= 6:
			return "err.param"
		var neighbor: Tile = s.neighbor_in_dir(tile, cmd.param)
		if neighbor == null or neighbor.is_sea:
			return "err.param"
	elif cmd.param != -1:
		return "err.param"
	var price: Vector2i = cost(s, cmd)
	if s.labor < price.x:
		return "err.labor"
	if s.wood < price.y:
		return "err.wood"
	return ""


static func cost(s: GameState, cmd: Command) -> Vector2i:
	if not DEFS.has(cmd.id):
		return Vector2i.ZERO
	var definition: Dictionary = DEFS[cmd.id]
	var labor_key: String = String(definition.get("labor", ""))
	if cmd.id in ["dig", "fill"]:
		labor_key += "_rain" if s.is_rain() else "_dry"
	var labor: int = _price(s, labor_key)
	if cmd.id in ["dig", "fill"]:
		labor = maxi(1, labor)
	return Vector2i(labor, _price(s, String(definition.get("wood", ""))))


static func apply(s: GameState, cmd: Command) -> void:
	var error: String = check(s, cmd)
	assert(error.is_empty(), "Cannot apply %s: %s" % [cmd.id, error])
	if not error.is_empty():
		return
	var tile: Tile = s.get_tile(cmd.coord)
	var price: Vector2i = cost(s, cmd)
	s.labor -= price.x
	s.wood -= price.y
	match cmd.id:
		"dig":
			tile.elevation = maxi(0, tile.elevation - _count(s, "dig_amount"))
		"fill":
			tile.elevation = mini(4, tile.elevation + _count(s, "fill_amount"))
		"paddy":
			tile.feature = C.Feature.PADDY
			_reset_paddy(tile)
		"chop":
			tile.feature = C.Feature.NONE
			s.wood += _count(s, "chop_wood")
		"plant":
			tile.feature = C.Feature.SAPLING
		"toggle_gate":
			tile.gate_open = not tile.gate_open
		"demolish":
			_demolish(s, tile)
		_:
			tile.building = int(DEFS[cmd.id]["building"])
			if cmd.id == "gate":
				tile.gate_open = true
			elif cmd.id == "waterwheel":
				tile.wheel_dir = cmd.param
			elif cmd.id == "reservoir":
				tile.elevation = maxi(-3, tile.elevation - _count(s, "reservoir_depth"))


static func valid_targets(s: GameState, id: String, param: int = -1) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile: Tile in s.tiles:
		if check(s, Command.new(id, tile.coord, param)).is_empty():
			result.append(tile.coord)
	return result


static func _target_matches(tile: Tile, id: String) -> bool:
	match id:
		"dig", "fill":
			var earthwork_target: bool = tile.building == C.Building.NONE and tile.feature in [C.Feature.NONE, C.Feature.PADDY] and not tile.is_sea and not tile.is_source
			return earthwork_target and (tile.elevation >= 1 if id == "dig" else tile.elevation <= 3)
		"chop":
			return tile.feature == C.Feature.FOREST
		"toggle_gate":
			return tile.building == C.Building.GATE
		"demolish":
			if tile.building != C.Building.NONE:
				return tile.building != C.Building.HALL
			return tile.feature in [C.Feature.PADDY, C.Feature.SAPLING]
		_:
			return tile.building == C.Building.NONE and tile.feature == C.Feature.NONE and not tile.is_sea and not tile.is_source


static func _count(s: GameState, key: String) -> int:
	return roundi(float(s.mod(key)))


static func _price(s: GameState, key: String) -> int:
	return 0 if key.is_empty() else maxi(0, _count(s, key))


static func _reset_paddy(tile: Tile) -> void:
	tile.paddy_yield = 0
	tile.paddy_dead = false
	tile.paddy_rain_turns = 0


static func _demolish(s: GameState, tile: Tile) -> void:
	if tile.building != C.Building.NONE:
		var wood_cost: int = 0
		for definition: Dictionary in DEFS.values():
			if int(definition.get("building", C.Building.NONE)) == tile.building:
				wood_cost = _price(s, String(definition.get("wood", "")))
				break
		s.wood += floori(float(wood_cost) * float(s.mod("demolish_refund_fraction")))
		tile.building = C.Building.NONE
		tile.gate_open = true
		tile.wheel_dir = -1
	else:
		tile.feature = C.Feature.NONE
		_reset_paddy(tile)
