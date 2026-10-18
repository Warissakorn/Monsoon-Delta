extends TestCase
## Menu setup must not accidentally replace a normal run checkpoint.

const CHECKPOINT_PATH: String = "user://test_main_menu_checkpoint.json"


func before_each() -> void:
	SaveIO.delete_save(CHECKPOINT_PATH)
	Localization.setup("en")


func test_missing_checkpoint_hides_continue_and_text_seed_creates_config() -> void:
	var menu: MainMenu = _open_menu()
	assert_true(not menu._continue_button.visible)
	assert_eq(menu._difficulty_option.get_selected_id(), 0, "new villages default to the existing standard rules")
	var starts: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	menu._seed_input.text = "rain village"
	menu._leader_option.select(3)
	menu._seed_input.text_submitted.emit(menu._seed_input.text)
	assert_eq(starts.size(), 1)
	if not starts.is_empty():
		assert_eq(starts[0], {
			"seed": SeedUtil.parse_seed_text("rain village"), "leader": "soil_doctor",
			"map_type": "plains", "difficulty": 0,
			"run_mode": "classic", "village_goal": "none",
		})
	assert_true(not SaveIO.has_save(CHECKPOINT_PATH), "menu emits a request; it never saves a run")
	menu.free()


func test_valid_checkpoint_enables_continue_without_changing_file() -> void:
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 73}), CHECKPOINT_PATH), "")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
	var menu: MainMenu = _open_menu()
	assert_true(menu._continue_button.visible)
	var continued: Array[bool] = []
	menu.continue_requested.connect(func(): continued.append(true))
	menu._continue_button.pressed.emit()
	menu._show_page(menu._setup)
	menu._show_page(menu._home)
	assert_eq(continued.size(), 1)
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), before, "opening setup must not overwrite a save")
	menu.free()
	SaveIO.delete_save(CHECKPOINT_PATH)


func test_new_game_requires_confirmation_and_cancel_keeps_checkpoint() -> void:
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 74}), CHECKPOINT_PATH), "")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
	var menu: MainMenu = _open_menu()
	var starts: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	menu._seed_input.text = "99"
	menu._difficulty_option.select(7)
	menu._seed_input.text_submitted.emit("99")
	assert_true(menu._overwrite_dialog.visible, "Enter follows the same overwrite confirmation as Play")
	assert_eq(starts.size(), 0)
	menu._overwrite_dialog.canceled.emit()
	menu._overwrite_dialog.hide()
	menu._confirm_start()
	assert_eq(starts.size(), 0, "canceled requests must not start later")
	assert_eq(menu._difficulty_option.get_selected_id(), 7, "cancel keeps the chosen difficulty")
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), before)
	menu._request_start()
	menu._seed_input.text = "100"
	menu._difficulty_option.select(1)
	menu._request_start()
	menu._overwrite_dialog.confirmed.emit()
	assert_eq(starts.size(), 1)
	if not starts.is_empty():
		assert_eq(starts[0]["seed"], 99, "confirmation applies the exact configuration shown when requested")
		assert_eq(starts[0]["difficulty"], 7, "the overwrite dialog keeps the requested difficulty")
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), before, "only boot writes the replacement checkpoint")
	menu.free()
	SaveIO.delete_save(CHECKPOINT_PATH)


func test_each_difficulty_starts_the_selected_run_without_menu_checkpoint_writes() -> void:
	var menu: MainMenu = _open_menu()
	var starts: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	menu._leader_option.select(1)
	menu._run_mode_option.select(1)
	menu._goal_option.select(3)
	assert_eq(menu._difficulty_option.item_count, 11)
	for level: int in range(11):
		menu._difficulty_option.select(level)
		menu._difficulty_option.item_selected.emit(level)
		menu._request_start()
		assert_eq(starts.size(), level + 1)
		if starts.size() <= level:
			continue
		var state: GameState = GameFlow.new_game(starts[level])
		assert_true(state != null, "every displayed level is accepted by the runtime")
		if state != null:
			assert_eq(state.difficulty, level)
			assert_eq(state.leader, "carpenter")
			assert_eq(state.run_mode, "long")
			assert_eq(state.village_goal, "rice")
	assert_true(not SaveIO.has_save(CHECKPOINT_PATH), "previewing and requesting a run never saves it")
	menu.free()


