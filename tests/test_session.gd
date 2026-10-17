extends TestCase

const DIRECTORY: String = "user://tests/session"
const PATH: String = DIRECTORY + "/checkpoint.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for path: String in [PATH, PATH + ".tmp", DIRECTORY + "/directory"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _session(seed_value: int = 42) -> GameSession:
	var session: GameSession = GameSession.new()
	session.save_path = PATH
	assert_eq(session.start({"seed": seed_value}), "")
	assert_eq(session.last_save_error, "")
	return session


func _loaded() -> GameState:
	var result: Dictionary = SaveIO.load_game(PATH)
	assert_eq(result["error"], "")
	assert_true(result["state"] is GameState)
	return result["state"]


func _command(state: GameState, id: String = "fill") -> Command:
	var targets: Array[Vector2i] = CommandRules.valid_targets(state, id)
	assert_true(not targets.is_empty(), "fixture has a legal " + id + " target")
	return Command.new(id, targets[0]) if not targets.is_empty() else null


func _block_write() -> void:
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)


func _allow_write() -> void:
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)


func _stable(session: GameSession) -> void:
	# Keep the full, serializable generated map while isolating session flow
	# from flood/food strategy. A flat source-free board stays dry through year 5.
	for tile: Tile in session.state.tiles:
		tile.elevation = 4
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	session.state.tiles[0].building = C.Building.HALL
	for index: int in range(1, 4):
		session.state.tiles[index].building = C.Building.HOUSE
	session.state.food = 1000
	assert_eq(session.checkpoint(), "")


func test_start_replaces_checkpoint_even_at_same_phase_and_turn() -> void:
	var session: GameSession = _session(42)
	var previous: GameState = session.state
	assert_eq(session.start({"seed": 1001, "leader": "carpenter"}), "")
	assert_true(session.state != previous)
	assert_eq(session.state.year, 1)
	assert_eq(session.state.turn, 1)
	assert_eq(session.state.phase, C.Phase.PLANNING)
	assert_eq(session.state.seed, 1001)
	assert_eq(_loaded().to_dict(), session.state.to_dict())
	var checkpoint: String = FileAccess.get_file_as_string(PATH)
	previous = session.state
	assert_eq(session.start({"leader": "unknown"}), "msg.new_game_failed")
	assert_true(session.state == previous)
	assert_eq(FileAccess.get_file_as_string(PATH), checkpoint)
	SaveIO.delete_save(PATH)


func test_commands_and_whole_state_undo_redo_checkpoint_exact_current_board() -> void:
	var session: GameSession = _session()
	var initial: Dictionary = session.state.to_dict()
	assert_eq(session.apply(_command(session.state)), "")
	var after_first: Dictionary = session.state.to_dict()
	assert_eq(session.apply(_command(session.state)), "")
	var after_second: Dictionary = session.state.to_dict()
	assert_eq(session.state.undo.size(), 2, "autosave keeps live command history")
	assert_eq(_loaded().to_dict(), session.state.to_dict())
	var previous: GameState = session.state
	assert_true(session.undo())
	assert_true(session.state != previous, "undo replaces the model for board rebinding")
	assert_eq(session.state.to_dict(), after_first)
	assert_eq(session.state.undo.size(), 1)
	assert_eq(session.state.redo.size(), 1)
	assert_eq(_loaded().to_dict(), after_first)
	assert_true(session.undo())
	assert_eq(session.state.to_dict(), initial)
	assert_eq(_loaded().to_dict(), initial)
	assert_true(not session.undo())
	previous = session.state
	assert_true(session.redo())
	assert_true(session.state != previous, "redo replaces the model for board rebinding")
	assert_eq(session.state.to_dict(), after_first)
	assert_eq(session.state.undo.size(), 1)
	assert_eq(session.state.redo.size(), 1)
	assert_eq(_loaded().to_dict(), after_first)
	assert_true(session.redo())
	assert_eq(session.state.to_dict(), after_second)
	assert_eq(_loaded().to_dict(), after_second)
	assert_true(not session.redo())
	assert_true(session.undo())
	assert_true(session.undo())
	assert_eq(session.apply(_command(session.state)), "")
	assert_true(session.state.redo.is_empty(), "a new command invalidates the redone future")
	var expected: Dictionary = session.state.to_dict()
	var resumed: GameSession = GameSession.new()
	resumed.save_path = PATH
	assert_eq(resumed.load_game(), "")
	assert_eq(resumed.state.to_dict(), expected)
	assert_true(resumed.state.undo.is_empty(), "new session cannot undo past checkpoints")
	assert_true(resumed.state.redo.is_empty(), "new session cannot redo past checkpoints")
	assert_eq(session.state.undo.size(), 1)
	assert_eq(session.advance_turn().to_dict(), resumed.advance_turn().to_dict())
	assert_eq(session.state.to_dict(), resumed.state.to_dict(), "water and RNG continue exactly")
	SaveIO.delete_save(PATH)


