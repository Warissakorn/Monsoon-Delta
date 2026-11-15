extends "res://tools/year_polish_probe.gd"
## Complete the lesson through actual input, then verify the paused player's run.

class PracticeBoot extends "res://ui/boot.gd":
	func _ready() -> void:
		pass


func _advance_practice(screen: YearPracticeScreen) -> void:
	await create_timer(0.45).timeout
	await _click(screen._time_buttons[1])
	if screen._advance_confirmation.visible:
		await _click(screen._advance_confirmation.get_ok_button())


func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Localization.setup(language)
	root.size = Vector2i(1600, 900) if "--wide" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	var boot: PracticeBoot = PracticeBoot.new()
	root.add_child(boot)
	boot._language = language
	boot._save_path = output.path_join("normal.json")
	_check(SaveIO.save(GameFlow.new_game({"seed": 42}), boot._save_path) == "", "normal checkpoint fixture exists separately")
	var normal_bytes: PackedByteArray = FileAccess.get_file_as_bytes(boot._save_path)
	var source: YearScreen = YearScreen.new()
	source.session = YearSession.new()
	source.session.save_path = output.path_join("original-year.json")
	_check(source.session.start_campaign(73, "forest", "water", "fisher", 5, true, true) == "", "original player year starts")
	source.session.advance_year(1)
	var target: int = YearPlanner.target(source.session.year, "forage")
	source.session.edit_year("order", "forage", target, 1, true)
	boot._bind_year_screen(source)
	boot._replace_screen(source)
	source._select_action("dig")
	source._seed.text = "keep my setup"
	source.board.zoom_by(1.2)
	(source.board as YearBoard3D).rotate_view(1)
	var original: Dictionary = source.session.year.duplicate(true)
	var undo: Array[Dictionary] = source.session.undo_plans.duplicate(true)
	var history: Array[Dictionary] = source.session.daily_history.duplicate(true)
	var camera: Dictionary = source.board.view_draft()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source.session.save_path)
	await _key(KEY_F1)
	_check(source._guide.visible, "F1 opens the current-year guide")
	var bar: TabBar = source._guide._tabs.get_tab_bar()
	var point: Vector2 = bar.get_global_position() + bar.get_tab_rect(2).get_center() + Vector2(source._guide.position)
	await _click_at(point)
	_check(source._guide._tabs.current_tab == 2, "native guide tabs open the water chapter")
	await _key(KEY_SPACE)
	_check(source.session.year == original and FileAccess.get_file_as_bytes(source.session.save_path) == bytes, "reading the guide and modal input do not resolve or save the run")
	await _capture("year-guide-" + language)
	var draft: Dictionary = source.ui_draft()
	await _click(source._guide._practice)
	_check(boot._screen is YearPracticeScreen and not source.is_inside_tree(), "guide opens a separate practice screen and keeps the original node paused")
	var practice: YearPracticeScreen = boot._screen as YearPracticeScreen
	_check(practice._attempt.step == 0 and practice.session.year["board"]["seed"] == "42" and not practice._save_button.visible, "practice begins at its own fixed world with no save action")
	var before_prepare: Dictionary = practice.session.year.duplicate(true)
	await _click(practice._advice_button)
	_check(practice.action_id() == "forage" and practice._repeat.button_pressed and practice.session.year == before_prepare, "lesson hint prepares repeated food work without placing it")
	await _capture("year-practice-start-" + language)
	await _click(practice._order_button)
	_check(practice._attempt.step == 1 and practice.session.year["jobs"].size() == 1, "real food assignment advances the first goal")
	_check(practice._time_buttons[0].disabled, "planning lessons keep the undo opportunity before time advances")
	await _click(practice._undo)
	_check(practice._attempt.step == 2 and practice.session.year["jobs"].is_empty(), "native Undo removes the actual order")
	await _click(practice._redo)
	_check(practice._attempt.step == 3 and practice.session.year["jobs"].size() == 1, "native Redo restores the same job")
	for _attempt: int in range(6):
		if practice._attempt.step >= 4:
			break
		await _advance_practice(practice)
	_check(practice._attempt.step == 4 and int(practice.session.year["stats"]["food"]) > 0, "real daily completion passes production despite daily meal costs")
	await _click(practice._advice_button)
	var tile: int = practice._attempt.forage_tile
	await _click(practice._queue.find_child("PauseTile_" + str(tile), true, false))
	_check(practice._attempt.step == 5 and practice._attempt.guided_job()["paused"], "native pause returns the lesson worker")
	await _click(practice._advice_button)
	await _click(practice._queue.find_child("PauseTile_" + str(tile), true, false))
	_check(practice._attempt.step == 6 and not practice._attempt.guided_job()["paused"], "native resume returns the worker to production")
	await _click(practice._advice_button)
	_check(practice.action_id() == "build_house", "final lesson prepares a valid home construction form")
	await _click(practice._order_button)
	_check(not practice._attempt.completed() and YearGame.housing(practice.session.year) == practice._attempt.initial_housing, "reserving construction materials does not invent housing")
	for _attempt: int in range(12):
		if practice._attempt.completed() or practice._attempt.failed:
			break
		await _advance_practice(practice)
	_check(practice._attempt.completed() and YearGame.housing(practice.session.year) > practice._attempt.initial_housing and YearCheckpoint.valid(practice.session.year), "actual construction completion finishes all seven lesson goals")
	await _capture("year-practice-complete-" + language)
	await _click(practice._advice_button)
	_check(boot._screen == source and source.session.year == original, "completion returns to the exact original player run")
	_check(source.session.undo_plans == undo and source.session.daily_history == history and source.ui_draft() == draft and source.board.view_draft() == camera, "return preserves planning, history, setup draft, current tool and camera")
	_check(FileAccess.get_file_as_bytes(source.session.save_path) == bytes and FileAccess.get_file_as_bytes(boot._save_path) == normal_bytes, "the complete practice attempt leaves both player checkpoint files byte-identical")
	await _click(source._back_button)
	_check(boot._screen is MainMenu, "player can return to the main menu normally")
	var menu: MainMenu = boot._screen as MainMenu
	await _click(menu.find_child("YearPractice", true, false))
	_check(boot._screen is YearPracticeScreen and (boot._screen as YearPracticeScreen)._attempt.step == 0, "main menu can start a new practice attempt independently")
	practice = boot._screen as YearPracticeScreen
	await _key(KEY_F1)
	_check(practice._guide.visible and not practice._guide._practice.visible, "practice help cannot nest another practice attempt")
	await _click(practice._guide.get_ok_button())
	await _click(practice._new_button)
	_check(practice._restart_practice_dialog.visible, "practice restart has its own confirmation")
	await _click(practice._restart_practice_dialog.get_cancel_button())
	await _click(practice._back_button)
	_check(boot._screen == menu, "leaving practice returns to the same menu without starting a player year")
	await process_frame
	await process_frame
	boot.free()
	var passed: bool = checks.all(func(check: Dictionary): return check["passed"])
	var file: FileAccess = FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"language": language, "resolution": [root.size.x, root.size.y], "checks": checks, "passed": passed}, "  "))
	file.close()
	print("YEAR PRACTICE NATIVE ", language, " ", root.size, ": ", "PASS" if passed else "FAIL", " ", checks.size(), " checks")
	quit(0 if passed else 1)
