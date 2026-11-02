extends TestCase
## Lesson results use committed receipts, never previews or persistent rewards.

const Run = preload("res://core/river_school_run.gd")
const Fixtures = preload("res://core/river_school_fixtures.gd")
const DIRECTORY: String = "user://tests/river_school_run"
const PATH: String = DIRECTORY + "/normal-checkpoint.json"
const SETTINGS: String = DIRECTORY + "/settings.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func _new(id: String = "river_school_01") -> RiverSchoolRun:
	var run: RiverSchoolRun = Run.new()
	assert_true(run.start(id))
	if run.session != null:
		run.session.save_path = PATH
	return run


func _command(data: Dictionary) -> Command:
	return Command.new(String(data["id"]), data["coord"], int(data.get("param", -1)))


func _replay(run: RiverSchoolRun, solution: Dictionary) -> void:
	for turn: Array in solution["turns"]:
		if run.completed:
			break
		for data: Dictionary in turn:
			assert_eq(run.session.apply(_command(data)), "", "verified solution command")
		var expected: Dictionary = GameFlow.preview(run.session.state)
		var report: TurnReport = run.advance_turn()
		assert_true(report != null)
		if report != null:
			assert_eq(report.to_dict(), (expected["report"] as TurnReport).to_dict())


func _controlled_terminal(hall_loss: bool = false) -> GameState:
	# Explicit unit fixture, independent of the prepared, playable lessons.
	var state: GameState = TestMaps.small(0, 0)
	state.is_tutorial = true
	state.turn = 4 if hall_loss else C.TURNS_PER_YEAR
	state.population = 6
	state.food = 100
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	if hall_loss:
		state.tiles[0].building = C.Building.HALL
		state.tiles[0].water = 0.7
	else:
		state.tiles[0].feature = C.Feature.PADDY
		state.tiles[0].paddy_yield = 1
	return state


func test_start_and_invalid_selection_do_not_lose_the_current_attempt() -> void:
	var run: RiverSchoolRun = Run.new()
	assert_true(not run.start(""))
	assert_eq(run.session, null)
	for id: String in Fixtures.IDS:
		assert_true(run.start(id))
		assert_eq(run.scenario_id, id)
		assert_true(run.session.state.is_tutorial)
		assert_true(not run.completed)
		assert_true(not run.passed)
		assert_true(not run.mastered)
		assert_eq(run.turns_resolved, 0)
		assert_eq(run.fish_food, 0)
		var before: Dictionary = run.session.state.to_dict()
		assert_true(not run.start("river_school_04"), "unimplemented lesson is not silently substituted")
		assert_eq(run.scenario_id, id)
		assert_eq(run.session.state.to_dict(), before)
	assert_true(not FileAccess.file_exists(PATH))


func test_progress_and_repeated_previews_do_not_record_results_or_consume_rng() -> void:
	for id: String in Fixtures.IDS:
		var run: RiverSchoolRun = _new(id)
		var state: GameState = run.session.state
		var before: Dictionary = state.to_dict()
		var result_before: Dictionary = run.result()
		var rng_before: int = state.rng.state
		for _read: int in range(3):
			var values: Dictionary = run.progress()
			assert_eq(values["turns"], 0)
			assert_eq(values["total_turns"], C.TURNS_PER_YEAR)
			assert_eq(values["rice_food"], 0)
			assert_eq(values["fish_food"], 0)
			assert_eq(values["food"], state.food)
			assert_eq(values["capacity"], state.capacity())
			values["food"] = -1
			assert_eq(run.progress()["food"], state.food)
			GameFlow.preview(state)
			assert_eq(run.result(), result_before)
		assert_eq(state.to_dict(), before)
		assert_eq(state.rng.state, rng_before)
		assert_true(run.session.turn_history().is_empty())
		assert_true(not FileAccess.file_exists(PATH))


