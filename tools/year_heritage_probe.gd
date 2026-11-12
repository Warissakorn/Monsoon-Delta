extends "res://tools/year_parity_probe.gd"
## Actual daily replays before mounting each screen. Saves/XDG must be isolated.


func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Localization.setup(language)
	root.size = Vector2i(1280, 720)
	var session: YearSession = YearSession.new()
	session.save_path = output.path_join("living-year.json")
	_check(session.start_campaign(42, "forest", "water", "farmer", 0, true, true) == "", "explicit new year starts v5")
	for _job: int in range(2):
		_check(YearGame.order(session.year, "forage", YearStrategy.target(session.year, "forage"), 1, true) == "", "real food work assigned")
	var workplace: int = YearStrategy.target(session.year, "build_sawmill")
	_check(YearGame.order(session.year, "build_sawmill", workplace) == "", "workplace starts through a public order")
	while int(session.year["day"]) < 90 and session.year["outcome"] == "running":
		session.advance_year(mini(7, 90 - int(session.year["day"])))
	_check(int(session.year["day"]) == 90 and YearCheckpoint.valid(session.year), "actual ninety-day replay produces a valid checkpoint")
	_check(session.year["settlement_progress"]["condition"] == "thriving", "repeated daily observations create a thriving village")
	var house: int = session.year["structures"].find("house")
	_check(YearHeritage.age(session.year, house) == 90 and int(YearHeritage.building(session.year, house)["stage"]) == 2, "initial house keeps ninety days of age and two development stages")
	_check(int(session.year["goal_medal"]["day"]) > 0, "ambition earned its medal during actual play")
	var original: Dictionary = session.year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(session.save_path)
	var screen: YearScreen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	(screen.board as YearBoard3D).set_reduced_motion(true)
	await _click(screen._heritage_button)
	_check(screen._tabs.current_tab == 7 and screen._heritage_goal.text.contains("250"), "village panel shows the permanent medal bonus")
	await _capture("year-heritage-village-" + language)
	var board: YearBoard3D = screen.board as YearBoard3D
	var cell: Node = board.village._tiles_root.get_child(house)
	var details: Node = cell.get_node_or_null("SettlementDetails")
	_check(details != null and int(details.get_meta("stage")) == 2 and int(details.get_meta("age")) == 3, "shared house renderer uses saved stages and month-scaled real age")
	var workshop_details: Node = board.village._tiles_root.get_child(workplace).get_node_or_null("YearWorkplaceProgress")
	_check(workshop_details != null and int(workshop_details.get_meta("age_days")) == YearHeritage.age(session.year, workplace), "custom workplace renderer uses its true completion date")
	await _click(screen._heritage_buildings.get_node("BuildingAge_" + str(house)))
	_check(screen.selected == house and screen._tabs.current_tab == 0 and screen._inspection.text.contains("90"), "native building row focuses the inspector with its actual age")
	await _capture("year-heritage-building-" + language)
	_check(session.year == original and FileAccess.get_file_as_bytes(session.save_path) == bytes and session.undo_plans.is_empty(), "age and medal inspection never changes state, RNG, save or Undo")
	screen.free()
	var loaded: YearSession = YearSession.new()
	loaded.save_path = session.save_path
	_check(loaded.load_year() == "" and loaded.year == original, "reload preserves all daily history fields and original medal receipt")
	_check(FileAccess.get_file_as_bytes(loaded.save_path) == bytes, "loading remains read-only")

	# A full reference replay, followed by native input for its final day.
	session = YearSession.new()
	session.save_path = output.path_join("final-year.json")
	_check(session.start_campaign(42, "forest", "water", "farmer", 0, true, true) == "", "isolated full-year replay starts")
	while int(session.year["day"]) < 364 and session.year["outcome"] == "running":
		YearProjectStrategy.plan(session.year)
		session.advance_year(mini(7, 364 - int(session.year["day"])))
	YearProjectStrategy.plan(session.year)
	_check(int(session.year["day"]) == 364 and session.checkpoint_year() == "", "public reference policy reaches day 364 with a valid checkpoint")
	screen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	await _click(screen._time_buttons[0])
	if screen._advance_confirmation.visible:
		await _click(screen._advance_confirmation.get_ok_button())
	_check(int(session.year["day"]) == 365 and session.year["outcome"] == "won", "native final-day input wins the full year")
	_check(screen._result_dialog.visible, "committed end opens the score breakdown")
	var parts: Dictionary = YearHeritage.score_parts(session.year)
	_check(int(parts["goal"]) == 250 and int(parts["total"]) == int(session.year["score"]) and screen._result_dialog.dialog_text.contains(str(parts["total"])), "result shows the real permanent bonus and final score")
	await _capture("year-heritage-result-" + language)
	bytes = FileAccess.get_file_as_bytes(session.save_path)
	await _key(KEY_SPACE)
	_check(int(session.year["day"]) == 365 and FileAccess.get_file_as_bytes(session.save_path) == bytes, "modal keyboard input cannot advance or rewrite the completed year")
	await _click(screen._result_dialog.get_ok_button())
	await _click(screen._heritage_button)
	await _click(screen._result_button)
	_check(screen._result_dialog.visible and FileAccess.get_file_as_bytes(session.save_path) == bytes, "score can be reopened without recomputing or saving the run")
	await _click(screen._result_dialog.get_ok_button())
	original = session.year.duplicate(true)
	screen.free()
	loaded = YearSession.new()
	loaded.save_path = session.save_path
	_check(loaded.load_year() == "" and loaded.year == original, "completed year retains its medal, ages and exact final score after load")

	# Existing v4 is viewed without migration; only confirming a new year opts in.
	session = YearSession.new()
	session.save_path = output.path_join("legacy-year.json")
	_check(session.start_campaign(73, "rice", "craft", "fisher", 5, true) == "", "existing v4 fixture starts")
	screen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	bytes = FileAccess.get_file_as_bytes(session.save_path)
	_check(not screen._heritage_button.visible and not session.year.has("goal_medal"), "continuing v4 keeps its original fields and rules")
	await _click(screen._new_button)
	await _click(screen._classic)
	await _click(screen._classic)
	await _capture("year-heritage-setup-" + language)
	await _click(screen._restart.get_cancel_button())
	_check(FileAccess.get_file_as_bytes(session.save_path) == bytes and session.year["ruleset"] == "year365_v4", "cancelling the new-year form preserves the old envelope")
	await _click(screen._new_button)
	await _click(screen._restart.get_ok_button())
	_check(session.year["ruleset"] == "year365_v5" and session.year["board"]["seed"] == "73" and session.year["leader"] == "fisher" and int(session.year["difficulty"]) == 5, "explicit native restart opts into v5 while preserving the chosen profile")
	screen.free()
	var passed: bool = checks.all(func(check: Dictionary): return check["passed"])
	var file: FileAccess = FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"language": language, "checks": checks, "passed": passed}, "  "))
	file.close()
	print("YEAR HERITAGE NATIVE ", language, ": ", "PASS" if passed else "FAIL", " ", checks.size(), " checks")
	quit(0 if passed else 1)
