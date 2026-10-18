extends TestCase
## Longer runs and village ambitions remain playable through the real controller.

const PATH: String = "user://tests/long_hud/checkpoint.json"


func before_each() -> void:
	Localization.setup("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)


func _state(mode: String = "long", goal: String = "none", population: int = 6, homes: int = 3) -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 1, "run_mode": mode, "village_goal": goal})
	# Retain the complete serializable map while removing weather strategy from
	# controller and annual-accounting assertions. The granary preserves food.
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	state.tiles[0].building = C.Building.HALL
	for index: int in range(1, homes + 1):
		state.tiles[index].building = C.Building.HOUSE
	state.tiles[7].building = C.Building.GRANARY
	state.population = population
	state.food = 1000
	state.wood = 100
	state.stats["max_population"] = maxi(population, int(state.stats["max_population"]))
	GameFlow.begin_turn(state)
	return state


func _screen(state: GameState) -> GameScreen:
	var session: GameSession = GameSession.new()
	session.state = state
	session.save_path = PATH
	assert_eq(session.checkpoint(), "")
	return _screen_for_session(session)


func _screen_for_session(session: GameSession) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = true
	return screen


func _close(screen: GameScreen) -> void:
	screen.free()
	SaveIO.delete_save(PATH)


func _translate(key: String) -> String:
	return String(TranslationServer.translate(key))


func _labels(parent: Node) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for child: Node in parent.get_children():
		if child is Label:
			result.append(child.text)
		result.append_array(_labels(child))
	return result


func _end_turn(screen: GameScreen) -> void:
	screen.request_end_turn()
	if screen.modal_kind == "confirm_labor":
		screen._confirm_end_turn()
	assert_true(screen.modal_kind in ["", "harvest"], "controlled turns cannot require a loss confirmation")
	assert_eq(screen.session.last_save_error, "")


func test_mode_hud_uses_its_own_duration_and_exposes_long_run_tools() -> void:
	for mode: String in ["classic", "long"]:
		var state: GameState = _state(mode)
		state.tiles[20].water = 0.3
		var screen: GameScreen = _screen(state)
		var years: int = 10 if mode == "long" else 5
		assert_eq(screen._time_label.text, _translate("hud.time") % [1, years, _translate("season.dry"), 1, C.TURNS_PER_YEAR])
		assert_eq(screen._run_label.text, _translate("run_mode." + mode + ".name") + "\n" + _translate("difficulty.run") % [0, 1.0])
		assert_eq(screen._status_label.text, _translate("help.survive_years") % years)
		assert_eq(screen._survival_help.text, _translate("help.survive_years") % years)
		assert_true(not screen._goal_label.is_visible_in_tree(), "a run without an ambition has no empty goal panel")
		for command: String in ["waterwheel", "raft_house"]:
			assert_eq(screen._command_buttons[command].visible, mode == "long")
			if mode == "long":
				assert_true(not screen._command_buttons[command].disabled, command + " is usable from the first turn")
				assert_true(not screen.valid_targets(command).is_empty())
		_close(screen)


func test_long_run_harvest_preview_finishes_at_year_ten_and_continues_after_year_five() -> void:
	for year: int in [5, 10]:
		var state: GameState = _state()
		state.year = year
		state.stats["reached_year"] = year
		state.turn = C.TURNS_PER_YEAR
		var screen: GameScreen = _screen(state)
		var expected: int = C.Outcome.WIN if year == 10 else C.Outcome.NONE
		assert_eq(screen._predicted_outcome, expected)
		assert_eq(screen.prediction["state"].outcome, C.Outcome.NONE, "the water preview still stops before harvest")
		assert_true(not screen.harvest_projection.is_empty())
		assert_eq(state.outcome, C.Outcome.NONE, "showing the final-year projection cannot finish the live run")
		_end_turn(screen)
		assert_eq(state.phase, C.Phase.HARVEST)
		assert_eq(state.outcome, expected)
		assert_eq(screen.modal_kind, "harvest")
		screen.continue_harvest()
		if year == 5:
			assert_eq(state.year, 6)
			assert_eq(state.phase, C.Phase.PLANNING)
			assert_eq(screen.modal_kind, "")
			assert_eq(screen._time_label.text, _translate("hud.time") % [6, 10, _translate("season.dry"), 1, C.TURNS_PER_YEAR])
		else:
			assert_eq(state.phase, C.Phase.GAME_OVER)
			assert_eq(screen.modal_kind, "game_over")
			assert_true(not SaveIO.has_save(PATH))
		_close(screen)


