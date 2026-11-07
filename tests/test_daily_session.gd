extends TestCase

const PATH: String = "user://test-daily-prototype.json"


func before_each() -> void:
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _new_session() -> DailySession:
	var result: DailySession = DailySession.new()
	result.save_path = PATH
	assert_eq(result.start_prototype(), "")
	return result


func test_save_load_keeps_reservations_work_and_future_results_exact() -> void:
	var session: DailySession = _new_session()
	assert_eq(session.edit("order", "build_sawmill"), "")
	session.advance_days(1)
	assert_eq(session.last_save_error, "")
	var resumed: DailySession = DailySession.new()
	resumed.save_path = PATH
	assert_eq(resumed.load_prototype(), "")
	assert_eq(resumed.daily, session.daily)
	assert_eq(resumed.advance_days(7), session.advance_days(7))
	assert_eq(resumed.daily, session.daily)


func test_whole_plan_undo_redo_and_day_commit_boundary() -> void:
	var session: DailySession = _new_session()
	var initial: Dictionary = session.daily.duplicate(true)
	session.edit("order", "build_sawmill")
	var ordered: Dictionary = session.daily.duplicate(true)
	assert_true(session.undo_daily())
	assert_eq(session.daily, initial)
	assert_true(session.redo_daily())
	assert_eq(session.daily, ordered)
	assert_true(session.undo_daily())
	session.edit("order", "build_kiln")
	assert_true(not session.redo_daily(), "new orders clear redo")
	session.advance_days(1)
	assert_true(not session.undo_daily(), "cannot undo resolved days")


func test_failed_save_keeps_previous_file_and_accepts_retry() -> void:
	var session: DailySession = _new_session()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	assert_eq(session.edit("order", "build_sawmill"), "")
	assert_eq(session.last_save_error, "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_true(not session.daily["jobs"].is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	assert_eq(session.checkpoint_daily(), "")
	var resumed: DailySession = DailySession.new()
	resumed.save_path = PATH
	assert_eq(resumed.load_prototype(), "")
	assert_eq(resumed.daily, session.daily)


func test_unsupported_and_corrupt_files_are_preserved_on_load_and_restart() -> void:
	for content: String in ['{"format":"monsoon_delta_daily_prototype","version":99,"ruleset":"future"}', '{broken']:
		var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		var session: DailySession = DailySession.new()
		session.save_path = PATH
		assert_true(not session.load_prototype().is_empty())
		assert_true(session.daily.is_empty())
		assert_true(not session.start_prototype().is_empty())
		assert_eq(FileAccess.get_file_as_string(PATH), content)


func test_normal_checkpoint_is_never_used_by_daily_session() -> void:
	var session: DailySession = DailySession.new()
	assert_eq(session.save_path, DailySession.DAILY_PATH)
	session.save_path = SaveIO.DEFAULT_PATH
	var existed: bool = FileAccess.file_exists(SaveIO.DEFAULT_PATH)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveIO.DEFAULT_PATH) if existed else PackedByteArray()
	assert_eq(session.start_prototype(), "msg.save_failed")
	assert_eq(FileAccess.file_exists(SaveIO.DEFAULT_PATH), existed)
	if existed:
		assert_eq(FileAccess.get_file_as_bytes(SaveIO.DEFAULT_PATH), bytes)


func test_checkpoint_rejects_malformed_jobs_numbers_and_duplicate_rewards() -> void:
	var initial: Dictionary = DailyProduction.new_state()
	var corruptions: Array = [
		{"day": 1.5}, {"knowledge": -1}, {"day": 366}, {"claimed": ["planks", "planks"]},
		{"outcome": "won"}, {"jobs": [{"id": "unknown"}]},
		{"resources": {"food": "many"}}, {"buildings": []},
	]
	for changes: Dictionary in corruptions:
		var state: Dictionary = initial.duplicate(true)
		state.merge(changes, true)
		assert_eq(DailyCheckpoint.decode(DailyCheckpoint.envelope(state))["error"], "msg.save_corrupt")
	var valid: Dictionary = initial.duplicate(true)
	DailyProduction.order(valid, "build_sawmill")
	assert_eq(DailyCheckpoint.decode(DailyCheckpoint.envelope(valid))["error"], "")
	valid["jobs"][0]["progress"] = 1000
	assert_eq(DailyCheckpoint.decode(DailyCheckpoint.envelope(valid))["error"], "msg.save_corrupt")
	for value: Variant in [null, [], 1, "bad", {"format": [], "ruleset": {}}]:
		assert_eq(DailyCheckpoint.decode(value)["error"], "msg.save_corrupt")


func test_paused_job_and_reward_state_resume_without_reapplying() -> void:
	var session: DailySession = _new_session()
	session.edit("order", "build_sawmill")
	session.advance_days(7)
	session.edit("order", "saw_planks", 3)
	session.advance_days(7)
	session.edit("pause", "saw_planks")
	var resumed: DailySession = DailySession.new()
	resumed.save_path = PATH
	assert_eq(resumed.load_prototype(), "")
	assert_eq(resumed.daily, session.daily)
	assert_true(resumed.daily["jobs"][0]["paused"])
	assert_eq(resumed.daily["knowledge"], 1)


func test_screen_reads_preview_without_mutation_and_rejects_double_advance() -> void:
	Localization.setup("th")
	var session: DailySession = _new_session()
	session.edit("order", "build_sawmill")
	var before: Dictionary = session.daily.duplicate(true)
	var screen: DailyScreen = DailyScreen.new()
	screen.session = session
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	assert_eq(session.daily, before)
	assert_eq(screen._orders.size(), DailyProduction.config()["jobs"].size())
	screen._advance(1)
	screen._advance(1)
	assert_eq(session.daily["day"], 1)
	assert_true(screen._summary.text.contains("วัน 1/30"))
	screen.free()
	Localization.setup("en")
