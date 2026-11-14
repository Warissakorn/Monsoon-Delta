extends TestCase

const PATH: String = "user://test-year-practice-protected.json"
const NORMAL: String = "user://test-year-practice-normal.json"

class YearBoot extends "res://ui/boot.gd":
	func _ready() -> void:
		pass


func before_each() -> void:
	for path: String in [PATH, PATH + ".tmp", NORMAL]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Localization.setup("en")


func _lesson() -> YearPracticeSession:
	var session: YearPracticeSession = YearPracticeSession.new()
	session.begin()
	return session


func _assign(session: YearPracticeSession) -> int:
	var tile: int = session.target()
	assert_eq(session.edit_year("order", "forage", tile, 1, true), "")
	return tile


func _produce(session: YearPracticeSession) -> int:
	var tile: int = _assign(session)
	assert_true(session.undo_year())
	assert_true(session.redo_year())
	for _day: int in range(10):
		if session.step >= 4:
			break
		session.advance_year(1)
	assert_eq(session.step, 4)
	return tile


func test_lesson_uses_valid_real_year_rules_and_reading_targets_does_not_mutate_rng() -> void:
	var session: YearPracticeSession = _lesson()
	assert_true(YearCheckpoint.valid(session.year))
	var before: Dictionary = session.year.duplicate(true)
	for _read: int in range(5):
		assert_true(session.target() >= 0)
		session.guided_job()
		assert_true(not session.completed())
		YearGame.preview(session.year)
	assert_eq(session.year, before)
	assert_eq(session.step, 0)
	assert_eq(session.year, YearGame.new_campaign(42, "none", "food", "farmer", 0, true, true))


func test_planning_steps_require_actual_assign_undo_redo_and_cannot_advance_early() -> void:
	var session: YearPracticeSession = _lesson()
	var before: Dictionary = session.year.duplicate(true)
	assert_eq(session.advance_year(7)["days"], 0)
	assert_eq(session.year, before)
	assert_eq(session.edit_year("order", "bad", 0), "year.error.order")
	assert_eq(session.step, 0)
	var tile: int = _assign(session)
	assert_eq(session.step, 1)
	var planned: Dictionary = session.year.duplicate(true)
	assert_eq(session.advance_year(7)["days"], 0)
	assert_eq(session.year, planned)
	assert_true(session.undo_year())
	assert_eq(session.step, 2)
	assert_eq(session.year, before)
	assert_true(session.redo_year())
	assert_eq(session.step, 3)
	assert_eq(session.year, planned)
	assert_eq(session.forage_tile, tile)


func test_production_requires_the_guided_job_completion_not_a_food_balance_change() -> void:
	var session: YearPracticeSession = _lesson()
	var tile: int = _assign(session)
	session.undo_year()
	session.redo_year()
	session.year["jobs"][0]["paused"] = true
	session.advance_year(1)
	assert_eq(session.step, 3)
	assert_eq(session.edit_year("pause", "", tile), "")
	var before_food: int = int(session.year["stats"]["food"])
	while session.step == 3:
		session.advance_year(1)
	assert_true(int(session.year["stats"]["food"]) > before_food)
	assert_eq(session.step, 4)
	assert_eq(session.edit_year("cancel", "", tile), "yearpractice.keep_work")
	assert_eq(session.step, 4)


func test_real_pause_resume_and_completed_construction_finish_the_lesson() -> void:
	var session: YearPracticeSession = _lesson()
	var tile: int = _produce(session)
	var workers: int = YearGame.workers(session.year)
	assert_eq(session.edit_year("pause", "", tile), "")
	assert_eq(session.step, 5)
	assert_true(YearGame.workers(session.year) < workers)
	assert_eq(session.edit_year("pause", "", tile), "")
	assert_eq(session.step, 6)
	assert_eq(YearGame.workers(session.year), workers)
	var target: int = session.target()
	assert_eq(session.edit_year("order", "build_house", target), "")
	assert_true(not session.completed())
	assert_eq(YearGame.housing(session.year), session.initial_housing)
	while not session.completed() and not session.failed:
		session.advance_year(1)
	assert_true(session.completed())
	assert_true(YearGame.housing(session.year) > session.initial_housing)
	assert_true(YearCheckpoint.valid(session.year))
	var final: Dictionary = session.year.duplicate(true)
	assert_eq(session.advance_year(365)["days"], 0)
	assert_eq(session.year, final)


