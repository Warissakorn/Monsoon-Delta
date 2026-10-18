class_name SettlementProgress
extends RefCounted
## Persistent visual history. None of these values affect simulation rules.
## Existing saves stay on their original schema until a new run opts in.

enum Condition { STRUGGLING, STABLE, THRIVING }

const CONDITION_IDS: Array[String] = ["struggling", "stable", "thriving"]


static func enabled(s: GameState) -> bool:
	return s != null and not s.settlement_progress.is_empty()


static func condition(s: GameState) -> int:
	if not enabled(s):
		return Condition.STABLE
	return CONDITION_IDS.find(String(s.settlement_progress.get("condition", "stable")))


static func condition_key(s: GameState) -> String:
	return "settlement." + CONDITION_IDS[clampi(condition(s), 0, 2)]


static func building_stage(s: GameState, tile: Tile) -> int:
	return int(_record(s, tile).get("stage", 0))


static func building_age(s: GameState, tile: Tile) -> int:
	var record: Dictionary = _record(s, tile)
	return maxi(0, s.year - int(record["built_year"])) if not record.is_empty() else 0


static func initialize(s: GameState) -> void:
	s.settlement_progress = {
		"version": 1, "condition": "stable", "evaluated_year": 0,
		"candidate": "stable", "candidate_years": 0, "buildings": {},
	}
	reconcile(s)


static func reconcile(s: GameState) -> void:
	if not enabled(s):
		return
	var previous: Dictionary = s.settlement_progress["buildings"]
	var current: Dictionary = {}
	for tile: Tile in s.tiles:
		if tile.building == C.Building.NONE:
			continue
		var key: String = _coord_key(tile)
		var kind: String = C.enum_name(C.Building, tile.building)
		if previous.has(key) and previous[key]["building"] == kind:
			current[key] = previous[key]
		else:
			current[key] = {"building": kind, "built_year": s.year, "built_turn": s.turn, "stage": 0}
	s.settlement_progress["buildings"] = current


static func constructed(s: GameState, tile: Tile) -> void:
	# Explicitly forget the old birth date, including same-kind rebuilds.
	if enabled(s):
		s.settlement_progress["buildings"].erase(_coord_key(tile))
		reconcile(s)


static func evaluate_year(s: GameState) -> void:
	if not enabled(s) or int(s.settlement_progress["evaluated_year"]) >= s.year:
		return
	reconcile(s)
	var progress: Dictionary = s.settlement_progress
	var target: int = _observed_condition(s)
	var current: int = condition(s)
	if target == current:
		progress["candidate"] = CONDITION_IDS[current]
		progress["candidate_years"] = 0
	else:
		var candidate: String = CONDITION_IDS[target]
		progress["candidate_years"] = int(progress["candidate_years"]) + 1 if progress["candidate"] == candidate else 1
		progress["candidate"] = candidate
		# Two consecutive harvests prevent a single purchase/harvest from
		# changing the whole village. Move at most one condition per year.
		if int(progress["candidate_years"]) >= 2:
			current += 1 if target > current else -1
			progress["condition"] = CONDITION_IDS[current]
			progress["candidate_years"] = 0
			progress["candidate"] = CONDITION_IDS[current]
	for record: Dictionary in progress["buildings"].values():
		var age: int = s.year - int(record["built_year"])
		if current == Condition.THRIVING and age >= 1:
			record["stage"] = mini(2, int(record["stage"]) + 1)
		elif current == Condition.STRUGGLING:
			record["stage"] = maxi(0, int(record["stage"]) - 1)
	progress["evaluated_year"] = s.year


static func _observed_condition(s: GameState) -> int:
	var hunger: int = int(s.harvest_report.get("left_hunger", 0))
	var displaced: int = int(s.harvest_report.get("left_housing", 0))
	if s.population == 0 or hunger > 0 or displaced > 0 or s.food == 0:
		return Condition.STRUGGLING
	var annual_need: int = s.population * maxi(0, roundi(float(s.mod("food_per_person"))))
	var wood_reserve: int = 2 * maxi(0, roundi(float(s.mod("house_wood"))))
	if s.capacity() >= s.population and s.food >= annual_need and s.wood >= wood_reserve:
		return Condition.THRIVING
	return Condition.STABLE


static func _record(s: GameState, tile: Tile) -> Dictionary:
	if not enabled(s) or tile == null or tile.building == C.Building.NONE:
		return {}
	var record: Dictionary = s.settlement_progress["buildings"].get(_coord_key(tile), {})
	return record if record.get("building", "") == C.enum_name(C.Building, tile.building) else {}


static func _coord_key(tile: Tile) -> String:
	return "%d,%d" % [tile.q, tile.r]
