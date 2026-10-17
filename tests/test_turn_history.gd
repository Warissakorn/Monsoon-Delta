extends TestCase
## Actual turn results are session data; reading them must never change a run.

const PATH: String = "user://tests/turn_history/checkpoint.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)


func _session(seed_value: int = 1) -> GameSession:
	var session: GameSession = GameSession.new()
	session.save_path = PATH
	assert_eq(session.start({"seed": seed_value}), "")
	assert_eq(session.last_save_error, "")
	return session


func _controlled(session: GameSession, water: float = 0.0) -> void:
	# Retain a real, serializable map, but isolate report values from river flow.
	for tile: Tile in session.state.tiles:
		tile.elevation = 3
		tile.water = water
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	session.state.tiles[0].building = C.Building.HALL
	for index: int in range(1, 4):
		session.state.tiles[index].building = C.Building.HOUSE
	session.state.food = 1000


func _assert_report(actual: Dictionary, expected: TurnReport) -> void:
	assert_eq(actual, {
		"inflow": expected.inflow,
		"destroyed": expected.destroyed,
		"paddies_died": expected.paddies_died,
		"paddy_gains": expected.paddy_gains,
		"fish_food": expected.fish_food,
		"hall_wet": expected.hall_wet,
		"dry_paddy_water_used": expected.dry_paddy_water_used,
	})
	for omitted: String in ["snapshots", "levels_before", "levels_after"]:
		assert_true(not actual.has(omitted), "runtime history omits large water animation data")


func _farmer_commands(session: GameSession) -> void:
	var reference: GameState = session.state.duplicate_state()
	assert_true(BotFarmer.play_turn(reference) >= 0)
	for tile: Tile in reference.tiles:
		if tile.feature == C.Feature.PADDY and session.state.get_tile(tile.coord).feature != C.Feature.PADDY:
			assert_eq(session.apply(Command.new("paddy", tile.coord)), "")
	assert_eq(session.state.to_dict(), reference.to_dict(), "session accepts the real farmer policy")


func test_results_match_real_damage_with_original_types_and_timestamp() -> void:
	var session: GameSession = _session()
	_controlled(session, 0.7)
	session.state.turn = C.TURNS_PER_YEAR
	session.state.tiles[2].building = C.Building.STILT_HOUSE
	session.state.tiles[3].building = C.Building.GRANARY
	session.state.tiles[8].feature = C.Feature.PADDY
	session.state.tiles[9].building = C.Building.FISH_TRAP
	var predicted: TurnReport = GameFlow.preview(session.state)["report"]
	assert_true(session.turn_history().is_empty(), "forecasting cannot record an actual turn")
	var report: TurnReport = session.advance_turn()
	assert_eq(report.to_dict(), predicted.to_dict())
	var history: Array[Dictionary] = session.turn_history()
	assert_eq(history.size(), 1)
	assert_eq(history[0]["year"], 1)
	assert_eq(history[0]["turn"], C.TURNS_PER_YEAR)
	assert_eq(history[0]["season"], C.Season.RAIN)
	_assert_report(history[0]["report"], report)
	assert_eq(report.destroyed.size(), 3)
	assert_eq(report.paddies_died, [session.state.tiles[8].coord])
	assert_eq(typeof(history[0]["report"]["destroyed"][0]["coord"]), TYPE_VECTOR2I)
	assert_eq(typeof(history[0]["report"]["destroyed"][0]["building"]), TYPE_INT)
	assert_eq(typeof(history[0]["report"]["paddies_died"][0]), TYPE_VECTOR2I)
	assert_true(report.hall_wet)
	assert_eq(history[0]["outcome"], C.Outcome.LOSE_HALL)
	assert_eq(history[0]["harvest"], {}, "losing the hall skips annual harvest even on turn six")
	assert_eq(report.fish_food, 0, "hall loss skips production")
	assert_eq(session.state.phase, C.Phase.GAME_OVER)
	assert_eq(session.advance_turn(), null)
	assert_eq(session.turn_history(), history, "terminal no-op cannot duplicate a result")
	SaveIO.delete_save(PATH)


