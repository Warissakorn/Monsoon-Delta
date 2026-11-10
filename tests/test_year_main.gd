extends TestCase

const PATH: String = "user://tests-year-main.json"
const NORMAL: String = "user://tests-year-main-normal.json"


func before_each() -> void:
	for path: String in [PATH, PATH + ".tmp", NORMAL]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Localization.setup("en")


func test_main_menu_describes_year_without_changing_either_checkpoint() -> void:
	var session: YearSession = YearSession.new()
	session.save_path = PATH
	assert_eq(session.start_year(73, "forest", "water"), "")
	session.advance_year(1)
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 42}), NORMAL), "")
	var year_bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var normal_bytes: PackedByteArray = FileAccess.get_file_as_bytes(NORMAL)
	var menu: MainMenu = MainMenu.new()
	menu.save_path = NORMAL
	menu.year_save_path = PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var summary: Label = menu.find_child("YearContinueSummary", true, false) as Label
	assert_true(summary != null)
	assert_true(summary.text.contains("Day 1/365"))
	assert_true(menu.find_child("FullYearGame", true, false) != null)
	assert_true(menu.find_child("NewFullYearGame", true, false) != null)
	assert_eq(FileAccess.get_file_as_bytes(PATH), year_bytes)
	assert_eq(FileAccess.get_file_as_bytes(NORMAL), normal_bytes)
	menu.free()


func test_new_year_setup_can_be_cancelled_without_creating_a_checkpoint() -> void:
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.save_path = PATH
	screen.initial_setup = true
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	assert_true(screen._restart.visible)
	assert_true(screen.session.year.is_empty())
	assert_true(not FileAccess.file_exists(PATH))
	screen._restart.hide()
	assert_true(not FileAccess.file_exists(PATH))
	screen._seed.text = "73"
	screen._goal.select(2)
	screen._project.select(1)
	screen._new_year()
	assert_eq(screen.session.year["board"]["seed"], "73")
	assert_eq(screen.session.year["goal"], "forest")
	assert_eq(screen.session.year["project"], "water")
	assert_eq(screen.session.year["structures"].size(), 127)
	assert_eq(screen.session.last_save_error, "")
	screen.free()


func test_history_tracks_real_resource_changes_and_is_detached_from_planning_and_saves() -> void:
	var session: YearSession = YearSession.new()
	session.save_path = PATH
	assert_eq(session.start_year(42, "none", "food"), "")
	assert_eq(session.edit_year("order", "forage", YearStrategy.target(session.year, "forage"), 1, true), "")
	var before: Dictionary = session.year["resources"].duplicate(true)
	var report: Dictionary = session.advance_year(7)
	assert_true(int(report["days"]) > 0)
	assert_eq(session.daily_history.size(), 1)
	var history: Dictionary = session.daily_history.duplicate(true)[0]
	assert_eq(history["before"], before)
	assert_eq(history["after"], session.year["resources"])
	for resource: String in YearGame.resources(session.year):
		assert_eq(int(history["before"][resource]) + int(history["delta"][resource]), history["after"][resource])
	session.year["resources"]["wood"] += 1
	assert_eq(session.daily_history[0], history)
	assert_eq(session.advance_year(0)["days"], 0)
	assert_eq(session.daily_history.size(), 1)
	assert_eq(session.load_year(), "")
	assert_true(session.daily_history.is_empty())


func test_rejected_restart_keeps_live_run_and_future_save_untouched() -> void:
	var session: YearSession = YearSession.new()
	session.save_path = PATH
	assert_eq(session.start_year(42, "none", "food"), "")
	var live: Dictionary = session.year.duplicate(true)
	var future: String = '{"format":"monsoon_year","version":99,"ruleset":"future"}'
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(future)
	file.close()
	assert_eq(session.start_year(73, "forest", "water"), "msg.save_unsupported")
	assert_eq(session.year, live)
	assert_eq(FileAccess.get_file_as_string(PATH), future)