func test_initial_difficulty_presets_the_menu_and_start_request() -> void:
	var menu: MainMenu = MainMenu.new()
	menu.save_path = CHECKPOINT_PATH
	menu.initial_difficulty = 10
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var starts: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	assert_eq(menu._difficulty_option.get_selected_id(), 10)
	menu._request_start()
	assert_eq(starts.size(), 1)
	if not starts.is_empty():
		assert_eq(starts[0]["difficulty"], 10)
	menu.free()


func test_cumulative_difficulty_values_are_localized_and_follow_selected_leader() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var menu: MainMenu = _open_menu()
		assert_true(menu._difficulty_option.custom_minimum_size.y >= 52)
		assert_eq(menu._difficulty_option.get_item_text(0), String(TranslationServer.translate("setup.difficulty_zero")))
		assert_true(menu._difficulty_description.text.contains(String(TranslationServer.translate("setup.difficulty_start")) % [6, 6]))
		for level: int in range(1, 11):
			assert_eq(menu._difficulty_option.get_item_text(level), String(TranslationServer.translate("setup.difficulty_level")) % level)
		menu._difficulty_option.select(10)
		menu._difficulty_option.item_selected.emit(10)
		var text: String = menu._difficulty_description.text
		assert_true(text.contains(String(TranslationServer.translate("setup.difficulty_score")) % 2.0))
		assert_true(text.contains(String(TranslationServer.translate("setup.difficulty_start")) % [4, 4]))
		assert_true(text.contains(String(TranslationServer.translate("setup.difficulty_rain")) % [1.21, 1.2]))
		assert_true(text.contains(String(TranslationServer.translate("setup.difficulty_range")) % 1.5))
		assert_true(text.contains(String(TranslationServer.translate("setup.difficulty_homes")) % [3, 4]))
		assert_true(text.contains(String(TranslationServer.translate("setup.difficulty_survival")) % [75.0, 0.15]))
		menu._leader_option.select(1)
		menu._leader_option.item_selected.emit(1)
		assert_true(menu._difficulty_description.text.contains(String(TranslationServer.translate("setup.difficulty_homes")) % [2, 3]), "carpenter discount is reflected in actual home costs")
		menu._run_mode_option.select(1)
		menu._run_mode_option.item_selected.emit(1)
		assert_eq(menu._difficulty_option.tooltip_text, menu._difficulty_description.text)
		assert_true(not menu._difficulty_description.text.contains("setup.difficulty_"), "every dynamic description is translated")
		menu.free()
	Localization.setup("en")


func test_level_six_explains_unchanged_rules_and_higher_score() -> void:
	var menu: MainMenu = _open_menu()
	menu._difficulty_option.select(5)
	menu._difficulty_option.item_selected.emit(5)
	var five: PackedStringArray = menu._difficulty_description.text.split("\n")
	menu._difficulty_option.select(6)
	menu._difficulty_option.item_selected.emit(6)
	var six: PackedStringArray = menu._difficulty_description.text.split("\n")
	assert_true(six[0].contains("1.6"))
	assert_true(five[0].contains("1.5"))
	for index: int in range(1, five.size()):
		assert_eq(six[index], five[index], "level 6 has the same current gameplay values as level 5")
	assert_eq(six[six.size() - 1], String(TranslationServer.translate("setup.difficulty_six")))
	menu.free()


func test_reading_difficulty_values_preserves_live_rng_state_data_and_checkpoint() -> void:
	var session: GameSession = GameSession.new()
	session.save_path = CHECKPOINT_PATH
	assert_eq(session.start({"seed": 73, "difficulty": 4}), "")
	var before: Dictionary = session.state.to_dict()
	var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
	var balance: Dictionary = DataDB.balance().duplicate(true)
	var menu: MainMenu = _open_menu()
	for level: int in range(11):
		menu._difficulty_option.select(level)
		menu._difficulty_option.item_selected.emit(level)
		menu._leader_option.select(level % MainMenu.LEADERS.size())
		menu._leader_option.item_selected.emit(menu._leader_option.selected)
		menu._run_mode_option.select(level % MainMenu.RUN_MODES.size())
		menu._run_mode_option.item_selected.emit(menu._run_mode_option.selected)
	assert_eq(session.state.to_dict(), before, "menu reads cannot advance the live run or RNG")
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), checkpoint)
	assert_eq(DataDB.balance(), balance, "the rule catalog remains read-only")
	menu.free()
	SaveIO.delete_save(CHECKPOINT_PATH)


