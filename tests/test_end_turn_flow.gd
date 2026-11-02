extends TestCase
## End-turn review and input pacing are UI state, independent of rules and saves.
const DIRECTORY: String = "user://tests/end_turn_flow"
const PATH: String = DIRECTORY + "/checkpoint.json"
const SETTINGS: String = DIRECTORY + "/settings.json"
const HOME: Vector2i = Vector2i(-1, 0)
const FIELD: Vector2i = Vector2i(2, -2)
const HALL: Vector2i = Vector2i(-2, 0)


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	Localization.setup("en")


func _state(damage: bool = false, turn: int = 4) -> GameState:
	return EndTurnFixtures.create(damage, turn)

func _screen(state: GameState = null) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = GameSession.new()
	screen.session.state = _state() if state == null else state
	screen.session.save_path = PATH
	screen.preferences_path = SETTINGS
	assert_eq(screen.session.checkpoint(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = false
	return screen


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func _labels(node: Node) -> String:
	var lines: PackedStringArray = []
	for child: Node in node.get_children():
		if child is Label:
			lines.append(child.text)
		lines.append(_labels(child))
	return "\n".join(lines)


func _key(code: Key, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.echo = echo
	return event


func test_damage_review_is_read_only_localized_and_prefers_return_to_planning() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var screen: GameScreen = _screen(_state(true))
		var before: Dictionary = screen.session.state.to_dict()
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		screen.toggle_preview()
		assert_true(not screen.preview_enabled)
		screen.request_end_turn()
		assert_eq(screen.modal_kind, "confirm_impact")
		assert_true(_labels(screen._modal_content).contains(_tr("turn.review_forecast")))
		assert_true(_labels(screen._modal_content).contains(_tr("turn.commit_explained")))
		var cancel: Button = screen._modal.find_child("CancelEndTurn", true, false) as Button
		assert_eq(screen.get_viewport().gui_get_focus_owner(), cancel)
		assert_true(screen._skip_confirmation == null, "damage warnings cannot be disabled by the labor preference")
		screen._unhandled_input(_key(KEY_SPACE))
		screen.undo_command()
		assert_eq(screen.session.state.to_dict(), before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		assert_true(screen.session.turn_history().is_empty())
		cancel.pressed.emit()
		assert_eq(screen.modal_kind, "")
		assert_eq(screen.session.state.to_dict(), before)
		screen.free()


func test_inspect_risk_selects_the_actual_forecast_coordinate_without_using_a_command() -> void:
	var screen: GameScreen = _screen(_state(true))
	screen.select_command("fill")
	screen.toggle_preview()
	var before: Dictionary = screen.session.state.to_dict()
	screen.request_end_turn()
	var inspect: Button = screen._modal.find_child("EndTurnRisk_-1_0", true, false) as Button
	assert_true(inspect != null)
	inspect.pressed.emit()
	assert_eq(screen.modal_kind, "")
	assert_eq(screen.hovered_coord, HOME)
	assert_eq(screen.board._selected_coord, HOME)
	assert_true(screen.preview_enabled, "risk inspection reveals the forecast even when it was hidden")
	assert_eq(screen.command_mode, "")
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(SaveIO.load_game(PATH)["state"].to_dict(), before)
	screen.free()


func test_partial_hunger_migration_requires_review_even_when_the_village_survives() -> void:
	var state: GameState = _state(false, 6)
	state.food = 2
	state.get_tile(FIELD).feature = C.Feature.NONE
	state.get_tile(Vector2i(1, 0)).building = C.Building.NONE
	var screen: GameScreen = _screen(state)
	assert_eq(screen._predicted_outcome, C.Outcome.NONE)
	assert_true(int(screen.harvest_projection["left_hunger"]) > 0)
	var before: Dictionary = state.to_dict()
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_impact")
	assert_true(_labels(screen._modal_content).contains(_tr("preview.harvest_title")))
	assert_eq(state.to_dict(), before)
	screen._confirm_end_turn()
	assert_eq(screen.modal_kind, "harvest")
	assert_eq(state.outcome, C.Outcome.NONE)
	assert_true(int(state.harvest_report["left_hunger"]) > 0)
	assert_eq(screen.session.turn_history().size(), 1)
	screen.free()


func test_fatal_loss_keeps_priority_over_damage_and_unused_labor() -> void:
	var state: GameState = _state(true)
	state.get_tile(HALL).elevation = 0
	state.get_tile(HALL).water = 0.8
	var screen: GameScreen = _screen(state)
	screen.confirm_unused_labor = true
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_loss")
	assert_true(screen._modal.find_child("EndTurnRisk_-2_0", true, false) != null)
	screen._confirm_end_turn()
	assert_eq(state.phase, C.Phase.GAME_OVER)
	assert_eq(screen.modal_kind, "game_over")
	assert_eq(screen.session.turn_history().size(), 1)
	assert_true(not FileAccess.file_exists(PATH))
	screen.free()


func test_confirmation_resolves_once_and_receipt_uses_committed_facts() -> void:
	var screen: GameScreen = _screen(_state(true))
	var expected: GameState = screen.session.state.duplicate_state()
	var expected_report: TurnReport = GameFlow.end_turn(expected)
	screen.request_end_turn()
	screen._confirm_end_turn()
	screen._confirm_end_turn()
	assert_eq(screen.session.state.to_dict(), expected.to_dict())
	assert_eq(screen.session.turn_history().size(), 1)
	assert_true(screen._turn_receipt.visible)
	assert_true(screen._turn_receipt_label.text.contains(_tr("turn.receipt") % [screen._turn_stamp(screen.session.turn_history()[0]), expected_report.paddy_gains.size(), expected_report.fish_food, expected_report.destroyed.size(), expected_report.paddies_died.size()]))
	assert_true(screen.session.state.undo.is_empty() and screen.session.state.redo.is_empty())
	screen.free()


func test_safe_turn_is_immediate_and_receipt_timestamp_is_the_resolved_turn() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var screen: GameScreen = _screen()
		screen.request_end_turn()
		assert_eq(screen.modal_kind, "")
		assert_eq(screen.session.state.turn, 5)
		assert_true(screen._turn_receipt.visible)
		assert_true(screen._turn_receipt_label.text.contains(_tr("history.turn") % [1, _tr("season.rain"), 4]))
		assert_true(screen._turn_receipt_label.text.contains(_tr("turn.receipt") % [screen._turn_stamp(screen.session.turn_history()[0]), 1, 1, 0, 0]))
		screen.free()


func test_receipt_details_and_dismissal_do_not_write_or_resolve_again() -> void:
	var screen: GameScreen = _screen()
	screen.request_end_turn()
	var before: Dictionary = screen.session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	(screen._turn_receipt.find_child("TurnReceiptHistory", true, false) as Button).pressed.emit()
	assert_eq(screen.modal_kind, "turn_history")
	assert_eq(screen.history_index, 0)
	screen.close_turn_history()
	screen._dismiss_turn_receipt()
	assert_true(not screen._turn_receipt.visible)
	screen.refresh_state()
	assert_true(not screen._turn_receipt.visible, "refresh does not undo dismissal")
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_eq(screen.session.turn_history().size(), 1)
	screen.request_end_turn()
	assert_eq(screen.session.turn_history().size(), 2)
	assert_true(screen._turn_receipt.visible, "the next committed result gets a new receipt")
	screen.free()


func test_mouse_button_and_keyboard_spam_cannot_end_two_turns_within_the_input_guard() -> void:
	var screen: GameScreen = _screen()
	screen._end_button.pressed.emit()
	assert_eq(screen.session.state.turn, 5)
	# Hold the UI clock during this synchronous input sequence. The native
	# probe separately checks the real 400 ms window on a rendering display.
	screen._end_input_locked_until = Time.get_ticks_msec() + 60000
	var before: Dictionary = screen.session.state.to_dict()
	for _repeat: int in range(5):
		screen._end_button.pressed.emit()
		screen._unhandled_input(_key(KEY_SPACE))
		screen._unhandled_input(_key(KEY_ENTER))
		screen._unhandled_input(_key(KEY_ENTER, true))
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.session.turn_history().size(), 1)
	assert_true(screen._end_button.disabled)
	screen.select_command("fill")
	var target: Vector2i = screen.valid_targets("fill")[0]
	var tile: Tile = screen.session.state.get_tile(target)
	var height_before: int = tile.elevation
	var at: Vector3 = Hex.to_world(target, tile.elevation)
	at.y = screen.board._surface_y(tile)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = screen.camera_rig.get_camera().unproject_position(screen.board.to_global(at))
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_eq(screen.board.pick(screen.camera_rig.get_camera(), click.position).coord, target)
	screen._unhandled_input(click)
	assert_eq(screen.session.state.to_dict(), before, "a confirmation's trailing click cannot build on the newly exposed board")
	# Controlled UI-clock expiry, without waiting or changing any game state.
	screen._end_input_locked_until = Time.get_ticks_msec() - 1
	screen._process(0.0)
	assert_true(not screen._end_button.disabled)
	assert_eq(screen.session.state.to_dict(), before)
	screen._unhandled_input(click)
	assert_eq(screen.session.state.get_tile(target).elevation, height_before + 1)
	screen._end_button.pressed.emit()
	assert_eq(screen.session.state.turn, 6)
	assert_eq(screen.session.turn_history().size(), 2)
	screen.free()


func test_labor_opt_out_still_applies_only_to_unused_labor_not_losses() -> void:
	var screen: GameScreen = _screen()
	screen.confirm_unused_labor = true
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_labor")
	screen._skip_confirmation.button_pressed = true
	screen._confirm_end_turn()
	assert_true(not screen.confirm_unused_labor)
	assert_eq(GamePreferences.read(SETTINGS)["confirm_unused_labor"], false)
	screen.session.state = _state(true)
	screen.refresh_state()
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_impact")
	assert_true(screen._skip_confirmation == null)
	screen.free()


func test_load_starts_without_a_fabricated_receipt_and_harvest_remains_the_authoritative_summary() -> void:
	var screen: GameScreen = _screen(_state(false, 6))
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "harvest")
	var saved: Dictionary = screen.session.state.to_dict()
	var loaded: GameSession = GameSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_game(), "")
	screen.free()
	screen = GameScreen.new()
	screen.session = loaded
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	assert_eq(screen.modal_kind, "harvest")
	assert_true(not screen._turn_receipt.visible)
	assert_eq(screen.session.state.to_dict(), saved)
	screen.continue_harvest()
	assert_eq(screen.session.state.year, 2)
	assert_eq(screen.session.turn_history().size(), 0)
	screen.free()


func test_new_harvest_summary_cannot_be_skipped_by_a_repeated_end_turn_activation() -> void:
	var screen: GameScreen = _screen(_state(false, 6))
	screen._end_button.pressed.emit()
	assert_eq(screen.modal_kind, "harvest")
	screen._end_input_locked_until = Time.get_ticks_msec() + 60000
	var before: Dictionary = screen.session.state.to_dict()
	var next: Button = screen._modal.find_child("ContinueHarvest", true, false) as Button
	assert_true(next.disabled)
	for _repeat: int in range(3):
		next.pressed.emit()
		screen.request_end_turn_from_input()
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.session.turn_history().size(), 1)
	assert_eq(screen.modal_kind, "harvest")
	screen._end_input_locked_until = Time.get_ticks_msec() - 1
	screen._process(0.0)
	assert_true(not next.disabled)
	assert_eq(screen.get_viewport().gui_get_focus_owner(), next, "keyboard continuation regains its safe default focus after the guard")
	next.pressed.emit()
	assert_eq(screen.session.state.year, 2)
	assert_eq(screen.session.state.turn, 1)
	assert_eq(screen.modal_kind, "")
	screen.free()