func test_every_checkpoint_entry_point_keeps_protected_and_future_files_untouched() -> void:
	var protected: String = "{\"format\":\"monsoon_year\",\"version\":999,\"ruleset\":\"future\"}"
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(protected)
	file.close()
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 42}), NORMAL), "")
	var normal: PackedByteArray = FileAccess.get_file_as_bytes(NORMAL)
	var session: YearPracticeSession = _lesson()
	session.save_path = PATH
	assert_eq(session.checkpoint_year(), "")
	assert_eq(session.load_year(), "msg.no_save")
	assert_eq(session._read_year()["error"], "msg.no_save")
	assert_eq(session.start_campaign(73, "rice", "water"), "yearpractice.restart_only")
	assert_eq(session.start_year(), "yearpractice.restart_only")
	assert_eq(session.start({"seed": 73}), "yearpractice.restart_only")
	assert_eq(session.load_game(), "msg.no_save")
	session.state = GameFlow.new_game({"seed": 73})
	assert_eq(session.checkpoint(), "")
	session.save_path = NORMAL
	assert_eq(session.load_game(), "msg.no_save")
	assert_eq(session.checkpoint(), "")
	session.save_path = PATH
	var tile: int = _produce(session)
	session.edit_year("pause", "", tile)
	session.edit_year("pause", "", tile)
	session.begin()
	assert_eq(FileAccess.get_file_as_string(PATH), protected)
	assert_eq(FileAccess.get_file_as_bytes(NORMAL), normal)
	assert_true(not FileAccess.file_exists(PATH + ".tmp"))


func test_failed_attempt_can_restart_without_reusing_progress_or_undo() -> void:
	var session: YearPracticeSession = _lesson()
	_produce(session)
	session.year["population"] = 1
	session.year["resources"]["food"] = 0
	session.year["starvation"] = 2
	session.year["jobs"][0]["paused"] = true
	session.advance_year(1)
	assert_true(session.failed)
	assert_true(not session.completed())
	session.begin()
	assert_eq(session.step, 0)
	assert_true(not session.failed)
	assert_eq(session.forage_tile, -1)
	assert_true(session.undo_plans.is_empty())
	assert_true(session.daily_history.is_empty())
	assert_true(YearCheckpoint.valid(session.year))


func _origin(boot: Node) -> YearScreen:
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.save_path = PATH
	assert_eq(screen.session.start_campaign(73, "forest", "water", "fisher", 5, true, true), "")
	screen.session.advance_year(1)
	var target: int = YearPlanner.target(screen.session.year, "forage")
	assert_eq(screen.session.edit_year("order", "forage", target, 1, true), "")
	boot._replace_screen(screen)
	screen._select_action("dig")
	screen._batches.value = 1
	screen.board.zoom_by(1.2)
	(screen.board as YearBoard3D).rotate_view(1)
	return screen


func test_enter_exit_keeps_the_exact_live_run_plans_history_ui_and_camera() -> void:
	var boot: YearBoot = YearBoot.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(boot)
	var origin: YearScreen = _origin(boot)
	var before: Dictionary = origin.session.year.duplicate(true)
	var undo: Array[Dictionary] = origin.session.undo_plans.duplicate(true)
	var history: Array[Dictionary] = origin.session.daily_history.duplicate(true)
	var draft: Dictionary = origin.ui_draft()
	var camera: Dictionary = origin.board.view_draft()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	boot._start_year_practice()
	assert_true(boot._screen is YearPracticeScreen)
	var practice: YearPracticeScreen = boot._screen as YearPracticeScreen
	assert_true(not practice._save_button.visible)
	assert_true(practice._attempt.year != before)
	_produce(practice._attempt)
	boot._return_year_practice()
	assert_true(boot._screen == origin)
	assert_eq(origin.session.year, before)
	assert_eq(origin.session.undo_plans, undo)
	assert_eq(origin.session.daily_history, history)
	assert_eq(origin.ui_draft(), draft)
	assert_eq(origin.board.view_draft(), camera)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	boot.free()


func test_practice_language_change_keeps_step_and_returns_to_translated_original_run() -> void:
	var preferences: Dictionary = GamePreferences.read()
	var boot: YearBoot = YearBoot.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(boot)
	boot._language = "en"
	var origin: YearScreen = _origin(boot)
	var session: YearSession = origin.session
	var before: Dictionary = session.year.duplicate(true)
	var draft: Dictionary = origin.ui_draft()
	var camera: Dictionary = origin.board.view_draft()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	boot._start_year_practice()
	var attempt: YearPracticeSession = (boot._screen as YearPracticeScreen)._attempt
	_assign(attempt)
	boot._change_year_language()
	assert_true(boot._screen is YearPracticeScreen)
	assert_true((boot._screen as YearPracticeScreen)._attempt == attempt)
	assert_eq(attempt.step, 1)
	boot._return_year_practice()
	var returned: YearScreen = boot._screen as YearScreen
	assert_true(returned.session == session)
	assert_eq(returned.session.year, before)
	assert_eq(returned.ui_draft(), draft)
	assert_eq(returned.board.view_draft(), camera)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_true(returned._help_button.text.contains("วิธีเล่น"))
	boot.free()
	assert_eq(GamePreferences.write(preferences), "")