func test_goal_progress_is_read_only_and_tracks_command_undo_and_redo() -> void:
	var state: GameState = _state("long", "forest", 8, 4)
	for index: int in range(8, 16):
		state.tiles[index].feature = C.Feature.FOREST
	var screen: GameScreen = _screen(state)
	var expected: Dictionary = state.to_dict()
	var rng_before: int = state.rng.state
	var undo_before: Array[Dictionary] = state.undo.snapshots()
	var redo_before: Array[Dictionary] = state.redo.snapshots()
	var history_before: Array[Dictionary] = screen.session.turn_history()
	var saved_before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var label_before: String = screen._goal_label.text
	assert_true(screen._goal_label.visible)
	assert_true(label_before.contains(_translate("goal.forest.name")))
	assert_true(label_before.contains(_translate("goal.progress_population") % [8, 8]))
	assert_true(label_before.contains(_translate("goal.progress_forests") % [8, 8]))
	assert_true(label_before.contains(_translate("goal.harvest_check")))
	assert_true(label_before.contains(_translate("goal.reward") % 50))
	var progress: Dictionary = RunGoals.progress(state)
	assert_eq(progress["population"], 8)
	assert_eq(progress["forests"], 8)
	assert_eq(progress["required_forests"], 8)
	assert_true(not progress["achieved"], "meeting a target while planning does not award a harvest medal")
	progress["forests"] = 99
	progress["achieved"] = true
	screen.refresh_state()
	screen.toggle_preview()
	screen.toggle_preview()
	screen.refresh_state()
	assert_eq(RunGoals.progress(state)["forests"], 8, "callers receive an independent progress record")
	assert_eq(state.to_dict(), expected)
	assert_eq(state.rng.state, rng_before)
	assert_eq(state.undo.snapshots(), undo_before)
	assert_eq(state.redo.snapshots(), redo_before)
	assert_eq(screen.session.turn_history(), history_before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved_before)
	assert_eq(screen._goal_label.text, label_before)
	screen.select_command("chop")
	screen.apply_at(state.tiles[8].coord)
	assert_eq(RunGoals.progress(screen.session.state)["forests"], 7)
	assert_true(screen._goal_label.text != label_before, "the visible target follows construction immediately")
	assert_true(screen._goal_label.text.contains(_translate("goal.progress_forests") % [7, 8]))
	screen.undo_command()
	assert_true(screen.session.state != state, "undo replaces the model")
	assert_true(screen.board.state == screen.session.state)
	assert_eq(screen.session.state.to_dict(), expected)
	assert_eq(screen._goal_label.text, label_before, "the HUD reads the restored model")
	screen.redo_command()
	assert_eq(RunGoals.progress(screen.session.state)["forests"], 7)
	assert_true(screen._goal_label.text != label_before)
	assert_eq(screen.session.turn_history(), history_before, "planning actions do not add completed turns")
	_close(screen)