func test_invalid_commands_and_no_op_flow_do_not_attempt_checkpoint() -> void:
	var session: GameSession = _session()
	var expected: Dictionary = session.state.to_dict()
	var previous: String = FileAccess.get_file_as_string(PATH)
	_block_write()
	assert_eq(session.apply(Command.new("unknown")), "err.unknown")
	assert_eq(session.apply(Command.new("fill", Vector2i(100, 100))), "err.no_tile")
	assert_eq(session.apply(null), "err.unknown")
	assert_true(not session.undo())
	assert_true(not session.redo())
	assert_true(not session.continue_year())
	assert_eq(session.state.to_dict(), expected)
	assert_eq(session.last_save_error, "", "a blocked checkpoint would expose an unintended write")
	assert_eq(FileAccess.get_file_as_string(PATH), previous)
	session.state.phase = C.Phase.HARVEST
	assert_eq(session.apply(Command.new("fill")), "err.phase")
	assert_eq(session.advance_turn(), null)
	assert_true(not session.undo())
	assert_true(not session.redo())
	assert_eq(session.last_save_error, "")
	assert_eq(FileAccess.get_file_as_string(PATH), previous)
	_allow_write()
	SaveIO.delete_save(PATH)


func test_failed_autosave_keeps_previous_file_and_live_play_can_retry() -> void:
	var session: GameSession = _session()
	var previous: String = FileAccess.get_file_as_string(PATH)
	_block_write()
	var command: Command = _command(session.state)
	assert_eq(session.apply(command), "", "storage error cannot undo an accepted player action")
	assert_eq(session.last_save_error, "msg.save_failed")
	assert_eq(session.state.undo.size(), 1)
	assert_eq(FileAccess.get_file_as_string(PATH), previous)
	var accepted: Dictionary = session.state.to_dict()
	assert_eq(session.apply(Command.new("unknown")), "err.unknown")
	assert_eq(session.last_save_error, "msg.save_failed", "invalid action cannot hide the save banner")
	assert_eq(session.state.to_dict(), accepted)
	_allow_write()
	assert_eq(session.checkpoint(), "")
	assert_eq(session.last_save_error, "")
	assert_eq(_loaded().to_dict(), accepted)
	assert_true(session.undo(), "save retry also preserves the live undo stack")
	assert_eq(_loaded().to_dict(), session.state.to_dict())
	SaveIO.delete_save(PATH)


