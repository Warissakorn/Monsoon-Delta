extends "res://tools/year_main_probe.gd"
## Native input and screenshots on isolated saves; flood case is an authored fixture.

func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Localization.setup(language)
	root.size = Vector2i(1280, 720)
	var session: YearSession = YearSession.new()
	session.save_path = output.path_join("campaign.json")
	_check(session.start_campaign(42, "forest", "water", "farmer", 0, true, true, 3) == "", "explicit three-year campaign validates")
	var screen: YearScreen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	await _capture("year-campaign-start-" + language)
	var before: Dictionary = session.year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(session.save_path)
	await _click(screen._new_button)
	_check(screen._campaign_years.selected == 1 and screen._classic.disabled, "loaded campaign duration is preserved in setup")
	screen._campaign_years.select(2)
	screen._campaign_length_changed()
	await _capture("year-campaign-setup-" + language)
	await _click(screen._restart.get_cancel_button())
	_check(session.year == before and FileAccess.get_file_as_bytes(session.save_path) == bytes, "cancelling duration changes preserves the checkpoint")

	screen.select_tile(YearPlanner.target(session.year, "build_house"))
	await _click(screen._area_button)
	_check(screen._area_dialog.visible, "native develop-hex button opens contextual actions")
	_check(screen._area_dialog.position.y >= 0 and screen._area_dialog.position.y + screen._area_dialog.size.y <= root.get_visible_rect().size.y, "area dialog and its close button fit the window")
	var panel: YearAreaDevelopmentPanel = screen._area_panel
	for i: int in range(panel._options.size()):
		if panel._options[i]["id"] == "build_house":
			panel._choice.select(i)
	panel._selection_changed()
	panel._horizon.select(1)
	await _click(panel._trial)
	_check(panel._result.get("completed", false) and int(panel._result.get("days", 0)) > 7, "native trial resolves beyond seven days until the house finishes")
	_check(session.year == before and FileAccess.get_file_as_bytes(session.save_path) == bytes, "trial does not assign resources or save")
	await _capture("year-campaign-area-" + language)
	_check(panel.get_viewport().gui_get_focus_owner() == panel._details, "preview focuses its forecast details for reading")
	await _click(panel._apply)
	_check(session.year["jobs"].size() == 1, "native confirmation assigns exactly one job")
	await _click(screen._area_dialog.get_ok_button())
	await _click(screen._undo)
	_check(session.year == before, "native Undo restores the plan and materials")
	screen.free()

	# Actual public orders, no state injection, through the first annual boundary.
	while int(session.year["day"]) < 365 and session.year["outcome"] == "running":
		YearProjectStrategy.plan(session.year)
		session.advance_year(mini(7, 365 - int(session.year["day"])))
	_check(int(session.year["day"]) == 365 and session.year["outcome"] == "running", "public replay reaches a live second-year boundary")
	screen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	await _capture("year-campaign-boundary-" + language)
	await _click(screen._time_buttons[0])
	if screen._advance_confirmation.visible:
		await _click(screen._advance_confirmation.get_ok_button())
	_check(int(session.year["day"]) == 366 and YearGame.year_number(session.year) == 2 and YearGame.season(session.year) == "dry", "native next-day input enters year two without resetting the village")
	await _capture("year-campaign-second-year-" + language)
	var loaded: YearSession = YearSession.new()
	loaded.save_path = session.save_path
	_check(loaded.load_year() == "" and loaded.year == session.year, "second-year checkpoint reloads exactly")
	screen.free()

	# Authored isolated crop-loss fixture; never changes the replay above.
	session = YearSession.new()
	session.save_path = output.path_join("crop-risk.json")
	session.year = YearGame.new_campaign(42, "none", "water", "farmer", 0, true, true, 3)
	var field: int = YearPlanner.target(session.year, "plant_paddy")
	session.year["board"]["tiles"][field]["feature"] = "paddy"
	session.year["crop_growth"][field] = 60
	session.year["crop_stress"][field] = 4
	session.year["soil_moisture"][field] = 2
	for index: int in range(session.year["structures"].size()):
		session.year["board"]["tiles"][index]["elevation"] = 4 if session.year["structures"][index] != "" else 0
		session.year["board"]["tiles"][index]["water"] = 0.0 if session.year["structures"][index] != "" else 3.0
	_check(session.checkpoint_year() == "", "authored crop-risk fixture validates")
	screen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	_check(screen._plan["advice"]["kind"] == "crops" and screen._plan["advice"]["action"] == "", "advisor warns rather than suggesting a harvest that will be too late")
	_check((screen.board as YearBoard3D).village.get_node("Preview").find_child("PaddyDied*", false, false) != null, "crop-loss forecast has a map marker")
	await _capture("year-campaign-crop-risk-" + language)
	bytes = FileAccess.get_file_as_bytes(session.save_path)
	await _click(screen._time_buttons[0])
	_check(screen._advance_confirmation.visible and screen._risk_choice.item_count > 0, "native warning offers individual risk locations")
	_check(screen._advance_confirmation.position.y >= 0 and screen._advance_confirmation.position.y + screen._advance_confirmation.size.y <= root.get_visible_rect().size.y, "risk confirmation buttons fit the window")
	await _capture("year-campaign-warning-" + language)
	await _click(screen._impact_button)
	_check(screen.selected == field and int(session.year["day"]) == 0 and FileAccess.get_file_as_bytes(session.save_path) == bytes, "inspecting a risk does not advance or save")
	screen.free()
	var passed: bool = checks.all(func(check: Dictionary): return check["passed"])
	var file: FileAccess = FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"language": language, "checks": checks, "passed": passed}, "  "))
	file.close()
	print("YEAR CAMPAIGN NATIVE ", language, ": ", "PASS" if passed else "FAIL", " ", checks.size(), " checks")
	quit(0 if passed else 1)
