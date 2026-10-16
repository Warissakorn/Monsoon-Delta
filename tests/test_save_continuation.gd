extends TestCase
## Disk checkpoints must not change a run's commands, water, harvest or RNG.

const CHECKPOINT_PATH: String = "user://test_save_continuation.json"


func test_reloading_every_checkpoint_matches_uninterrupted_seeded_games() -> void:
	var planning_checkpoints: int = 0
	var harvest_checkpoints: int = 0
	var year_transitions: int = 0
	for seed_value: int in range(1, 17):
		var reference: GameState = GameFlow.new_game({"seed": seed_value})
		var resumed: GameState = reference.duplicate_state()
		var random := RandomNumberGenerator.new()
		random.seed = SeedUtil.derive_seed(seed_value, 9100)
		var turns: int = 0
		while reference.phase != C.Phase.GAME_OVER and turns < C.YEARS * C.TURNS_PER_YEAR:
			if reference.phase == C.Phase.HARVEST:
				resumed = _reload_checkpoint(resumed)
				if resumed == null:
					return
				harvest_checkpoints += 1
				var previous_year: int = reference.year
				GameFlow.continue_after_harvest(reference)
				GameFlow.continue_after_harvest(resumed)
				_assert_same(resumed.to_dict(), reference.to_dict(), "annual RNG and harvest continue identically")
				if reference.year != previous_year:
					year_transitions += 1
				continue
			# Farmer games reach later years; other games exercise terrain/buildings.
			if seed_value <= 8:
				BotFarmer.play_turn(reference, random)
				BotFarmer.play_turn(resumed, random)
			else:
				for _action: int in range(4):
					var choices: Array[Command] = BotGreedy.legal_commands(reference, BotGreedy.RANDOM_COMMANDS)
					if choices.is_empty():
						break
					var command: Command = choices[random.randi_range(0, choices.size() - 1)]
					assert_eq(GameFlow.apply_command(reference, command), "")
					assert_eq(GameFlow.apply_command(resumed, command), "")
			resumed = _reload_checkpoint(resumed)
			if resumed == null:
				return
			planning_checkpoints += 1
			_assert_same(resumed.to_dict(), reference.to_dict(), "mid-turn checkpoint keeps spent resources and all tile data")
			var expected: TurnReport = GameFlow.end_turn(reference)
			var actual: TurnReport = GameFlow.end_turn(resumed)
			assert_true(actual != null and expected != null)
			if actual == null or expected == null:
				return
			_assert_same(actual.to_dict(), expected.to_dict(), "resumed water/damage/production report")
			_assert_same(resumed.to_dict(), reference.to_dict(), "resumed turn and harvest match uninterrupted run")
			turns += 1
		# The 30th turn can end at the final harvest rather than GAME_OVER.
		if reference.phase == C.Phase.HARVEST:
			resumed = _reload_checkpoint(resumed)
			if resumed == null:
				return
			harvest_checkpoints += 1
			GameFlow.continue_after_harvest(reference)
			GameFlow.continue_after_harvest(resumed)
		assert_eq(reference.phase, C.Phase.GAME_OVER)
		_assert_same(resumed.to_dict(), reference.to_dict(), "final outcome and score")
	assert_true(planning_checkpoints >= 100, "many checkpointed turns across 16 seeds")
	assert_true(harvest_checkpoints >= 10, "annual summaries are restored without harvesting twice")
	assert_true(year_transitions >= 10, "next-year forecast RNG continues after reload")
	assert_eq(SaveIO.delete_save(CHECKPOINT_PATH), "")


func _reload_checkpoint(state: GameState) -> GameState:
	var before: Dictionary = state.to_dict()
	var history: Array[Dictionary] = state.undo.snapshots()
	var error: String = SaveIO.save(state, CHECKPOINT_PATH)
	assert_eq(error, "")
	if not error.is_empty():
		return null
	_assert_same(state.to_dict(), before, "saving cannot mutate state or RNG")
	_assert_same(state.undo.snapshots(), history, "saving cannot consume undo history")
	var result: Dictionary = SaveIO.load_game(CHECKPOINT_PATH)
	assert_eq(result["error"], "", "seed %d year %d turn %d phase %d" % [state.seed, state.year, state.turn, state.phase])
	var restored: GameState = result["state"]
	assert_true(restored != null)
	if restored != null:
		if not _assert_same(restored.to_dict(), before, "full-precision disk roundtrip"):
			return null
		assert_true(restored.undo.is_empty(), "loaded checkpoints start a new undo history")
	return restored


func _assert_same(actual: Variant, expected: Variant, context: String) -> bool:
	var difference: String = _first_difference(actual, expected, "state")
	if not difference.is_empty():
		fail(context + ": " + difference)
		return false
	return true


func _first_difference(actual: Variant, expected: Variant, path: String) -> String:
	if typeof(actual) != typeof(expected):
		return "%s type %d != %d" % [path, typeof(actual), typeof(expected)]
	if actual is Dictionary:
		if actual.size() != expected.size():
			return path + " dictionary size differs"
		for key: Variant in expected:
			if not actual.has(key):
				return path + " missing key " + str(key)
			var difference: String = _first_difference(actual[key], expected[key], path + "." + str(key))
			if not difference.is_empty():
				return difference
	elif actual is Array:
		if actual.size() != expected.size():
			return path + " array size differs"
		for index: int in range(expected.size()):
			var difference: String = _first_difference(actual[index], expected[index], "%s[%d]" % [path, index])
			if not difference.is_empty():
				return difference
	elif actual != expected:
		return "%s: %s != %s" % [path, var_to_str(actual), var_to_str(expected)]
	return ""
