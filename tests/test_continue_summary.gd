extends TestCase
## Resume details describe a validated checkpoint without changing the run.

const DIRECTORY: String = "user://tests/continue_summary"
const PATH: String = DIRECTORY + "/checkpoint.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for path: String in [PATH, PATH + ".tmp", DIRECTORY + "/blocked"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)
	Localization.setup("en")


func _save(state: GameState) -> PackedByteArray:
	assert_eq(SaveIO.save(state, PATH), "")
	return FileAccess.get_file_as_bytes(PATH)


func _open(language: String = "en", school: bool = false) -> MainMenu:
	Localization.setup(language)
	var menu: MainMenu = MainMenu.new()
	menu.save_path = PATH
	menu.language = language
	menu.initial_seed = 999
	menu.initial_school = school
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	return menu


func test_planning_details_use_saved_choices_and_resources_in_both_languages() -> void:
	var state: GameState = GameFlow.new_game({"seed": 73, "leader": "fisher", "difficulty": 7, "run_mode": "long", "village_goal": "forest"})
	var snapshot: Dictionary = state.to_dict()
	var bytes: PackedByteArray = _save(state)
	for language: String in ["en", "th"]:
		var menu: MainMenu = _open(language)
		assert_true(menu._continue_group.is_visible_in_tree())
		var text: String = menu._continue_summary.text
		assert_true(text.contains("Year 1/10 · Dry season · Turn 1/6" if language == "en" else "ปี 1/10 · ฤดูแล้ง · เทิร์น 1/6"))
		assert_true(text.contains("Long run · 10 years · Fisher · Difficulty 7" if language == "en" else "ระยะยาว · 10 ปี · ชาวประมง · ความยาก 7"))
		assert_true(text.contains(String(TranslationServer.translate("menu.continue_resources")) % [state.population, state.food, state.wood]))
		assert_true(menu._continue_button.tooltip_text.contains("73"))
		assert_true(menu._continue_button.tooltip_text.contains(String(TranslationServer.translate("goal.forest.name"))))
		menu._show_page(menu._setup)
		menu._seed_input.text = "different village"
		menu._leader_option.select(1)
		menu._difficulty_option.select(0)
		menu._run_mode_option.select(0)
		menu._show_page(menu._home)
		assert_eq(menu._continue_summary.text, text, "new-game choices cannot relabel the saved village")
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		assert_eq(state.to_dict(), snapshot, "formatting does not change the live run or RNG")
		menu.free()


func test_every_supported_envelope_displays_without_migration_or_rng_changes() -> void:
	var configurations: Array[Dictionary] = [
		{}, {"run_mode": "long"}, {"living_village": true},
		{"ruleset": "bracing_v1"}, {"ruleset": "moisture_v1"},
		{"ruleset": "bracing_moisture_irrigation_v1"},
	]
	for index: int in range(configurations.size()):
		var config: Dictionary = configurations[index].duplicate(true)
		config["seed"] = 9223372036854775807
		var state: GameState = GameFlow.new_game(config)
		assert_true(state != null)
		if state == null:
			continue
		var snapshot: Dictionary = state.to_dict()
		var bytes: PackedByteArray = _save(state)
		assert_eq(int(JSON.parse_string(bytes.get_string_from_utf8())["version"]), index + 1)
		var menu: MainMenu = _open()
		assert_true(menu._continue_group.is_visible_in_tree(), "envelope v%d" % (index + 1))
		assert_true(menu._continue_summary.text.contains("Year 1/%d" % state.target_years()))
		assert_true(menu._continue_button.tooltip_text.contains("9223372036854775807"), "seed stays an exact int64 string")
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes, "opening a legacy save does not rewrite it")
		assert_eq(SaveIO.load_game(PATH)["state"].to_dict(), snapshot)
		menu.free()


