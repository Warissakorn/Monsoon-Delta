extends TestCase
## Lessons report committed learning progress without touching a normal run.

const PATH: String = "user://tests/river_school_screen/checkpoint.json"
const SETTINGS: String = "user://tests/river_school_screen/settings.json"


func before_each() -> void:
	Localization.setup("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 174}), PATH), "")


func _screen(id: String = "river_school_01") -> RiverSchoolScreen:
	var run: RiverSchoolRun = RiverSchoolRun.new()
	assert_true(run.start(id))
	# Even an accidentally shared path remains protected by tutorial semantics.
	run.session.save_path = PATH
	var screen: RiverSchoolScreen = RiverSchoolScreen.new()
	screen.lesson = run
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = false
	return screen


func _text(key: String) -> String:
	return String(TranslationServer.translate(key))


func _labels(node: Node) -> String:
	var texts: PackedStringArray = []
	for child: Node in node.get_children():
		if child is Label:
			texts.append(child.text)
		texts.append(_labels(child))
	return "\n".join(texts)


func _key(screen: RiverSchoolScreen, code: int) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.pressed = true
	screen._unhandled_input(key)


func _apply(screen: RiverSchoolScreen, item: Dictionary) -> void:
	var command: Command = Command.new(String(item["id"]), item["coord"], int(item.get("param", -1)))
	assert_eq(screen.session.apply(command), "")
	screen.refresh_state()


func _solve(screen: RiverSchoolScreen, solution_index: int = 0) -> void:
	var solution: Dictionary = RiverSchoolFixtures.solutions(screen.lesson.scenario_id)[solution_index]
	for commands: Array in solution["turns"]:
		for item: Dictionary in commands:
			_apply(screen, item)
		screen._finish_turn()


func test_lesson_header_and_banner_explain_real_objective_and_memory_only_progress() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var screen: RiverSchoolScreen = _screen()
		assert_eq(screen._survival_help.text, _text("school.river_school_01.goal"))
		assert_true(screen._goal_panel.visible)
		assert_eq(int(screen._survival_progress.max_value), C.TURNS_PER_YEAR)
		assert_eq(int(screen._survival_progress.value), 0)
		assert_true(screen._goal_label.text.contains(_text("school.deadline")))
		assert_eq(screen._save_label.text, _text("school.no_checkpoint"))
		assert_true(not screen._save_label.text.contains(_text("msg.saved")))
		assert_true(screen._hint_button.is_visible_in_tree())
		assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
		screen.free()


func test_voluntary_hints_reveal_verified_route_without_changing_state_rng_or_attempt() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var screen: RiverSchoolScreen = _screen()
		var before: Dictionary = screen.session.state.to_dict()
		var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var progress: Dictionary = screen.lesson.progress()
		_key(screen, KEY_F1)
		assert_eq(screen.modal_kind, "school_hint")
		assert_eq(screen.hint_level, 1)
		screen._next_hint()
		screen._next_hint()
		assert_eq(screen.hint_level, 3)
		assert_true(_labels(screen._modal_content).contains(_text("school.river_school_01.hint3")))
		assert_true(_labels(screen._modal_content).contains(_text("school.solution_turn") % 1))
		_key(screen, KEY_SPACE)
		_key(screen, KEY_ENTER)
		assert_eq(screen.session.state.to_dict(), before)
		assert_eq(screen.lesson.progress(), progress)
		assert_eq(screen.lesson.turns_resolved, 0)
		assert_true(not screen.lesson.completed)
		assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
		_key(screen, KEY_ESCAPE)
		assert_eq(screen.modal_kind, "")
		assert_eq(screen.session.state.to_dict(), before)
		screen.free()


func test_completed_lesson_uses_truthful_result_and_cannot_continue_into_normal_year_two() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var screen: RiverSchoolScreen = _screen()
		var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		_solve(screen)
		assert_true(screen.lesson.completed)
		assert_true(screen.lesson.passed, "actual result: " + str(screen.lesson.result()))
		assert_eq(screen.modal_kind, "school_result")
		assert_eq(screen.session.state.phase, C.Phase.HARVEST)
		assert_eq(screen.session.state.outcome, C.Outcome.NONE, "finishing a lesson is not winning the normal five-year run")
		assert_true(screen._end_button.disabled)
		assert_true(screen._modal.find_child("ContinueHarvest", true, false) == null)
		assert_true(screen._modal.find_child("SchoolNext", true, false) != null)
		var actual: Dictionary = screen.session.state.to_dict()
		screen.continue_harvest()
		_key(screen, KEY_SPACE)
		_key(screen, KEY_ESCAPE)
		screen._finish_turn()
		assert_eq(screen.session.state.to_dict(), actual)
		assert_eq(screen.lesson.turns_resolved, C.TURNS_PER_YEAR)
		assert_eq(screen._save_label.text, _text("school.no_checkpoint"))
		screen.open_turn_history()
		assert_eq(screen.modal_kind, "turn_history")
		screen.close_turn_history()
		assert_eq(screen.modal_kind, "school_result")
		assert_eq(screen.session.state.to_dict(), actual)
		assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
		screen.free()


func test_waiting_without_actions_fails_with_the_real_unmet_goal() -> void:
	var screen: RiverSchoolScreen = _screen()
	for _turn: int in range(C.TURNS_PER_YEAR):
		screen._finish_turn()
	assert_true(screen.lesson.completed)
	assert_true(not screen.lesson.passed)
	assert_eq(screen.modal_kind, "school_result")
	assert_true(_labels(screen._modal_content).contains(_text("school.reason.no_rice")))
	assert_true(screen._modal.find_child("SchoolNext", true, false) == null)
	screen.free()


func test_retry_restores_exact_fixture_and_resets_hints_without_reward_or_save_writes() -> void:
	var screen: RiverSchoolScreen = _screen()
	var before: Dictionary = screen.session.state.to_dict()
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen.open_hint()
	screen._next_hint()
	screen._close_school_modal()
	_solve(screen)
	screen.retry_lesson()
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.board.state, screen.session.state)
	assert_eq(screen.lesson.turns_resolved, 0)
	assert_eq(screen.lesson.fish_food, 0)
	assert_true(not screen.lesson.completed)
	assert_true(not screen.lesson.passed)
	assert_eq(screen.hint_level, 0)
	assert_eq(screen.modal_kind, "")
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
	screen.free()


