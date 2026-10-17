extends TestCase


func test_three_commands_undo_and_redo_exact_states_with_remaining_history() -> void:
	var state: GameState = TestMaps.small(1, 2)
	state.rng.seed = 42
	state.rng.randi()
	var original: Dictionary = state.to_dict()
	var snapshots: Array[Dictionary] = [original]
	var commands: Array[Command] = [
		Command.new("dig", Vector2i.ZERO), Command.new("paddy", Vector2i.ZERO),
		Command.new("fill", Vector2i(1, 0)),
	]
	for index: int in range(commands.size()):
		assert_eq(GameFlow.apply_command(state, commands[index]), "")
		assert_eq(state.undo.size(), index + 1)
		snapshots.append(state.to_dict())
	for index: int in range(2, -1, -1):
		state = GameFlow.undo(state)
		assert_eq(state.to_dict(), snapshots[index], "undo restores all resources, tiles and RNG")
		assert_eq(state.undo.size(), index, "remaining undo history survives state replacement")
		assert_eq(state.redo.size(), commands.size() - index)
	assert_eq(state.to_dict(), original)
	assert_eq(GameFlow.undo(state), state, "empty history returns the current state")
	for index: int in range(1, snapshots.size()):
		state = GameFlow.redo(state)
		assert_eq(state.to_dict(), snapshots[index], "redo restores all resources, tiles and RNG")
		assert_eq(state.undo.size(), index)
		assert_eq(state.redo.size(), commands.size() - index, "remaining redo history survives state replacement")
	assert_eq(GameFlow.redo(state), state, "empty redo history returns the current state")
	state = GameFlow.undo(state)
	assert_eq(state.to_dict(), snapshots[2], "a redone command can be undone again")
	state = GameFlow.redo(state)
	assert_eq(state.to_dict(), snapshots[3])


func test_failed_command_does_not_change_state_or_history() -> void:
	var state: GameState = TestMaps.small(1, 2)
	assert_eq(GameFlow.apply_command(state, Command.new("dig", Vector2i.ZERO)), "")
	var before: Dictionary = state.to_dict()
	var history: Array[Dictionary] = state.undo.snapshots()
	assert_eq(GameFlow.apply_command(state, Command.new("dig", Vector2i(99, 99))), "err.no_tile")
	assert_eq(state.to_dict(), before)
	assert_eq(state.undo.snapshots(), history)
	state.phase = C.Phase.HARVEST
	before = state.to_dict()
	assert_eq(GameFlow.apply_command(state, Command.new("fill", Vector2i.ZERO)), "err.phase")
	assert_eq(GameFlow.undo(state), state, "undo is unavailable outside planning")
	assert_eq(state.to_dict(), before)


func test_new_command_branches_history_but_failed_commands_preserve_redo() -> void:
	var state: GameState = TestMaps.small(1, 2)
	var original: Dictionary = state.to_dict()
	assert_eq(GameFlow.apply_command(state, Command.new("dig", Vector2i.ZERO)), "")
	var after_dig: Dictionary = state.to_dict()
	state = GameFlow.undo(state)
	var redo_history: Array[Dictionary] = state.redo.snapshots()
	assert_eq(GameFlow.apply_command(state, Command.new("dig", Vector2i(99, 99))), "err.no_tile")
	assert_eq(state.to_dict(), original)
	assert_true(state.undo.is_empty())
	assert_eq(state.redo.snapshots(), redo_history)
	state = GameFlow.redo(state)
	assert_eq(state.to_dict(), after_dig, "a rejected command leaves redo available")
	state = GameFlow.undo(state)
	assert_eq(GameFlow.apply_command(state, Command.new("fill", Vector2i(1, 0))), "")
	var branch: Dictionary = state.to_dict()
	assert_true(state.redo.is_empty(), "a new accepted command discards the old future")
	assert_eq(GameFlow.redo(state), state)
	state = GameFlow.undo(state)
	assert_eq(state.to_dict(), original)
	state = GameFlow.redo(state)
	assert_eq(state.to_dict(), branch, "redo follows the new command branch")


