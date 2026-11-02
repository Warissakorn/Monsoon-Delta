extends TestCase
const F = preload("res://tools/area_development_fixtures.gd")


func before_each() -> void:
	Localization.setup("en")


func test_all_area_categories_have_localized_identities_and_roles() -> void:
	var state: GameState = F.create()
	for locale: String in ["en", "th"]:
		Localization.setup(locale)
		var categories: Dictionary = {}
		for tile: Tile in state.tiles:
			var category: String = AreaDevelopment.category(tile)
			categories[category] = true
			for prefix: String in ["area.type.", "area.role."]:
				var key: String = prefix + category
				assert_true(String(TranslationServer.translate(key)) != key, key)
		assert_eq(categories.size(), 19)
		assert_eq(AreaDevelopment.category(state.get_tile(F.DEAD)), "paddy_dead")
		assert_eq(AreaDevelopment.category(state.get_tile(F.LOW)), "lowland")
		assert_eq(AreaDevelopment.category(state.get_tile(F.WET)), "wetland")


func test_structural_options_agree_with_command_rules_without_spending_or_randomizing() -> void:
	var state: GameState = F.create(false, "bracing_moisture_irrigation_v1", "long")
	var before: Dictionary = state.to_dict()
	for tile: Tile in state.tiles:
		var options: Array[String] = AreaDevelopment.options(state, tile.coord)
		for id: String in CommandRules.DEFS:
			if not tile.is_source and not tile.is_sea:
				assert_eq(options.has(id), CommandRules.supports_target(tile, id), id)
	assert_eq(state.to_dict(), before)
	assert_true(state.undo.is_empty())
	assert_true(state.redo.is_empty())


func test_sources_sea_and_hall_remain_non_developable() -> void:
	var state: GameState = F.create()
	for coord: Vector2i in [F.SOURCE, F.SEA, F.HALL]:
		assert_true(AreaDevelopment.options(state, coord).is_empty())
	assert_true(AreaDevelopment.options(state, Vector2i(99, 99)).is_empty())
	assert_true(AreaDevelopment.options(null, F.LAND).is_empty())
	assert_true(not CommandRules.supports_target(null, "dig"))
	assert_true(not CommandRules.supports_target(state.get_tile(F.LAND), "unknown"))


func test_season_and_resource_failures_remain_visible_with_exact_validation_errors() -> void:
	var rain: GameState = F.create(true)
	assert_true(AreaDevelopment.options(rain, F.LAND).has("paddy"))
	assert_eq(AreaDevelopment.preview(rain, Command.new("paddy", F.LAND)), {"error": "err.season"})
	var dry: GameState = F.create()
	dry.wood = 0
	assert_true(AreaDevelopment.options(dry, F.LAND).has("house"))
	assert_eq(AreaDevelopment.preview(dry, Command.new("house", F.LAND)), {"error": "err.wood"})
	dry.labor = 0
	assert_eq(AreaDevelopment.preview(dry, Command.new("dig", F.LAND)), {"error": "err.labor"})


func test_locked_and_disabled_mechanics_are_not_offered() -> void:
	var state: GameState = F.create()
	assert_true(not AreaDevelopment.options(state, F.LAND).has("waterwheel"))
	assert_true(not AreaDevelopment.options(state, F.WET).has("raft_house"))
	assert_true(not AreaDevelopment.options(state, F.HOUSE).has("brace_house"))
	assert_true(not AreaDevelopment.options(state, F.FIELD).has("irrigation_policy"))
	state = F.create(false, "bracing_moisture_irrigation_v1", "long")
	assert_true(AreaDevelopment.options(state, F.LAND).has("waterwheel"))
	assert_true(AreaDevelopment.options(state, F.WET).has("raft_house"))
	assert_true(AreaDevelopment.options(state, F.HOUSE).has("brace_house"))
	assert_true(AreaDevelopment.options(state, F.FIELD).has("irrigation_policy"))


