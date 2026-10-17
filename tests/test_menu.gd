extends TestCase
## Menu setup must not accidentally replace a normal run checkpoint.

const CHECKPOINT_PATH: String = "user://test_main_menu_checkpoint.json"


func before_each() -> void:
	SaveIO.delete_save(CHECKPOINT_PATH)
	Localization.setup("en")


func test_missing_checkpoint_hides_continue_and_text_seed_creates_config() -> void:
	var menu: MainMenu = _open_menu()
	assert_true(not menu._continue_button.visible)
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
	menu._seed_input.text_submitted.emit("99")
	assert_true(menu._overwrite_dialog.visible, "Enter follows the same overwrite confirmation as Play")
	assert_eq(starts.size(), 0)
	menu._overwrite_dialog.canceled.emit()
	menu._overwrite_dialog.hide()
	menu._confirm_start()
	assert_eq(starts.size(), 0, "canceled requests must not start later")
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), before)
	menu._request_start()
	menu._seed_input.text = "100"
	menu._overwrite_dialog.confirmed.emit()
	assert_eq(starts.size(), 1)
	if not starts.is_empty():
		assert_eq(starts[0]["seed"], 99, "confirmation applies the exact configuration shown when requested")
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), before, "only boot writes the replacement checkpoint")
	menu.free()
	SaveIO.delete_save(CHECKPOINT_PATH)


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