func test_redo_failed_autosave_preserves_checkpoint_and_live_history_for_retry() -> void:
	var session: GameSession = _session()
	assert_eq(session.apply(_command(session.state)), "")
	var accepted: Dictionary = session.state.to_dict()
	assert_true(session.undo())
	var previous: String = FileAccess.get_file_as_string(PATH)
	_block_write()
	assert_true(session.redo(), "storage error cannot reject a valid redo")
	assert_eq(session.state.to_dict(), accepted)
	assert_eq(session.last_save_error, "msg.save_failed")
	assert_eq(session.state.undo.size(), 1)
	assert_true(session.state.redo.is_empty())
	assert_eq(FileAccess.get_file_as_string(PATH), previous)
	assert_true(not session.redo())
	assert_eq(session.last_save_error, "msg.save_failed", "a no-op cannot hide the save error")
	_allow_write()
	assert_eq(session.checkpoint(), "")
	assert_eq(session.last_save_error, "")
	assert_eq(_loaded().to_dict(), accepted)
	assert_true(session.undo(), "redo/save retry preserves undo")
	assert_eq(_loaded().to_dict(), session.state.to_dict())
	SaveIO.delete_save(PATH)


func test_redo_outside_planning_preserves_history_without_checkpoint() -> void:
	var session: GameSession = _session()
	assert_eq(session.apply(_command(session.state)), "")
	assert_true(session.undo())
	var previous: String = FileAccess.get_file_as_string(PATH)
	var redo_history: Array[Dictionary] = session.state.redo.snapshots()
	_block_write()
	for phase: int in [C.Phase.HARVEST, C.Phase.GAME_OVER]:
		session.state.phase = phase
		var expected: Dictionary = session.state.to_dict()
		assert_true(not session.redo())
		assert_eq(session.state.to_dict(), expected)
		assert_eq(session.state.redo.snapshots(), redo_history)
		assert_eq(session.last_save_error, "", "phase rejection cannot checkpoint")
		assert_eq(FileAccess.get_file_as_string(PATH), previous)
	_allow_write()
	SaveIO.delete_save(PATH)


func test_start_is_playable_after_checkpoint_failure_and_can_save_later() -> void:
	var session: GameSession = _session()
	var previous: String = FileAccess.get_file_as_string(PATH)
	_block_write()
	assert_eq(session.start({"seed": 1001}), "")
	assert_eq(session.state.seed, 1001)
	assert_eq(session.last_save_error, "msg.save_failed")
	assert_eq(FileAccess.get_file_as_string(PATH), previous)
	assert_eq(session.apply(_command(session.state)), "")
	assert_eq(session.last_save_error, "msg.save_failed")
	_allow_write()
	assert_eq(session.checkpoint(), "")
	assert_eq(_loaded().to_dict(), session.state.to_dict())
	SaveIO.delete_save(PATH)


