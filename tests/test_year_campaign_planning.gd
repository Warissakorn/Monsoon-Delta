extends TestCase

const PATH: String = "user://test-year-campaign-planning.json"


func before_each() -> void:
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Localization.setup("en")


func _year(years: int = 3) -> Dictionary:
	return YearGame.new_campaign(42, "forest", "water", "farmer", 0, true, true, years)


func _screen(s: Dictionary) -> YearScreen:
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.save_path = PATH
	screen.session.year = s
	assert_eq(screen.session.checkpoint_year(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


func _crop_risk() -> Dictionary:
	var s: Dictionary = _year()
	var field: int = YearPlanner.target(s, "plant_paddy")
	s["board"]["tiles"][field]["feature"] = "paddy"
	s["crop_growth"][field] = 60
	s["crop_stress"][field] = 4
	s["soil_moisture"][field] = 2
	for index: int in range(s["structures"].size()):
		s["board"]["tiles"][index]["elevation"] = 4 if s["structures"][index] != "" else 0
		s["board"]["tiles"][index]["water"] = 0.0 if s["structures"][index] != "" else 3.0
	return s


func test_multiyear_requires_explicit_version_and_complete_village_rules() -> void:
	var old: Dictionary = YearGame.new_campaign(42, "forest", "water", "farmer", 0, true, true)
	for years: int in [3, 5]:
		var s: Dictionary = _year(years)
		assert_true(YearCheckpoint.valid(s))
		assert_eq(YearCheckpoint.envelope(s)["version"], 6)
		assert_eq(s["ruleset"], "year365_v6")
		assert_eq(s["weather"].slice(0, 365), old["weather"])
		assert_eq(YearGame.total_days(s), 365 * years)
	assert_eq(YearCheckpoint.envelope(old)["version"], 5)
	assert_true(not old.has("campaign_years"))
	assert_true(YearGame.new_campaign(42, "none", "water", "farmer", 0, true, true, 2).is_empty())
	assert_true(YearGame.new_campaign(42, "none", "water", "farmer", 0, false, false, 3).is_empty())


func test_strict_campaign_duration_weather_and_terminal_validation() -> void:
	var good: Dictionary = _year()
	for patch: Dictionary in [{"campaign_years": 4}, {"campaign_years": "3"}, {"day": 1096}, {"day": 1095}, {"outcome": "won"}]:
		var bad: Dictionary = good.duplicate(true)
		bad.merge(patch, true)
		assert_true(not YearCheckpoint.valid(bad))
	var bad: Dictionary = good.duplicate(true)
	bad.erase("campaign_years")
	assert_true(not YearCheckpoint.valid(bad))
	bad = good.duplicate(true)
	bad["weather"][365] += 1
	assert_true(not YearCheckpoint.valid(bad))
	var envelope: Dictionary = YearCheckpoint.envelope(good)
	envelope["version"] = 5
	assert_eq(YearCheckpoint.decode(envelope)["error"], "msg.save_corrupt")
	envelope["version"] = 7
	assert_eq(YearCheckpoint.decode(envelope)["error"], "msg.save_unsupported")


func test_year_boundary_preserves_jobs_and_village_then_resumes_dry_season() -> void:
	var s: Dictionary = _year()
	s["day"] = 364
	s["settlement_progress"]["observed_day"] = 364
	s["settlement_progress"]["evaluated_day"] = 360
	var field: int = YearPlanner.target(s, "build_house")
	assert_eq(YearGame.order(s, "build_house", field), "")
	var before_structures: Array = s["structures"].duplicate()
	var events: Array = YearGame.resolve_day(s)
	assert_eq(s["outcome"], "running")
	assert_eq(s["day"], 365)
	assert_true("yearmulti.event.year_complete" in events)
	assert_eq(s["structures"], before_structures)
	assert_eq(s["jobs"].size(), 1)
	assert_eq(s["jobs"][0]["progress"], 1)
	assert_true(YearCheckpoint.valid(s))
	var loaded: Dictionary = YearCheckpoint.decode(JSON.parse_string(JSON.stringify(YearCheckpoint.envelope(s), "", true, true)))["state"]
	for _day: int in range(8):
		assert_eq(YearGame.resolve_day(loaded), YearGame.resolve_day(s))
		assert_eq(loaded, s)
	assert_eq(YearGame.year_number(s), 2)
	assert_eq(YearGame.season(s), "dry")
	assert_true(YearCheckpoint.valid(s))
	assert_eq(s["structures"][field], "house")


func test_weather_and_forecasts_repeat_seasons_with_versioned_annual_pressure() -> void:
	var s: Dictionary = _year()
	assert_eq(s["weather"], YearWeather.generate(42, 3))
	assert_true(s["weather"].slice(0, 365) != s["weather"].slice(365, 730))
	assert_near(YearWeather.inflow(s, 365), float(s["weather"][365]) / 1000.0 * 1.05, 1e-12)
	s["day"] = 364
	assert_eq(YearWeather.forecast(s).size(), 7)
	assert_eq(YearWeather.forecast(s)[1]["day"], 366)
	assert_eq(YearGame.day_of_year(s, 366), 1)
	assert_eq(YearGame.year_number(s, 731), 3)
	s["day"] = 366
	var field: int = YearPlanner.target(s, "plant_paddy")
	assert_true(field >= 0, "planting is available again in the next dry season")


func test_reference_policy_survives_three_and_five_years_with_real_orders() -> void:
	for years: int in [3, 5]:
		var s: Dictionary = _year(years)
		while s["outcome"] == "running":
			YearProjectStrategy.plan(s)
			YearGame.advance(s, 7)
		assert_eq(s["outcome"], "won", "public replay survives " + str(years) + " years")
		assert_eq(s["day"], 365 * years)
		assert_true(YearCheckpoint.valid(s))
		assert_eq(YearGame.advance(s, 1)["days"], 0)


func test_crop_advice_never_suggests_a_harvest_that_cannot_finish_in_time() -> void:
	var s: Dictionary = _crop_risk()
	var before: Dictionary = s.duplicate(true)
	var plan: Dictionary = YearPlanner.describe(s)
	assert_eq(plan["advice"]["kind"], "crops")
	assert_eq(plan["advice"]["action"], "")
	assert_eq(plan["days"][0]["crops"].size(), 1)
	assert_eq(YearPlanner.target(s, "harvest"), -1)
	assert_eq(s, before)


func test_until_completion_shows_finished_house_and_matches_real_resolution() -> void:
	var s: Dictionary = _year()
	var index: int = YearPlanner.target(s, "build_house")
	var before: Dictionary = s.duplicate(true)
	var week: Dictionary = YearOrderPreview.describe(s, "build_house", index)
	assert_true(not week["completed"])
	var result: Dictionary = YearOrderPreview.describe(s, "build_house", index, 1, false, 0, 0, 0, true)
	assert_true(result["completed"])
	assert_true(int(result["days"]) > 7)
	assert_eq(YearGame.housing(result["planned"]), YearGame.housing(s) + 2)
	var actual: Dictionary = s.duplicate(true)
	assert_eq(YearGame.order(actual, "build_house", index), "")
	for _day: int in range(int(result["days"])):
		YearGame.resolve_day(actual)
	assert_eq(actual, result["planned"])
	assert_eq(s, before)


func test_completion_horizon_distinguishes_all_batches_from_first_repeating_batch() -> void:
	var s: Dictionary = _year()
	var index: int = YearPlanner.target(s, "forage")
	var finite: Dictionary = YearOrderPreview.describe(s, "forage", index, 2, false, 0, 0, 0, true)
	var repeating: Dictionary = YearOrderPreview.describe(s, "forage", index, 1, true, 0, 0, 0, true)
	assert_true(finite["completed"] and repeating["completed"])
	assert_eq(finite["days"], int(repeating["days"]) * 2)
	assert_true(finite["planned"]["jobs"].is_empty())
	assert_eq(repeating["planned"]["jobs"].size(), 1)


func test_unfinished_orders_stop_honestly_at_campaign_end_or_exhausted_deposit() -> void:
	var s: Dictionary = YearGame.new_campaign(42, "none", "water")
	s["day"] = 364
	var index: int = YearPlanner.target(_year(), "build_house")
	var result: Dictionary = YearOrderPreview.describe(s, "build_house", index, 1, false, 0, 0, 0, true)
	assert_true(not result["completed"])
	assert_eq(result["reason"], "campaign_end")
	assert_eq(result["planned"]["day"], 365)
	s = _year()
	s["resources"]["food"] = 500
	index = YearPlanner.target(s, "gather_wood")
	result = YearOrderPreview.describe(s, "gather_wood", index, 100, false, 0, 0, 0, true)
	assert_true(not result["completed"])
	assert_eq(result["reason"], "blocked")
	assert_eq(result["completion_day"], 0)


func test_prediction_passes_crop_hall_and_brace_results_to_shared_renderer() -> void:
	var s: Dictionary = _crop_risk()
	var hall: int = s["structures"].find("hall")
	s["health"][hall] = 10
	for tile: Dictionary in s["board"]["tiles"]:
		tile["water"] = 10.0
	var reports: Array[TurnReport] = []
	var after: Dictionary = YearGame.preview(s, 1, reports)["state"]
	var prediction: Dictionary = YearPresentation.preview(s, after, reports[0])
	assert_eq(prediction["report"].outcome, C.Outcome.LOSE_HALL)
	assert_eq(prediction["report"].paddies_died.size(), 1)
	var board: YearBoard3D = YearBoard3D.new()
	board.size = Vector2(900, 600)
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	board.model = s
	board.predicted = after
	board.set_forecast_flow(reports[0])
	board.update_view()
	assert_true(board.village.get_node("Preview").find_child("PaddyDied*", false, false) != null)
	assert_true(board.village.get_node("Preview").find_child("HallRisk*", false, false) != null)
	board.free()
	s = _year()
	var house: int = s["structures"].find("house")
	for tile: Dictionary in s["board"]["tiles"]:
		tile["elevation"] = 0
		tile["water"] = 0.75
	assert_eq(YearGame.order(s, "brace_house", house), "")
	reports.clear()
	after = YearGame.preview(s, 1, reports)["state"]
	prediction = YearPresentation.preview(s, after, reports[0])
	assert_eq(prediction["report"].brace_results.size(), 1)
	assert_true(prediction["report"].brace_results[0]["prevented_loss"])
	assert_eq(s["brace_days"][house], 0)


func test_contextual_actions_include_appropriate_locked_work_and_existing_village_systems() -> void:
	var s: Dictionary = _year()
	var index: int = YearPlanner.target(s, "build_house")
	var options: Array[Dictionary] = YearAreaDevelopment.options(s, index)
	assert_true(options.any(func(o: Dictionary): return o["id"] == "build_house" and o["error"] == ""))
	assert_true(options.any(func(o: Dictionary): return o["id"] == "build_wheel" and o["error"] == "year.error.research"))
	s["board"]["tiles"][index]["feature"] = "paddy"
	s["crop_growth"][index] = 60
	options = YearAreaDevelopment.options(s, index)
	assert_true(options.any(func(o: Dictionary): return o["id"] == "clear_land"))
	assert_eq(options.filter(func(o: Dictionary): return o["action"] == "irrigation").size(), 3)
	assert_eq(YearAreaDevelopment.expected_output(s, "harvest", index)["food"], 61)
	assert_eq(YearAreaDevelopment.role(s, index), "field")
	assert_true(not options.any(func(o: Dictionary): return o["id"] == "build_house"))


func test_area_preview_and_cancellation_preserve_checkpoint_then_commit_is_undoable() -> void:
	for language: String in ["th", "en"]:
		Localization.setup(language)
		var screen: YearScreen = _screen(_year())
		screen.select_tile(YearPlanner.target(screen.session.year, "build_house"))
		var before: Dictionary = screen.session.year.duplicate(true)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		screen.open_area_development()
		var panel: YearAreaDevelopmentPanel = screen._area_panel
		for i: int in range(panel._options.size()):
			if panel._options[i]["id"] == "build_house":
				panel._choice.select(i)
		panel._selection_changed()
		panel._horizon.select(1)
		panel._preview()
		assert_true(panel._result["completed"])
		assert_eq(screen.session.year, before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		assert_true(screen.session.undo_plans.is_empty())
		screen._area_dialog.hide()
		assert_eq(screen.session.year, before)
		panel._request_command()
		assert_eq(screen.session.year["jobs"].size(), 1)
		panel._request_command()
		assert_eq(screen.session.year["jobs"].size(), 1)
		assert_true(screen.session.undo_year())
		assert_eq(screen.session.year, before)
		assert_true(screen.session.redo_year())
		screen.free()


func test_stale_area_preview_requires_a_new_trial_before_assignment() -> void:
	var screen: YearScreen = _screen(_year())
	screen.select_tile(YearPlanner.target(screen.session.year, "build_house"))
	screen.open_area_development()
	var panel: YearAreaDevelopmentPanel = screen._area_panel
	panel._preview()
	assert_true(not panel._apply.disabled)
	var other: int = YearPlanner.target(screen.session.year, "forage")
	assert_eq(screen.session.edit_year("order", "forage", other), "")
	var current: Dictionary = screen.session.year.duplicate(true)
	panel._request_command()
	assert_eq(screen.session.year, current)
	assert_true(panel._apply.disabled)
	assert_true(panel._pending.is_empty())
	screen.free()


func test_new_campaign_form_preserves_duration_across_language_and_cancel() -> void:
	var screen: YearScreen = _screen(_year())
	assert_eq(screen._campaign_years.selected, 1)
	assert_true(screen._classic.button_pressed and screen._classic.disabled)
	var draft: Dictionary = screen.ui_draft()
	var before: Dictionary = screen.session.year.duplicate(true)
	screen._campaign_years.select(2)
	screen.restore_ui_draft(draft)
	assert_eq(screen.ui_draft(), draft)
	assert_eq(screen.session.year, before)
	screen._campaign_years.select(2)
	screen._campaign_length_changed()
	screen._new_year()
	assert_eq(screen.session.year["campaign_years"], 5)
	assert_eq(screen.session.year["ruleset"], "year365_v6")
	assert_true(YearCheckpoint.valid(screen.session.year))
	screen.free()