func test_enter_from_seed_starts_at_turn_one_through_real_input_dispatch() -> void:
	var menu: MainMenu = _open_menu()
	var screens: Array[GameScreen] = []
	menu.start_requested.connect(func(config: Dictionary):
		var session: GameSession = GameSession.new()
		session.save_path = CHECKPOINT_PATH
		assert_eq(session.start(config), "")
		screens.append(_replace_menu_with_game(menu, session))
	)
	menu._show_page(menu._setup)
	menu._run_mode_option.select(1)
	menu._leader_option.select(1)
	menu._difficulty_option.select(6)
	menu._goal_option.select(1)
	menu._seed_input.text = "42"
	menu._seed_input.grab_focus()
	_dispatch_enter()
	assert_eq(screens.size(), 1, "Enter travels through the focused seed field and starts the game")
	if not screens.is_empty():
		var state: GameState = screens[0].session.state
		assert_eq(state.turn, 1, "the activation key must not also end the new game's first turn")
		assert_eq(state.to_dict(), GameFlow.new_game({"seed": 42, "leader": "carpenter", "difficulty": 6, "run_mode": "long", "village_goal": "growth"}).to_dict())
		assert_eq(SaveIO.load_game(CHECKPOINT_PATH)["state"].to_dict(), state.to_dict())
		screens[0].free()
	SaveIO.delete_save(CHECKPOINT_PATH)


func test_keyboard_continue_does_not_also_advance_the_loaded_run() -> void:
	var original: GameSession = GameSession.new()
	original.save_path = CHECKPOINT_PATH
	assert_eq(original.start({"seed": 42, "difficulty": 6, "run_mode": "long"}), "")
	var expected: Dictionary = original.state.to_dict()
	var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
	var menu: MainMenu = _open_menu()
	var screens: Array[GameScreen] = []
	menu.continue_requested.connect(func():
		var session: GameSession = GameSession.new()
		session.save_path = CHECKPOINT_PATH
		assert_eq(session.load_game(), "")
		screens.append(_replace_menu_with_game(menu, session))
	)
	menu._continue_button.grab_focus()
	_dispatch_enter()
	assert_eq(screens.size(), 1, "keyboard input activates the real Continue button")
	if not screens.is_empty():
		assert_eq(screens[0].session.state.to_dict(), expected, "the Continue key cannot advance the restored turn or RNG")
		assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), checkpoint)
		screens[0].free()
	SaveIO.delete_save(CHECKPOINT_PATH)


func _replace_menu_with_game(menu: MainMenu, session: GameSession) -> GameScreen:
	# Match Boot's synchronous replacement during the GUI event's propagation.
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.remove_child(menu)
	menu.queue_free()
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	screen.preferences_path = "user://test_menu_input_preferences.json"
	root.add_child(screen)
	screen.set_process(false)
	return screen


func _dispatch_enter() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func test_corrupt_checkpoint_hides_continue_and_reports_localized_error() -> void:
	var file: FileAccess = FileAccess.open(CHECKPOINT_PATH, FileAccess.WRITE)
	file.store_string("not a checkpoint")
	file.close()
	var menu: MainMenu = _open_menu()
	assert_true(not menu._continue_button.visible)
	assert_true(menu._error_panel.visible)
	assert_eq(menu._error_key, "msg.save_corrupt")
	assert_true(not SaveIO.has_save(CHECKPOINT_PATH))
	menu.free()


func _open_menu() -> MainMenu:
	var menu: MainMenu = MainMenu.new()
	menu.save_path = CHECKPOINT_PATH
	menu.language = "en"
	menu.initial_seed = 42
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	return menu