func test_each_ambition_awards_only_at_harvest_and_keeps_its_medal_for_the_final_score() -> void:
	for goal: String in ["growth", "forest", "rice"]:
		var population: int = 10 if goal == "growth" else 8
		var homes: int = 6 if goal == "growth" else 4
		var state: GameState = _state("long", goal, population, homes)
		state.year = 2
		state.stats["reached_year"] = 2
		state.turn = C.TURNS_PER_YEAR
		if goal == "forest":
			for index: int in range(8, 16):
				state.tiles[index].feature = C.Feature.FOREST
		elif goal == "rice":
			state.tiles[20].feature = C.Feature.PADDY
			state.tiles[20].paddy_yield = 18
			state.tiles[20].paddy_rain_turns = 2
		var screen: GameScreen = _screen(state)
		var before: Dictionary = state.to_dict()
		var rng_before: int = state.rng.state
		var saved_before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var history_before: Array[Dictionary] = screen.session.turn_history()
		screen.refresh_state()
		screen.toggle_preview()
		screen.toggle_preview()
		assert_eq(state.goal_achieved_year, 0, "harvest projection cannot award the live medal")
		assert_true(not RunGoals.progress(state)["achieved"])
		assert_true(screen._goal_preview_achieved)
		assert_true(screen._harvest_preview_lines().has(_translate("goal.preview_complete") % 50))
		assert_true(screen._preview_label.text.contains(_translate("goal.preview_complete") % 50))
		assert_eq(state.to_dict(), before, "a projected achievement cannot mutate the live run")
		assert_eq(state.rng.state, rng_before)
		assert_eq(screen.session.turn_history(), history_before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), saved_before)
		_end_turn(screen)
		assert_eq(state.goal_achieved_year, 2, goal + " evaluates after food, housing and births")
		assert_true(RunGoals.progress(state)["achieved"])
		assert_eq(RunGoals.progress(state)["score"], 50)
		assert_true(_labels(screen._modal).has(_translate("goal." + goal + ".name")), "harvest names the earned ambition")
		assert_true(_labels(screen._modal).has(_translate("goal.completed") % [2, 50]))
		assert_true(screen._goal_label.text.contains(_translate("goal.completed") % [2, 50]))
		var saved: GameSession = GameSession.new()
		saved.save_path = PATH
		assert_eq(saved.load_game(), "")
		assert_eq(saved.state.goal_achieved_year, 2)
		screen.continue_harvest()
		assert_eq(state.goal_achieved_year, 2, "starting a new year keeps the original medal date")
		# Finish a later year with the earned medal. Resetting paddy yields or
		# removing forests after achievement cannot revoke a completed ambition.
		for tile: Tile in state.tiles:
			if tile.feature == C.Feature.FOREST:
				tile.feature = C.Feature.NONE
		state.year = 10
		state.stats["reached_year"] = 10
		state.turn = C.TURNS_PER_YEAR
		screen.refresh_state()
		assert_true(not screen._goal_preview_achieved, "a previous medal cannot be announced as newly projected")
		_end_turn(screen)
		assert_eq(state.goal_achieved_year, 2)
		assert_true(not _labels(screen._modal).has(_translate("goal.completed") % [2, 50]), "later harvests do not celebrate the same medal again")
		screen.continue_harvest()
		assert_eq(state.phase, C.Phase.GAME_OVER)
		var earned_score: int = state.final_score
		state.goal_achieved_year = 0
		assert_eq(earned_score - Scoring.score(state), 50, "the displayed final score includes the ambition bonus")
		state.goal_achieved_year = 2
		assert_true("\n".join(_labels(screen._modal)).contains(_translate("goal." + goal + ".name")), "the result names the earned ambition")
		assert_true(_labels(screen._modal).has(_translate("goal.completed") % [2, 50]))
		_close(screen)


func test_thai_goal_progress_and_unfinished_result_are_localized_without_a_score_bonus() -> void:
	Localization.setup("th")
	var state: GameState = _state("long", "forest")
	state.year = 10
	state.stats["reached_year"] = 10
	state.turn = C.TURNS_PER_YEAR
	var screen: GameScreen = _screen(state)
	assert_true(screen._goal_label.text.contains(_translate("goal.forest.name")))
	assert_true(screen._goal_label.text.contains(_translate("goal.progress_population") % [6, 8]))
	assert_true(screen._goal_label.text.contains(_translate("goal.progress_forests") % [0, 8]))
	assert_true(not screen._goal_preview_achieved)
	assert_eq(screen._harvest_preview_lines().size(), 7, "an unmet ambition keeps the ordinary harvest forecast")
	_end_turn(screen)
	assert_eq(state.goal_achieved_year, 0)
	assert_eq(state.outcome, C.Outcome.WIN, "an optional ambition never blocks survival victory")
	screen.continue_harvest()
	assert_true(_labels(screen._modal).has(_translate("goal.unfinished")))
	assert_true("\n".join(_labels(screen._modal)).contains(_translate("goal.forest.name")))
	var score_without_medal: int = state.final_score
	state.goal_achieved_year = 10
	assert_eq(Scoring.score(state) - score_without_medal, 50)
	state.goal_achieved_year = 0
	_close(screen)


