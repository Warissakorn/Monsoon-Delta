extends TestCase
## Seasonal soil storage is optional and never pays food during presentation.

const PATH: String = "user://tests/moisture_ui/checkpoint.json"
const SETTINGS: String = "user://tests/moisture_ui/settings.json"


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


func _state(ruleset: String = "moisture_v1") -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 42, "ruleset": ruleset})
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	state.tiles[0].building = C.Building.HALL
	for index: int in range(1, 4):
		state.tiles[index].building = C.Building.HOUSE
	state.tiles[4].feature = C.Feature.PADDY
	state.tiles[4].soil_moisture = 2 if state.has_moisture() else 0
	state.food = 100
	state.wood = 20
	state.turn = 1
	GameFlow.begin_turn(state)
	return state


func _screen_for(session: GameSession) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = false
	return screen


func _screen(state: GameState) -> GameScreen:
	var session: GameSession = GameSession.new()
	session.save_path = PATH
	session.state = state
	assert_eq(session.checkpoint(), "")
	return _screen_for(session)


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


func test_new_run_choices_are_independent_opt_in_and_do_not_write_saves() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var menu: MainMenu = _menu()
		var starts: Array[Dictionary] = []
		menu.start_requested.connect(func(config: Dictionary): starts.append(config))
		assert_true(not menu._moisture_toggle.button_pressed)
		assert_true(not menu._bracing_toggle.button_pressed)
		for pair: Array in [[false, false], [false, true], [true, false], [true, true]]:
			menu._bracing_toggle.button_pressed = pair[0]
			menu._moisture_toggle.button_pressed = pair[1]
			menu._request_start()
			var config: Dictionary = starts[-1]
			var state: GameState = GameFlow.new_game(config)
			assert_eq(state.has_bracing(), pair[0])
			assert_eq(state.has_moisture(), pair[1])
			if not pair[0] and not pair[1]:
				assert_true(not config.has("ruleset"), "default setup keeps the legacy config contract")
			assert_true(not FileAccess.file_exists(PATH))
		menu.free()


func test_initial_ruleset_and_overwrite_confirmation_keep_the_proposed_choices() -> void:
	for ruleset: String in GameState.RULESETS:
		var menu: MainMenu = _menu(ruleset)
		var state: GameState = GameFlow.new_game({"ruleset": ruleset})
		assert_eq(menu._bracing_toggle.button_pressed, state.has_bracing())
		assert_eq(menu._moisture_toggle.button_pressed, state.has_moisture())
		menu.free()
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 74}), PATH), "")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var menu: MainMenu = _menu("bracing_moisture_v1")
	var starts: Array[Dictionary] = []
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	menu._request_start()
	assert_true(menu._overwrite_dialog.visible)
	menu._moisture_toggle.button_pressed = false
	menu._bracing_toggle.button_pressed = false
	menu._overwrite_dialog.confirmed.emit()
	assert_eq(starts.size(), 1)
	assert_eq(starts[0]["ruleset"], "bracing_moisture_v1")
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
	menu.free()


