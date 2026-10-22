extends TestCase
## Bracing is an explicit new-run choice; presentation never grants protection.

const PATH: String = "user://tests/bracing_ui/checkpoint.json"
const SETTINGS: String = "user://tests/bracing_ui/settings.json"


func before_each() -> void:
	Localization.setup("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func _menu(ruleset: String = "legacy") -> MainMenu:
	var menu: MainMenu = MainMenu.new()
	menu.save_path = PATH
	menu.initial_ruleset = ruleset
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	return menu


func _state(ruleset: String = "bracing_v1", water: float = 0.0, mode: String = "classic") -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 42, "ruleset": ruleset, "run_mode": mode})
	# Controlled, serializable board: water levels stay fixed in the rain and
	# hall loss is excluded so protection feedback can be inspected separately.
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = water
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	state.tiles[0].building = C.Building.HALL
	for index: int in range(1, 4):
		state.tiles[index].building = C.Building.HOUSE
	state.food = 100
	state.wood = 20
	state.turn = 4
	state.year_mods.assign([{"key": "hall_lose_level", "op": "set", "value": 4}])
	state.recompute_mods()
	GameFlow.begin_turn(state)
	return state


func _screen(state: GameState) -> GameScreen:
	var session: GameSession = GameSession.new()
	session.save_path = PATH
	session.state = state
	assert_eq(session.checkpoint(), "")
	return _screen_for(session)


func _screen_for(session: GameSession) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = false
	return screen


func _text(key: String) -> String:
	return String(TranslationServer.translate(key))


func _labels(node: Node) -> PackedStringArray:
	var result: PackedStringArray = []
	for child: Node in node.get_children():
		if child is Label:
			result.append(child.text)
		result.append_array(_labels(child))
	return result


func _marker_texts(screen: GameScreen) -> String:
	var lines: PackedStringArray = []
	for child: Node in screen._feedback.get_children():
		lines.append((child.get_node("Label") as Label3D).text)
	return "\n".join(lines)


func test_menu_bracing_is_opt_in_and_never_writes_a_checkpoint() -> void:
	var menu: MainMenu = _menu()
	var starts: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	assert_true(not menu._bracing_toggle.button_pressed)
	menu._request_start()
	assert_eq(starts.size(), 1)
	assert_true(not starts[0].has("ruleset"), "default setup retains the exact legacy config contract")
	menu._bracing_toggle.button_pressed = true
	menu._request_start()
	assert_eq(starts[1]["ruleset"], "bracing_v1")
	assert_true(GameFlow.new_game(starts[1]).has_bracing())
	assert_true(not FileAccess.file_exists(PATH))
	menu.free()


func test_overwrite_confirmation_keeps_requested_ruleset_and_existing_save() -> void:
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 74}), PATH), "")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var menu: MainMenu = _menu("bracing_v1")
	var starts: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	assert_true(menu._bracing_toggle.button_pressed)
	menu._request_start()
	assert_true(menu._overwrite_dialog.visible)
	menu._overwrite_dialog.canceled.emit()
	menu._overwrite_dialog.hide()
	menu._confirm_start()
	assert_true(starts.is_empty())
	assert_true(menu._bracing_toggle.button_pressed)
	menu._request_start()
	menu._bracing_toggle.button_pressed = false
	menu._overwrite_dialog.confirmed.emit()
	assert_eq(starts.size(), 1)
	assert_eq(starts[0]["ruleset"], "bracing_v1", "confirmation uses the proposed run, not later form changes")
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
	menu.free()


func test_tool_and_keyboard_only_offer_bracing_in_an_enabled_run() -> void:
	for ruleset: String in ["legacy", "bracing_v1"]:
		var screen: GameScreen = _screen(_state(ruleset))
		var enabled: bool = ruleset == "bracing_v1"
		assert_eq(screen._command_buttons["brace_house"].visible, enabled)
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_R
		key.pressed = true
		screen._unhandled_input(key)
		assert_eq(screen.command_mode, "brace_house" if enabled else "")
		key.physical_keycode = KEY_V
		screen._unhandled_input(key)
		assert_true(screen.show_levels, "V still toggles water numbers")
		screen.free()
		SaveIO.delete_save(PATH)


