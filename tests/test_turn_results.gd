extends TestCase
## Resolved turn facts, history navigation and modal input stay independent of play.

const DIRECTORY: String = "user://tests/turn_results"
const CHECKPOINT_PATH: String = DIRECTORY + "/checkpoint.json"


func before_each() -> void:
	Localization.setup("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for path: String in [CHECKPOINT_PATH, CHECKPOINT_PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _quiet_state(turn: int = 1) -> GameState:
	# A real serializable map keeps the screen, command rules and autosave active.
	var state: GameState = GameFlow.new_game({"seed": 42})
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
	state.turn = turn
	state.food = 40
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	state.year_mods = [
		{"key": "water_iterations", "op": "set", "value": 1},
		{"key": "flow_rate", "op": "set", "value": 0.05},
		{"key": "dry_inflow", "op": "set", "value": 0.0},
		{"key": "evaporation_dry", "op": "set", "value": 0.0},
	]
	state.recompute_mods()
	return state


func _damage_state() -> GameState:
	var state: GameState = _quiet_state(4)
	state.year = 2
	state.stats["reached_year"] = 2
	state.rain_inflows.assign([1.25, 0.0, 0.0])
	state.tiles[0].water = 0.3
	state.tiles[1].water = 0.3
	state.tiles[2].building = C.Building.STILT_HOUSE
	state.tiles[2].water = 0.6
	state.tiles[3].building = C.Building.GRANARY
	state.tiles[3].water = 0.6
	state.tiles[4].feature = C.Feature.PADDY
	state.tiles[4].paddy_yield = 3
	state.tiles[4].water = 0.6
	state.tiles[5].feature = C.Feature.PADDY
	state.tiles[5].water = 0.3
	for index: int in [6, 8]:
		state.tiles[index].building = C.Building.FISH_TRAP
		state.tiles[index].water = 0.3
	state.tiles[7].is_source = true
	return state


func _screen(state: GameState = null, session: GameSession = null) -> GameScreen:
	if session == null:
		session = GameSession.new()
		session.save_path = CHECKPOINT_PATH
		session.state = _quiet_state() if state == null else state
		assert_eq(session.checkpoint(), "")
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = false
	return screen


func _close(screen: GameScreen) -> void:
	screen.free()
	SaveIO.delete_save(CHECKPOINT_PATH)


func _key(code: int, echo: bool = false, control: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	event.ctrl_pressed = control
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _texts(node: Node) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for child: Node in node.get_children():
		if child is Label:
			result.append(child.text)
		result.append_array(_texts(child))
	return result


func _translate(key: String) -> String:
	return String(TranslationServer.translate(key))


func _finish_turn(screen: GameScreen) -> void:
	screen.request_end_turn()
	if screen.modal_kind in ["confirm_labor", "confirm_loss"]:
		screen._confirm_end_turn()


func _bounded_scroll(node: Node) -> ScrollContainer:
	for child: Node in node.get_children():
		if child is ScrollContainer:
			return child
		var found: ScrollContainer = _bounded_scroll(child)
		if found != null:
			return found
	return null


func test_history_starts_empty_and_loading_does_not_invent_past_results() -> void:
	var screen: GameScreen = _screen()
	assert_eq(screen._latest_result.text, "")
	screen.open_turn_history()
	assert_eq(screen.modal_kind, "turn_history")
	assert_true(screen._history_previous.disabled)
	assert_true(screen._history_next.disabled)
	assert_true(screen.session.turn_history().is_empty())
	screen.close_turn_history()
	assert_eq(screen.modal_kind, "")
	_finish_turn(screen)
	assert_eq(screen.session.turn_history().size(), 1)
	assert_true(not screen._latest_result.text.is_empty())
	screen.free()
	var resumed: GameSession = GameSession.new()
	resumed.save_path = CHECKPOINT_PATH
	assert_eq(resumed.load_game(), "")
	screen = _screen(null, resumed)
	assert_eq(screen.session.state.turn, 2)
	assert_true(resumed.turn_history().is_empty())
	assert_eq(screen._latest_result.text, "", "checkpoint loading cannot manufacture a resolved report")
	screen.open_turn_history()
	assert_true(screen._history_previous.disabled)
	assert_true(screen._history_next.disabled)
	_close(screen)


func test_history_displays_actual_damage_production_and_original_turn_in_both_languages() -> void:
	for locale: String in ["en", "th"]:
		Localization.setup(locale)
		var screen: GameScreen = _screen(_damage_state())
		_finish_turn(screen)
		assert_eq(screen.session.state.turn, 5)
		var history: Array[Dictionary] = screen.session.turn_history()
		assert_eq(history.size(), 1)
		var entry: Dictionary = history[0]
		var report: Dictionary = entry["report"]
		assert_eq(entry["year"], 2)
		assert_eq(entry["turn"], 4, "the timestamp describes the resolved turn, not the next planning turn")
		assert_eq(entry["season"], C.Season.RAIN)
		assert_eq(report["destroyed"].size(), 3)
		assert_eq(report["paddies_died"].size(), 1)
		assert_eq(report["paddy_gains"].size(), 1)
		assert_eq(report["fish_food"], 2)
		assert_eq(report["hall_wet"], true)
		assert_near(float(report["inflow"]), 1.25, 1e-9)
		screen.open_turn_history()
		assert_eq(screen.history_index, 0)
		assert_true(screen._history_previous.disabled)
		assert_true(screen._history_next.disabled)
		var lines: PackedStringArray = _texts(screen._history_details)
		assert_true(not lines.is_empty(), "actual reports need visible details")
		assert_true(lines.has(_translate("history.inflow") % float(report["inflow"])))
		assert_true(lines.has(_translate("history.buildings") % report["destroyed"].size()))
		assert_true(lines.has(_translate("history.hall_wet")))
		assert_true(lines.has(_translate("history.fish") % int(report["fish_food"])))
		assert_true(lines.has(_translate("history.yield_note")), "growing rice is distinguished from immediate food")
		for destroyed: Dictionary in report["destroyed"]:
			var coord: Vector2i = destroyed["coord"]
			var building: String = _translate("building." + C.enum_name(C.Building, int(destroyed["building"])))
			assert_true(lines.has(_translate("history.destroyed_item") % [building, coord.x, coord.y]))
		var died: Vector2i = report["paddies_died"][0]
		var grew: Vector2i = report["paddy_gains"][0]
		assert_true(lines.has(_translate("history.paddies_died") % [1, "(%d, %d)" % [died.x, died.y]]))
		assert_true(lines.has(_translate("history.paddy_gains") % [1, "(%d, %d)" % [grew.x, grew.y]]))
		for line: String in lines:
			assert_true(not line.begins_with("history."), "history details must be translated")
		assert_eq(screen._history_title.text, _translate("history.turn") % [2, _translate("season.rain"), 4])
		assert_true(not screen._latest_result.text.is_empty())
		var scroll: ScrollContainer = _bounded_scroll(screen._modal)
		assert_true(scroll != null, "long reports remain reachable inside the dialog")
		if scroll != null:
			assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
		_close(screen)


func test_history_navigation_and_input_preserve_model_rng_command_stacks_and_checkpoint() -> void:
	var screen: GameScreen = _screen(_damage_state())
	_finish_turn(screen)
	_finish_turn(screen)
	screen.select_command("fish_trap")
	screen.apply_at(screen.valid_targets("fish_trap")[0])
	screen.apply_at(screen.valid_targets("fish_trap")[0])
	screen.undo_command()
	assert_eq(screen.session.state.undo.size(), 1)
	assert_eq(screen.session.state.redo.size(), 1)
	var before: Dictionary = screen.session.state.to_dict()
	var undo: Array[Dictionary] = screen.session.state.undo.snapshots()
	var redo: Array[Dictionary] = screen.session.state.redo.snapshots()
	var history: Array[Dictionary] = screen.session.turn_history()
	var rng: int = screen.session.state.rng.state
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
	var latest: String = screen._latest_result.text
	var coord: Vector2i = screen.hovered_coord
	var camera_position: Vector3 = screen.camera_rig.position
	var yaw: float = screen.camera_rig._yaw_target
	var zoom: float = screen.camera_rig._zoom_target
	var preview: bool = screen.preview_enabled
	var levels: bool = screen.show_levels
	screen._unhandled_input(_key(KEY_H, true))
	assert_eq(screen.modal_kind, "", "holding H cannot repeatedly open the dialog")
	screen._unhandled_input(_key(KEY_H))
	assert_eq(screen.modal_kind, "turn_history")
	assert_eq(screen.history_index, 1, "opening selects the latest actual report")
	assert_true(not screen._history_previous.disabled)
	assert_true(screen._history_next.disabled)
	var latest_title: String = screen._history_title.text
	screen._history_previous.pressed.emit()
	assert_eq(screen.history_index, 0)
	assert_true(screen._history_previous.disabled)
	assert_true(not screen._history_next.disabled)
	assert_true(screen._history_title.text != latest_title)
	screen._change_history(-1)
	assert_eq(screen.history_index, 0, "previous is bounded at the oldest recorded turn")
	screen._history_next.pressed.emit()
	assert_eq(screen.history_index, 1)
	assert_eq(screen._history_title.text, latest_title)
	screen._change_history(1)
	assert_eq(screen.history_index, 1, "next is bounded at the latest recorded turn")
	screen.apply_at(screen.valid_targets("fish_trap")[0])
	screen.undo_command()
	screen.redo_command()
	screen.request_end_turn()
	screen.continue_harvest()
	screen.select_command("dig")
	screen.toggle_preview()
	for code: int in [KEY_SPACE, KEY_ENTER, KEY_Q, KEY_E, KEY_V, KEY_TAB, KEY_H]:
		screen._unhandled_input(_key(code))
	screen._unhandled_input(_key(KEY_Z, false, true))
	screen._unhandled_input(_key(KEY_Y, false, true))
	for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		screen._unhandled_input(_mouse(button))
	screen._process(0.25)
	assert_eq(screen.modal_kind, "turn_history")
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.session.state.undo.snapshots(), undo)
	assert_eq(screen.session.state.redo.snapshots(), redo)
	assert_eq(screen.session.turn_history(), history)
	assert_eq(screen.session.state.rng.state, rng)
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), saved)
	assert_eq(screen._latest_result.text, latest, "browsing old results cannot replace the compact latest result")
	assert_eq(screen.command_mode, "fish_trap")
	assert_eq(screen.hovered_coord, coord)
	assert_eq(screen.camera_rig.position, camera_position)
	assert_eq(screen.camera_rig._yaw_target, yaw)
	assert_eq(screen.camera_rig._zoom_target, zoom)
	assert_eq(screen.preview_enabled, preview)
	assert_eq(screen.show_levels, levels)
	screen._unhandled_input(_key(KEY_ESCAPE, true))
	assert_eq(screen.modal_kind, "turn_history", "a repeated Escape cannot dismiss a newly opened dialog")
	screen._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(screen.modal_kind, "")
	screen.redo_command()
	assert_true(screen.session.state.to_dict() != before, "closing history restores normal command interaction")
	_close(screen)