func test_playable_solutions_complete_at_first_harvest_without_faking_game_win() -> void:
	for id: String in Fixtures.IDS:
		var solutions: Array[Dictionary] = Fixtures.solutions(id)
		assert_true(not solutions.is_empty())
		for solution: Dictionary in solutions:
			var run: RiverSchoolRun = _new(id)
			_replay(run, solution)
			assert_true(run.completed, id + " / " + String(solution["id"]))
			assert_true(run.passed, id + " / " + String(solution["id"]))
			assert_eq(run.turns_resolved, C.TURNS_PER_YEAR)
			assert_eq(run.session.state.phase, C.Phase.HARVEST)
			assert_eq(run.session.state.year, 1)
			assert_eq(run.session.state.outcome, C.Outcome.NONE, "lesson success is not a five-year victory")
			assert_eq(run.result()["harvest"], run.session.state.harvest_report)
			assert_true(run.result()["reasons"].is_empty())


func test_no_action_attempts_fail_for_their_actual_missing_goals() -> void:
	for id: String in Fixtures.IDS:
		var run: RiverSchoolRun = _new(id)
		for _turn: int in range(C.TURNS_PER_YEAR):
			if run.completed:
				break
			assert_true(run.advance_turn() != null)
		assert_true(run.completed)
		assert_true(not run.passed)
		assert_true(not run.mastered)
		var reasons: Array = run.result()["reasons"]
		var expected: String = {"river_school_01": "school.reason.no_rice", "river_school_02": "school.reason.target_houses", "river_school_03": "school.reason.hunger"}[id]
		assert_true(reasons.has(expected))


func test_only_committed_turns_count_fish_and_final_result_is_idempotent() -> void:
	var any_fish: bool = false
	for solution: Dictionary in Fixtures.solutions("river_school_03"):
		var run: RiverSchoolRun = _new("river_school_03")
		var fish: int = 0
		var turns: int = 0
		for actions: Array in solution["turns"]:
			for data: Dictionary in actions:
				assert_eq(run.session.apply(_command(data)), "")
			GameFlow.preview(run.session.state)
			GameFlow.preview(run.session.state)
			assert_eq(run.fish_food, fish)
			assert_eq(run.turns_resolved, turns)
			var report: TurnReport = run.advance_turn()
			assert_true(report != null)
			if report == null:
				break
			fish += report.fish_food
			turns += 1
			assert_eq(run.fish_food, fish)
			assert_eq(run.turns_resolved, turns)
		any_fish = any_fish or fish > 0
		var completed_result: Dictionary = run.result()
		var state_before: Dictionary = run.session.state.to_dict()
		var history_before: Array[Dictionary] = run.session.turn_history()
		for _repeat: int in range(3):
			assert_eq(run.advance_turn(), null)
			assert_eq(run.result(), completed_result)
			assert_eq(run.session.state.to_dict(), state_before)
			assert_eq(run.session.turn_history(), history_before)
	assert_true(any_fish, "at least one verified approach demonstrates committed fish production")


func test_fish_rice_and_mixed_play_keep_optional_mastery_separate_from_passing() -> void:
	var mastered: bool = false
	var ordinary_pass: bool = false
	for solution: Dictionary in Fixtures.solutions("river_school_03"):
		var run: RiverSchoolRun = _new("river_school_03")
		_replay(run, solution)
		var rice: int = int(run.result()["harvest"].get("paddy_food", 0))
		assert_eq(run.mastered, run.passed and rice >= 1 and run.fish_food >= 1)
		mastered = mastered or run.mastered
		ordinary_pass = ordinary_pass or (run.passed and not run.mastered)
	assert_true(mastered, "an optional mixed-food mastery route is reachable")
	assert_true(ordinary_pass, "one-food approaches remain valid ways to pass")


func test_actual_population_loss_overrules_a_non_losing_turn_report() -> void:
	var run: RiverSchoolRun = _new()
	run.session.state = _controlled_terminal()
	var report: TurnReport = run.advance_turn()
	assert_true(report != null)
	if report == null:
		return
	assert_eq(report.outcome, C.Outcome.NONE, "population loss occurs in the later harvest step")
	assert_eq(run.session.state.outcome, C.Outcome.LOSE_POPULATION)
	assert_true(run.completed)
	assert_true(not run.passed, "rice and no hunger cannot override actual population loss from housing")
	assert_true(not run.mastered)
	assert_true(run.result()["reasons"].has("school.reason.population"))


