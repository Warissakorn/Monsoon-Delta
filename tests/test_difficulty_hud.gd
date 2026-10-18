extends TestCase
## Continued runs display their own rules; inspecting them never rewrites a save.

const PATH: String = "user://tests/difficulty_hud/checkpoint.json"
const SETTINGS_PATH: String = "user://tests/difficulty_hud/settings.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _labels(parent: Node) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for child: Node in parent.get_children():
		if child is Label:
			result.append(child.text)
		result.append_array(_labels(child))
	return result


func _screen(session: GameSession) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	screen.preferences_path = SETTINGS_PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	return screen


func test_continue_displays_saved_difficulty_without_changing_checkpoint_or_rng() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		for mode: String in ["classic", "long"]:
			var original: GameSession = GameSession.new()
			original.save_path = PATH
			assert_eq(original.start({"seed": 42, "difficulty": 10, "run_mode": mode}), "")
			var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
			var session: GameSession = GameSession.new()
			session.save_path = PATH
			assert_eq(session.load_game(), "")
			var expected: Dictionary = session.state.to_dict()
			var screen: GameScreen = _screen(session)
			var caption: String = String(TranslationServer.translate("difficulty.run")) % [10, 2.0]
			assert_true(screen._run_label.text.contains(caption))
			screen.open_pause()
			assert_true(_labels(screen._modal).has(caption))
			screen.close_modal()
			screen.toggle_preview()
			screen.refresh_state()
			assert_eq(session.state.to_dict(), expected, "HUD, Pause and previews preserve exact saved state/RNG")
			assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
			screen.free()
			SaveIO.delete_save(PATH)


func test_result_and_replay_keep_the_selected_difficulty_and_score_multiplier() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var session: GameSession = GameSession.new()
		session.save_path = PATH
		assert_eq(session.start({"seed": 42, "difficulty": 7, "run_mode": "long", "village_goal": "forest"}), "")
		# Controlled result fixture: verify presentation/replay, not win feasibility.
		session.state.outcome = C.Outcome.WIN
		session.state.phase = C.Phase.GAME_OVER
		session.state.final_score = Scoring.score(session.state)
		var expected: Dictionary = session.state.to_dict()
		var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var screen: GameScreen = _screen(session)
		assert_eq(screen.modal_kind, "game_over")
		var caption: String = String(TranslationServer.translate("difficulty.run")) % [7, 1.7]
		assert_true(_labels(screen._modal).has(caption))
		var requests: Array[Dictionary] = []
		screen.restart_requested.connect(func(config: Dictionary): requests.append(config))
		screen._restart()
		assert_eq(requests.size(), 1)
		if not requests.is_empty():
			assert_eq(requests[0]["difficulty"], 7)
			var replay: GameState = GameFlow.new_game(requests[0])
			assert_eq(replay.seed, 43)
			assert_eq(replay.difficulty, 7)
			assert_eq(replay.run_mode, "long")
			assert_eq(replay.village_goal, "forest")
			assert_eq(replay.population, 4)
			assert_eq(replay.food, 4)
		assert_eq(session.state.to_dict(), expected)
		assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
		screen.free()
		SaveIO.delete_save(PATH)
