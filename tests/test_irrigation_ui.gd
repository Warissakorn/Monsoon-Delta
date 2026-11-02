extends TestCase
const F = preload("res://tools/irrigation_fixtures.gd")
const DIRECTORY: String = "user://tests/irrigation_ui"
const PATH: String = DIRECTORY + "/checkpoint.json"
const SETTINGS: String = DIRECTORY + "/settings.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	Localization.setup("en")


func _screen(ruleset: String = "moisture_irrigation_v1") -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = GameSession.new()
	screen.session.state = F.create(ruleset)
	screen.session.save_path = PATH
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.confirm_unused_labor = false
	return screen


func _text(key: String) -> String:
	return String(TranslationServer.translate(key))


func _labels(node: Node) -> String:
	var result: PackedStringArray = []
	for child: Node in node.get_children():
		if child is Label:
			result.append(child.text)
		result.append(_labels(child))
	return "\n".join(result)


func test_menu_all_presets_emit_the_selected_ruleset_and_language_drafts_keep_the_new_flag() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		for ruleset: String in GameState.RULESETS:
			var menu: MainMenu = MainMenu.new()
			menu.save_path = PATH
			menu.initial_ruleset = ruleset
			(Engine.get_main_loop() as SceneTree).root.add_child(menu)
			var expected: GameState = GameFlow.new_game({"ruleset": ruleset})
			assert_eq(menu._irrigation_toggle.button_pressed, expected.has_irrigation())
			assert_eq(menu._bracing_toggle.button_pressed, expected.has_bracing())
			assert_eq(menu._moisture_toggle.button_pressed, expected.has_moisture())
			var draft: Dictionary = menu.setup_draft()
			assert_eq(draft["irrigation"], expected.has_irrigation())
			menu._irrigation_toggle.set_pressed_no_signal(not expected.has_irrigation())
			menu.restore_setup_draft(draft)
			assert_eq(menu.setup_draft(), draft)
			var started: Array[Dictionary] = []
			menu.start_requested.connect(func(config: Dictionary): started.append(config))
			menu._request_start()
			assert_eq(started.size(), 1)
			assert_eq(started[0].get("ruleset", "legacy"), ruleset)
			menu.free()


func test_inspector_policy_buttons_change_checkpoint_and_support_undo_redo_in_both_languages() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var screen: GameScreen = _screen()
		screen.apply_at(F.FIELDS[0])
		assert_true(screen._irrigation_controls.visible)
		assert_eq(screen._irrigation_coord, F.FIELDS[0])
		var before: Dictionary = screen.session.state.to_dict()
		var normal: Button = screen._irrigation_buttons["normal"]
		assert_true(normal.button_pressed and normal.disabled)
		(screen._irrigation_buttons["skip"] as Button).pressed.emit()
		assert_eq(screen.session.state.get_tile(F.FIELDS[0]).irrigation_policy, "skip")
		assert_eq(SaveIO.load_game(PATH)["state"].get_tile(F.FIELDS[0]).irrigation_policy, "skip")
		assert_true(screen._tile_note.text.contains(_text("irrigation.policy") % _text("irrigation.skip")))
		assert_true(screen._tile_note.text.contains(_text("irrigation.from_moisture") % [1, 0]))
		assert_eq((screen.prediction["report"] as TurnReport).paddy_gains.size(), 3)
		screen.undo_command()
		assert_eq(screen.session.state.to_dict(), before)
		screen.redo_command()
		assert_eq(screen.session.state.get_tile(F.FIELDS[0]).irrigation_policy, "skip")
		assert_true(screen._irrigation_buttons["skip"].button_pressed)
		assert_true(screen._irrigation_buttons["skip"].text.begins_with("✓ "))
		screen.free()


func test_keyboard_policy_activation_cannot_also_end_the_turn_and_modal_blocks_changes() -> void:
	var screen: GameScreen = _screen()
	screen.apply_at(F.FIELDS[0])
	(screen._irrigation_buttons["first"] as Button).grab_focus()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key, true)
	key.pressed = false
	root.push_input(key, true)
	assert_eq(screen.session.state.get_tile(F.FIELDS[0]).irrigation_policy, "first")
	assert_eq(screen.session.state.turn, 1)
	assert_true(screen.session.turn_history().is_empty())
	var before: Dictionary = screen.session.state.to_dict()
	screen.open_pause()
	screen._set_irrigation("skip")
	assert_eq(screen.session.state.to_dict(), before)
	screen.free()


func test_rain_dead_fields_and_legacy_states_cannot_edit_policies() -> void:
	var screen: GameScreen = _screen()
	screen.apply_at(F.FIELDS[0])
	screen.session.state.turn = 4
	screen.refresh_state()
	assert_true(screen._tile_note.text.contains(_text("irrigation.dormant")))
	for button: Button in screen._irrigation_buttons.values():
		assert_true(button.disabled)
	var before: Dictionary = screen.session.state.to_dict()
	screen._set_irrigation("first")
	assert_eq(screen.session.state.to_dict(), before)
	screen.session.state.get_tile(F.FIELDS[0]).paddy_dead = true
	screen.refresh_state()
	assert_true(not screen._irrigation_controls.visible)
	screen.free()
	screen = _screen("legacy")
	screen.apply_at(F.FIELDS[0])
	assert_true(not screen._irrigation_controls.visible)
	screen.free()


func test_actual_history_and_preview_show_allocation_sources_and_no_production_reasons() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var screen: GameScreen = _screen()
		var before: Dictionary = screen.session.state.to_dict()
		screen.apply_at(F.RESERVOIR)
		var lines: String = "\n".join(screen._tile_preview_lines(screen.session.state.get_tile(F.RESERVOIR)))
		assert_true(lines.contains(_text("irrigation.from_reservoir") % [0, 0, 0.75, 0.5]))
		assert_eq(screen.session.state.to_dict(), before)
		screen._finish_turn()
		screen.open_turn_history()
		var text: String = _labels(screen._history_details)
		assert_true(text.contains(_text("irrigation.from_reservoir") % [0, 0, 0.75, 0.5]))
		assert_true(text.contains(_text("irrigation.reason.insufficient_water")))
		assert_eq(screen.session.state.turn, 2)
		screen.free()


func test_policy_board_markers_are_transient_and_rebuilt_by_undo_and_reduce_motion() -> void:
	var screen: GameScreen = _screen()
	screen.apply_at(F.FIELDS[0])
	screen._set_irrigation("skip")
	assert_eq(screen.board._irrigation_status_root.get_child_count(), 1)
	var marker: Node = screen.board._irrigation_status_root.get_child(0)
	assert_eq(marker.get_meta("irrigation_policy"), "skip")
	var before: Dictionary = screen.session.state.to_dict()
	screen._on_motion_toggled(true)
	assert_eq(screen.session.state.to_dict(), before)
	screen.undo_command()
	assert_eq(screen.board._irrigation_status_root.get_child_count(), 0)
	screen.redo_command()
	assert_eq(screen.board._irrigation_status_root.get_child_count(), 1)
	assert_eq(screen.session.state.to_dict(), before)
	screen.free()