func test_redo_rejects_null_and_nonplanning_states_without_changing_histories() -> void:
	assert_eq(GameFlow.redo(null), null)
	var state: GameState = TestMaps.small(1, 2)
	assert_eq(GameFlow.apply_command(state, Command.new("dig", Vector2i.ZERO)), "")
	assert_eq(GameFlow.apply_command(state, Command.new("fill", Vector2i(1, 0))), "")
	state = GameFlow.undo(state)
	var undo_history: Array[Dictionary] = state.undo.snapshots()
	var redo_history: Array[Dictionary] = state.redo.snapshots()
	for phase: int in [C.Phase.HARVEST, C.Phase.GAME_OVER]:
		state.phase = phase
		var before: Dictionary = state.to_dict()
		assert_eq(GameFlow.undo(state), state)
		assert_eq(GameFlow.redo(state), state)
		assert_eq(state.to_dict(), before)
		assert_eq(state.undo.snapshots(), undo_history)
		assert_eq(state.redo.snapshots(), redo_history)


func test_history_has_a_200_snapshot_limit_and_owns_its_data() -> void:
	var history := UndoStack.new()
	var input: Dictionary = {"number": 0, "nested": ["original"]}
	history.push(input)
	input["nested"].append("changed")
	var exported: Array[Dictionary] = history.snapshots()
	exported[0]["nested"].append("changed again")
	assert_eq(history.pop(), {"number": 0, "nested": ["original"]})
	for number: int in range(201):
		history.push({"number": number})
	assert_eq(history.size(), 200)
	for number: int in range(200, 0, -1):
		assert_eq(history.pop()["number"], number)
	assert_true(history.is_empty())
	assert_eq(history.pop(), {})


func test_loading_duplication_and_preview_do_not_copy_command_histories() -> void:
	var state: GameState = TestMaps.small(1, 2)
	assert_eq(GameFlow.apply_command(state, Command.new("dig", Vector2i.ZERO)), "")
	assert_eq(GameFlow.apply_command(state, Command.new("fill", Vector2i(1, 0))), "")
	state = GameFlow.undo(state)
	var undo_history: Array[Dictionary] = state.undo.snapshots()
	var redo_history: Array[Dictionary] = state.redo.snapshots()
	var saved: Dictionary = state.to_dict()
	assert_true(not saved.has("undo"))
	assert_true(not saved.has("redo"))
	var copies: Array[GameState] = [GameState.from_dict(saved), state.duplicate_state(), GameFlow.preview(state)["state"]]
	for copy: GameState in copies:
		assert_true(copy.undo.is_empty())
		assert_true(copy.redo.is_empty())
		copy.undo.push(saved)
		copy.redo.push(saved)
	assert_eq(state.undo.snapshots(), undo_history, "copies own their history without draining the source")
	assert_eq(state.redo.snapshots(), redo_history)


func test_end_turn_and_new_year_clear_command_history() -> void:
	var state: GameState = TestMaps.small(1, 2)
	assert_eq(GameFlow.apply_command(state, Command.new("dig", Vector2i.ZERO)), "")
	assert_eq(GameFlow.apply_command(state, Command.new("fill", Vector2i(1, 0))), "")
	state = GameFlow.undo(state)
	assert_eq(state.redo.size(), 1)
	GameFlow.end_turn(state)
	assert_true(state.undo.is_empty())
	assert_true(state.redo.is_empty())
	var after: Dictionary = state.to_dict()
	state = GameFlow.undo(state)
	state = GameFlow.redo(state)
	assert_eq(state.to_dict(), after, "previous-turn commands cannot be undone")
	state.phase = C.Phase.HARVEST
	state.turn = 6
	state.undo.push(state.to_dict())
	state.redo.push(state.to_dict())
	GameFlow.continue_after_harvest(state)
	assert_eq(state.year, 2)
	assert_true(state.undo.is_empty())
	assert_true(state.redo.is_empty())


func test_begin_turn_start_year_and_game_over_clear_both_histories() -> void:
	var state: GameState = TestMaps.small(1, 2)
	for transition: String in ["begin_turn", "start_year", "game_over"]:
		state.undo.push(state.to_dict())
		state.redo.push(state.to_dict())
		match transition:
			"begin_turn":
				GameFlow.begin_turn(state)
			"start_year":
				GameFlow.start_year(state)
			"game_over":
				state.phase = C.Phase.HARVEST
				state.outcome = C.Outcome.WIN
				GameFlow.continue_after_harvest(state)
				assert_eq(state.phase, C.Phase.GAME_OVER)
		assert_true(state.undo.is_empty(), transition)
		assert_true(state.redo.is_empty(), transition)
