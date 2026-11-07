extends TestCase

const PATH: String = "user://tests-year365.json"


func before_each() -> void:
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _session() -> YearSession:
	var result: YearSession = YearSession.new()
	result.save_path = PATH
	assert_eq(result.start_year(42), "")
	return result


func test_mid_season_checkpoint_and_every_future_result_are_exact() -> void:
	var session: YearSession = _session()
	while int(session.year["day"]) < 242 and session.year["outcome"] == "running":
		YearStrategy.plan(session.year)
		session.advance_year(mini(7, 242 - int(session.year["day"])))
	assert_eq(session.year["day"], 242)
	assert_eq(session.last_save_error, "")
	var loaded: YearSession = YearSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_year(), "")
	assert_eq(loaded.year, session.year)
	for count: int in range(10):
		YearStrategy.plan(session.year)
		YearStrategy.plan(loaded.year)
		assert_eq(loaded.advance_year(7), session.advance_year(7))
		assert_eq(loaded.year, session.year)
	while loaded.year["outcome"] == "running":
		YearStrategy.plan(loaded.year)
		loaded.advance_year(7)
		assert_eq(loaded.last_save_error, "")
	assert_eq(loaded.year["day"], 365)
	assert_eq(loaded.year["outcome"], "won")
	var finished: YearSession = YearSession.new()
	finished.save_path = PATH
	assert_eq(finished.load_year(), "")
	assert_eq(finished.year, loaded.year)
	assert_eq(finished.advance_year(7)["days"], 0)


func test_planning_undo_redo_restores_reserved_materials_and_research() -> void:
	var session: YearSession = _session()
	var before: Dictionary = session.year.duplicate(true)
	var index: int = YearStrategy.target(session.year, "build_sawmill")
	assert_eq(session.edit_year("order", "build_sawmill", index), "")
	var ordered: Dictionary = session.year.duplicate(true)
	assert_true(session.undo_year())
	assert_eq(session.year, before)
	assert_true(session.redo_year())
	assert_eq(session.year, ordered)
	session.advance_year(1)
	assert_true(not session.undo_year())
	assert_eq(session.last_save_error, "")


func test_write_failure_preserves_previous_bytes_and_live_plan_can_retry() -> void:
	var session: YearSession = _session()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	assert_eq(session.edit_year("order", "forage", YearStrategy.target(session.year, "forage"), 1, true), "")
	assert_eq(session.last_save_error, "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	assert_eq(session.checkpoint_year(), "")
	var loaded: YearSession = YearSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_year(), "")
	assert_eq(loaded.year, session.year)


func test_future_and_corrupt_saves_are_preserved_even_on_new_year() -> void:
	for text: String in ['{"format":"monsoon_year","version":99,"ruleset":"future"}', '{broken']:
		var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		var session: YearSession = YearSession.new()
		session.save_path = PATH
		assert_true(not session.load_year().is_empty())
		assert_true(session.year.is_empty())
		assert_true(not session.start_year().is_empty())
		assert_eq(FileAccess.get_file_as_string(PATH), text)


func test_year_cannot_overwrite_normal_or_prototype_checkpoint() -> void:
	for path: String in [SaveIO.DEFAULT_PATH, DailySession.DAILY_PATH]:
		var session: YearSession = YearSession.new()
		session.save_path = path
		var exists: bool = FileAccess.file_exists(path)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path) if exists else PackedByteArray()
		assert_eq(session.start_year(), "msg.save_failed")
		assert_eq(FileAccess.file_exists(path), exists)
		if exists:
			assert_eq(FileAccess.get_file_as_bytes(path), bytes)


func test_checkpoint_rejects_invalid_queues_weather_and_spatial_arrays() -> void:
	var initial: Dictionary = YearGame.new_game(42)
	var cases: Array = [{"day": 365}, {"day": 1.5}, {"population": -1}, {"research": ["water3"]}, {"claimed": ["flood", "flood"]}, {"health": []}, {"weather": []}, {"jobs": [{"id": "unknown"}]}, {"outcome": "won"}]
	for change: Dictionary in cases:
		var s: Dictionary = initial.duplicate(true)
		s.merge(change, true)
		assert_true(not YearCheckpoint.valid(s))
	var changed_weather: Dictionary = initial.duplicate(true)
	changed_weather["weather"][0] = 1000
	assert_true(not YearCheckpoint.valid(changed_weather))
	for value: Variant in [null, [], 1, {"format": [], "ruleset": {}}]:
		assert_eq(YearCheckpoint.decode(value)["error"], "msg.save_corrupt")


func test_ui_refresh_and_risk_preview_do_not_advance_the_run() -> void:
	Localization.setup("th")
	var session: YearSession = _session()
	var before: Dictionary = session.year.duplicate(true)
	var screen: YearScreen = YearScreen.new()
	screen.session = session
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	assert_eq(session.year, before)
	screen._preview.button_pressed = true
	screen._refresh()
	assert_eq(session.year, before)
	screen._advance(1)
	screen._advance(1)
	assert_eq(session.year["day"], 1)
	assert_true(screen._status.text.contains("วัน 1/365"))
	screen.free()
	Localization.setup("en")
