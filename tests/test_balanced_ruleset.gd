extends TestCase

const PATH: String = "user://tests-balanced-v1.json"

func before_each() -> void:
	SaveIO.delete_save(PATH)
	Localization.setup("en")

func test_balanced_rules_are_opt_in_and_level_six_has_real_extra_rain() -> void:
	var old: GameState = GameFlow.new_game({"seed":42,"difficulty":7})
	assert_eq(old.population, 4)
	assert_eq(old.food, 4)
	var lower: GameState = GameFlow.new_game({"seed":42,"difficulty":5,"ruleset":"balanced_v1"})
	var higher: GameState = GameFlow.new_game({"seed":42,"difficulty":6,"ruleset":"balanced_v1"})
	var next: GameState = GameFlow.new_game({"seed":42,"difficulty":7,"ruleset":"balanced_v1"})
	assert_near(float(higher.mod("rain_inflow_multiplier")),float(lower.mod("rain_inflow_multiplier"))*1.1,1e-12)
	assert_eq(next.population, higher.population)
	assert_eq(next.food, higher.food - 2)
	assert_true(float(next.mod("food_per_person")) >= float(higher.mod("food_per_person")))
	assert_eq(lower.population, 6)
	assert_eq(lower.food, 70)
	assert_eq(GameState.from_dict(higher.to_dict()).to_dict(), higher.to_dict())

func test_v7_load_preview_and_next_turn_match_exactly_without_migrating_legacy() -> void:
	for mode: String in ["classic", "long"]:
		var session: GameSession = GameSession.new()
		session.save_path = PATH
		assert_eq(session.start({"seed":42,"ruleset":"balanced_v1","living_village":true,"difficulty":6,"run_mode":mode}), "")
		var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		assert_eq(int(envelope["version"]), 7)
		var loaded: GameSession = GameSession.new()
		loaded.save_path = PATH
		assert_eq(loaded.load_game(), "")
		assert_eq(loaded.state.to_dict(), session.state.to_dict())
		var preview: Dictionary = GameFlow.preview(loaded.state)
		assert_eq(loaded.state.to_dict(), session.state.to_dict())
		session.advance_turn()
		loaded.advance_turn()
		assert_eq(loaded.state.to_dict(), session.state.to_dict())
		assert_eq(loaded.state.get_tile(Vector2i.ZERO).water, preview["state"].get_tile(Vector2i.ZERO).water)
		var old: GameState = GameFlow.new_game({"seed":42,"difficulty":6})
		assert_eq(SaveIO.save(old, PATH), "")
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		assert_eq(SaveIO.save(SaveIO.load_game(PATH)["state"], PATH), "")
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		assert_eq(SaveIO.load_game(PATH)["state"].ruleset, "legacy")

func test_future_version_is_preserved_and_v7_rejects_wrong_ruleset() -> void:
	var s: GameState = GameFlow.new_game({"seed":42,"ruleset":"balanced_v1"})
	assert_eq(SaveIO.save(s, PATH), "")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	data["version"] = 8
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var original: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	assert_eq(SaveIO.load_game(PATH)["error"], "msg.save_unsupported")
	assert_eq(FileAccess.get_file_as_bytes(PATH), original)
	data["version"] = 7
	data["state"].erase("ruleset")
	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	assert_eq(SaveIO.load_game(PATH)["error"], "msg.save_corrupt")

func test_menu_preserves_balanced_choice_in_language_draft_and_sends_ruleset() -> void:
	var menu: MainMenu = MainMenu.new()
	menu.save_path = PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	menu._balanced_toggle.button_pressed = true
	menu._difficulty_option.select(6)
	var draft: Dictionary = menu.setup_draft()
	assert_true(menu._bracing_toggle.disabled and menu._moisture_toggle.disabled and menu._irrigation_toggle.disabled)
	var requests: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): requests.append(config))
	menu._request_start()
	assert_eq(requests[0]["ruleset"], "balanced_v1")
	menu.free()
	Localization.setup("th")
	menu = MainMenu.new()
	menu.save_path = PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	menu.restore_setup_draft(draft)
	assert_true(menu._balanced_toggle.button_pressed)
	assert_eq(menu._difficulty_description.text, DifficultyInfo.description(6,"farmer","classic","balanced_v1"))
	menu.free()
	Localization.setup("en")


func test_bot_preview_without_animation_matches_state_and_policy_score() -> void:
	for ruleset: String in ["legacy", "balanced_v1", "moisture_irrigation_v1"]:
		var s: GameState = GameFlow.new_game({"seed":42,"ruleset":ruleset})
		var original: Dictionary = s.to_dict()
		var animated: Dictionary = GameFlow.preview(s)
		var fast: Dictionary = GameFlow.preview(s, false)
		assert_eq(animated["state"].to_dict(), fast["state"].to_dict())
		assert_eq(BotGreedy.score_preview(animated, BotGreedy.configuration()["weights"]), BotGreedy.score_preview(fast, BotGreedy.configuration()["weights"]))
		assert_true(fast["report"].snapshots.is_empty())
		assert_eq(s.to_dict(), original)
