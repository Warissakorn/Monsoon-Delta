extends TestCase
## Inspect committed locations without replaying or changing the live game.
const DIRECTORY: String = "user://tests/turn_result_inspection"
const PATH: String = DIRECTORY + "/checkpoint.json"
const SETTINGS: String = DIRECTORY + "/settings.json"
const F = preload("res://tools/end_turn_fixtures.gd")


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	Localization.setup("en")


func _screen(state: GameState = null) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = GameSession.new()
	screen.session.state = F.create(true) if state == null else state
	screen.session.save_path = PATH
	screen.preferences_path = SETTINGS
	assert_eq(screen.session.checkpoint(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = false
	screen._finish_turn()
	screen._end_input_locked_until = 0
	return screen


func _school(turn: int = 4) -> RiverSchoolScreen:
	var lesson: RiverSchoolRun = RiverSchoolRun.new()
	assert_true(lesson.start("river_school_01"))
	# An authored UI fixture, installed before the first test activation.
	lesson.session.state = F.create(false, turn)
	lesson.session.state.is_tutorial = true
	var screen: RiverSchoolScreen = RiverSchoolScreen.new()
	screen.lesson = lesson
	screen.session = lesson.session
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen._finish_turn()
	screen._end_input_locked_until = 0
	return screen


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func _labels(node: Node) -> String:
	var result: PackedStringArray = []
	for child: Node in node.get_children():
		if child is Label:
			result.append(child.text)
		result.append(_labels(child))
	return "\n".join(result)


func test_fish_locations_are_actual_detached_session_facts_and_do_not_enter_saves() -> void:
	var screen: GameScreen = _screen(F.create())
	var entry: Dictionary = screen.session.turn_history()[0]
	var actual: Dictionary = entry["report"]["fish_food_by_tile"]
	assert_eq(actual, {Vector2i(1, 0): 1})
	var report: TurnReport = screen.session.advance_turn()
	var recorded: Array[Dictionary] = screen.session.turn_history()
	report.fish_food_by_tile.clear()
	var detached: Array[Dictionary] = screen.session.turn_history()
	detached[1]["report"]["fish_food_by_tile"].clear()
	assert_eq(screen.session.turn_history(), recorded)
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_true(not JSON.stringify(envelope).contains("fish_food_by_tile"))
	var loaded: GameSession = GameSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_game(), "")
	assert_true(loaded.turn_history().is_empty())
	screen.free()


func test_locations_are_localized_prioritize_damage_and_support_older_reports() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var screen: GameScreen = _screen()
		var entry: Dictionary = screen.session.turn_history()[0]
		var locations: Array[Dictionary] = TurnResultLocations.collect(entry)
		assert_eq(locations.size(), 3)
		assert_eq(locations[0]["coord"], F.HOME)
		assert_eq(locations[1]["coord"], F.FIELD)
		assert_true(locations[0]["lines"].has(_tr("feedback.destroyed") % _tr("building.house")))
		assert_true(locations[1]["lines"].has(_tr("feedback.rice_lost")))
		assert_true(locations[2]["lines"].has(_tr("history.map_fish") % 1))
		entry["report"].erase("fish_food_by_tile")
		assert_eq(TurnResultLocations.collect(entry).size(), 2, "old reports must not infer trap positions from the current board")
		screen.free()


func test_same_tile_events_are_grouped_and_rice_remains_distinct_from_food() -> void:
	var screen: GameScreen = _screen(F.create())
	var entry: Dictionary = screen.session.turn_history()[0]
	entry["report"]["fish_food_by_tile"][F.FIELD] = 2
	var locations: Array[Dictionary] = TurnResultLocations.collect(entry)
	assert_eq(locations.size(), 2)
	assert_eq(locations[0]["coord"], F.FIELD)
	assert_true(locations[0]["lines"].has(_tr("history.yield_note")))
	assert_true(locations[0]["lines"].has(_tr("history.map_fish") % 2))
	assert_eq(screen.session.turn_history()[0]["report"]["fish_food_by_tile"], {Vector2i(1, 0): 1})
	screen.free()


func test_inspection_preserves_model_rng_stacks_checkpoint_and_selected_tool() -> void:
	var screen: GameScreen = _screen()
	screen.select_command("house")
	var site: Vector2i = screen.valid_targets("house")[0]
	screen.apply_at(site)
	screen.select_command("demolish")
	screen.apply_at(site)
	screen.undo_command()
	screen.select_command("fill")
	assert_eq(screen.session.state.undo.size(), 1)
	assert_eq(screen.session.state.redo.size(), 1)
	var before: Dictionary = screen.session.state.to_dict()
	var undo: Array[Dictionary] = screen.session.state.undo.snapshots()
	var redo: Array[Dictionary] = screen.session.state.redo.snapshots()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var history: Array[Dictionary] = screen.session.turn_history()
	screen.open_turn_history()
	screen._inspect_history_location(0)
	assert_eq(screen.modal_kind, "history_map")
	assert_eq(screen.board._selected_coord, F.HOME)
	assert_true(screen.board._result_marker.visible)
	assert_true((screen.board._result_marker.material_override as StandardMaterial3D).no_depth_test)
	assert_true(not (screen.board._selection.material_override as StandardMaterial3D).no_depth_test, "ordinary selection materials must keep their depth")
	assert_true(not screen.preview_enabled)
	assert_true(screen.board._prediction.is_empty(), "do not draw next-turn forecasts as historical results")
	assert_eq(screen.command_mode, "fill", "inspection suspends the tool without changing the plan")
	screen.select_command("dig")
	screen.apply_at(F.HOME)
	screen.undo_command()
	screen.redo_command()
	screen.request_end_turn_from_input()
	screen._unhandled_input(_key(KEY_SPACE))
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen._unhandled_input(click)
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.session.state.undo.snapshots(), undo)
	assert_eq(screen.session.state.redo.snapshots(), redo)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_eq(screen.session.turn_history(), history)
	screen._return_from_history_map()
	assert_eq(screen.modal_kind, "turn_history")
	assert_true(screen.preview_enabled)
	assert_true(not screen.board._result_marker.visible)
	assert_eq(screen.command_mode, "fill")
	screen.free()