func test_early_hall_loss_ends_the_attempt_without_waiting_for_harvest() -> void:
	for id: String in Fixtures.IDS:
		var run: RiverSchoolRun = _new(id)
		run.session.state = _controlled_terminal(true)
		assert_true(run.advance_turn() != null)
		assert_eq(run.session.state.phase, C.Phase.GAME_OVER)
		assert_eq(run.session.state.outcome, C.Outcome.LOSE_HALL)
		assert_true(run.completed)
		assert_true(not run.passed)
		assert_true(not run.mastered)
		assert_eq(run.result()["reasons"], ["school.reason.hall"])
		assert_true(run.result()["harvest"].is_empty())
		assert_eq(run.turns_resolved, 1)
		assert_eq(run.advance_turn(), null)


func test_retry_restores_exact_fixture_rng_and_clears_receipts_history_and_commands() -> void:
	for id: String in Fixtures.IDS:
		var run: RiverSchoolRun = _new(id)
		var initial: Dictionary = run.session.state.to_dict()
		_replay(run, Fixtures.solutions(id)[0])
		assert_true(run.completed)
		assert_true(run.retry())
		run.session.save_path = PATH
		assert_eq(run.session.state.to_dict(), initial)
		assert_eq(run.scenario_id, id)
		assert_true(not run.completed)
		assert_true(not run.passed)
		assert_true(not run.mastered)
		assert_eq(run.fish_food, 0)
		assert_eq(run.turns_resolved, 0)
		assert_true(run.result()["harvest"].is_empty())
		assert_true(run.result()["reasons"].is_empty())
		assert_true(run.session.turn_history().is_empty())
		assert_true(run.session.state.undo.is_empty())
		assert_true(run.session.state.redo.is_empty())


func test_result_receipts_are_detached_and_do_not_grant_persistent_rewards() -> void:
	var run: RiverSchoolRun = _new()
	_replay(run, Fixtures.solutions("river_school_01")[0])
	var result_before: Dictionary = run.result()
	var state_before: Dictionary = run.session.state.to_dict()
	var received: Dictionary = run.result()
	received["harvest"]["paddy_food"] = 999
	received["reasons"].append("invented")
	received["mastered"] = not run.mastered
	assert_eq(run.result(), result_before)
	assert_eq(run.session.state.to_dict(), state_before)
	assert_true(not FileAccess.file_exists(PATH))


func test_commands_undo_redo_completion_and_loss_preserve_normal_save_and_settings() -> void:
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 723}), PATH), "")
	var settings: FileAccess = FileAccess.open(SETTINGS, FileAccess.WRITE)
	settings.store_string('{"language":"th","reduced_motion":true,"future_note":"keep"}')
	settings.close()
	var checkpoint_before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var settings_before: PackedByteArray = FileAccess.get_file_as_bytes(SETTINGS)
	for id: String in Fixtures.IDS:
		var run: RiverSchoolRun = _new(id)
		var solution: Dictionary = Fixtures.solutions(id)[0]
		for actions: Array in solution["turns"]:
			for data: Dictionary in actions:
				var before: Dictionary = run.session.state.to_dict()
				assert_eq(run.session.apply(_command(data)), "")
				var after: Dictionary = run.session.state.to_dict()
				assert_true(run.session.undo())
				assert_eq(run.session.state.to_dict(), before)
				assert_true(run.session.redo())
				assert_eq(run.session.state.to_dict(), after)
			assert_true(run.advance_turn() != null)
			assert_eq(FileAccess.get_file_as_bytes(PATH), checkpoint_before)
			assert_eq(FileAccess.get_file_as_bytes(SETTINGS), settings_before)
		assert_true(run.completed)
		assert_true(run.retry())
		run.session.save_path = PATH
		run.session.state = _controlled_terminal(true)
		assert_true(run.advance_turn() != null)
		assert_eq(FileAccess.get_file_as_bytes(PATH), checkpoint_before)
		assert_eq(FileAccess.get_file_as_bytes(SETTINGS), settings_before)