func test_advancing_warns_for_idle_workers_and_preview_does_not_commit() -> void:
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.save_path = PATH
	assert_eq(screen.session.start_year(42, "none", "food"), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	var before: Dictionary = screen.session.year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var preferences: Dictionary = GamePreferences.read()
	assert_eq(GamePreferences.write({"confirm_unused_labor": true}), "")
	screen._request_advance(7)
	assert_true(screen._advance_confirmation.visible)
	assert_eq(screen.session.year, before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen._advance_confirmation.hide()
	screen._advance_confirmation.confirmed.emit()
	assert_true(int(screen.session.year["day"]) > 0)
	assert_eq(screen.session.daily_history.size(), 1)
	var day: int = int(screen.session.year["day"])
	screen._advance(7)
	assert_eq(screen.session.year["day"], day, "rapid confirmation cannot advance twice")
	assert_eq(GamePreferences.write({"confirm_unused_labor": preferences["confirm_unused_labor"]}), "")
	screen.free()


func test_campaign_profiles_preview_and_checkpoint_continue_exactly() -> void:
	for leader: String in MainMenu.LEADERS:
		for difficulty: int in [0, 10]:
			var session: YearSession = YearSession.new()
			session.save_path = PATH
			assert_eq(session.start_campaign(73, "rice", "water", leader, difficulty), "")
			assert_eq(YearCheckpoint.envelope(session.year)["version"], 3)
			var expected: Dictionary = YearGame.preview(session.year)
			var loaded: YearSession = YearSession.new()
			loaded.save_path = PATH
			assert_eq(loaded.load_year(), "")
			assert_true(loaded.year == session.year, "loaded initial state " + leader + str(difficulty))
			assert_eq(loaded.advance_year(1), session.advance_year(1))
			for key: String in session.year:
				assert_true(session.year[key] == expected["state"][key], "preview key " + key + " " + leader + str(difficulty))
			for key: String in session.year:
				assert_true(loaded.year[key] == session.year[key], "loaded committed key " + key + " " + leader + str(difficulty))
			var corrupt: Dictionary = YearCheckpoint.envelope(session.year)
			corrupt["state"]["difficulty"] = 11
			assert_eq(YearCheckpoint.decode(corrupt)["error"], "msg.save_corrupt")
			corrupt = YearCheckpoint.envelope(session.year)
			corrupt["state"]["leader"] = "unknown"
			assert_eq(YearCheckpoint.decode(corrupt)["error"], "msg.save_corrupt")


func test_campaign_bonuses_do_not_change_legacy_year_rules() -> void:
	var legacy: Dictionary = YearGame.new_expanded(42)
	var legacy_config: Dictionary = YearGame.config(legacy).duplicate(true)
	var fisher: Dictionary = YearGame.new_campaign(42, "none", "food", "fisher", 10)
	assert_eq(YearGame.outputs(fisher, "fish")["food"], YearGame.outputs(legacy, "fish")["food"] + 1)
	var carpenter: Dictionary = YearGame.new_campaign(42, "none", "food", "carpenter")
	assert_eq(YearGame.config(carpenter)["jobs"]["build_house"]["inputs"]["wood"], int(legacy_config["jobs"]["build_house"]["inputs"]["wood"]) - 1)
	var doctor: Dictionary = YearGame.new_campaign(42, "none", "food", "soil_doctor")
	assert_eq(YearGame.config(doctor)["jobs"]["fill"]["days"], int(legacy_config["jobs"]["fill"]["days"]) - 1)
	assert_eq(YearGame.config(legacy), legacy_config)
	assert_eq(YearWeather.inflow(fisher, 0), YearWeather.inflow(legacy, 0) * 1.5)
	assert_eq(YearWeather.forecast(fisher)[0]["inflow"], YearWeather.inflow(fisher, 0))
	assert_eq(YearCheckpoint.envelope(legacy)["version"], 2)
	assert_eq(YearCheckpoint.decode(YearCheckpoint.envelope(legacy))["state"], legacy)


class YearBoot extends "res://ui/boot.gd":
	func _ready() -> void:
		pass


func test_language_change_preserves_live_year_history_and_setup_draft() -> void:
	var settings: Dictionary = GamePreferences.read()
	var boot: YearBoot = YearBoot.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(boot)
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.save_path = PATH
	assert_eq(screen.session.start_campaign(73, "forest", "water", "fisher", 5), "")
	screen.session.advance_year(1)
	boot._language = "en"
	boot._replace_screen(screen)
	screen._seed.text = "หมู่บ้าน 73"
	screen._leader.select(2)
	screen._difficulty.value = 7
	screen._group.select(1)
	screen._populate_actions()
	screen._batches.value = 3
	screen._preview.button_pressed = true
	var draft: Dictionary = screen.ui_draft()
	var state: Dictionary = screen.session.year.duplicate(true)
	var history: Array[Dictionary] = screen.session.daily_history.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	boot._change_year_language()
	screen = boot._screen as YearScreen
	assert_eq(screen.ui_draft(), draft)
	assert_eq(screen.session.year, state)
	assert_eq(screen.session.daily_history, history)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_true(screen._history.text.contains("วันที่"))
	boot.free()
	assert_eq(GamePreferences.write(settings), "")
	Localization.setup("en")


func test_campaign_survives_full_year_and_replays_after_flood_save() -> void:
	var session: YearSession = YearSession.new()
	session.save_path = PATH
	assert_eq(session.start_campaign(42, "forest", "water", "farmer", 0), "")
	while int(session.year["day"]) < 242 and session.year["outcome"] == "running":
		YearProjectStrategy.plan(session.year)
		session.advance_year(mini(7, 242 - int(session.year["day"])))
	assert_eq(session.year["day"], 242)
	var loaded: YearSession = YearSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_year(), "")
	while session.year["outcome"] == "running":
		YearProjectStrategy.plan(session.year)
		YearProjectStrategy.plan(loaded.year)
		assert_eq(loaded.advance_year(7), session.advance_year(7))
		assert_true(loaded.year == session.year, "same future state after flood load")
	assert_eq(session.year["day"], 365)
	assert_eq(session.year["outcome"], "won")
	assert_eq(session.year["score"], YearGame.score(session.year))
	assert_eq(session.advance_year(1)["days"], 0)
	assert_eq(loaded.load_year(), "")
	assert_eq(loaded.year, session.year)