func test_exit_confirmation_cancel_restores_pause_and_only_explicit_leave_emits_navigation() -> void:
	var screen: RiverSchoolScreen = _screen()
	var exits: Array[String] = []
	screen.menu_requested.connect(func(): exits.append("menu"))
	var before: Dictionary = screen.session.state.to_dict()
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen.open_pause()
	screen._return_menu()
	assert_eq(screen.modal_kind, "school_exit")
	assert_true(exits.is_empty())
	_key(screen, KEY_ESCAPE)
	assert_eq(screen.modal_kind, "pause")
	assert_eq(screen.session.state.to_dict(), before)
	screen._return_menu()
	(screen._modal.find_child("SchoolLeave", true, false) as Button).pressed.emit()
	assert_eq(exits, ["menu"])
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
	screen.free()


func test_undo_redo_and_previews_preserve_only_committed_lesson_progress() -> void:
	var screen: RiverSchoolScreen = _screen()
	var before: Dictionary = screen.session.state.to_dict()
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var solution: Dictionary = RiverSchoolFixtures.solutions(screen.lesson.scenario_id)[0]
	var command: Dictionary = solution["turns"][0][0]
	_apply(screen, command)
	var after: Dictionary = screen.session.state.to_dict()
	assert_true(after != before)
	assert_eq(screen.lesson.turns_resolved, 0)
	screen.undo_command()
	assert_eq(screen.session.state.to_dict(), before)
	screen.redo_command()
	assert_eq(screen.session.state.to_dict(), after)
	screen.toggle_preview()
	screen.toggle_preview()
	assert_eq(screen.session.state.to_dict(), after)
	assert_eq(screen.lesson.turns_resolved, 0)
	assert_eq(screen.lesson.fish_food, 0)
	assert_true(not screen.lesson.completed)
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
	screen.free()


func test_cancel_exit_from_hint_restores_hint_and_its_original_pause_without_advancing() -> void:
	var screen: RiverSchoolScreen = _screen()
	var exits: Array[bool] = []
	var before: Dictionary = screen.session.state.to_dict()
	screen.open_pause()
	screen.open_hint()
	assert_eq(screen.modal_kind, "school_hint")
	# This is the same exit path used by the native window close button.
	screen._leave_game(func(): exits.append(true))
	assert_eq(screen.modal_kind, "school_exit")
	_key(screen, KEY_ESCAPE)
	assert_eq(screen.modal_kind, "school_hint")
	_key(screen, KEY_ESCAPE)
	assert_eq(screen.modal_kind, "pause")
	assert_true(exits.is_empty())
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.lesson.turns_resolved, 0)
	screen.free()
