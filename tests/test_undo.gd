extends TestCase


func test_three_commands_undo_to_original_with_remaining_history() -> void:
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
	assert_eq(state.to_dict(), original)
	assert_eq(GameFlow.undo(state), state, "empty history returns the current state")


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


func test_loading_and_duplication_do_not_copy_undo_history() -> void:
	var state: GameState = TestMaps.small(1, 2)
	assert_eq(GameFlow.apply_command(state, Command.new("dig", Vector2i.ZERO)), "")
	var saved: Dictionary = state.to_dict()
	assert_true(not saved.has("undo"))
	assert_true(GameState.from_dict(saved).undo.is_empty())
	assert_true(state.duplicate_state().undo.is_empty())
	assert_eq(state.undo.size(), 1, "copying and loading cannot drain the source history")


func test_end_turn_and_new_year_clear_command_history() -> void:
	var state: GameState = TestMaps.small(1, 2)
	assert_eq(GameFlow.apply_command(state, Command.new("dig", Vector2i.ZERO)), "")
	GameFlow.end_turn(state)
	assert_true(state.undo.is_empty())
	var after: Dictionary = state.to_dict()
	state = GameFlow.undo(state)
	assert_eq(state.to_dict(), after, "previous-turn commands cannot be undone")
	state.phase = C.Phase.HARVEST
	state.turn = 6
	state.undo.push(state.to_dict())
	GameFlow.continue_after_harvest(state)
	assert_eq(state.year, 2)
	assert_true(state.undo.is_empty())
