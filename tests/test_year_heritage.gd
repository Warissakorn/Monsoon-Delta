extends TestCase

const PATH: String = "user://test-year-heritage.json"


func before_each() -> void:
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Localization.setup("en")


func _year(goal: String = "none") -> Dictionary:
	return YearGame.new_campaign(42, goal, "water", "farmer", 0, true, true)


func _fed(s: Dictionary) -> void:
	for _job: int in range(2):
		assert_eq(YearGame.order(s, "forage", YearStrategy.target(s, "forage"), 1, true), "")


func _days(s: Dictionary, count: int) -> void:
	for _day: int in range(count):
		YearGame.advance(s, 1)


func _eligible(s: Dictionary) -> void:
	match String(s["goal"]):
		"growth": s["population"] = 10
		"rice":
			s["stats"]["harvest"] = 180
			s["stats"]["food"] = 180
		"forest":
			for index: int in range(s["structures"].size()):
				if YearGame.forests(s) >= 12:
					break
				if YearGame.target_matches(s, "build_house", index):
					s["board"]["tiles"][index]["feature"] = "forest"
					s["stock"][index] = 30


func _screen(s: Dictionary) -> YearScreen:
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.save_path = PATH
	screen.session.year = s
	assert_eq(screen.session.checkpoint_year(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


func test_v5_is_explicit_and_all_older_envelopes_remain_distinct() -> void:
	var versions: Array[Dictionary] = [YearGame.new_game(), YearGame.new_expanded(), YearGame.new_campaign(42, "none", "water"), YearGame.new_campaign(42, "none", "water", "farmer", 0, true), _year()]
	for index: int in range(versions.size()):
		var s: Dictionary = versions[index]
		assert_eq(YearCheckpoint.envelope(s)["version"], index + 1)
		assert_true(YearCheckpoint.valid(s))
		assert_eq(YearCheckpoint.decode(YearCheckpoint.envelope(s))["state"], s)
		assert_eq(s.has("goal_medal"), index == 4)
		assert_true(not s["board"].has("settlement_progress"))
	var stripped: Dictionary = versions.back().duplicate(true)
	for field: String in YearHeritage.FIELDS:
		stripped.erase(field)
	stripped["ruleset"] = "year365_v4"
	assert_eq(stripped, versions[3])
	assert_true(YearGame.new_campaign(42, "none", "water", "farmer", 0, false, true).is_empty())


func test_age_and_two_period_reviews_decorate_without_changing_daily_simulation() -> void:
	var living: Dictionary = _year()
	var old: Dictionary = YearGame.new_campaign(42, "none", "water", "farmer", 0, true)
	_fed(living)
	_fed(old)
	var house: int = living["structures"].find("house")
	for day: int in range(1, 91):
		YearGame.advance(living, 1)
		YearGame.advance(old, 1)
		var stripped: Dictionary = living.duplicate(true)
		for field: String in YearHeritage.FIELDS:
			stripped.erase(field)
		stripped["ruleset"] = "year365_v4"
		assert_eq(stripped, old, "cosmetics do not change resources, water, jobs, health or RNG")
		assert_eq(YearHeritage.age(living, house), day)
		if day == 30:
			assert_eq(living["settlement_progress"]["condition"], "stable")
			assert_eq(YearHeritage.building(living, house)["stage"], 0)
		elif day == 60:
			assert_eq(living["settlement_progress"]["condition"], "thriving")
			assert_eq(YearHeritage.building(living, house)["stage"], 1)
		assert_true(YearCheckpoint.valid(living))
	assert_eq(YearHeritage.building(living, house)["stage"], 2)


func test_poor_periods_change_condition_one_step_at_a_time_and_reduce_decoration() -> void:
	var s: Dictionary = _year()
	var house: int = s["structures"].find("house")
	for day: int in range(1, 241):
		s["day"] = day
		s["resources"]["food"] = 100 if day <= 90 else 0
		s["resources"]["wood"] = 50
		s["starvation"] = 0 if day <= 90 else 1
		YearHeritage.after_day(s, [])
		if day == 120:
			assert_eq(s["settlement_progress"]["condition"], "thriving")
		elif day == 150:
			assert_eq(s["settlement_progress"]["condition"], "stable")
		elif day == 210:
			assert_eq(s["settlement_progress"]["condition"], "struggling")
			assert_eq(YearHeritage.building(s, house)["stage"], 1)
	assert_eq(YearHeritage.building(s, house)["stage"], 0)
	assert_true(YearCheckpoint.valid(s))


func test_an_earlier_hungry_day_is_not_hidden_by_purchases_before_review() -> void:
	var s: Dictionary = _year()
	for day: int in range(1, 31):
		s["day"] = day
		s["starvation"] = 1 if day == 10 else 0
		s["resources"]["food"] = 100
		YearHeritage.after_day(s, [])
	assert_eq(s["settlement_progress"]["condition"], "stable")
	assert_eq(s["settlement_progress"]["candidate"], "struggling")
	assert_eq(s["settlement_progress"]["candidate_periods"], 1)
	var before: Dictionary = s.duplicate(true)
	YearHeritage.after_day(s, [])
	assert_eq(s, before, "a daily observation and review cannot be counted twice")


func test_build_dates_follow_completion_and_rebuilding_resets_age_after_undo_and_load() -> void:
	var session: YearSession = YearSession.new()
	session.save_path = PATH
	assert_eq(session.start_campaign(42, "none", "water", "farmer", 0, true, true), "")
	_days(session.year, 10)
	var index: int = YearStrategy.target(session.year, "build_house")
	var before: Dictionary = session.year.duplicate(true)
	assert_eq(session.edit_year("order", "build_house", index), "")
	var queued: Dictionary = session.year.duplicate(true)
	assert_true(session.undo_year())
	assert_eq(session.year, before)
	assert_true(session.redo_year())
	assert_eq(session.year, queued)
	while session.year["structures"][index] != "house":
		session.advance_year(1)
	var first_built: int = int(session.year["day"])
	assert_true(first_built > 10)
	assert_eq(YearHeritage.building(session.year, index)["built_day"], first_built)
	assert_eq(YearHeritage.age(session.year, index), 0)
	assert_eq(session.load_year(), "")
	assert_eq(YearHeritage.building(session.year, index)["built_day"], first_built)
	assert_eq(session.edit_year("order", "demolish", index), "")
	while session.year["structures"][index] != "":
		session.advance_year(1)
	assert_true(YearHeritage.building(session.year, index).is_empty())
	assert_eq(session.edit_year("order", "build_house", index), "")
	while session.year["structures"][index] != "house":
		session.advance_year(1)
	assert_true(int(YearHeritage.building(session.year, index)["built_day"]) > first_built)
	assert_eq(YearHeritage.age(session.year, index), 0)
	assert_true(YearCheckpoint.valid(session.year))


func test_destroyed_buildings_lose_history_and_recovered_ruins_start_fresh() -> void:
	var s: Dictionary = _year()
	var house: int = s["structures"].find("house")
	s["health"][house] = 10
	for tile: Dictionary in s["board"]["tiles"]:
		tile["water"] = 10.0
	YearGame.advance(s, 1)
	assert_eq(s["health"][house], 0)
	assert_true(YearHeritage.building(s, house).is_empty())
	assert_true(YearCheckpoint.valid(s))
	assert_eq(YearGame.order(s, "repair", house), "")
	while int(s["health"][house]) == 0 and s["outcome"] == "running":
		YearGame.advance(s, 1)
	assert_true(int(s["health"][house]) > 0)
	assert_eq(YearHeritage.building(s, house)["built_day"], s["day"])
	assert_eq(YearHeritage.age(s, house), 0)
	assert_true(YearCheckpoint.valid(s))


func test_preview_at_review_boundary_matches_commit_and_never_ages_the_live_board() -> void:
	var s: Dictionary = _year()
	_fed(s)
	_days(s, 59)
	var before: Dictionary = s.duplicate(true)
	var expected: Dictionary = YearGame.preview(s)
	assert_eq(s, before)
	var forecast: Dictionary = YearPlanner.describe(s)
	assert_true(forecast["days"][0]["events"].has("yearheritage.event.condition"))
	assert_eq(s, before)
	YearGame.advance(s, 1)
	assert_eq(s, expected["state"])
	var board: GameState = YearPresentation.board(s)
	var house: int = s["structures"].find("house")
	assert_eq(SettlementProgress.condition_key(board), "settlement.thriving")
	assert_eq(SettlementProgress.building_age(board, board.tiles[house]), 2)
	assert_eq(SettlementProgress.building_stage(board, board.tiles[house]), 1)
	assert_eq(YearHeritage.age(s, house), 60)
	assert_true(not s["board"].has("settlement_progress"))


func test_each_ambition_awards_once_then_keeps_its_original_receipt_when_progress_falls() -> void:
	for goal: String in ["growth", "forest", "rice"]:
		var s: Dictionary = _year(goal)
		_eligible(s)
		assert_true(YearCheckpoint.valid(s))
		var report: Dictionary = YearGame.advance(s, 1)
		assert_true(report["events"].has("yearheritage.event.medal"))
		assert_eq(s["goal_medal"]["day"], 1)
		var receipt: Dictionary = s["goal_medal"].duplicate(true)
		s["population"] = 5
		assert_true(not YearGame.goal_met(s))
		assert_eq(YearHeritage.score_parts(s)["goal"], 250)
		report = YearGame.advance(s, 1)
		assert_true(not report["events"].has("yearheritage.event.medal"))
		assert_eq(s["goal_medal"], receipt)
		assert_true(YearCheckpoint.valid(s))


func test_none_has_no_medal_and_terminal_flood_cannot_earn_one_posthumously() -> void:
	var s: Dictionary = _year()
	YearGame.advance(s, 1)
	assert_eq(s["goal_medal"]["day"], 0)
	assert_eq(YearHeritage.score_parts(s)["goal"], 0)
	s = _year("forest")
	_eligible(s)
	for tile: Dictionary in s["board"]["tiles"]:
		tile["water"] = 10.0
	s["health"][s["structures"].find("hall")] = 10
	var report: Dictionary = YearGame.advance(s, 1)
	assert_eq(s["outcome"], "lost_hall")
	assert_eq(s["goal_medal"]["day"], 0)
	assert_true(not report["events"].has("yearheritage.event.medal"))
	assert_true(YearCheckpoint.valid(s))


func test_an_earlier_medal_contributes_once_to_loss_score_and_difficulty_multiplier() -> void:
	var s: Dictionary = YearGame.new_campaign(42, "rice", "water", "fisher", 5, true, true)
	_eligible(s)
	YearGame.advance(s, 1)
	s["population"] = 1
	s["resources"]["food"] = 0
	s["starvation"] = 2
	YearGame.advance(s, 1)
	assert_eq(s["outcome"], "lost_population")
	assert_eq(s["goal_medal"]["day"], 1)
	var parts: Dictionary = YearHeritage.score_parts(s)
	assert_eq(parts["goal"], 250)
	assert_eq(parts["multiplier"], 1.5)
	assert_eq(parts["base"], int(parts["people"]) + int(parts["food"]) + int(parts["challenges"]) + int(parts["project"]) + 250)
	assert_eq(s["score"], roundi(float(parts["base"]) * 1.5))
	assert_true(YearCheckpoint.valid(s))


func test_checkpoint_requires_complete_history_and_rejects_impossible_dates_and_medals() -> void:
	var good: Dictionary = _year()
	var house: int = good["structures"].find("house")
	var id: String = YearHeritage.key(good, house)
	for field: String in YearHeritage.FIELDS:
		var broken: Dictionary = good.duplicate(true)
		broken.erase(field)
		assert_true(not YearCheckpoint.valid(broken))
	for patch: Dictionary in [{"version": 2}, {"observed_day": 1}, {"evaluated_day": 30}, {"condition": "rich"}, {"candidate_periods": 2}, {"candidate": "thriving"}, {"hungry_days": 1}, {"buildings": {}}]:
		var broken: Dictionary = good.duplicate(true)
		broken["settlement_progress"].merge(patch, true)
		assert_true(not YearCheckpoint.valid(broken))
	for patch: Dictionary in [{"built_day": 1}, {"built_day": -1}, {"stage": 1}, {"stage": 3}, {"building": "hall"}]:
		var broken: Dictionary = good.duplicate(true)
		broken["settlement_progress"]["buildings"][id].merge(patch, true)
		assert_true(not YearCheckpoint.valid(broken))
	var awarded: Dictionary = _year("rice")
	_eligible(awarded)
	YearGame.advance(awarded, 1)
	for patch: Dictionary in [{"day": 2}, {"day": 0}, {"population": 5}, {"harvest": 179}, {"harvest": 181}, {"forests": 128}]:
		var broken: Dictionary = awarded.duplicate(true)
		broken["goal_medal"].merge(patch, true)
		assert_true(not YearCheckpoint.valid(broken))


func test_json_round_trip_preserves_age_receipt_float64_weather_and_reserved_job_prices() -> void:
	var s: Dictionary = _year("rice")
	_eligible(s)
	_fed(s)
	_days(s, 61)
	s["board"]["tiles"][0]["water"] = 0.123456789012345
	var parser: JSON = JSON.new()
	assert_eq(parser.parse(JSON.stringify(YearCheckpoint.envelope(s), "", true, true)), OK)
	var loaded: Dictionary = YearCheckpoint.decode(parser.data)["state"]
	assert_eq(loaded, s)
	for _day: int in range(7):
		assert_eq(YearGame.advance(loaded, 1), YearGame.advance(s, 1))
		assert_eq(loaded, s)


func test_future_and_mismatched_envelopes_leave_live_history_and_checkpoint_untouched() -> void:
	var session: YearSession = YearSession.new()
	session.save_path = PATH
	assert_eq(session.start_campaign(42, "none", "water", "farmer", 0, true, true), "")
	var before: Dictionary = session.year.duplicate(true)
	var future: Dictionary = YearCheckpoint.envelope(session.year)
	future["version"] = 4
	assert_eq(YearCheckpoint.decode(future)["error"], "msg.save_corrupt")
	future["version"] = 6
	var bytes: String = JSON.stringify(future)
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(bytes)
	file.close()
	assert_eq(session.load_year(), "msg.save_unsupported")
	assert_eq(session.start_campaign(73, "rice", "craft", "fisher", 5, true, true), "msg.save_unsupported")
	assert_eq(FileAccess.get_file_as_string(PATH), bytes)
	assert_eq(session.year, before)


func test_v5_full_year_and_flood_save_continue_exactly_with_earned_medal() -> void:
	var s: Dictionary = _year("forest")
	while int(s["day"]) < 242 and s["outcome"] == "running":
		YearProjectStrategy.plan(s)
		YearGame.advance(s, mini(7, 242 - int(s["day"])))
	assert_eq(s["day"], 242)
	var parser: JSON = JSON.new()
	assert_eq(parser.parse(JSON.stringify(YearCheckpoint.envelope(s), "", true, true)), OK)
	var decoded: Dictionary = YearCheckpoint.decode(parser.data)
	assert_eq(decoded["error"], "")
	var loaded: Dictionary = decoded["state"]
	while s["outcome"] == "running":
		YearProjectStrategy.plan(s)
		YearProjectStrategy.plan(loaded)
		assert_eq(YearGame.advance(s, 7), YearGame.advance(loaded, 7))
		assert_eq(s, loaded)
	assert_eq(s["day"], 365)
	assert_eq(s["outcome"], "won")
	assert_true(int(s["goal_medal"]["day"]) > 0)
	assert_eq(s["score"], YearHeritage.score_parts(s)["total"])
	assert_true(YearCheckpoint.valid(s))


func test_village_panel_and_building_location_are_read_only_in_both_languages() -> void:
	var s: Dictionary = _year("rice")
	_eligible(s)
	YearGame.advance(s, 1)
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var screen: YearScreen = _screen(s)
		var before: Dictionary = screen.session.year.duplicate(true)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		assert_true(screen._heritage_button.visible)
		assert_true(screen._heritage_goal.text.contains("1"))
		assert_true(screen._heritage_goal.text.contains("250"))
		assert_true(not screen._heritage_goal.text.contains("yearheritage."))
		var house: int = s["structures"].find("house")
		screen._heritage_buildings.get_node("BuildingAge_" + str(house)).pressed.emit()
		assert_eq(screen.selected, house)
		assert_true(screen._inspection.text.contains("1"))
		screen._refresh()
		assert_eq(screen.session.year, before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		assert_true(screen.session.undo_plans.is_empty())
		screen.free()


func test_new_year_ui_explicitly_starts_v5_but_loading_v4_does_not_migrate_it() -> void:
	var s: Dictionary = YearGame.new_campaign(73, "rice", "craft", "fisher", 5, true)
	var screen: YearScreen = _screen(s)
	assert_eq(screen.session.year["ruleset"], "year365_v4")
	assert_true(not screen._heritage_button.visible)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen.show_new_year()
	screen._restart.hide()
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen._new_year()
	assert_eq(screen.session.year["ruleset"], "year365_v5")
	assert_eq(screen.session.year["board"]["seed"], "73")
	assert_eq(screen.session.year["leader"], "fisher")
	assert_eq(screen.session.year["difficulty"], 5)
	assert_eq(screen.session.year["goal_medal"]["day"], 0)
	assert_eq(screen.session.last_save_error, "")
	screen.free()


func test_completion_dialog_breaks_down_real_score_and_cannot_advance_another_day() -> void:
	var s: Dictionary = _year("rice")
	_eligible(s)
	s["day"] = 360
	YearHeritage.after_day(s, [])
	s["day"] = 364
	YearHeritage.after_day(s, [])
	var screen: YearScreen = _screen(s)
	screen._advance(1)
	assert_eq(screen.session.year["day"], 365)
	assert_true(screen._result_dialog.visible)
	var parts: Dictionary = YearHeritage.score_parts(screen.session.year)
	assert_true(screen._result_total.text.contains(str(parts["total"])))
	assert_true(screen._result_values["goal"].text == "250")
	assert_true(screen._result_button.visible)
	var before: Dictionary = screen.session.year.duplicate(true)
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_ENTER
	screen._unhandled_key_input(event)
	assert_eq(screen.session.year, before)
	assert_eq(YearCheckpoint.decode(YearCheckpoint.envelope(before))["state"], before)
	screen.free()