func test_history_returns_to_pause_without_resuming_gameplay() -> void:
	var screen: GameScreen = _screen()
	_finish_turn(screen)
	screen.open_pause()
	var captions: PackedStringArray = _texts(screen._modal)
	var before: Dictionary = screen.session.state.to_dict()
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
	screen._unhandled_input(_key(KEY_H))
	assert_eq(screen.modal_kind, "turn_history")
	screen._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(screen.modal_kind, "pause")
	assert_eq(_texts(screen._modal), captions)
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), saved)
	_close(screen)


func test_harvest_history_returns_to_same_summary_without_harvesting_twice() -> void:
	var state: GameState = _quiet_state(C.TURNS_PER_YEAR)
	state.tiles[4].feature = C.Feature.PADDY
	state.tiles[4].paddy_yield = 3
	state.tiles[4].paddy_rain_turns = 2
	var screen: GameScreen = _screen(state)
	_finish_turn(screen)
	assert_eq(screen.modal_kind, "harvest")
	var before: Dictionary = state.to_dict()
	var harvest: Dictionary = state.harvest_report.duplicate(true)
	var captions: PackedStringArray = _texts(screen._modal)
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
	screen.open_turn_history()
	assert_eq(screen.modal_kind, "turn_history")
	assert_eq(screen.session.turn_history()[0]["harvest"], harvest)
	var lines: PackedStringArray = _texts(screen._history_details)
	for key: String in ["paddy_food", "eaten", "left_hunger", "left_housing", "born", "spoiled", "food_after", "population_after"]:
		assert_true(lines.has(_translate("summary." + key) % int(harvest[key])))
	screen.continue_harvest()
	screen._unhandled_input(_key(KEY_ENTER, true))
	screen._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(screen.modal_kind, "harvest")
	assert_eq(_texts(screen._modal), captions)
	assert_eq(state.to_dict(), before)
	assert_eq(state.harvest_report, harvest)
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), saved)
	screen.continue_harvest()
	assert_eq(state.phase, C.Phase.PLANNING)
	assert_eq(state.year, 2)
	assert_eq(screen.session.turn_history().size(), 1, "year continuation retains the actual turn result")
	_close(screen)


