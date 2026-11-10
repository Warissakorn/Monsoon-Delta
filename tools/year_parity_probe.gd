extends "res://tools/year_main_probe.gd"
## Native mouse/physical keyboard checks on isolated authored fixtures.


func _key(code: Key) -> void:
	var focused: Control = root.gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _land(s: Dictionary) -> int:
	var best: int = -1
	for index: int in range(s["structures"].size()):
		if YearGame.target_matches(s, "build_house", index) and (best < 0 or YearExpansion.distance_to_work(s, index) < YearExpansion.distance_to_work(s, best)):
			best = index
	return best


func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Localization.setup(language)
	root.size = Vector2i(1280, 720)
	var session: YearSession = YearSession.new()
	session.save_path = output.path_join("year-profile.json")
	_check(session.start_campaign(73, "rice", "craft", "fisher", 5, true) == "", "new profile uses extra daily systems")
	var screen: YearScreen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	await _capture("year-extra-start-" + language)
	var before: Dictionary = session.year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(session.save_path)
	await _click(screen._new_button)
	_check(screen._restart.visible and screen._seed.text == "73" and int(screen._difficulty.value) == 5 and screen._classic.button_pressed, "new-year form keeps the loaded campaign profile")
	await _click(screen._classic)
	await _click(screen._classic)
	await _capture("year-extra-setup-" + language)
	await _click(screen._restart.get_cancel_button())
	_check(session.year == before and FileAccess.get_file_as_bytes(session.save_path) == bytes, "cancelling restart preserves state and checkpoint")
	await _key(KEY_6)
	_check(screen.action_id() == "build_raft", "physical 6 selects raft construction")
	await _key(KEY_R)
	_check(screen.action_id() == "brace_house", "physical R selects bracing")
	await _key(KEY_TAB)
	_check(not screen._preview.button_pressed, "physical Tab toggles prediction")
	await _key(KEY_TAB)
	var camera: Dictionary = screen.board.view_draft()
	await _key(KEY_D)
	_check(screen.board.view_draft() != camera, "physical D pans the camera")
	screen.board.fit_map()
	await _click(screen._advice_button)
	await _click(screen._try_button)
	_check(screen._order_confirmation.visible, "native try-order opens the seven-day comparison")
	_check(session.year == before and FileAccess.get_file_as_bytes(session.save_path) == bytes and session.undo_plans.is_empty(), "comparison does not commit or write")
	await _capture("year-extra-try-" + language)
	await _click(screen._order_confirmation.get_cancel_button())
	_check(session.year == before, "cancelling trial leaves the year unchanged")
	await _click(screen._try_button)
	await _click(screen._order_confirmation.get_ok_button())
	_check(session.year["jobs"].size() == 1, "confirming trial assigns once")
	await _click(screen._undo)
	_check(session.year == before, "trial assignment can be undone")
	screen.free()

	# Authored flood fixture: inspect and cancel a nonfatal real water warning.
	session = YearSession.new()
	session.save_path = output.path_join("year-flood.json")
	session.year = YearGame.new_campaign(42, "none", "water", "farmer", 0, true)
	for tile: Dictionary in session.year["board"]["tiles"]:
		tile["water"] = 10.0
	_check(session.checkpoint_year() == "", "nonfatal flood fixture validates")
	screen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	bytes = FileAccess.get_file_as_bytes(session.save_path)
	await _click(screen._time_buttons[1])
	_check(screen._advance_confirmation.visible and screen._impact_button.visible, "damage warning includes a location button")
	await _capture("year-extra-warning-" + language)
	await _click(screen._impact_button)
	_check(screen.selected == screen._impact_tile and int(session.year["day"]) == 0 and FileAccess.get_file_as_bytes(session.save_path) == bytes, "native risk inspection keeps the day and checkpoint")
	screen.free()

	# Authored harvest fixture; the order and all subsequent days use normal input.
	session = YearSession.new()
	session.save_path = output.path_join("year-harvest.json")
	session.year = YearGame.new_campaign(42, "none", "water", "farmer", 0, true)
	var index: int = _land(session.year)
	session.year["board"]["tiles"][index]["feature"] = "paddy"
	session.year["crop_growth"][index] = 60
	session.year["soil_moisture"][index] = 2
	_check(session.checkpoint_year() == "", "harvest fixture validates")
	screen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	screen.select_tile(index)
	screen._select_action("harvest")
	await _click(screen._irrigation)
	var popup: PopupMenu = screen._irrigation.get_popup()
	_check(popup.visible, "native priority popup opens")
	if popup.visible:
		await _click_at(Vector2(popup.position) + Vector2(popup.size) * Vector2(0.5, 0.82))
	_check(session.year["irrigation_policy"][index] == "skip", "native priority control assigns skip")
	await _capture("year-extra-field-" + language)
	await _click(screen._order_button)
	_check(session.year["jobs"].size() == 1, "native harvest order commits")
	for _day: int in range(3):
		await create_timer(0.45).timeout
		await _click(screen._time_buttons[0])
		if screen._advance_confirmation.visible:
			await _click(screen._advance_confirmation.get_ok_button())
	_check(int(session.year["stats"]["harvest"]) > 0, "real daily work produces harvest food")
	await _key(KEY_F3)
	_check(screen._tabs.current_tab == 5 and session.daily_history.size() == int(session.year["day"]), "history contains one record per actual day")
	var harvest_day: int = -1
	for entry: Dictionary in session.daily_history:
		if entry["locations"].any(func(fact: Dictionary): return fact["kind"] == "year.action.harvest"):
			harvest_day = int(entry["day"])
	screen._history_day = harvest_day
	screen._refresh_history()
	await _capture("year-extra-history-" + language)
	var location: Button = screen._history_rows.get_child(0) as Button if screen._history_rows.get_child_count() > 0 else null
	_check(location != null, "actual record offers a clickable location")
	if location != null:
		bytes = FileAccess.get_file_as_bytes(session.save_path)
		camera = screen.board.view_draft()
		await _click(location)
		_check(screen._history_return.visible, "result inspection offers return to history")
		await _capture("year-extra-location-" + language)
		await _click(screen._history_return)
		_check(screen._tabs.current_tab == 5 and screen.board.view_draft() == camera and FileAccess.get_file_as_bytes(session.save_path) == bytes, "return restores camera and preserves checkpoint")
	screen.free()
	var passed: bool = checks.all(func(check: Dictionary): return check["passed"])
	var file: FileAccess = FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"language": language, "checks": checks, "passed": passed}, "  "))
	file.close()
	print("YEAR PARITY NATIVE ", language, ": ", "PASS" if passed else "FAIL", " ", checks.size(), " checks")
	quit(0 if passed else 1)