func test_production_records_yield_and_food_separately_and_detaches_every_read() -> void:
	var session: GameSession = _session()
	_controlled(session, 0.3)
	session.state.turn = C.DRY_TURNS + 1
	session.state.tiles[8].feature = C.Feature.PADDY
	session.state.tiles[9].building = C.Building.FISH_TRAP
	var report: TurnReport = session.advance_turn()
	assert_eq(report.paddy_gains, [session.state.tiles[8].coord])
	assert_eq(report.fish_food, 1)
	assert_eq(session.state.food, 1001, "growing paddy yield is not harvested food")
	var original: Array[Dictionary] = session.turn_history()
	_assert_report(original[0]["report"], report)
	assert_eq(original[0]["turn"], C.DRY_TURNS + 1, "record labels the completed turn")
	assert_eq(session.state.turn, C.DRY_TURNS + 2)
	var state_before: Dictionary = session.state.to_dict()
	var saved_before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	# The returned live report and copied nested dictionaries/arrays are each
	# independent from the facts retained by the session.
	report.destroyed[0]["building"] = C.Building.NONE
	report.destroyed.clear()
	report.paddy_gains.clear()
	report.fish_food = 99
	var changed: Array[Dictionary] = session.turn_history()
	changed[0]["report"]["destroyed"][0]["coord"] = Vector2i(99, 99)
	changed[0]["report"]["paddy_gains"].clear()
	changed[0]["report"]["fish_food"] = 200
	changed[0]["year"] = 99
	changed.append({"year": 100})
	assert_eq(session.turn_history(), original, "callers cannot rewrite recorded results")
	assert_eq(session.state.to_dict(), state_before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved_before, "reading history performs no checkpoint")
	SaveIO.delete_save(PATH)


func test_dry_irrigation_water_and_yield_survive_compact_report() -> void:
	var session: GameSession = _session()
	_controlled(session, 1.0)
	session.state.get_tile(Vector2i.ZERO).feature = C.Feature.PADDY
	session.state.get_tile(Vector2i(1, 0)).building = C.Building.RESERVOIR
	# Keep damage thresholds out of this water-accounting fixture.
	session.state.year_mods.assign([
		{"key": "hall_lose_level", "op": "set", "value": 4},
		{"key": "paddy_death_level", "op": "set", "value": 4},
	])
	session.state.recompute_mods()
	var expected: TurnReport = GameFlow.preview(session.state)["report"]
	assert_near(expected.dry_paddy_water_used, 0.25, 1e-9)
	var report: TurnReport = session.advance_turn()
	_assert_report(session.turn_history()[0]["report"], expected)
	assert_eq(report.paddy_gains, [Vector2i.ZERO])
	assert_eq(session.turn_history()[0]["season"], C.Season.DRY)
	SaveIO.delete_save(PATH)


func test_annual_results_capture_final_outcome_and_isolate_harvest() -> void:
	for population_loss: bool in [false, true]:
		var session: GameSession = _session()
		_controlled(session)
		session.state.year = C.YEARS
		session.state.turn = C.TURNS_PER_YEAR
		session.state.food = 0 if population_loss else 1000
		var report: TurnReport = session.advance_turn()
		assert_eq(report.outcome, C.Outcome.NONE, "turn resolution finishes before annual outcome")
		var history: Array[Dictionary] = session.turn_history()
		var result: Dictionary = history[0]
		assert_eq(result["outcome"], C.Outcome.LOSE_POPULATION if population_loss else C.Outcome.WIN)
		assert_eq(result["harvest"], session.state.harvest_report)
		assert_eq(session.state.phase, C.Phase.HARVEST)
		assert_true(not session.state.harvest_report.is_empty())
		var actual_food: int = int(result["harvest"]["food_after"])
		session.state.harvest_report["food_after"] = 777
		assert_eq(session.turn_history()[0]["harvest"]["food_after"], actual_food)
		var changed: Array[Dictionary] = session.turn_history()
		changed[0]["harvest"]["food_after"] = 999
		assert_eq(session.turn_history(), history, "harvest dictionaries are detached on write and read")
		# Restore valid annual state before its ordinary final checkpoint.
		session.state.harvest_report["food_after"] = actual_food
		assert_true(session.continue_year())
		assert_eq(session.state.phase, C.Phase.GAME_OVER)
		assert_eq(session.turn_history(), history, "viewing the final score cannot add a second turn")
		SaveIO.delete_save(PATH)


