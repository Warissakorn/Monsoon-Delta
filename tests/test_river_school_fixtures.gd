extends TestCase
## Real commands and unchanged physics demonstrate practice-board solutions.

const Fixtures = preload("res://core/river_school_fixtures.gd")


func _play(id: String, turns: Array, verify_preview: bool = false) -> Dictionary:
	var state: GameState = Fixtures.create(id)
	var fish_food: int = 0
	var reports: Array[Dictionary] = []
	for index: int in range(C.TURNS_PER_YEAR):
		assert_eq(state.turn, index + 1)
		assert_eq(state.phase, C.Phase.PLANNING)
		for entry: Dictionary in turns[index]:
			var command: Command = Command.new(entry["id"], entry["coord"], int(entry.get("param", -1)))
			assert_eq(CommandRules.check(state, command), "", "%s turn %d command %s is legal" % [id, index + 1, command.id])
			assert_eq(GameFlow.apply_command(state, command), "")
		var before: Dictionary = state.to_dict()
		var prediction: Dictionary = GameFlow.preview(state) if verify_preview else {}
		assert_eq(state.to_dict(), before, "preview does not change the attempt or RNG")
		var report: TurnReport = GameFlow.end_turn(state)
		assert_true(report != null)
		if report == null:
			return {"state": state, "fish_food": fish_food, "reports": reports}
		if verify_preview:
			assert_eq(report.to_dict(), (prediction["report"] as TurnReport).to_dict())
			var predicted: GameState = prediction["state"]
			for tile_index: int in range(state.tiles.size()):
				assert_eq(state.tiles[tile_index].to_dict(), predicted.tiles[tile_index].to_dict())
			assert_eq(state.rng.state, predicted.rng.state)
		fish_food += report.fish_food
		reports.append(report.to_dict())
	assert_eq(state.phase, C.Phase.HARVEST)
	return {"state": state, "fish_food": fish_food, "reports": reports}


func _passed(id: String, state: GameState) -> bool:
	if state.outcome != C.Outcome.NONE or state.phase != C.Phase.HARVEST:
		return false
	if id == "river_school_01":
		return int(state.harvest_report["paddy_food"]) >= 1 and int(state.harvest_report["left_hunger"]) == 0
	return int(state.harvest_report["left_hunger"]) == 0 and int(state.harvest_report["left_housing"]) == 0 and int(state.harvest_report["population_after"]) >= 6


func test_initial_fixtures_are_exact_repeatable_tutorial_states_with_declared_resources() -> void:
	for id: String in Fixtures.IDS:
		var state: GameState = Fixtures.create(id)
		var repeat: GameState = Fixtures.create(id)
		assert_eq(state.to_dict(), repeat.to_dict())
		assert_true(state.is_tutorial)
		assert_eq(state.ruleset, "legacy")
		assert_eq(state.map_type, "plains")
		assert_eq(state.run_mode, "classic")
		assert_eq(state.village_goal, "none")
		assert_eq(state.difficulty, 0)
		assert_eq(state.year, 1)
		assert_eq(state.turn, 1)
		assert_eq(state.population, 6)
		assert_eq(state.food, 6 if id == "river_school_01" else 0)
		assert_eq(state.wood, 2)
		assert_eq(state.labor, 6)
		assert_eq(state.leader, "farmer" if id == "river_school_01" else "fisher")
		assert_eq(state.tiles.size(), 61)
		assert_eq(state.capacity(), 6)
		assert_eq(state.get_tile(Fixtures.HALL).building, C.Building.HALL)
		assert_eq(state.rain_inflows, [3.0, 3.0, 4.0])
		assert_true(state.year_mods.is_empty(), "practice does not change rule modifiers")
		assert_true(state.undo.is_empty() and state.redo.is_empty())
		var coords: Array[Vector2i] = Hex.coords()
		for index: int in range(state.tiles.size()):
			var tile: Tile = state.tiles[index]
			assert_eq(tile.coord, coords[index])
			assert_eq(tile.paddy_yield, 0)
			assert_eq(tile.soil_moisture, 0)
			assert_eq(tile.brace_turns, 0)
			assert_true(tile.feature != C.Feature.PADDY)
			assert_true(tile.building != C.Building.FISH_TRAP)
		for _draw: int in range(4):
			assert_eq(state.rng.randi(), repeat.rng.randi())
	assert_eq(Fixtures.create("not_a_lesson"), null)
	assert_true(Fixtures.solutions("not_a_lesson").is_empty())
	assert_true(Fixtures.manifest("not_a_lesson").is_empty())


func test_first_rain_canal_solution_is_legal_matches_preview_and_earns_mastery() -> void:
	var solution: Dictionary = Fixtures.solutions("river_school_01")[0]
	assert_eq(solution["turns"].size(), 6)
	var result: Dictionary = _play("river_school_01", solution["turns"], true)
	var state: GameState = result["state"]
	assert_true(_passed("river_school_01", state))
	assert_eq(state.harvest_report["paddy_food"], 3)
	assert_eq(state.harvest_report["left_hunger"], 0)
	assert_eq(state.population, 6)
	assert_eq(state.stats["houses_lost"], 0)
	assert_true(not state.stats["hall_ever_wet"])
	assert_eq(state.get_tile(Fixtures.CHANNEL).elevation, 1)
	assert_eq(state.get_tile(Fixtures.PADDY).paddy_yield, 2)
	assert_eq(result["fish_food"], 0)