func test_non_tutorial_or_nonplanning_states_cannot_escape_the_controller_boundary() -> void:
	var run: RiverSchoolRun = _new()
	run.session.state.is_tutorial = false
	var before: Dictionary = run.session.state.to_dict()
	assert_eq(run.advance_turn(), null)
	assert_eq(run.session.state.to_dict(), before)
	assert_eq(run.turns_resolved, 0)
	assert_true(not FileAccess.file_exists(PATH))
	run.session.state.is_tutorial = true
	run.session.state.phase = C.Phase.HARVEST
	assert_eq(run.advance_turn(), null)
	assert_eq(run.turns_resolved, 0)


func test_share_flow_mastery_is_reachable_by_both_distinct_water_plans() -> void:
	for solution: Dictionary in Fixtures.solutions("river_school_02"):
		var run: RiverSchoolRun = _new("river_school_02")
		_replay(run, solution)
		assert_true(run.passed and run.mastered, solution["id"])
		assert_true(run.result()["target_losses"].is_empty())
		assert_eq(run.progress()["target_houses"], 2)
		assert_eq(run.progress()["target_total"], 2)


func test_share_flow_pending_demolition_follows_undo_redo_and_does_not_penalize_undone_actions() -> void:
	var run: RiverSchoolRun = _new("river_school_02")
	var home: Vector2i = Fixtures.FLOW_HOUSES[0]
	var before: Dictionary = run.session.state.to_dict()
	assert_eq(run.session.apply(Command.new("demolish", home)), "")
	assert_eq(run.progress()["target_houses"], 1)
	assert_eq(run.session.apply(Command.new("house", home)), "")
	assert_eq(run.progress()["target_houses"], 1, "rebuilding before commit must not conceal removal")
	assert_true(run.result()["target_losses"].is_empty(), "pending commands are not committed losses")
	var pending: Array[Vector2i] = run.session.target_removals()
	pending.clear()
	assert_eq(run.session.target_removals(), [home], "metadata receipts are detached")
	for _preview: int in range(3):
		GameFlow.preview(run.session.state)
		assert_eq(run.progress()["target_houses"], 1)
		assert_true(run.result()["target_losses"].is_empty())
	assert_true(run.session.undo())
	assert_eq(run.session.target_removals(), [home])
	assert_true(run.session.undo())
	assert_eq(run.session.state.to_dict(), before)
	assert_eq(run.progress()["target_houses"], 2)
	assert_true(run.session.redo())
	assert_eq(run.session.target_removals(), [home])
	assert_true(run.session.redo())
	assert_eq(run.progress()["target_houses"], 1)
	assert_true(run.session.undo())
	assert_true(run.session.undo())
	# A new plan clears the abandoned Redo branch in model and lesson metadata.
	_replay(run, Fixtures.solutions("river_school_02")[0])
	assert_true(run.passed and run.mastered)
	assert_true(run.result()["target_losses"].is_empty())
	assert_true(not run.session.redo())


func test_share_flow_same_turn_rebuilding_cannot_restore_the_preservation_goal() -> void:
	var run: RiverSchoolRun = _new("river_school_02")
	var home: Vector2i = Fixtures.FLOW_HOUSES[0]
	assert_eq(run.session.apply(Command.new("demolish", home)), "")
	assert_eq(run.session.apply(Command.new("house", home)), "")
	_replay(run, Fixtures.solutions("river_school_02")[0])
	assert_true(run.completed and not run.passed and not run.mastered)
	assert_eq(run.session.state.get_tile(home).building, C.Building.HOUSE)
	assert_eq(run.session.state.stats["houses_lost"], 0, "removal is distinct from flood damage")
	assert_eq(run.result()["target_losses"], [home])
	assert_eq(run.result()["reasons"], ["school.reason.target_houses"])
	var receipt: Dictionary = run.result()
	receipt["target_losses"].clear()
	assert_eq(run.result()["target_losses"], [home])
	assert_true(run.retry())
	assert_true(run.session.target_removals().is_empty())
	assert_true(run.result()["target_losses"].is_empty())
	assert_eq(run.progress()["target_houses"], 2)
	_replay(run, Fixtures.solutions("river_school_02")[0])
	assert_true(run.passed and run.mastered)