func test_commands_undo_redo_and_failed_actions_preserve_completed_results() -> void:
	var session: GameSession = _session()
	assert_true(session.turn_history().is_empty())
	assert_true(session.advance_turn() != null)
	var expected: Array[Dictionary] = session.turn_history()
	var targets: Array[Vector2i] = CommandRules.valid_targets(session.state, "fill")
	assert_true(not targets.is_empty())
	assert_eq(session.apply(Command.new("fill", targets[0])), "")
	assert_eq(session.turn_history(), expected)
	assert_true(session.undo())
	assert_eq(session.turn_history(), expected, "replacing GameState during undo preserves session history")
	assert_true(session.redo())
	assert_eq(session.turn_history(), expected)
	assert_eq(session.apply(Command.new("unknown")), "err.unknown")
	assert_true(not session.continue_year())
	assert_eq(session.turn_history(), expected)
	SaveIO.delete_save(PATH)


func test_start_and_load_clear_history_only_when_they_replace_the_run() -> void:
	var session: GameSession = _session()
	assert_true(session.advance_turn() != null)
	var previous: GameState = session.state
	var expected: Array[Dictionary] = session.turn_history()
	assert_eq(session.start({"leader": "unknown"}), "msg.new_game_failed")
	assert_eq(session.turn_history(), expected)
	assert_true(session.state == previous)
	assert_eq(SaveIO.delete_save(PATH), "")
	assert_eq(session.load_game(), "msg.no_save")
	assert_eq(session.turn_history(), expected)
	assert_true(session.state == previous)
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	assert_eq(session.load_game(), "msg.save_corrupt")
	assert_eq(session.turn_history(), expected)
	assert_true(session.state == previous)
	assert_eq(session.checkpoint(), "")
	var state_before: Dictionary = session.state.to_dict()
	assert_eq(session.load_game(), "")
	assert_eq(session.state.to_dict(), state_before)
	assert_true(session.turn_history().is_empty(), "loading starts a new runtime result history")
	assert_true(session.advance_turn() != null)
	assert_eq(session.start({"seed": 42}), "")
	assert_true(session.turn_history().is_empty(), "new game cannot inherit a previous run's results")
	assert_true(session.advance_turn() != null)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	assert_eq(session.start({"seed": 1001}), "", "accepted new game still replaces a run when autosave fails")
	assert_eq(session.last_save_error, "msg.save_failed")
	assert_true(session.turn_history().is_empty())
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	SaveIO.delete_save(PATH)