func test_school_end_turn_uses_the_same_receipt_and_input_guard_and_retry_resets_both() -> void:
	var run: RiverSchoolRun = RiverSchoolRun.new()
	assert_true(run.start("river_school_01"))
	var screen: RiverSchoolScreen = RiverSchoolScreen.new()
	screen.lesson = run
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.confirm_unused_labor = false
	screen._end_button.pressed.emit()
	assert_eq(run.turns_resolved, 1)
	screen._end_button.pressed.emit()
	assert_eq(run.turns_resolved, 1)
	assert_true(screen._turn_receipt.visible)
	screen.retry_lesson()
	assert_eq(screen._end_input_locked_until, 0)
	assert_true(not screen._turn_receipt.visible)
	screen._end_button.pressed.emit()
	assert_eq(run.turns_resolved, 1)
	screen.free()


func test_keyboard_receipt_details_and_dismissal_do_not_trigger_the_end_turn_shortcut() -> void:
	var screen: GameScreen = _screen()
	screen.request_end_turn()
	screen._end_input_locked_until = Time.get_ticks_msec() - 1
	screen._process(0.0)
	screen.set_process_unhandled_input(true)
	var before: Dictionary = screen.session.state.to_dict()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var details: Button = screen._turn_receipt.find_child("TurnReceiptHistory", true, false) as Button
	details.grab_focus()
	var event: InputEventKey = _key(KEY_ENTER)
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)
	assert_eq(screen.modal_kind, "turn_history")
	assert_eq(screen.session.state.to_dict(), before)
	screen.close_turn_history()
	var dismiss: Button = screen._turn_receipt.find_child("DismissTurnReceipt", true, false) as Button
	dismiss.grab_focus()
	event = _key(KEY_ENTER)
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)
	assert_true(not screen._turn_receipt.visible)
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.session.turn_history().size(), 1)
	screen.free()