func test_share_flow_committed_removal_stays_lost_after_a_later_rebuild() -> void:
	var run: RiverSchoolRun = _new("river_school_02")
	var home: Vector2i = Fixtures.FLOW_HOUSES[1]
	var plan: Dictionary = Fixtures.solutions("river_school_02")[0]
	assert_eq(run.session.apply(Command.new("demolish", home)), "")
	assert_eq(run.session.apply(_command(plan["turns"][0][0])), "")
	assert_true(run.advance_turn() != null)
	assert_eq(run.result()["target_losses"], [home])
	assert_true(run.session.target_removals().is_empty())
	assert_eq(run.session.apply(Command.new("house", home)), "")
	assert_eq(run.progress()["target_houses"], 1)
	_replay(run, {"turns": plan["turns"].slice(1)})
	assert_true(run.completed and not run.passed)
	assert_eq(run.result()["target_losses"], [home])


func test_share_flow_pending_metadata_survives_the_bounded_undo_history() -> void:
	var run: RiverSchoolRun = _new("river_school_02")
	var home: Vector2i = Fixtures.FLOW_HOUSES[0]
	var rng_before: int = run.session.state.rng.state
	assert_eq(run.session.apply(Command.new("demolish", home)), "")
	assert_eq(run.session.apply(Command.new("house", home)), "")
	for _toggle: int in range(UndoStack.MAX_SIZE + 20):
		assert_eq(run.session.apply(Command.new("toggle_gate", Fixtures.CHANNEL)), "")
	assert_eq(run.session.state.undo.size(), UndoStack.MAX_SIZE)
	for _undo: int in range(UndoStack.MAX_SIZE):
		assert_true(run.session.undo())
		assert_eq(run.session.target_removals(), [home])
	assert_true(not run.session.undo())
	assert_eq(run.progress()["target_houses"], 1)
	for _redo: int in range(UndoStack.MAX_SIZE):
		assert_true(run.session.redo())
		assert_eq(run.session.target_removals(), [home])
	assert_true(not run.session.redo())
	var model: Dictionary = run.session.state.to_dict()
	assert_eq(run.session.apply(Command.new("demolish", Fixtures.HALL)), "err.target")
	assert_eq(run.session.state.to_dict(), model)
	assert_eq(run.session.target_removals(), [home])
	assert_eq(run.session.state.rng.state, rng_before)
	_replay(run, Fixtures.solutions("river_school_02")[0])
	assert_true(run.completed and not run.passed)
	assert_eq(run.result()["target_losses"], [home])


func test_share_flow_repeated_gate_toggling_does_not_replace_a_real_water_plan() -> void:
	var run: RiverSchoolRun = _new("river_school_02")
	for _toggle: int in range(20):
		assert_eq(run.session.apply(Command.new("toggle_gate", Fixtures.CHANNEL)), "")
	_replay(run, {"turns": [[], [], [], [], [], []]})
	assert_true(run.completed and not run.passed and not run.mastered)
	assert_eq(run.result()["target_losses"], Fixtures.FLOW_HOUSES)
	assert_eq(run.progress()["target_houses"], 0)
	assert_eq(run.result()["reasons"], ["school.reason.target_houses"])


func test_share_flow_optional_no_crop_loss_is_separate_from_the_required_house_and_rice_goal() -> void:
	var run: RiverSchoolRun = _new("river_school_02")
	var plan: Dictionary = Fixtures.solutions("river_school_02")[0]
	# The river dries after turn one, allowing a legal extra upstream field.
	# It later floods without altering the two homes' prepared water plan.
	plan["turns"][1] = [{"id": "paddy", "coord": Fixtures.FISH}]
	_replay(run, plan)
	assert_true(run.passed)
	assert_true(not run.mastered)
	assert_true(int(run.session.state.stats["paddies_lost"]) > 0)
	assert_true(run.result()["target_losses"].is_empty())
	assert_true(int(run.result()["harvest"]["paddy_food"]) >= 1)
