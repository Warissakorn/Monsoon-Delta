extends TestCase


func test_preview_matches_real_turn_for_100_complete_seeded_runs() -> void:
	var turns_checked: int = 0
	for seed_value: int in range(1, 101):
		var state: GameState = GameFlow.new_game({"seed": seed_value})
		assert_true(state != null, "seed %d creates a game" % seed_value)
		if state == null:
			continue
		var random := RandomNumberGenerator.new()
		random.seed = SeedUtil.derive_seed(seed_value, 9000)
		var run_turns: int = 0
		while state.phase != C.Phase.GAME_OVER and run_turns < C.YEARS * C.TURNS_PER_YEAR:
			if state.phase == C.Phase.HARVEST:
				GameFlow.continue_after_harvest(state)
				continue
			assert_eq(state.phase, C.Phase.PLANNING)
			# Bound free toggles, but otherwise use every legal kind of command.
			for _action: int in range(12):
				if state.labor <= 0:
					break
				var choices: Array[Command] = BotGreedy.legal_commands(state, BotGreedy.RANDOM_COMMANDS)
				if choices.is_empty():
					break
				var command: Command = choices[random.randi_range(0, choices.size() - 1)]
				assert_eq(GameFlow.apply_command(state, command), "")
			var before: Dictionary = state.to_dict()
			var history: Array[Dictionary] = state.undo.snapshots()
			var prediction: Dictionary = GameFlow.preview(state)
			var repeated: Dictionary = GameFlow.preview(state)
			var predicted: GameState = prediction["state"]
			var predicted_report: TurnReport = prediction["report"]
			var repeated_state: GameState = repeated["state"]
			var repeated_report: TurnReport = repeated["report"]
			assert_eq(state.to_dict(), before, "preview cannot change source or RNG")
			assert_eq(state.undo.snapshots(), history, "preview cannot consume undo history")
			assert_eq(predicted.to_dict(), repeated_state.to_dict(), "repeat preview state")
			assert_eq(predicted_report.to_dict(), repeated_report.to_dict(), "repeat preview report")
			var old_turn: int = state.turn
			var actual: TurnReport = GameFlow.end_turn(state)
			assert_true(actual != null)
			if actual == null:
				break
			assert_eq(actual.to_dict(), predicted_report.to_dict(), "seed %d turn %d report" % [seed_value, run_turns])
			assert_eq(state.rng.state, predicted.rng.state, "resolving and advancing a turn consume no RNG")
			for index: int in range(state.tiles.size()):
				assert_eq(state.tiles[index].to_dict(), predicted.tiles[index].to_dict(), "actual terrain, water and crops match preview")
			assert_eq(state.wood, predicted.wood)
			if old_turn != C.TURNS_PER_YEAR or predicted.outcome != C.Outcome.NONE:
				assert_eq(state.food, predicted.food)
				assert_eq(state.population, predicted.population)
				assert_eq(state.stats, predicted.stats)
				assert_eq(state.outcome, predicted.outcome)
			assert_true(state.undo.is_empty(), "ending a turn clears the history")
			run_turns += 1
			turns_checked += 1
		if state.phase == C.Phase.HARVEST:
			GameFlow.continue_after_harvest(state)
		assert_eq(state.phase, C.Phase.GAME_OVER, "seed %d terminates" % seed_value)
		assert_true(state.outcome != C.Outcome.NONE)
	assert_true(turns_checked >= 100, "all seeded games resolve at least one turn")


func test_harvest_preview_stops_before_summary_and_actual_game_finishes_after_continue() -> void:
	var state: GameState = TestMaps.small(1, 2)
	state.year = C.YEARS
	state.turn = C.TURNS_PER_YEAR
	state.population = 1
	state.food = 1
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	state.tiles[0].building = C.Building.HOUSE
	var prediction: Dictionary = GameFlow.preview(state)
	var predicted: GameState = prediction["state"]
	var report: TurnReport = prediction["report"]
	assert_eq(predicted.phase, C.Phase.PLANNING, "preview represents turn resolution, before harvesting")
	assert_eq(predicted.outcome, C.Outcome.NONE)
	assert_true(predicted.harvest_report.is_empty())
	assert_eq(GameFlow.end_turn(state).to_dict(), report.to_dict())
	assert_eq(state.phase, C.Phase.HARVEST)
	assert_eq(state.outcome, C.Outcome.WIN)
	assert_eq(state.harvest_report["population_after"], 1)
	GameFlow.continue_after_harvest(state)
	assert_eq(state.phase, C.Phase.GAME_OVER)
	assert_eq(state.final_score, Scoring.score(state))


func test_hall_loss_preview_and_actual_report_match_without_touching_original() -> void:
	var state: GameState = TestMaps.small(0, 2)
	state.turn = 4
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	state.tiles[0].building = C.Building.HALL
	state.tiles[0].water = 0.5
	var original: Dictionary = state.to_dict()
	var prediction: Dictionary = GameFlow.preview(state)
	var predicted: GameState = prediction["state"]
	var report: TurnReport = prediction["report"]
	assert_eq(state.to_dict(), original)
	assert_eq(predicted.outcome, C.Outcome.LOSE_HALL)
	assert_eq(report.outcome, C.Outcome.LOSE_HALL)
	assert_eq(GameFlow.end_turn(state).to_dict(), report.to_dict())
	assert_eq(state.phase, C.Phase.GAME_OVER)
	assert_eq(state.outcome, predicted.outcome)
	assert_eq(state.final_score, Scoring.score(state))