func test_preview_matches_real_commands_and_end_turn_without_mutating_any_original_snapshot() -> void:
	var state: GameState = F.create(false, "bracing_moisture_irrigation_v1", "long")
	var before: Dictionary = state.to_dict()
	var commands: Array[Command] = []
	for id: String in ["dig", "fill", "paddy", "house", "stilt_house", "plant", "gate", "reservoir", "fish_trap", "granary"]:
		commands.append(Command.new(id, F.LAND))
	commands.append_array([Command.new("chop", F.FOREST), Command.new("demolish", F.HOUSE), Command.new("toggle_gate", F.GATE), Command.new("waterwheel", F.LAND, 0), Command.new("raft_house", F.WET), Command.new("brace_house", F.HOUSE), Command.new("irrigation_policy", F.FIELD, 0)])
	for cmd: Command in commands:
		var plan: Dictionary = AreaDevelopment.preview(state, cmd)
		assert_eq(plan["error"], "", cmd.id)
		var actual: GameState = state.duplicate_state()
		assert_eq(GameFlow.apply_command(actual, cmd), "")
		assert_eq((plan["state"] as GameState).to_dict(), actual.to_dict(), cmd.id)
		var report: TurnReport = GameFlow.end_turn(actual)
		assert_eq((plan["prediction"]["report"] as TurnReport).to_dict(), report.to_dict(), cmd.id)
		assert_eq(state.to_dict(), before, cmd.id)
	assert_true(state.undo.is_empty())
	assert_true(state.redo.is_empty())


func test_harvest_projection_matches_actual_food_population_and_outcome() -> void:
	var state: GameState = F.create(true)
	state.turn = 6
	state.food = 2
	var before: Dictionary = state.to_dict()
	var cmd: Command = Command.new("demolish", F.GRANARY)
	var plan: Dictionary = AreaDevelopment.preview(state, cmd)
	assert_eq(plan["error"], "")
	var actual: GameState = state.duplicate_state()
	assert_eq(GameFlow.apply_command(actual, cmd), "")
	GameFlow.end_turn(actual)
	assert_eq(plan["harvest"], actual.harvest_report)
	assert_eq(plan["outcome"], actual.outcome)
	assert_eq(state.to_dict(), before)


func test_rice_is_not_added_as_immediate_food_and_demolition_returns_actual_wood() -> void:
	var state: GameState = F.create(true)
	var plan: Dictionary = AreaDevelopment.preview(state, Command.new("demolish", F.GRANARY))
	var after: GameState = plan["state"]
	assert_eq(after.food, state.food)
	assert_true(after.wood > state.wood)
	var report: TurnReport = plan["prediction"]["report"]
	var predicted: GameState = plan["prediction"]["state"]
	assert_true(report.paddy_gains.has(F.FIELD))
	assert_eq(predicted.food - after.food, report.fish_food)
	assert_true(plan["harvest"].is_empty())


func test_irrigation_preview_uses_the_selected_policy_and_remains_detached() -> void:
	var state: GameState = F.create(false, "moisture_irrigation_v1")
	var before: Dictionary = state.to_dict()
	var plan: Dictionary = AreaDevelopment.preview(state, Command.new("irrigation_policy", F.FIELD, 2))
	assert_eq(plan["error"], "")
	assert_eq((plan["state"] as GameState).get_tile(F.FIELD).irrigation_policy, "skip")
	var results: Array[Dictionary] = (plan["prediction"]["report"] as TurnReport).irrigation_results
	assert_true(not results.is_empty())
	assert_eq(results[0]["reason"], "skip")
	(plan["state"] as GameState).get_tile(F.FIELD).soil_moisture = 2
	assert_eq(state.to_dict(), before)


func test_all_waterwheel_directions_use_ordinary_parameter_validation() -> void:
	var state: GameState = F.create(false, "legacy", "long")
	for direction: int in range(-1, 7):
		var cmd: Command = Command.new("waterwheel", F.LAND, direction)
		var expected: String = CommandRules.check(state, cmd)
		var plan: Dictionary = AreaDevelopment.preview(state, cmd)
		assert_eq(plan["error"], expected)
		if expected.is_empty():
			assert_eq((plan["state"] as GameState).get_tile(F.LAND).wheel_dir, direction)


func test_invalid_requests_preserve_the_original_validation_order() -> void:
	var state: GameState = F.create()
	assert_eq(AreaDevelopment.preview(null, Command.new("dig", F.LAND)), {"error": "err.phase"})
	assert_eq(AreaDevelopment.preview(state, null), {"error": "err.unknown"})
	assert_eq(AreaDevelopment.preview(state, Command.new("unknown", F.LAND)), {"error": "err.unknown"})
	assert_eq(AreaDevelopment.preview(state, Command.new("dig", Vector2i(99, 99))), {"error": "err.no_tile"})
	state.phase = C.Phase.HARVEST
	assert_eq(AreaDevelopment.preview(state, Command.new("unknown", F.LAND)), {"error": "err.phase"})