func test_bracing_command_inspector_and_undo_redo_agree_in_both_languages() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var screen: GameScreen = _screen(_state())
		var coord: Vector2i = screen.session.state.tiles[1].coord
		var before: Dictionary = screen.session.state.to_dict()
		var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		screen.select_command("brace_house")
		screen.apply_at(coord)
		assert_eq(screen.session.state.get_tile(coord).brace_turns, 1)
		assert_eq(screen.session.state.labor, int(before["labor"]) - 2)
		assert_eq(screen.session.state.wood, int(before["wood"]) - 1)
		assert_true(screen._tile_note.text.contains(_text("tile.braced")))
		assert_true(screen._tile_note.text.contains(_text("tile.brace_forecast") % 2))
		assert_true(_marker_texts(screen).contains(_text("cmd.brace_house.name")))
		var after: Dictionary = screen.session.state.to_dict()
		var saved_after: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		screen.apply_at(coord)
		assert_eq(screen.session.state.to_dict(), after)
		assert_eq(screen._status_label.text, _text("err.braced"))
		screen.undo_command()
		assert_eq(screen.session.state.to_dict(), before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
		screen.redo_command()
		assert_eq(screen.session.state.to_dict(), after)
		assert_eq(FileAccess.get_file_as_bytes(PATH), saved_after)
		assert_eq(screen._feedback.get_child_count(), 0, "redo restores state without replaying payment")
		screen.free()
		SaveIO.delete_save(PATH)


func test_destroyed_house_inspector_uses_resolved_protection_not_expired_preview_state() -> void:
	var state: GameState = _state("bracing_v1", 0.7)
	var coord: Vector2i = state.tiles[1].coord
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", coord)), "")
	var screen: GameScreen = _screen(state)
	screen.hovered_coord = coord
	screen._update_inspector()
	var predicted: GameState = screen.prediction["state"]
	assert_eq(predicted.get_tile(coord).brace_turns, 0)
	assert_eq(predicted.get_tile(coord).building, C.Building.NONE)
	assert_true(screen._tile_note.text.contains(_text("tile.brace_forecast") % 2))
	assert_true(screen._tile_note.text.contains(screen._flood_threshold_line(2)))
	assert_true(not screen._tile_note.text.contains(screen._flood_threshold_line(1)))
	assert_eq(state.get_tile(coord).brace_turns, 1, "inspection does not expire the real brace")
	screen.free()


func test_actual_results_show_held_and_expired_and_are_retained_in_history() -> void:
	for water: float in [0.0, 0.3, 0.7]:
		var state: GameState = _state("bracing_v1", water)
		var coord: Vector2i = state.tiles[1].coord
		assert_eq(GameFlow.apply_command(state, Command.new("brace_house", coord)), "")
		var screen: GameScreen = _screen(state)
		assert_eq(screen._feedback.get_child_count(), 0, "opening previews is silent")
		screen._finish_turn()
		assert_eq(state.get_tile(coord).brace_turns, 0)
		var key: String = "feedback.brace_expired" if water == 0.0 else ("feedback.brace_held" if water < 0.5 else "feedback.brace_failed")
		assert_true(_marker_texts(screen).contains(_text(key)))
		var resolved: Dictionary = state.to_dict()
		var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		screen._feedback._process(0.5)
		screen.open_turn_history()
		assert_true("\n".join(_labels(screen._history_details)).contains(_text(key)))
		assert_eq(state.to_dict(), resolved)
		assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
		screen.free()
		SaveIO.delete_save(PATH)


func test_continue_and_restart_keep_bracing_rules_and_pause_explains_them() -> void:
	var state: GameState = _state()
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", state.tiles[1].coord)), "")
	assert_eq(SaveIO.save(state, PATH), "")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var session: GameSession = GameSession.new()
	session.save_path = PATH
	assert_eq(session.load_game(), "")
	var screen: GameScreen = _screen_for(session)
	assert_true(screen._command_buttons["brace_house"].visible)
	assert_eq(session.state.tiles[1].brace_turns, 1)
	screen.open_pause()
	assert_true(_labels(screen._modal).has(_text("ruleset.bracing_v1.name")))
	screen.close_modal()
	var starts: Array[Dictionary] = []
	screen.restart_requested.connect(func(config: Dictionary): starts.append(config))
	screen._restart()
	assert_eq(starts[0]["ruleset"], "bracing_v1")
	var next: GameState = GameFlow.new_game(starts[0])
	assert_true(next.has_bracing())
	for tile: Tile in next.tiles:
		assert_eq(tile.brace_turns, 0, "restart keeps rules, not last game's temporary protection")
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
	screen.free()


func test_long_bracing_run_keeps_all_tools_in_two_rows() -> void:
	var screen: GameScreen = _screen(_state("bracing_v1", 0.0, "long"))
	var visible: int = 0
	for button: Button in screen._command_buttons.values():
		if button.visible:
			visible += 1
	assert_eq(visible, 15)
	assert_eq(screen._commands_grid.columns, 8)
	assert_eq(screen._command_buttons["brace_house"].custom_minimum_size.x, 128.0)
	screen.free()