func test_historical_inspection_uses_recorded_damage_after_a_player_changes_the_site() -> void:
	var screen: GameScreen = _screen()
	# A real planning command changes this site after the recorded loss.
	var height: int = screen.session.state.get_tile(F.HOME).elevation
	assert_eq(screen.session.apply(Command.new("fill", F.HOME)), "")
	assert_eq(screen.session.state.get_tile(F.HOME).elevation, height + 1)
	screen.refresh_state()
	var before: Dictionary = screen.session.state.to_dict()
	screen.open_turn_history()
	screen._inspect_history_location(0)
	var text: String = _labels(screen._history_map_panel)
	assert_true(text.contains(_tr("feedback.destroyed") % _tr("building.house")))
	assert_true(text.contains(_tr("history.map_current")))
	assert_true(text.contains(_tr("history.map_stamp") % (_tr("history.turn") % [1, _tr("season.rain"), 4])))
	assert_true(screen._tile_title.text.contains(_tr("tile.land")))
	assert_eq(screen.session.state.to_dict(), before)
	screen.free()


func test_location_navigation_has_boundaries_and_invalid_activations_are_noops() -> void:
	var screen: GameScreen = _screen()
	screen.open_turn_history()
	screen._inspect_history_location(-1)
	screen._inspect_history_location(99)
	assert_eq(screen.modal_kind, "turn_history")
	screen._inspect_history_location(0)
	assert_true((screen._history_map_panel.find_child("PreviousHistoryLocation", true, false) as Button).disabled)
	screen._show_history_location(1)
	assert_eq(screen.board._selected_coord, F.FIELD)
	screen._show_history_location(2)
	assert_eq(screen.board._selected_coord, Vector2i(1, 0))
	assert_true((screen._history_map_panel.find_child("NextHistoryLocation", true, false) as Button).disabled)
	screen._show_history_location(3)
	screen._inspect_history_location(0)
	assert_eq(screen._history_map_index, 2)
	screen._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(screen.modal_kind, "turn_history")
	assert_eq(screen._history_map_index, -1)
	screen.free()


