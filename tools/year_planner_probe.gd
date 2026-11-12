extends "res://tools/year_main_probe.gd"
## Native planning workflow plus an isolated prebuilt flood-risk fixture.


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Use a rendering display and an isolated --out-dir=.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Localization.setup(language)
	root.size = Vector2i(1280, 720)
	var session: YearSession = YearSession.new()
	session.save_path = output.path_join("planner-year.json")
	_check(session.start_campaign(42, "none", "water") == "", "isolated campaign starts")
	var screen: YearScreen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	await _capture("planner-start-" + language)
	var before: Dictionary = session.year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(session.save_path)
	await _click(screen._advice_button)
	_check(screen.action_id() == "build_sawmill", "advisor prepares the recommended recipe")
	_check(session.year == before and FileAccess.get_file_as_bytes(session.save_path) == bytes, "advisor does not commit work or rewrite checkpoint")
	await _click(screen._order_button)
	_check(session.year["jobs"].size() == 1, "explicit native order commits work")
	await _key(KEY_F2)
	_check(screen._tabs.current_tab == 4, "F2 opens village planning")
	_check(screen._planning_rows.get_child_count() == 7, "planning shows seven resolved daily projections")
	await _capture("planner-week-" + language)
	await _key(KEY_H)
	_check(screen._tabs.current_tab == 1, "H opens the work queue")
	var tile: int = int(session.year["jobs"][0]["tile"])
	await _click(screen._queue.find_child("PauseTile_" + str(tile), true, false))
	_check(session.year["jobs"][0]["paused"], "native pause returns assigned workers")
	bytes = FileAccess.get_file_as_bytes(session.save_path)
	# Select the filter as form input, then exercise queue actions with mouse events.
	screen._queue_filter.select(3)
	screen._queue_filter.item_selected.emit(3)
	_check(FileAccess.get_file_as_bytes(session.save_path) == bytes, "queue filtering does not write a checkpoint")
	_check(screen._queue_list.find_child("PauseTile_" + str(tile), true, false) != null, "paused filter contains the paused job")
	await _capture("planner-work-" + language)
	await _click(screen._queue.find_child("PauseTile_" + str(tile), true, false))
	_check(not session.year["jobs"][0]["paused"], "native resume restores the job")
	_check(screen._queue_list.find_child("PauseTile_" + str(tile), true, false) == null, "resumed job leaves the paused filter")
	screen.free()

	# Build a new fixture before mounting its UI; no live run state is injected.
	var danger: YearSession = YearSession.new()
	danger.save_path = output.path_join("flood-fixture.json")
	danger.year = YearGame.new_campaign(42, "none", "water")
	for cell: Dictionary in danger.year["board"]["tiles"]:
		cell["water"] = 10.0
	var hall: int = danger.year["structures"].find("hall")
	danger.year["health"][hall] = 10
	_check(danger.checkpoint_year() == "", "flood fixture validates before opening")
	screen = YearScreen.new()
	screen.session = danger
	root.add_child(screen)
	_check(screen._plan["advice"]["kind"] == "hall", "forecast identifies a real next-day hall loss")
	await _key(KEY_F2)
	var location: Button = null
	for row: Node in screen._planning_rows.get_children():
		for child: Node in row.get_children():
			if child is Button:
				location = child
				break
		if location != null:
			break
	_check(location != null, "forecast supplies a clickable damage location")
	if location != null:
		await _click(location)
		_check(screen._tabs.current_tab == 0 and screen.selected == int(screen._plan["days"][0]["damaged"][0]), "risk location returns to the board inspector")
	bytes = FileAccess.get_file_as_bytes(danger.save_path)
	await _click(screen._time_buttons[1])
	_check(screen._advance_confirmation.visible and screen._advance_text.text.contains(TranslationServer.translate("year.outcome.lost_hall")), "loss confirmation precedes idle-worker warning")
	await _capture("planner-risk-" + language)
	await _click(screen._advance_confirmation.get_cancel_button())
	_check(int(danger.year["day"]) == 0 and FileAccess.get_file_as_bytes(danger.save_path) == bytes, "native cancellation preserves day and checkpoint")
	screen.free()
	var passed: bool = checks.all(func(check: Dictionary): return check["passed"])
	var file: FileAccess = FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"language": language, "checks": checks, "passed": passed}, "  "))
	file.close()
	print("YEAR PLANNER NATIVE ", language, ": ", "PASS" if passed else "FAIL", " ", checks.size(), " checks")
	quit(0 if passed else 1)