func test_practice_quit_restores_the_original_unsaved_progress_confirmation() -> void:
	var boot: YearBoot = YearBoot.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(boot)
	var origin: YearScreen = _origin(boot)
	origin.session.last_save_error = "msg.save_failed"
	boot._start_year_practice()
	(boot._screen as YearPracticeScreen).request_quit()
	assert_true(boot._screen == origin)
	assert_true(origin._leave_confirmation.visible)
	assert_eq(origin.session.last_save_error, "msg.save_failed")
	boot.free()


func test_guide_reads_current_rules_and_never_changes_checkpoint_or_undo() -> void:
	for year: Dictionary in [YearGame.new_game(), YearGame.new_campaign(42, "none", "food"), YearGame.new_campaign(42, "none", "food", "farmer", 0, true, true)]:
		var screen: YearScreen = YearScreen.new()
		screen.session = YearSession.new()
		screen.session.save_path = PATH
		screen.session.year = year
		assert_eq(screen.session.checkpoint_year(), "")
		(Engine.get_main_loop() as SceneTree).root.add_child(screen)
		var before: Dictionary = year.duplicate(true)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		screen._open_guide()
		assert_true(screen._guide.visible)
		assert_eq(screen._guide._tabs.get_tab_count(), 5)
		assert_true(screen._guide._facts.text.contains(str(YearGame.food_need(year))))
		assert_eq(screen._guide._extra.text.contains(tr("yearguide.extra_on")), YearClassic.enabled(year))
		assert_eq(screen._guide._extra.text.contains(tr("yearguide.projects_on")), YearGame.expanded(year))
		assert_eq(screen._guide._extra.text.contains(tr("yearguide.heritage_on")), YearHeritage.enabled(year))
		screen._guide._tabs.current_tab = 2
		assert_eq(screen.session.year, before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		assert_true(screen.session.undo_plans.is_empty())
		screen.free()


func test_main_menu_starts_practice_before_any_player_run_and_returns_without_creating_files() -> void:
	var boot: YearBoot = YearBoot.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(boot)
	var menu: MainMenu = MainMenu.new()
	menu.save_path = NORMAL
	menu.year_save_path = PATH
	menu.year_practice_requested.connect(boot._start_year_practice)
	boot._replace_screen(menu)
	var draft: Dictionary = menu.setup_draft()
	var button: Button = menu.find_child("YearPractice", true, false) as Button
	assert_true(button != null)
	button.pressed.emit()
	assert_true(boot._screen is YearPracticeScreen)
	assert_true(not FileAccess.file_exists(PATH))
	assert_true(not FileAccess.file_exists(NORMAL))
	boot._return_year_practice()
	assert_true(boot._screen == menu)
	assert_eq(menu.setup_draft(), draft)
	boot.free()


func test_step_preparation_does_not_place_an_order_and_restart_requires_confirmation() -> void:
	var screen: YearPracticeScreen = YearPracticeScreen.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	var before: Dictionary = screen.session.year.duplicate(true)
	screen._advice_button.pressed.emit()
	assert_eq(screen.action_id(), "forage")
	assert_true(screen._repeat.button_pressed)
	assert_eq(screen.session.year, before)
	assert_true(screen.session.undo_plans.is_empty())
	screen._order()
	assert_eq(screen._attempt.step, 1)
	var planned: Dictionary = screen.session.year.duplicate(true)
	screen._new_button.pressed.emit()
	assert_true(screen._restart_practice_dialog.visible)
	assert_eq(screen.session.year, planned)
	screen._restart_practice_dialog.hide()
	screen._restart_practice_dialog.confirmed.emit()
	assert_eq(screen._attempt.step, 0)
	assert_eq(screen.session.year, before)
	assert_true(screen.session.undo_plans.is_empty())
	screen.free()


func test_language_change_from_practice_never_creates_an_unstarted_player_year() -> void:
	var preferences: Dictionary = GamePreferences.read()
	var boot: YearBoot = YearBoot.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(boot)
	boot._language = "en"
	var origin: YearScreen = YearScreen.new()
	origin.initial_setup = true
	origin.session = YearSession.new()
	origin.session.save_path = PATH
	boot._replace_screen(origin)
	origin._restart.hide()
	origin._seed.text = "draft world 73"
	var draft: Dictionary = origin.ui_draft()
	boot._start_year_practice()
	boot._change_year_language()
	boot._return_year_practice()
	var returned: YearScreen = boot._screen as YearScreen
	assert_true(returned.initial_setup)
	assert_true(returned.session.year.is_empty())
	assert_true(not returned._restart.visible)
	assert_eq(returned.ui_draft(), draft)
	assert_true(not FileAccess.file_exists(PATH))
	boot.free()
	assert_eq(GamePreferences.write(preferences), "")
