class_name YearClassic
extends RefCounted
## Opt-in year365_v4/v5/v6 mechanics; old campaigns keep the original daily rules.
const FIELDS: Array[String] = ["soil_moisture", "brace_days", "irrigation_policy"]
const STRUCTURES: Array[String] = ["", "hall", "house", "stilt_house", "sawmill", "kiln", "granary", "gate", "reservoir", "waterwheel", "workshop", "camp", "raft_house", "fish_trap"]

static func enabled(s: Dictionary) -> bool:
	return s.get("ruleset") in ["year365_v4", "year365_v5", "year365_v6"]


static func config() -> Dictionary:
	return DataDB.balance()["year_classic"]


static func initialize(s: Dictionary) -> void:
	s["ruleset"] = "year365_v4"
	for field: String in FIELDS:
		s[field] = []
		for _index: int in range(s["structures"].size()):
			s[field].append("normal" if field == "irrigation_policy" else 0)


static func policy(s: Dictionary, index: int, choice: String) -> String:
	if not enabled(s) or s["outcome"] != "running" or choice not in Irrigation.POLICIES or index < 0 or index >= s["structures"].size() or s["board"]["tiles"][index]["feature"] != "paddy":
		return "year.error.target"
	s["irrigation_policy"][index] = choice
	return ""


static func clear(s: Dictionary, index: int) -> void:
	var tile: Dictionary = s["board"]["tiles"][index]
	tile["feature"] = "none"
	for field: String in ["crop_growth", "crop_stress", "sapling_ready", "soil_moisture"]:
		s[field][index] = 0
	s["irrigation_policy"][index] = "normal"


static func crops_and_fish(s: Dictionary, board: GameState, season: String, events: Array, report: TurnReport) -> void:
	# Priority then stable tile order, so scarce reservoir water is allocated once.
	for priority: String in Irrigation.POLICIES:
		for index: int in range(board.tiles.size()):
			var tile: Tile = board.tiles[index]
			if tile.feature != C.Feature.PADDY or s["irrigation_policy"][index] != priority:
				continue
			var growth_before: int = int(s["crop_growth"][index])
			var moisture_before: int = int(s["soil_moisture"][index])
			if tile.water >= 1.0:
				s["crop_stress"][index] = int(s["crop_stress"][index]) + 1
				if int(s["crop_stress"][index]) >= 5:
					if int(s["crop_growth"][index]) > 0:
						YearLedger.fact(report, s, index, "year.event.crop_lost", int(s["crop_growth"][index]), 0)
						if report != null:
							report.paddies_died.append(tile.coord)
						events.append("year.event.crop_lost")
					s["crop_growth"][index] = 0
					s["soil_moisture"][index] = 0
				continue
			s["crop_stress"][index] = 0
			var source: String = "natural" if season in ["early_rain", "flood"] or tile.water >= 0.1 else "none"
			var reservoir: Tile = null
			var used: float = 0.0
			if source == "none" and priority != "skip":
				var radius: int = (2 if "water2" in s["research"] else 1) + (1 if s["project"] == "water" and int(s["project_stage"]) >= 2 else 0)
				for other: int in range(board.tiles.size()):
					var candidate: Tile = board.tiles[other]
					if s["structures"][other] == "reservoir" and int(s["health"][other]) > 0 and candidate.water >= 0.04 and Hex.distance(tile.coord, candidate.coord) <= radius + (1 if YearExpansion.upgrade(s, other) == "reservoir_reach" else 0):
						used = 0.01 if "water2" in s["research"] else 0.02
						candidate.water -= used
						reservoir = candidate
						source = "reservoir"
						s["stats"]["irrigated_days"] = int(s["stats"]["irrigated_days"]) + 1
						break
			var watered: bool = source != "none" or moisture_before > 0
			if source != "none":
				s["soil_moisture"][index] = int(config()["moisture_capacity"])
			elif moisture_before > 0:
				source = "moisture"
				s["soil_moisture"][index] = moisture_before - 1
			if watered:
				var previous: int = int(s["crop_growth"][index])
				s["crop_growth"][index] = mini(90, previous + 1)
				if previous == 44:
					events.append("year.event.harvest_ready")
			if report != null:
				if int(s["soil_moisture"][index]) != moisture_before:
					report.moisture_changes.append({"coord": tile.coord, "before": moisture_before, "after": int(s["soil_moisture"][index]), "reason": source, "yield_from_moisture": 1 if source == "moisture" else 0})
				if source == "reservoir":
					report.irrigation_results.append({"coord": tile.coord, "reservoir": reservoir.coord, "policy": priority, "source": source, "reason": "supplied", "water_used": used, "moisture_before": moisture_before, "moisture_after": int(s["soil_moisture"][index]), "yield_gain": 1})
					report.dry_paddy_water_used += used
					YearLedger.fact(report, s, index, "yearplus.irrigated", 0.0, used)
					report.year_ledger["locations"].back()["source"] = reservoir.coord
				if watered and growth_before < 90:
					YearLedger.fact(report, s, index, "yearplus.crop_growth", growth_before, int(s["crop_growth"][index]))
					report.paddy_gains.append(tile.coord)
	for index: int in range(board.tiles.size()):
		var tile: Tile = board.tiles[index]
		if s["structures"][index] == "fish_trap" and int(s["health"][index]) > 0 and s["outcome"] == "running" and tile.water >= float(config()["trap_min_water"]) and tile.water < float(config()["trap_max_water"]):
			var before: Dictionary = YearLedger.snapshot(s) if report != null else {}
			var amount: int = int(config()["trap_food_per_day"])
			s["resources"]["food"] = int(s["resources"]["food"]) + amount
			s["stats"]["food"] = int(s["stats"]["food"]) + amount
			YearLedger.record(report, s, before, "yearplus.passive_fish", index)
			YearLedger.fact(report, s, index, "yearplus.passive_fish", 0, amount)
			if report != null:
				report.fish_food += amount
				report.fish_food_by_tile[tile.coord] = amount
