class_name RiverSchoolRun
extends RefCounted
## A short, memory-only attempt. Ordinary rules resolve every committed turn;
## the lesson result stays separate from the five-year game's outcome.

const Fixtures = preload("res://core/river_school_fixtures.gd")

var session: RiverSchoolSession
var scenario_id: String = ""
var completed: bool = false
var passed: bool = false
var mastered: bool = false
var turns_resolved: int = 0
var fish_food: int = 0

var _reasons: Array[String] = []
var _harvest: Dictionary = {}
var _target_losses: Array[Vector2i] = []


func start(id: String) -> bool:
	var initial: GameState = Fixtures.create(id)
	if initial == null or not initial.is_tutorial:
		return false
	var next: RiverSchoolSession = RiverSchoolSession.new(Fixtures.target_houses(id))
	# SaveIO skips tutorial states. An unused path is a second boundary against
	# accidentally treating a practice attempt as the player's normal Continue.
	next.save_path = "user://river-school-unused.json"
	next.state = initial
	session = next
	scenario_id = id
	completed = false
	passed = false
	mastered = false
	turns_resolved = 0
	fish_food = 0
	_reasons.clear()
	_harvest.clear()
	_target_losses.clear()
	return true


func retry() -> bool:
	return start(scenario_id)


func advance_turn() -> TurnReport:
	if completed or session == null or session.state == null:
		return null
	if not session.state.is_tutorial or session.state.phase != C.Phase.PLANNING:
		return null
	var removals: Array[Vector2i] = session.target_removals()
	var report: TurnReport = session.advance_turn()
	if report == null:
		return null
	turns_resolved += 1
	fish_food += report.fish_food
	var state: GameState = session.state
	for coord: Vector2i in Fixtures.target_houses(scenario_id):
		var house: Tile = state.get_tile(coord)
		if (coord in removals or house == null or house.building != C.Building.HOUSE) and coord not in _target_losses:
			_target_losses.append(coord)
	if state.phase == C.Phase.GAME_OVER or (state.phase == C.Phase.HARVEST and state.year == 1):
		_complete()
	return report


func progress() -> Dictionary:
	var values: Dictionary = {
		"rice_food": 0, "fish_food": fish_food, "food": 0,
		"population": 0, "capacity": 0, "turns": turns_resolved,
		"total_turns": C.TURNS_PER_YEAR,
	}
	if session == null or session.state == null:
		return values
	var state: GameState = session.state
	# This is rice already earned in the live fields, expressed in food at
	# harvest. It neither simulates future rain nor deposits anything in stores.
	for produced: int in Harvest.paddy_food_by_tile(state).values():
		values["rice_food"] = int(values["rice_food"]) + produced
	values["food"] = state.food
	values["population"] = state.population
	values["capacity"] = state.capacity()
	var targets: Array[Vector2i] = Fixtures.target_houses(scenario_id)
	values["target_total"] = targets.size()
	values["target_houses"] = targets.size()
	var removals: Array[Vector2i] = session.target_removals()
	for coord: Vector2i in targets:
		var house: Tile = state.get_tile(coord)
		if coord in _target_losses or coord in removals or house == null or house.building != C.Building.HOUSE:
			values["target_houses"] = int(values["target_houses"]) - 1
	return values


func result() -> Dictionary:
	# Return detached receipts, not references a UI could alter accidentally.
	return {
		"completed": completed, "passed": passed, "mastered": mastered,
		"reasons": _reasons.duplicate(), "harvest": _harvest.duplicate(true),
		"fish_food": fish_food, "turns": turns_resolved,
		"target_losses": _target_losses.duplicate(),
	}


func _complete() -> void:
	if completed:
		return
	completed = true
	var state: GameState = session.state
	_harvest = state.harvest_report.duplicate(true)
	# A real loss always takes precedence over lesson counters. In particular,
	# hunger at harvest is decided after the TurnReport's own outcome is set.
	if state.outcome == C.Outcome.LOSE_HALL:
		_reasons.append("school.reason.hall")
		return
	if state.outcome == C.Outcome.LOSE_POPULATION:
		_reasons.append("school.reason.population")
	if scenario_id == "river_school_01":
		if int(_harvest.get("paddy_food", 0)) < 1:
			_reasons.append("school.reason.no_rice")
		if int(_harvest.get("left_hunger", 0)) > 0:
			_reasons.append("school.reason.hunger")
	elif scenario_id == "river_school_02":
		if not _target_losses.is_empty():
			_reasons.append("school.reason.target_houses")
		if int(_harvest.get("paddy_food", 0)) < 1:
			_reasons.append("school.reason.no_rice")
	elif scenario_id == "river_school_03":
		if int(_harvest.get("left_hunger", 0)) > 0:
			_reasons.append("school.reason.hunger")
		if int(_harvest.get("left_housing", 0)) > 0:
			_reasons.append("school.reason.housing")
		if int(_harvest.get("population_after", 0)) < 6 and not _reasons.has("school.reason.population"):
			_reasons.append("school.reason.population")
	# All supported lessons end at the actual first harvest. They do not turn a
	# five-year state into Outcome.WIN, nor allow a second year to begin here.
	passed = not _harvest.is_empty() and _reasons.is_empty()
	if not passed:
		return
	if scenario_id == "river_school_01":
		mastered = int(state.stats.get("houses_lost", 0)) == 0 and not bool(state.stats.get("hall_ever_wet", false))
	elif scenario_id == "river_school_02":
		mastered = int(state.stats.get("paddies_lost", 0)) == 0 and not bool(state.stats.get("hall_ever_wet", false))
	elif scenario_id == "river_school_03":
		mastered = int(_harvest["paddy_food"]) >= 1 and fish_food >= 1
