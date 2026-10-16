extends TestCase


func test_full_greedy_seed_42_is_identical_twice() -> void:
	# Exercise the complete policy/game loop with the actual default bot budget.
	var first: Dictionary = BotGreedy.play_game(42, "greedy")
	var second: Dictionary = BotGreedy.play_game(42, "greedy")
	assert_eq(first["error"], "", "first game completes")
	assert_eq(second["error"], "", "second game completes")
	var first_state: GameState = first["state"]
	var second_state: GameState = second["state"]
	assert_true(first_state != null and second_state != null)
	if first_state == null or second_state == null:
		return
	assert_eq(first_state.phase, C.Phase.GAME_OVER)
	assert_eq(second_state.phase, C.Phase.GAME_OVER)
	assert_true(first_state.outcome != C.Outcome.NONE)
	assert_eq(first_state.to_dict(), second_state.to_dict(), "all final state fields, including RNG")
	assert_eq(first["turns"], second["turns"])
	assert_eq(first["actions"], second["actions"])