func test_restart_preserves_run_mode_and_ambition_with_the_next_seed() -> void:
	for mode: String in ["classic", "long"]:
		var state: GameState = _state(mode, "rice")
		state.seed = 99
		state.leader = "fisher"
		state.difficulty = 3
		state.recompute_mods()
		var screen: GameScreen = _screen(state)
		var requests: Array[Dictionary] = []
		screen.restart_requested.connect(func(config: Dictionary): requests.append(config))
		screen._restart()
		assert_eq(requests.size(), 1)
		if not requests.is_empty():
			assert_eq(requests[0]["seed"], 100)
			assert_eq(requests[0]["map_type"], "plains")
			assert_eq(requests[0]["leader"], "fisher")
			assert_eq(requests[0]["difficulty"], 3)
			assert_eq(requests[0]["run_mode"], mode)
			assert_eq(requests[0]["village_goal"], "rice")
		_close(screen)


func test_sixty_turn_controller_run_saves_year_five_and_keeps_all_long_run_results() -> void:
	var screen: GameScreen = _screen(_state())
	var completed: int = 0
	var harvests: int = 0
	var reloaded_year_five: bool = false
	while screen.session.state.phase != C.Phase.GAME_OVER and completed < 60:
		var state: GameState = screen.session.state
		var year: int = state.year
		var turn: int = state.turn
		_end_turn(screen)
		completed += 1
		var history: Array[Dictionary] = screen.session.turn_history()
		assert_eq(history.size(), completed, "the extended session retains more than thirty results")
		assert_eq(history[-1]["year"], year)
		assert_eq(history[-1]["turn"], turn)
		if state.phase != C.Phase.HARVEST:
			continue
		harvests += 1
		assert_eq(screen.modal_kind, "harvest")
		assert_eq(state.outcome, C.Outcome.WIN if year == 10 else C.Outcome.NONE)
		if year == 5:
			var checkpoint: Dictionary = state.to_dict()
			var resumed: GameSession = GameSession.new()
			resumed.save_path = PATH
			assert_eq(resumed.load_game(), "")
			assert_eq(resumed.state.to_dict(), checkpoint)
			assert_eq(resumed.state.target_years(), 10)
			assert_true(resumed.turn_history().is_empty(), "load preserves the existing runtime-only history contract")
			var reopened: GameScreen = _screen_for_session(resumed)
			assert_eq(reopened.modal_kind, "harvest")
			reopened.continue_harvest()
			assert_eq(resumed.state.year, 6)
			assert_eq(resumed.state.phase, C.Phase.PLANNING)
			var next_year: Dictionary = resumed.state.to_dict()
			reopened.free()
			screen.continue_harvest()
			assert_eq(state.to_dict(), next_year, "the reloaded summary continues to the same extended year")
			reloaded_year_five = true
		else:
			screen.continue_harvest()
	assert_true(reloaded_year_five)
	assert_eq(completed, 60)
	assert_eq(harvests, 10)
	assert_eq(screen.session.state.phase, C.Phase.GAME_OVER)
	assert_eq(screen.session.state.outcome, C.Outcome.WIN)
	assert_eq(screen.session.state.year, 10)
	assert_eq(screen.modal_kind, "game_over")
	assert_eq(screen.session.state.final_score, Scoring.score(screen.session.state))
	assert_eq(screen.session.turn_history().size(), 60)
	assert_eq(screen.session.turn_history()[0]["year"], 1)
	assert_eq(screen.session.turn_history()[-1]["outcome"], C.Outcome.WIN)
	assert_true(not SaveIO.has_save(PATH))
	assert_eq(screen.session.advance_turn(), null)
	assert_eq(screen.session.turn_history().size(), 60, "terminal input cannot append another result")
	# Public-state injection is used by controllers and fixtures. A shorter
	# replacement run must discard every result beyond its own duration limit.
	var completed_history: Array[Dictionary] = screen.session.turn_history()
	screen.session.state = _state("classic")
	assert_true(screen.session.advance_turn() != null)
	var bounded: Array[Dictionary] = screen.session.turn_history()
	assert_eq(bounded.size(), 30, "changing to classic immediately restores its history bound")
	assert_eq(bounded[0], completed_history[31], "the oldest results are removed until the new bound is met")
	assert_eq(bounded[-1]["year"], 1)
	assert_eq(bounded[-1]["turn"], 1)
	assert_eq(screen.session.last_save_error, "")
	_close(screen)