func test_load_errors_preserve_live_run_and_success_replaces_it() -> void:
	var session: GameSession = _session()
	var previous: GameState = session.state
	var expected: Dictionary = previous.to_dict()
	SaveIO.delete_save(PATH)
	assert_eq(session.load_game(), "msg.no_save")
	assert_true(session.state == previous)
	assert_eq(session.state.to_dict(), expected)
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	assert_eq(session.load_game(), "msg.save_corrupt")
	assert_eq(session.last_save_error, "msg.save_corrupt")
	assert_true(session.state == previous)
	assert_true(not SaveIO.has_save(PATH))
	var directory: String = DIRECTORY + "/directory"
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(directory)), OK)
	session.save_path = directory
	assert_eq(session.load_game(), "msg.save_failed")
	assert_true(session.state == previous)
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)))
	session.save_path = PATH
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 77}), PATH), "")
	assert_eq(session.load_game(), "")
	assert_true(session.state != previous)
	assert_eq(session.state.seed, 77)
	assert_eq(session.last_save_error, "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	SaveIO.delete_save(PATH)


func test_turn_and_year_checkpoints_resume_harvest_without_applying_it_twice() -> void:
	var session: GameSession = _session()
	_stable(session)
	for turn_number: int in range(1, 7):
		assert_eq(session.state.turn, turn_number)
		assert_true(session.advance_turn() != null)
		assert_eq(session.last_save_error, "")
		assert_eq(_loaded().to_dict(), session.state.to_dict())
	assert_eq(session.state.phase, C.Phase.HARVEST)
	var expected: Dictionary = session.state.to_dict()
	var summary: Dictionary = session.state.harvest_report.duplicate(true)
	var resumed: GameSession = GameSession.new()
	resumed.save_path = PATH
	assert_eq(resumed.load_game(), "")
	assert_eq(resumed.state.to_dict(), expected)
	assert_eq(resumed.advance_turn(), null)
	assert_eq(resumed.state.to_dict(), expected, "harvest is displayed once and does not rerun")
	assert_true(resumed.continue_year())
	assert_eq(resumed.state.year, 2)
	assert_eq(resumed.state.turn, 1)
	assert_eq(resumed.state.phase, C.Phase.PLANNING)
	assert_eq(resumed.state.harvest_report, summary)
	assert_eq(_loaded().to_dict(), resumed.state.to_dict())
	assert_true(not resumed.continue_year())
	SaveIO.delete_save(PATH)


func test_terminal_harvest_survives_reload_then_continue_removes_checkpoint() -> void:
	for starving: bool in [false, true]:
		var session: GameSession = _session()
		_stable(session)
		session.state.year = 2 if starving else C.YEARS
		session.state.stats["reached_year"] = session.state.year
		session.state.turn = C.TURNS_PER_YEAR
		session.state.food = 0 if starving else 1000
		assert_true(session.advance_turn() != null)
		assert_eq(session.state.phase, C.Phase.HARVEST)
		assert_eq(session.state.outcome, C.Outcome.LOSE_POPULATION if starving else C.Outcome.WIN)
		assert_eq(session.last_save_error, "")
		var expected: Dictionary = session.state.to_dict()
		var resumed: GameSession = GameSession.new()
		resumed.save_path = PATH
		assert_eq(resumed.load_game(), "")
		assert_eq(resumed.state.to_dict(), expected)
		assert_true(resumed.continue_year())
		assert_eq(resumed.state.phase, C.Phase.GAME_OVER)
		assert_eq(resumed.state.final_score, Scoring.score(resumed.state))
		assert_eq(resumed.last_save_error, "")
		assert_true(not SaveIO.has_save(PATH))
		assert_true(not resumed.continue_year())


func test_immediate_hall_loss_deletes_checkpoint_without_harvest() -> void:
	var session: GameSession = _session()
	_stable(session)
	var hall: Tile = session.state.tiles[0]
	hall.elevation = 0
	hall.water = 1.0
	session.state.turn = 4
	var report: TurnReport = session.advance_turn()
	assert_true(report != null)
	assert_eq(report.outcome, C.Outcome.LOSE_HALL)
	assert_eq(session.state.phase, C.Phase.GAME_OVER)
	assert_eq(session.last_save_error, "")
	assert_true(not SaveIO.has_save(PATH))


func test_empty_session_cannot_write_or_run_actions() -> void:
	var session: GameSession = GameSession.new()
	session.save_path = PATH
	assert_eq(session.apply(Command.new("fill")), "err.phase")
	assert_true(not session.undo())
	assert_true(not session.redo())
	assert_eq(session.advance_turn(), null)
	assert_true(not session.continue_year())
	assert_eq(session.checkpoint(), "msg.save_failed")
	assert_eq(session.last_save_error, "msg.save_failed")
	assert_true(not SaveIO.has_save(PATH))
	assert_eq(session.load_game(), "msg.no_save")
	assert_eq(session.state, null)


func test_tutorial_session_cannot_replace_the_normal_checkpoint() -> void:
	var session: GameSession = _session()
	var previous: String = FileAccess.get_file_as_string(PATH)
	assert_eq(session.start({"seed": 99, "is_tutorial": true}), "")
	assert_eq(session.apply(_command(session.state)), "")
	assert_true(session.undo())
	assert_true(session.advance_turn() != null)
	assert_eq(session.last_save_error, "")
	assert_eq(FileAccess.get_file_as_string(PATH), previous)
	session.state.phase = C.Phase.GAME_OVER
	assert_eq(session.checkpoint(), "")
	assert_eq(FileAccess.get_file_as_string(PATH), previous)
	SaveIO.delete_save(PATH)
