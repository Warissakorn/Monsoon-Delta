class_name GameFlow
extends RefCounted


# M2 is a repeatable rain-season water sandbox. Full game phases belong to a
# later milestone; the UI changes sandbox state only through this API.
static func sandbox_new(seed_value: int) -> GameState:
	var state: GameState = MapGen.generate(seed_value)
	if state != null:
		state.turn = 4
	return state


static func sandbox_edit(s: GameState, coord: Vector2i, amount: int) -> bool:
	if amount != -1 and amount != 1:
		return false
	var tile: Tile = s.get_tile(coord)
	if tile == null or tile.is_source or tile.is_sea:
		return false
	if tile.building != C.Building.NONE or tile.feature != C.Feature.NONE:
		return false
	var settings: Dictionary = DataDB.balance()["sandbox"]
	var next_elevation: int = tile.elevation + amount
	if next_elevation < int(settings["elevation_min"]) or next_elevation > int(settings["elevation_max"]):
		return false
	tile.elevation = next_elevation
	return true


static func sandbox_step(s: GameState, inflow: float) -> Dictionary:
	s.turn = 4
	var before: float = _land_water(s)
	var report: Dictionary = WaterSim.simulate(s, maxf(0.0, inflow), true)
	var absorbed: float = WaterSim.absorb(s)
	var after: float = _land_water(s)
	var expected_after: float = before + float(report["inflow"]) - float(report["to_sea"]) + float(report["from_sea"]) - absorbed
	var balance_error: float = after - expected_after
	var errors: Array[String] = []
	if absf(balance_error) > 1e-3:
		errors.append("mass_balance")
	for tile in s.tiles:
		if not is_finite(tile.water) or tile.water < 0.0:
			errors.append("invalid_water")
			break
	report.merge({
		"before": before,
		"after": after,
		"absorbed": absorbed,
		"evaporated": 0.0,
		"expected_after": expected_after,
		"balance_error": balance_error,
		"valid": errors.is_empty(),
		"errors": errors,
	})
	return report


static func _land_water(s: GameState) -> float:
	var total: float = 0.0
	for tile in s.tiles:
		if not tile.is_sea:
			total += tile.water
	return total