func test_return_preserves_report_identity_scroll_focus_and_view_preferences() -> void:
	for preview: bool in [false, true]:
		var screen: GameScreen = _screen()
		screen._finish_turn()
		if not preview:
			screen.toggle_preview()
		screen._dismiss_turn_receipt()
		screen.open_turn_history()
		screen._change_history(-1)
		var modal: Control = screen._modal
		var scroll: ScrollContainer = screen._history_scroll
		var focus: Button = screen._modal.find_child("HistoryLocation_-1_0", true, false) as Button
		focus.grab_focus()
		var offset: int = scroll.scroll_vertical
		var camera: Vector3 = screen.camera_rig.position
		var selected: Vector2i = screen.board._selected_coord
		screen._inspect_history_location(0)
		assert_true(not screen._turn_receipt.visible)
		screen._return_from_history_map()
		assert_eq(screen._modal, modal)
		assert_eq(screen._history_scroll, scroll)
		assert_eq(screen.history_index, 0)
		assert_eq(scroll.scroll_vertical, offset)
		assert_eq(screen.get_viewport().gui_get_focus_owner(), focus)
		assert_eq(screen.preview_enabled, preview)
		assert_true(not screen._turn_receipt.visible, "return does not undo a deliberate dismissal")
		assert_eq(screen.camera_rig.position, camera)
		assert_eq(screen.board._selected_coord, selected)
		screen.free()


func test_enter_on_map_return_restores_report_without_ending_another_turn() -> void:
	var screen: GameScreen = _screen()
	screen.open_turn_history()
	screen._inspect_history_location(0)
	screen.set_process_unhandled_input(true)
	var before: Dictionary = screen.session.state.to_dict()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.push_input(_key(KEY_ENTER))
	var release: InputEventKey = _key(KEY_ENTER)
	release.pressed = false
	root.push_input(release)
	assert_eq(screen.modal_kind, "turn_history")
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.session.turn_history().size(), 1)
	screen.free()


func test_harvest_and_pause_return_to_their_original_dialog_without_advancing() -> void:
	for harvest: bool in [false, true]:
		var screen: GameScreen = _screen(F.create(false, 6 if harvest else 4))
		if not harvest:
			screen.open_pause()
		var previous: String = screen.modal_kind
		var before: Dictionary = screen.session.state.to_dict()
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		screen.open_turn_history()
		screen._inspect_history_location(0)
		screen._return_from_history_map()
		screen.close_turn_history()
		assert_eq(screen.modal_kind, previous)
		assert_eq(screen.session.state.to_dict(), before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		screen.free()


func test_game_over_inspection_does_not_recreate_the_deleted_checkpoint() -> void:
	var state: GameState = F.create(true)
	state.get_tile(F.HALL).elevation = 0
	state.get_tile(F.HALL).water = 0.8
	var screen: GameScreen = _screen(state)
	assert_eq(screen.modal_kind, "game_over")
	assert_true(not FileAccess.file_exists(PATH))
	var before: Dictionary = screen.session.state.to_dict()
	screen.open_turn_history()
	screen._inspect_history_location(0)
	screen._return_from_history_map()
	screen.close_turn_history()
	assert_eq(screen.modal_kind, "game_over")
	assert_eq(screen.session.state.to_dict(), before)
	assert_true(not FileAccess.file_exists(PATH))
	screen.free()


func test_school_exit_cancel_restores_map_inspection_and_retry_restores_preview() -> void:
	var screen: RiverSchoolScreen = _school()
	screen.open_turn_history()
	screen._inspect_history_location(0)
	var panel: PanelContainer = screen._history_map_panel
	var before: Dictionary = screen.session.state.to_dict()
	screen._leave_game(func(): assert_true(false, "cancelling must not leave the lesson"))
	assert_eq(screen.modal_kind, "school_exit")
	screen._close_school_modal()
	assert_eq(screen.modal_kind, "history_map")
	assert_eq(screen._history_map_panel, panel)
	assert_true(panel.is_visible_in_tree())
	assert_eq(screen.session.state.to_dict(), before)
	screen._leave_game(func(): pass)
	screen.retry_lesson()
	assert_eq(screen.modal_kind, "")
	assert_true(screen.preview_enabled)
	assert_true(screen._history_map_context.is_empty())
	assert_true(screen._history_map_panel == null)
	assert_true(screen.session.turn_history().is_empty())
	screen.open_turn_history()
	assert_true(screen._history_map_locations.is_empty())
	screen.free()


func test_completed_school_returns_to_the_same_lesson_result() -> void:
	var screen: RiverSchoolScreen = _school(6)
	assert_eq(screen.modal_kind, "school_result")
	var result: Dictionary = screen.lesson.result()
	var before: Dictionary = screen.session.state.to_dict()
	screen.open_turn_history()
	screen._inspect_history_location(0)
	screen._return_from_history_map()
	screen.close_turn_history()
	assert_eq(screen.modal_kind, "school_result")
	assert_eq(screen.lesson.result(), result)
	assert_eq(screen.session.state.to_dict(), before)
	screen.free()