func test_first_rain_needs_a_water_connection_instead_of_only_planting() -> void:
	var turns: Array = [[], [], [], [], [], []]
	turns[0] = [{"id": "dig", "coord": Fixtures.PADDY}, {"id": "paddy", "coord": Fixtures.PADDY}]
	var state: GameState = _play("river_school_01", turns)["state"]
	assert_true(not _passed("river_school_01", state))
	assert_eq(state.harvest_report["paddy_food"], 0)
	assert_eq(state.harvest_report["left_hunger"], 0, "missing crop goal is distinct from starvation")


func test_food_lesson_has_fish_only_rice_only_and_mixed_solutions_with_real_tradeoffs() -> void:
	var solutions: Array[Dictionary] = Fixtures.solutions("river_school_03")
	assert_eq(solutions.size(), 3)
	for solution: Dictionary in solutions:
		assert_eq(solution["turns"].size(), 6)
		var result: Dictionary = _play("river_school_03", solution["turns"], true)
		var state: GameState = result["state"]
		assert_true(_passed("river_school_03", state), solution["id"] + " feeds the village")
		assert_eq(state.population, 6)
		assert_eq(state.harvest_report["left_hunger"], 0)
		assert_eq(state.harvest_report["left_housing"], 0)
		assert_eq(state.stats["houses_lost"], 0)
		assert_true(not state.stats["hall_ever_wet"])
		match solution["id"]:
			"fish_only":
				assert_eq(result["fish_food"], 6)
				assert_eq(state.harvest_report["paddy_food"], 0)
			"rice_only":
				assert_eq(result["fish_food"], 0)
				assert_eq(state.harvest_report["paddy_food"], 6)
				assert_eq(state.stats["paddies_lost"], 1, "the four-field rice plan spends labor and loses its upstream crop")
			"mixed":
				assert_eq(result["fish_food"], 6)
				assert_eq(state.harvest_report["paddy_food"], 2)
				assert_eq(state.stats["paddies_lost"], 0)


func test_untouched_attempts_fail_both_goals_and_leave_hall_and_houses_safe() -> void:
	for id: String in Fixtures.IDS:
		var state: GameState = _play(id, [[], [], [], [], [], []])["state"]
		assert_true(not _passed(id, state))
		assert_eq(state.harvest_report["paddy_food"], 0)
		assert_eq(state.stats["houses_lost"], 0)
		assert_true(not state.stats["hall_ever_wet"])
		if id == "river_school_03":
			assert_eq(state.harvest_report["left_hunger"], 6)
			assert_eq(state.outcome, C.Outcome.LOSE_POPULATION)


func test_retry_replays_are_exact_and_do_not_mutate_solution_definitions() -> void:
	for id: String in Fixtures.IDS:
		for solution: Dictionary in Fixtures.solutions(id):
			var turns: Array = solution["turns"].duplicate(true)
			var first: Dictionary = _play(id, turns)
			var second: Dictionary = _play(id, turns)
			assert_eq((first["state"] as GameState).to_dict(), (second["state"] as GameState).to_dict())
			assert_eq(first["reports"], second["reports"])
			assert_eq(turns, solution["turns"])
		var changed: Array[Dictionary] = Fixtures.solutions(id)
		changed[0]["turns"][0].clear()
		assert_true(not Fixtures.solutions(id)[0]["turns"][0].is_empty())


func test_manifest_identifies_balance_preparation_targets_and_exact_initial_rng() -> void:
	for id: String in Fixtures.IDS:
		var manifest: Dictionary = Fixtures.manifest(id)
		assert_eq(manifest["scenario_id"], id)
		assert_eq(manifest["revision"], Fixtures.REVISION)
		assert_eq(manifest["ruleset"], "legacy")
		assert_eq(manifest["balance_sha256"], FileAccess.get_sha256("res://data/balance.json"))
		assert_eq(manifest["initial_state"], Fixtures.create(id).to_dict())
		assert_true(manifest["initial_state"]["rng_state"] is String)
		assert_eq(manifest["targets"]["channel"], Fixtures.CHANNEL)
		assert_eq(manifest["targets"]["paddy"], Fixtures.PADDY)
		assert_eq(manifest["targets"]["fish"], Fixtures.FISH)
		assert_eq(manifest["weather"]["rain_inflows"], [3.0, 3.0, 4.0])
		assert_eq(manifest["prepared"]["starting_paddies"], 0)
		assert_eq(manifest["prepared"]["starting_fish_traps"], 0)
		assert_eq(manifest["solutions"], Fixtures.solutions(id))
		manifest["targets"]["houses"].clear()
		assert_eq(Fixtures.manifest(id)["targets"]["houses"].size(), 3)
