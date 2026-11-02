class_name Irrigation
extends RefCounted
## Pure allocation at the production boundary, after water, evaporation and
## damage. The caller applies each result once; planning never spends water.

const POLICIES: Array[String] = ["first", "normal", "skip"]


static func plan(state: GameState) -> Dictionary:
	var water: Dictionary = {}
	for tile: Tile in state.tiles:
		if tile.building == C.Building.RESERVOIR:
			water[tile.coord] = tile.water
	var by_tile: Dictionary = {}
	var receipts: Array[Dictionary] = []
	if state.is_rain() or state.outcome != C.Outcome.NONE:
		return {"by_tile": by_tile, "receipts": receipts, "reservoir_water": water}
	var minimum: float = float(state.mod("dry_paddy_reservoir_min"))
	var amount: float = maxf(0.0, float(state.mod("dry_paddy_water_use")))
	for policy: String in POLICIES:
		for tile: Tile in state.tiles:
			if tile.feature != C.Feature.PADDY or tile.paddy_dead or tile.irrigation_policy != policy:
				continue
			var entry: Dictionary = {
				"coord": tile.coord, "policy": policy, "source": "none", "reason": "skip" if policy == "skip" else "no_reservoir",
				"water_used": 0.0, "moisture_before": tile.soil_moisture,
				"moisture_after": maxi(0, tile.soil_moisture - 1) if state.has_moisture() else 0, "yield_gain": 0,
			}
			var best: Tile = null
			if policy != "skip":
				# neighbors() follows the same direction order and tie-break as the
				# legacy resolver. Never reorder tiles or the water simulation.
				for neighbor: Tile in state.neighbors(tile):
					if neighbor.building != C.Building.RESERVOIR:
						continue
					entry["reason"] = "insufficient_water"
					var available: float = float(water[neighbor.coord])
					if available + C.EPS < minimum:
						continue
					if best == null or available > float(water[best.coord]) + C.EPS or (absf(available - float(water[best.coord])) <= C.EPS and int(state.index[neighbor.coord]) < int(state.index[best.coord])):
						best = neighbor
			if best != null:
				var before: float = float(water[best.coord])
				var used: float = minf(maxf(0.0, before), amount)
				water[best.coord] = before - used
				entry.merge({"source": "reservoir", "reason": "", "reservoir": best.coord, "water_before": before, "water_after": water[best.coord], "water_used": used, "yield_gain": 1}, true)
			elif state.has_moisture() and tile.soil_moisture > 0:
				entry.merge({"source": "moisture", "reason": "", "yield_gain": 1}, true)
			by_tile[tile.coord] = entry
			receipts.append(entry)
	return {"by_tile": by_tile, "receipts": receipts, "reservoir_water": water}