func test_failed_checkpoint_records_actual_turn_but_null_advance_records_nothing() -> void:
	var empty: GameSession = GameSession.new()
	empty.save_path = PATH
	assert_eq(empty.advance_turn(), null)
	assert_true(empty.turn_history().is_empty())
	assert_eq(empty.last_save_error, "")
	var session: GameSession = _session()
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	var report: TurnReport = session.advance_turn()
	assert_true(report != null)
	assert_eq(session.last_save_error, "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
	var expected: Array[Dictionary] = session.turn_history()
	assert_eq(expected.size(), 1, "a save error cannot hide a resolved turn")
	_assert_report(expected[0]["report"], report)
	session.state.phase = C.Phase.HARVEST
	assert_eq(session.advance_turn(), null)
	assert_eq(session.turn_history(), expected)
	assert_eq(session.last_save_error, "msg.save_failed")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	session.state.phase = C.Phase.PLANNING
	assert_eq(session.checkpoint(), "")
	assert_eq(session.turn_history(), expected, "retrying persistence cannot duplicate the result")
	SaveIO.delete_save(PATH)


func test_farmer_full_run_keeps_all_thirty_results_across_years_and_bounds_history() -> void:
	var session: GameSession = _session(1)
	var completed: int = 0
	var harvests: int = 0
	while session.state.phase != C.Phase.GAME_OVER and completed < C.YEARS * C.TURNS_PER_YEAR:
		_farmer_commands(session)
		var year: int = session.state.year
		var turn: int = session.state.turn
		var season: int = session.state.season()
		var report: TurnReport = session.advance_turn()
		completed += 1
		var history: Array[Dictionary] = session.turn_history()
		assert_eq(history.size(), completed)
		assert_eq(history[-1]["year"], year)
		assert_eq(history[-1]["turn"], turn)
		assert_eq(history[-1]["season"], season)
		_assert_report(history[-1]["report"], report)
		assert_eq(session.last_save_error, "")
		if session.state.phase == C.Phase.HARVEST:
			harvests += 1
			assert_eq(history[-1]["harvest"], session.state.harvest_report)
			assert_true(session.continue_year())
			assert_eq(session.turn_history(), history, "beginning a year preserves completed results")
		else:
			assert_eq(history[-1]["harvest"], {}, "previous annual report must not leak into ordinary turns")
	assert_eq(completed, 30)
	assert_eq(harvests, C.YEARS)
	assert_eq(session.state.outcome, C.Outcome.WIN)
	var complete: Array[Dictionary] = session.turn_history()
	assert_eq(complete.size(), C.YEARS * C.TURNS_PER_YEAR)
	assert_eq(complete[0]["turn"], 1)
	assert_eq(complete[-1]["year"], C.YEARS)
	assert_eq(complete[-1]["outcome"], C.Outcome.WIN)
	assert_eq(session.advance_turn(), null)
	assert_eq(session.turn_history(), complete)
	# Public state is also injected by fixtures/controllers. Defensively bound
	# history even if a caller supplies another live state without start/load.
	session.state = GameFlow.new_game({"seed": 42})
	assert_true(session.advance_turn() != null)
	var bounded: Array[Dictionary] = session.turn_history()
	assert_eq(bounded.size(), C.YEARS * C.TURNS_PER_YEAR)
	assert_eq(bounded[0], complete[1], "the oldest result is evicted first")
	assert_eq(bounded[-1]["turn"], 1)
	SaveIO.delete_save(PATH)


func test_checkpoints_keep_original_schema_and_loading_a_harvest_has_no_fabricated_history() -> void:
	var session: GameSession = _session()
	_controlled(session)
	session.state.turn = C.TURNS_PER_YEAR
	assert_true(session.advance_turn() != null)
	assert_eq(session.turn_history().size(), 1)
	var data: Dictionary = session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var envelope: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	assert_eq(envelope.size(), 4, "history adds no envelope fields")
	assert_eq(envelope["version"], 1.0, "the save format version is unchanged")
	assert_eq(envelope["state"].size(), SaveIO.STATE_FIELDS.size())
	assert_true(not envelope["state"].has("turn_history"))
	assert_true(not envelope["state"].has("_turn_history"))
	var resumed: GameSession = GameSession.new()
	resumed.save_path = PATH
	assert_eq(resumed.load_game(), "")
	assert_eq(resumed.state.to_dict(), data)
	assert_eq(resumed.state.phase, C.Phase.HARVEST)
	assert_true(resumed.turn_history().is_empty(), "saved board cannot reconstruct an actual turn report")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes, "load does not rewrite checkpoint format")
	assert_true(resumed.continue_year())
	assert_true(resumed.turn_history().is_empty(), "loading the annual summary does not fabricate a turn")
	SaveIO.delete_save(PATH)
