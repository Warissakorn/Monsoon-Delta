class_name TurnResolver
extends RefCounted


# spec: T-08. Resolve one turn without advancing time or consuming any RNG.
static func resolve_turn(s: GameState, record_snapshots: bool = true) -> TurnReport:
	var report: TurnReport = TurnReport.new()
	report.levels_before = _levels(s)
	var water: Dictionary = WaterSim.simulate(s, s.current_inflow(), record_snapshots)
	report.inflow = float(water["inflow"])
	report.to_sea = float(water["to_sea"])
	report.from_sea = float(water["from_sea"])
	report.snapshots.assign(water["snapshots"])
	report.flow_edges.assign(water["flow_edges"])
	report.wheel_transfers.assign(water["wheel_transfers"])
	report.absorbed = WaterSim.absorb(s)
	if not s.is_rain():
		report.evaporated = WaterSim.evaporate(s)
	# Damage and production use the post-water levels, before irrigation changes
	# a reservoir. Reservoir eligibility still reads its remaining current water.
	var production_levels: PackedInt32Array = _levels(s)
	_damage(s, report, production_levels)
	SettlementProgress.reconcile(s)
	if s.outcome == C.Outcome.NONE:
		_produce(s, report, production_levels, record_snapshots)
		s.stats["food_produced"] = int(s.stats.get("food_produced", 0)) + report.fish_food
	report.levels_after = _levels(s)
	report.outcome = s.outcome
	return report


static func _levels(s: GameState) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for tile: Tile in s.tiles:
		result.append(s.level_of(tile))
	return result


static func _damage(s: GameState, report: TurnReport, levels: PackedInt32Array) -> void:
	var house_level: int = roundi(float(s.mod("house_destroy_level")))
	var stilt_level: int = roundi(float(s.mod("stilt_destroy_level")))
	var granary_level: int = roundi(float(s.mod("granary_destroy_level")))
	var hall_level: int = roundi(float(s.mod("hall_lose_level")))
	var paddy_level: int = roundi(float(s.mod("paddy_death_level")))
	for index: int in range(s.tiles.size()):
		var tile: Tile = s.tiles[index]
		var level: int = levels[index]
		var building: int = tile.building
		var destroyed: bool = (
			(building == C.Building.HOUSE and level >= house_level)
			or (building == C.Building.STILT_HOUSE and level >= stilt_level)
			or (building == C.Building.GRANARY and level >= granary_level)
		)
		if destroyed:
			report.destroyed.append({"coord": tile.coord, "building": building})
			tile.building = C.Building.NONE
			if building in [C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.RAFT_HOUSE]:
				s.stats["houses_lost"] = int(s.stats.get("houses_lost", 0)) + 1
		if building == C.Building.HALL:
			if level >= 1:
				report.hall_wet = true
				s.stats["hall_ever_wet"] = true
			if level >= hall_level:
				s.outcome = C.Outcome.LOSE_HALL
		if tile.feature == C.Feature.PADDY and not tile.paddy_dead and level >= paddy_level:
			tile.paddy_dead = true
			tile.paddy_yield = 0
			s.stats["paddies_lost"] = int(s.stats.get("paddies_lost", 0)) + 1
			report.paddies_died.append(tile.coord)


static func _produce(s: GameState, report: TurnReport, levels: PackedInt32Array, record_visuals: bool = true) -> void:
	var min_level: int = roundi(float(s.mod("paddy_min_level")))
	var max_level: int = roundi(float(s.mod("paddy_max_level")))
	var reservoir_min: float = float(s.mod("dry_paddy_reservoir_min"))
	var water_use: float = maxf(0.0, float(s.mod("dry_paddy_water_use")))
	var fish_yield: int = roundi(float(s.mod("fish_trap_yield")))
	var fish_food: int = roundi(float(fish_yield) * float(s.mod("fish_trap_multiplier")))
	for index: int in range(s.tiles.size()):
		var tile: Tile = s.tiles[index]
		var level: int = levels[index]
		if tile.feature == C.Feature.PADDY and not tile.paddy_dead:
			if s.is_rain():
				if level >= min_level and level <= max_level:
					tile.paddy_yield += 1
					tile.paddy_rain_turns += 1
					report.paddy_gains.append(tile.coord)
			else:
				var reservoir: Tile = _best_reservoir(s, tile, reservoir_min)
				if reservoir != null:
					var used: float = minf(maxf(0.0, reservoir.water), water_use)
					reservoir.water -= used
					report.dry_paddy_water_used += used
					tile.paddy_yield += 1
					report.paddy_gains.append(tile.coord)
		if tile.building == C.Building.FISH_TRAP and level >= 1:
			s.food += fish_food
			report.fish_food += fish_food
			if record_visuals:
				report.fish_food_by_tile[tile.coord] = fish_food


static func _best_reservoir(s: GameState, paddy: Tile, minimum: float) -> Tile:
	var best: Tile = null
	var best_index: int = s.tiles.size()
	for neighbor: Tile in s.neighbors(paddy):
		if neighbor.building != C.Building.RESERVOIR or neighbor.water + C.EPS < minimum:
			continue
		var index: int = int(s.index[neighbor.coord])
		if (
			best == null or neighbor.water > best.water + C.EPS
			or (absf(neighbor.water - best.water) <= C.EPS and index < best_index)
		):
			best = neighbor
			best_index = index
	return best
