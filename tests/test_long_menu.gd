extends TestCase
## New run choices are explicit and keep checkpoints protected until boot starts.

const CHECKPOINT_PATH: String = "user://test_long_menu_checkpoint.json"


func before_each() -> void:
	SaveIO.delete_save(CHECKPOINT_PATH)
	Localization.setup("en")


func test_default_run_keeps_classic_length_and_no_optional_goal() -> void:
	var menu: MainMenu = _open_menu()
	var starts: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	menu._request_start()
	assert_eq(starts.size(), 1)
	if not starts.is_empty():
		assert_eq(starts[0]["run_mode"], "classic")
		assert_eq(starts[0]["village_goal"], "none")
	assert_true(not SaveIO.has_save(CHECKPOINT_PATH))
	menu.free()


func test_each_goal_can_start_a_long_run_with_the_selected_leader_and_seed() -> void:
	var menu: MainMenu = _open_menu()
	var starts: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	menu._show_page(menu._setup)
	menu._run_mode_option.select(1)
	menu._run_mode_option.item_selected.emit(1)
	menu._leader_option.select(2)
	menu._seed_input.text = "long monsoon"
	for goal_index: int in range(MainMenu.GOALS.size()):
		menu._goal_option.select(goal_index)
		menu._goal_option.item_selected.emit(goal_index)
		menu._request_start()
		assert_eq(starts.size(), goal_index + 1)
		if starts.size() <= goal_index:
			continue
		assert_eq(starts[goal_index], {
			"seed": SeedUtil.parse_seed_text("long monsoon"),
			"leader": "fisher", "map_type": "plains", "difficulty": 0,
			"run_mode": "long", "village_goal": MainMenu.GOALS[goal_index],
		})
	assert_true(not SaveIO.has_save(CHECKPOINT_PATH), "choosing a mode or goal never writes a save")
	menu.free()


func test_cancel_keeps_run_choices_and_checkpoint_then_confirm_uses_requested_choices() -> void:
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 74}), CHECKPOINT_PATH), "")
	var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
	var menu: MainMenu = _open_menu()
	var starts: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	menu._run_mode_option.select(1)
	menu._goal_option.select(2)
	menu._request_start()
	assert_true(menu._overwrite_dialog.visible)
	assert_eq(starts.size(), 0)
	menu._overwrite_dialog.canceled.emit()
	menu._overwrite_dialog.hide()
	menu._confirm_start()
	assert_eq(starts.size(), 0, "cancel clears the pending request")
	assert_eq(menu._run_mode_option.selected, 1, "cancel preserves the form's selected mode")
	assert_eq(menu._goal_option.selected, 2, "cancel preserves the form's selected goal")
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), checkpoint)
	menu._request_start()
	menu._run_mode_option.select(0)
	menu._goal_option.select(0)
	menu._request_start()
	menu._overwrite_dialog.confirmed.emit()
	assert_eq(starts.size(), 1)
	if not starts.is_empty():
		assert_eq(starts[0]["run_mode"], "long", "confirmation keeps the requested mode")
		assert_eq(starts[0]["village_goal"], "forest", "confirmation keeps the requested goal")
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), checkpoint, "boot owns replacing a checkpoint")
	menu.free()
	SaveIO.delete_save(CHECKPOINT_PATH)


func test_mode_and_goal_descriptions_change_in_both_languages() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var menu: MainMenu = _open_menu(language)
		menu._show_page(menu._setup)
		assert_eq((Engine.get_main_loop() as SceneTree).root.gui_get_focus_owner(), menu._leader_option)
		assert_true(menu._run_mode_option.custom_minimum_size.y >= 52)
		assert_true(menu._goal_option.custom_minimum_size.y >= 52)
		for mode_index: int in range(MainMenu.RUN_MODES.size()):
			menu._run_mode_option.select(mode_index)
			menu._run_mode_option.item_selected.emit(mode_index)
			var mode_key: String = "run_mode." + MainMenu.RUN_MODES[mode_index]
			assert_true(not menu._run_mode_option.get_item_text(mode_index).is_empty())
			assert_true(menu._run_mode_option.get_item_text(mode_index) != mode_key + ".name")
			assert_eq(menu._run_mode_description.text, String(TranslationServer.translate(mode_key + ".desc")))
			assert_true(menu._run_mode_description.text != mode_key + ".desc")
		for goal_index: int in range(MainMenu.GOALS.size()):
			menu._goal_option.select(goal_index)
			menu._goal_option.item_selected.emit(goal_index)
			var goal_key: String = "goal." + MainMenu.GOALS[goal_index]
			assert_true(not menu._goal_option.get_item_text(goal_index).is_empty())
			assert_true(menu._goal_option.get_item_text(goal_index) != goal_key + ".name")
			assert_eq(menu._goal_description.text, String(TranslationServer.translate(goal_key + ".desc")))
			assert_true(menu._goal_description.text != goal_key + ".desc")
		menu.free()
	Localization.setup("en")


func _open_menu(language: String = "en") -> MainMenu:
	var menu: MainMenu = MainMenu.new()
	menu.save_path = CHECKPOINT_PATH
	menu.language = language
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	return menu
