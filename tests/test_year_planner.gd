extends TestCase

const PATH: String = "user://test-year-planner.json"


func before_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Localization.setup("en")


func _screen(year: Dictionary) -> YearScreen:
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.save_path = PATH
	screen.session.year = year
	assert_eq(screen.session.checkpoint_year(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


func test_seven_day_forecast_matches_real_daily_resolution_for_all_year_versions() -> void:
	for year: Dictionary in [YearGame.new_game(42), YearGame.new_expanded(42), YearGame.new_campaign(42, "none", "food", "fisher", 5)]:
		var before: Dictionary = year.duplicate(true)
		var plan: Dictionary = YearPlanner.describe(year)
		assert_eq(plan["days"].size(), 7)
		var actual: Dictionary = year.duplicate(true)
		for row: Dictionary in plan["days"]:
			var report: Dictionary = YearGame.advance(actual, 1)
			assert_eq(row["day"], actual["day"])
			assert_eq(row["food"], actual["resources"]["food"])
			assert_eq(row["population"], actual["population"])
			assert_eq(row["housing"], YearGame.housing(actual))
			assert_eq(row["events"], report["events"])
		assert_eq(year, before, "planning must not mutate the real year or its nested RNG/weather")
		var advice: Dictionary = plan["advice"]
		if not String(advice["action"]).is_empty():
			assert_eq(YearGame.check_order(year, advice["action"], int(advice["tile"])), "")


func test_forecast_stops_at_loss_and_day_365_without_resolving_a_day_366() -> void:
	var year: Dictionary = YearGame.new_campaign(42, "none", "food")
	year["population"] = 1
	year["resources"]["food"] = 0
	year["starvation"] = 2
	var plan: Dictionary = YearPlanner.describe(year)
	assert_eq(plan["days"].size(), 1)
	assert_eq(plan["days"][0]["outcome"], "lost_population")
	assert_eq(year["day"], 0)
	year = YearGame.new_campaign(42, "none", "food")
	year["day"] = 364
	plan = YearPlanner.describe(year)
	assert_eq(plan["days"].size(), 1)
	assert_eq(plan["days"][0]["day"], 365)
	assert_eq(plan["days"][0]["outcome"], "won")


func test_real_batch_completion_and_paused_jobs_get_truthful_forecasts() -> void:
	var year: Dictionary = YearGame.new_campaign(42, "none", "food")
	var index: int = YearPlanner.target(year, "forage")
	assert_eq(YearGame.order(year, "forage", index, 1, true), "")
	var plan: Dictionary = YearPlanner.describe(year)
	var completion: int = int(plan["jobs"][0]["completion_day"])
	assert_true(completion > 0 and completion <= 7)
	var copy: Dictionary = year.duplicate(true)
	while int(copy["day"]) < completion:
		YearGame.advance(copy, 1)
	assert_true(int(copy["stats"]["food"]) > int(year["stats"]["food"]))
	year["jobs"][0]["paused"] = true
	plan = YearPlanner.describe(year)
	assert_eq(plan["jobs"][0]["kind"], "paused")
	assert_eq(plan["jobs"][0]["completion_day"], 0)


func test_missing_materials_remain_blocked_without_a_fabricated_finish_day() -> void:
	var year: Dictionary = YearGame.new_campaign(42, "none", "food")
	var index: int = YearPlanner.target(year, "build_sawmill")
	year["structures"][index] = "sawmill"
	year["health"][index] = 100
	assert_eq(YearGame.order(year, "saw_planks", index, 1, true), "")
	year["jobs"][0]["reserved"] = false
	year["resources"]["wood"] = 0
	var plan: Dictionary = YearPlanner.describe(year)
	assert_eq(plan["jobs"][0]["kind"], "blocked")
	assert_eq(plan["jobs"][0]["status"], "exp.job.reserve")
	assert_eq(plan["jobs"][0]["completion_day"], 0)
	assert_eq(plan["advice"]["kind"], "blocked")


func test_advice_only_prepares_a_form_and_preserves_checkpoint_and_undo() -> void:
	var screen: YearScreen = _screen(YearGame.new_campaign(42, "none", "water"))
	var before: Dictionary = screen.session.year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var advice: Dictionary = screen._plan["advice"].duplicate(true)
	assert_eq(advice["kind"], "production")
	screen._act_on_advice()
	assert_eq(screen.selected, advice["tile"])
	assert_eq(screen.action_id(), "build_sawmill")
	assert_eq(screen.session.year, before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_true(screen.session.undo_plans.is_empty())
	screen._order()
	assert_eq(screen.session.year["jobs"].size(), 1)
	assert_true(screen.session.year != before)
	screen._undo_plan()
	assert_eq(screen.session.year, before)
	assert_eq(screen._plan["advice"]["kind"], "production")
	screen.free()


func test_queue_filters_do_not_change_jobs_or_checkpoint() -> void:
	var year: Dictionary = YearGame.new_campaign(42, "none", "food")
	var index: int = YearPlanner.target(year, "forage")
	assert_eq(YearGame.order(year, "forage", index, 1, true), "")
	year["jobs"][0]["paused"] = true
	var screen: YearScreen = _screen(year)
	var before: Dictionary = year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen._queue_filter.select(1)
	screen._refresh_queue()
	assert_true(screen._queue_list.find_child("PauseTile_" + str(index), true, false) == null)
	screen._queue_filter.select(3)
	screen._refresh_queue()
	assert_true(screen._queue_list.find_child("PauseTile_" + str(index), true, false) != null)
	assert_eq(screen.session.year, before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen.free()


func test_loss_confirmation_takes_priority_over_idle_workers_and_cancellation_is_read_only() -> void:
	var year: Dictionary = YearGame.new_campaign(42, "none", "food")
	year["population"] = 1
	year["resources"]["food"] = 0
	year["starvation"] = 2
	var screen: YearScreen = _screen(year)
	var before: Dictionary = year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen._request_advance(7)
	assert_true(screen._advance_confirmation.visible)
	assert_true(screen._advance_text.text.contains("ends the run"))
	screen._advance_confirmation.hide()
	assert_eq(screen.session.year, before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen.free()


func test_output_limit_can_pause_a_later_job_without_inventing_a_completion_date() -> void:
	var year: Dictionary = YearGame.new_campaign(42, "none", "food")
	var first: int = YearPlanner.target(year, "forage")
	assert_eq(YearGame.order(year, "forage", first, 1, true), "")
	var second: int = YearPlanner.target(year, "forage")
	assert_eq(YearGame.order(year, "forage", second, 1, true, 0, int(year["resources"]["food"]) + 1), "")
	year["jobs"][0]["progress"] = YearGame._job_days(year, "forage", first) - 1
	var plan: Dictionary = YearPlanner.describe(year)
	assert_eq(plan["jobs"][0]["completion_day"], 1)
	assert_eq(plan["jobs"][1]["completion_day"], 0)
	var copy: Dictionary = year.duplicate(true)
	YearGame.advance(copy, 1)
	assert_true(copy["jobs"][1]["paused"])
	assert_eq(copy["jobs"][1]["progress"], year["jobs"][1]["progress"])


func test_one_day_repeating_repair_uses_recorded_completion_without_changing_the_run() -> void:
	var year: Dictionary = YearGame.new_campaign(42, "none", "water")
	year["research"].append_array(["housing1", "housing2", "housing3"])
	var hall: int = year["structures"].find("hall")
	year["health"][hall] = 40
	assert_eq(YearGame.order(year, "repair", hall, 1, true), "")
	assert_eq(YearGame._job_days(year, "repair", hall), 1)
	var before: Dictionary = year.duplicate(true)
	var plan: Dictionary = YearPlanner.describe(year)
	assert_eq(plan["jobs"][0]["completion_day"], 1)
	assert_eq(year, before)
	var recorded: Dictionary = year.duplicate(true)
	var plain: Dictionary = year.duplicate(true)
	var reports: Array[TurnReport] = []
	assert_eq(YearGame.advance(recorded, 1, reports), YearGame.advance(plain, 1))
	assert_eq(recorded, plain)
	assert_eq(reports[0].year_jobs_completed, [{"tile": hall, "id": "repair"}])