func test_terminal_history_returns_to_game_over_without_recreating_checkpoint() -> void:
	var state: GameState = _quiet_state(4)
	state.tiles[0].water = 0.8
	var screen: GameScreen = _screen(state)
	_finish_turn(screen)
	assert_eq(screen.modal_kind, "game_over")
	assert_eq(state.outcome, C.Outcome.LOSE_HALL)
	assert_true(not SaveIO.has_save(CHECKPOINT_PATH))
	var before: Dictionary = state.to_dict()
	var captions: PackedStringArray = _texts(screen._modal)
	screen._unhandled_input(_key(KEY_H))
	assert_eq(screen.modal_kind, "turn_history")
	assert_eq(screen.session.turn_history()[0]["outcome"], C.Outcome.LOSE_HALL)
	assert_true(_texts(screen._history_details).has(_translate("gameover.lose_hall")))
	screen.request_end_turn()
	screen.continue_harvest()
	screen.close_turn_history()
	assert_eq(screen.modal_kind, "game_over")
	assert_eq(_texts(screen._modal), captions)
	assert_eq(state.to_dict(), before)
	assert_true(not SaveIO.has_save(CHECKPOINT_PATH))
	_close(screen)


func test_history_cannot_replace_confirmation_save_error_or_text_editing() -> void:
	var screen: GameScreen = _screen(_quiet_state(4))
	screen.confirm_unused_labor = true
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_labor")
	var before: Dictionary = screen.session.state.to_dict()
	var captions: PackedStringArray = _texts(screen._modal)
	screen.open_turn_history()
	screen._unhandled_input(_key(KEY_H))
	assert_eq(screen.modal_kind, "confirm_labor")
	assert_eq(_texts(screen._modal), captions)
	screen.close_modal()
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH + ".tmp")), OK)
	screen._return_menu()
	assert_eq(screen.modal_kind, "save_error")
	captions = _texts(screen._modal)
	screen.open_turn_history()
	screen._unhandled_input(_key(KEY_H))
	assert_eq(screen.modal_kind, "save_error")
	assert_eq(_texts(screen._modal), captions)
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH + ".tmp")), OK)
	screen.close_modal()
	var field: LineEdit = LineEdit.new()
	screen.hud.add_child(field)
	field.grab_focus()
	screen._unhandled_input(_key(KEY_H))
	assert_eq(screen.modal_kind, "", "typing H into a field must not open gameplay history")
	field.free()
	screen._unhandled_input(_key(KEY_H))
	assert_eq(screen.modal_kind, "turn_history")
	_close(screen)