func test_inspector_distinguishes_stored_moisture_from_read_only_forecast() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var state: GameState = _state()
		var before: Dictionary = state.to_dict()
		var rng_before: int = state.rng.state
		var screen: GameScreen = _screen(state)
		var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var coord: Vector2i = state.tiles[4].coord
		screen.hovered_coord = coord
		screen._update_inspector()
		assert_true(screen._tile_note.text.contains(_text("tile.moisture") % [2, 2]))
		assert_true(screen._tile_note.text.contains(_text("tile.moisture_forecast") % [2, 1]))
		assert_true(screen._tile_note.text.contains(_text("tile.moisture_yield")))
		var predicted: GameState = screen.prediction["state"]
		assert_eq(predicted.get_tile(coord).soil_moisture, 1)
		assert_eq(predicted.get_tile(coord).paddy_yield, 1)
		assert_eq(predicted.food, state.food, "stored crop yield is not food paid by a preview")
		assert_eq(screen._feedback.get_child_count(), 0)
		screen.toggle_preview()
		assert_true(screen._tile_note.text.contains(_text("tile.moisture") % [2, 2]))
		assert_true(not screen._tile_note.text.contains(_text("tile.moisture_forecast") % [2, 1]))
		assert_true(not screen._tile_note.text.contains(_text("tile.moisture_yield")))
		assert_eq(state.to_dict(), before)
		assert_eq(state.rng.state, rng_before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
		screen.free()
		SaveIO.delete_save(PATH)


func test_committed_moisture_yield_has_crop_feedback_and_persists_in_history() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var state: GameState = _state()
		var coord: Vector2i = state.tiles[4].coord
		var screen: GameScreen = _screen(state)
		var food_before: int = state.food
		screen._finish_turn()
		assert_eq(state.get_tile(coord).soil_moisture, 1)
		assert_eq(state.get_tile(coord).paddy_yield, 1)
		assert_eq(state.food, food_before, "moisture yield waits for the normal harvest")
		assert_true(_marker_texts(screen).contains(_text("feedback.moisture_yield")))
		var source_visible: bool = false
		for marker: Node in screen._feedback.get_children():
			if marker.has_node("Label/MoistureSource"):
				source_visible = true
		assert_true(source_visible, "compact crop feedback keeps the soil moisture source visible")
		var before_history: Dictionary = state.to_dict()
		var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var entries: Array[Dictionary] = screen.session.turn_history()
		assert_eq(entries.size(), 1)
		assert_eq(entries[0]["report"]["moisture_changes"][0]["yield_from_moisture"], 1)
		screen.open_turn_history()
		var history_text: String = "\n".join(_labels(screen._history_details))
		assert_true(history_text.contains(_text("feedback.moisture_yield")))
		assert_true(history_text.contains(_text("history.moisture_yield")))
		assert_eq(state.to_dict(), before_history)
		assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
		screen.free()
		SaveIO.delete_save(PATH)


func test_demolish_undo_redo_restore_moisture_and_checkpoint_without_earning_yield() -> void:
	var screen: GameScreen = _screen(_state())
	var coord: Vector2i = screen.session.state.tiles[4].coord
	var before: Dictionary = screen.session.state.to_dict()
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen.select_command("demolish")
	screen.apply_at(coord)
	assert_eq(screen.session.state.get_tile(coord).feature, C.Feature.NONE)
	assert_eq(screen.session.state.get_tile(coord).soil_moisture, 0)
	assert_eq(screen.session.state.food, int(before["food"]))
	var demolished: Dictionary = screen.session.state.to_dict()
	var demolished_save: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen.undo_command()
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
	assert_true(screen._tile_note.text.contains(_text("tile.moisture") % [2, 2]))
	screen.redo_command()
	assert_eq(screen.session.state.to_dict(), demolished)
	assert_eq(FileAccess.get_file_as_bytes(PATH), demolished_save)
	assert_true(not screen._tile_note.text.contains(_text("tile.moisture") % [2, 2]))
	screen.free()


func test_continue_restart_and_pause_keep_moisture_rules_without_reusing_crop_storage() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		for ruleset: String in ["moisture_v1", "bracing_moisture_v1"]:
			var state: GameState = _state(ruleset)
			assert_eq(SaveIO.save(state, PATH), "")
			var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
			var session: GameSession = GameSession.new()
			session.save_path = PATH
			assert_eq(session.load_game(), "")
			var screen: GameScreen = _screen_for(session)
			assert_eq(session.state.tiles[4].soil_moisture, 2)
			assert_eq(screen._command_buttons["brace_house"].visible, state.has_bracing())
			assert_eq(screen._run_label.tooltip_text, _text("ruleset." + ruleset + ".name"))
			screen.open_pause()
			assert_true(_labels(screen._modal).has(_text("ruleset." + ruleset + ".name")))
			screen.close_modal()
			var starts: Array[Dictionary] = []
			screen.restart_requested.connect(func(config: Dictionary): starts.append(config))
			screen._restart()
			assert_eq(starts[0]["ruleset"], ruleset)
			var next: GameState = GameFlow.new_game(starts[0])
			assert_true(next.has_moisture())
			assert_eq(next.has_bracing(), state.has_bracing())
			for tile: Tile in next.tiles:
				assert_eq(tile.soil_moisture, 0)
				assert_eq(tile.brace_turns, 0)
			assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
			screen.free()
			SaveIO.delete_save(PATH)


func test_legacy_paddies_do_not_display_or_gain_unselected_soil_storage() -> void:
	for ruleset: String in ["legacy", "bracing_v1"]:
		var state: GameState = _state(ruleset)
		var screen: GameScreen = _screen(state)
		screen.hovered_coord = state.tiles[4].coord
		screen._update_inspector()
		assert_true(not screen._tile_note.text.contains(_text("tile.moisture") % [0, 2]))
		assert_true(not screen._tile_note.text.contains(_text("tile.moisture_yield")))
		screen._finish_turn()
		assert_eq(state.tiles[4].paddy_yield, 0)
		assert_eq(state.tiles[4].soil_moisture, 0)
		assert_true(not _marker_texts(screen).contains(_text("feedback.moisture_yield")))
		screen.free()
		SaveIO.delete_save(PATH)