func test_real_turns_show_the_pending_season_and_harvest_without_reapplying_effects() -> void:
	var session: GameSession = GameSession.new()
	session.save_path = PATH
	assert_eq(session.start({"seed": 1}), "")
	for turn: int in range(C.DRY_TURNS):
		assert_true(session.advance_turn() != null)
	assert_eq(session.state.phase, C.Phase.PLANNING)
	assert_true(session.state.is_rain())
	var menu: MainMenu = _open()
	assert_true(menu._continue_summary.text.contains("Year 1/5 · Rainy season · Turn 4/6"))
	menu.free()
	for turn: int in range(C.TURNS_PER_YEAR - C.DRY_TURNS):
		assert_true(session.advance_turn() != null)
	assert_eq(session.state.phase, C.Phase.HARVEST)
	var snapshot: Dictionary = session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var history: Array[Dictionary] = session.turn_history()
	for language: String in ["en", "th"]:
		menu = _open(language)
		assert_true(menu._continue_summary.text.begins_with("Year 1/5 · Harvest summary" if language == "en" else "ปี 1/5 · สรุปเก็บเกี่ยว"))
		assert_true(not menu._continue_summary.text.contains("Turn 6/6"))
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		assert_eq(SaveIO.load_game(PATH)["state"].to_dict(), snapshot)
		assert_eq(session.state.to_dict(), snapshot)
		assert_eq(session.turn_history(), history)
		menu.free()


func test_failed_refresh_clears_stale_details_and_preserves_an_unsupported_file() -> void:
	_save(GameFlow.new_game({"seed": 42}))
	var menu: MainMenu = _open()
	assert_true(not menu._continue_summary.text.is_empty())
	var unsupported: String = '{"format":"monsoon_save","version":999}'
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(unsupported)
	file.close()
	menu._validate_checkpoint()
	assert_true(not menu._continue_group.visible)
	assert_true(not menu._continue_button.visible)
	assert_eq(menu._continue_summary.text, "")
	assert_eq(menu._continue_button.tooltip_text, "")
	assert_eq(menu._error_key, "msg.save_unsupported")
	assert_eq(FileAccess.get_file_as_string(PATH), unsupported)
	assert_eq(menu._new_game_button.theme_type_variation, &"QuietButton")
	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("broken checkpoint")
	file.close()
	menu._validate_checkpoint()
	assert_eq(menu._error_key, "msg.save_corrupt")
	assert_true(not menu._continue_group.visible)
	assert_eq(menu._continue_summary.text, "")
	assert_true(not FileAccess.file_exists(PATH), "the existing corrupt-save policy is retained")
	menu.free()


func test_missing_and_directory_paths_never_display_resume_details() -> void:
	var menu: MainMenu = _open()
	assert_true(not menu._continue_group.visible)
	assert_eq(menu._continue_summary.text, "")
	var blocked: String = DIRECTORY + "/blocked"
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocked)), OK)
	menu.save_path = blocked
	menu._validate_checkpoint()
	assert_true(not menu._continue_button.visible)
	assert_true(not menu._continue_group.visible)
	assert_eq(menu._continue_button.tooltip_text, "")
	assert_eq(menu._error_key, "msg.save_failed")
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(blocked)))
	menu.free()
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked)), OK)


func test_direct_school_waits_until_return_home_to_describe_the_checkpoint() -> void:
	var bytes: PackedByteArray = _save(GameFlow.new_game({"seed": 73, "run_mode": "long"}))
	var menu: MainMenu = _open("en", true)
	assert_true(menu._school.is_visible_in_tree())
	assert_true(not menu._continue_group.visible)
	assert_eq(menu._continue_summary.text, "")
	menu._return_from_school()
	assert_true(menu._continue_group.is_visible_in_tree())
	assert_true(menu._continue_summary.text.contains("Year 1/10"))
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	menu.free()


func test_refresh_replaces_the_old_resume_details_from_the_new_checkpoint() -> void:
	_save(GameFlow.new_game({"seed": 73}))
	var menu: MainMenu = _open()
	var previous: String = menu._continue_summary.text
	var state: GameState = GameFlow.new_game({"seed": -17, "run_mode": "long", "leader": "carpenter", "difficulty": 3})
	var bytes: PackedByteArray = _save(state)
	menu._validate_checkpoint()
	assert_true(menu._continue_summary.text != previous)
	assert_true(menu._continue_summary.text.contains("Long run · 10 years · Carpenter · Difficulty 3"))
	assert_true(menu._continue_button.tooltip_text.contains("Saved seed: -17"))
	assert_true(not menu._continue_button.tooltip_text.contains("Saved seed: 73"))
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	menu.free()
