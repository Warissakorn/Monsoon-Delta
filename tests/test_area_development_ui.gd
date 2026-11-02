extends TestCase
const F = preload("res://tools/area_development_fixtures.gd")
const DIRECTORY: String = "user://tests/area_development"
const PATH: String = DIRECTORY + "/checkpoint.json"
const SETTINGS: String = DIRECTORY + "/settings.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	Localization.setup("en")


func _screen(state: GameState = null) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = GameSession.new()
	screen.session.state = F.create() if state == null else state
	screen.session.save_path = PATH
	screen.preferences_path = SETTINGS
	assert_eq(screen.session.checkpoint(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	return screen


func _choose(screen: GameScreen, id: String) -> void:
	var panel: AreaDevelopmentPanel = screen._area_panel
	var index: int = panel._options.find(id)
	assert_true(index >= 0, id)
	if index >= 0:
		panel._choice.select(index)
		panel._choice.item_selected.emit(index)


func _texts(node: Node) -> String:
	var result: PackedStringArray = []
	for child: Node in node.get_children():
		if child is Label:
			result.append(child.text)
		result.append(_texts(child))
	return "\n".join(result)


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func test_selected_area_stays_in_inspector_and_unpin_does_not_change_the_run() -> void:
	var screen: GameScreen = _screen()
	var before: Dictionary = screen.session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen.apply_at(F.LAND)
	assert_eq(screen._pinned_coord, F.LAND)
	screen.hovered_coord = BoardView.NO_COORD
	screen._update_inspector()
	assert_true(screen._tile_title.text.contains("(0, 0)"))
	assert_true(not screen._area_button.disabled)
	screen.open_area_development()
	assert_eq(screen._area_coord, F.LAND)
	screen._close_area_development()
	screen._clear_area_selection()
	assert_eq(screen._pinned_coord, BoardView.NO_COORD)
	assert_true(not screen._area_button.visible)
	assert_eq(screen.board._selected_coord, BoardView.NO_COORD)
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen.free()


func test_open_preview_and_cancel_are_read_only_localized_and_safely_focused() -> void:
	for locale: String in ["en", "th"]:
		Localization.setup(locale)
		var screen: GameScreen = _screen()
		var before: Dictionary = screen.session.state.to_dict()
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		screen.open_area_development(F.LAND)
		assert_eq(screen.modal_kind, "area_development")
		assert_eq(screen.get_viewport().gui_get_focus_owner(), screen._area_panel._back)
		_choose(screen, "house")
		assert_true(_texts(screen._area_panel).contains(_tr("area.role.upland")))
		assert_true(_texts(screen._area_panel).contains(_tr("area.not_committed")))
		assert_true(_texts(screen._area_panel).contains(_tr("area.resources") % [6, 4, 12, 10, 10, 12]))
		assert_true(not screen._area_panel._apply.disabled)
		assert_eq(screen.session.state.to_dict(), before)
		assert_true(screen.session.state.undo.is_empty())
		assert_true(screen.session.turn_history().is_empty())
		screen._unhandled_input(_key(KEY_ESCAPE))
		assert_eq(screen.modal_kind, "")
		assert_eq(screen._area_panel, null)
		assert_eq(screen.session.state.to_dict(), before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		screen.free()


func test_apply_commits_once_and_keyboard_bursts_cannot_close_or_end_a_turn() -> void:
	var screen: GameScreen = _screen()
	screen.open_area_development(F.LAND)
	_choose(screen, "fill")
	var projected: Dictionary = (screen._area_panel._plan["state"] as GameState).to_dict()
	screen._area_panel._apply.pressed.emit()
	assert_eq(screen.session.state.to_dict(), projected)
	assert_true(screen._area_panel._apply.disabled)
	assert_eq(screen.get_viewport().gui_get_focus_owner(), screen._area_panel._receipt)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen._area_panel._apply.pressed.emit()
	screen._area_panel._request_command()
	screen.set_process_unhandled_input(true)
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	for code: Key in [KEY_ENTER, KEY_SPACE, KEY_ENTER]:
		root.push_input(_key(code))
		root.push_input(_key(code, false))
	assert_eq(screen.session.state.to_dict(), projected)
	assert_eq(screen.session.state.undo.size(), 1)
	assert_true(screen.session.turn_history().is_empty())
	assert_eq(screen.modal_kind, "area_development")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen.free()


func test_another_explicit_choice_can_apply_then_undo_redo_and_load_are_exact() -> void:
	var screen: GameScreen = _screen()
	var original: Dictionary = screen.session.state.to_dict()
	screen.open_area_development(F.LAND)
	_choose(screen, "fill")
	screen._area_panel._request_command()
	var first: Dictionary = screen.session.state.to_dict()
	_choose(screen, "paddy")
	assert_true(not screen._area_panel._apply.disabled)
	screen._area_panel._request_command()
	var final: Dictionary = screen.session.state.to_dict()
	assert_eq(screen.session.state.get_tile(F.LAND).feature, C.Feature.PADDY)
	screen._close_area_development()
	screen.undo_command()
	assert_eq(screen.session.state.to_dict(), first)
	screen.undo_command()
	assert_eq(screen.session.state.to_dict(), original)
	screen.redo_command()
	screen.redo_command()
	assert_eq(screen.session.state.to_dict(), final)
	assert_eq(screen._pinned_coord, F.LAND)
	var loaded: GameSession = GameSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_game(), "")
	assert_eq(loaded.state.to_dict(), final)
	assert_true(loaded.state.undo.is_empty())
	screen.free()


func test_season_and_budget_errors_disable_commit_with_the_original_reason() -> void:
	var state: GameState = F.create(true)
	state.wood = 0
	var screen: GameScreen = _screen(state)
	screen.open_area_development(F.LAND)
	_choose(screen, "paddy")
	assert_true(screen._area_panel._apply.disabled)
	assert_true(_texts(screen._area_panel).contains(_tr("err.season")))
	_choose(screen, "house")
	assert_true(screen._area_panel._apply.disabled)
	assert_true(_texts(screen._area_panel).contains(_tr("err.wood")))
	var before: Dictionary = state.to_dict()
	screen._area_panel._request_command()
	assert_eq(state.to_dict(), before)
	screen.free()


func test_a_stale_plan_refreshes_without_spending_resources_again() -> void:
	var screen: GameScreen = _screen()
	screen.open_area_development(F.LAND)
	_choose(screen, "house")
	# A trusted external controller change invalidates the pending UI plan.
	assert_eq(screen.session.apply(Command.new("fill", F.LOW)), "")
	var before: Dictionary = screen.session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen._area_panel._request_command()
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_true(screen._area_panel._receipt.text.contains(_tr("area.changed")))
	assert_eq(screen.session.state.get_tile(F.LAND).building, C.Building.NONE)
	screen.free()


func test_gate_and_waterwheel_use_real_parameters_and_leave_other_sites_unchanged() -> void:
	var screen: GameScreen = _screen(F.create(false, "legacy", "long"))
	screen.open_area_development(F.GATE)
	_choose(screen, "toggle_gate")
	assert_true(not screen._area_panel._apply.disabled)
	screen._area_panel._request_command()
	assert_true(not screen.session.state.get_tile(F.GATE).gate_open)
	assert_eq(screen.session.state.labor, 6)
	screen._close_area_development()
	screen.open_area_development(F.LAND)
	_choose(screen, "waterwheel")
	var panel: AreaDevelopmentPanel = screen._area_panel
	assert_true(panel._parameter.visible)
	panel._parameter.select(3)
	panel._parameter.item_selected.emit(3)
	assert_eq(panel._command.param, 3)
	panel._request_command()
	assert_eq(screen.session.state.get_tile(F.LAND).building, C.Building.WATERWHEEL)
	assert_eq(screen.session.state.get_tile(F.LAND).wheel_dir, 3)
	assert_true(not screen.session.state.get_tile(F.GATE).gate_open)
	screen.free()


func test_irrigation_and_bracing_keep_their_ruleset_fields_through_preview_and_apply() -> void:
	var screen: GameScreen = _screen(F.create(false, "bracing_moisture_irrigation_v1"))
	screen.open_area_development(F.FIELD)
	_choose(screen, "irrigation_policy")
	screen._area_panel._parameter.select(2)
	screen._area_panel._parameter.item_selected.emit(2)
	screen._area_panel._request_command()
	assert_eq(screen.session.state.get_tile(F.FIELD).irrigation_policy, "skip")
	screen._close_area_development()
	screen.open_area_development(F.HOUSE)
	_choose(screen, "brace_house")
	screen._area_panel._request_command()
	assert_eq(screen.session.state.get_tile(F.HOUSE).brace_turns, 1)
	var loaded: Dictionary = SaveIO.load_game(PATH)
	assert_eq(loaded["error"], "")
	assert_eq((loaded["state"] as GameState).to_dict(), screen.session.state.to_dict())
	screen.free()


func test_non_developable_areas_and_non_planning_phases_cannot_issue_commands() -> void:
	var screen: GameScreen = _screen()
	for coord: Vector2i in [F.SEA, F.SOURCE, F.HALL]:
		var before: Dictionary = screen.session.state.to_dict()
		screen.open_area_development(coord)
		assert_true(screen._area_panel._apply.disabled)
		assert_true(not screen._area_panel._choice.visible)
		assert_true(_texts(screen._area_panel).contains(_tr("area.no_actions")))
		screen._area_panel._request_command()
		assert_eq(screen.session.state.to_dict(), before)
		screen._close_area_development()
	screen.open_pause()
	screen.open_area_development(F.LAND)
	assert_eq(screen.modal_kind, "pause")
	screen.close_modal()
	screen.session.state.phase = C.Phase.HARVEST
	screen.open_area_development(F.LAND)
	assert_eq(screen.modal_kind, "")
	screen.free()


func test_area_preview_cannot_clear_an_existing_redo_or_completed_turn_history() -> void:
	var screen: GameScreen = _screen()
	screen._finish_turn()
	screen.select_command("fill")
	screen.apply_at(F.LAND)
	screen.undo_command()
	var history: Array[Dictionary] = screen.session.turn_history()
	var redo: Array[Dictionary] = screen.session.state.redo.snapshots()
	var before: Dictionary = screen.session.state.to_dict()
	screen.open_area_development(F.LAND)
	_choose(screen, "house")
	screen._close_area_development()
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.session.state.redo.snapshots(), redo)
	assert_eq(screen.session.turn_history(), history)
	screen.free()


func test_school_exit_cancel_restores_the_same_area_plan_and_retry_clears_selection() -> void:
	var lesson: RiverSchoolRun = RiverSchoolRun.new()
	assert_true(lesson.start("river_school_02"))
	var screen: RiverSchoolScreen = RiverSchoolScreen.new()
	screen.lesson = lesson
	screen.session = lesson.session
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	var coord: Vector2i = RiverSchoolFixtures.target_houses("river_school_02")[0]
	screen.open_area_development(coord)
	_choose(screen, "demolish")
	var panel: AreaDevelopmentPanel = screen._area_panel
	screen._leave_game(func(): fail("cancelling must stay in the lesson"))
	assert_eq(screen.modal_kind, "school_exit")
	screen._close_school_modal()
	assert_eq(screen.modal_kind, "area_development")
	assert_eq(screen._area_panel, panel)
	panel._request_command()
	assert_true(lesson.session.target_removals().has(coord))
	screen._close_area_development()
	screen.undo_command()
	assert_true(lesson.session.target_removals().is_empty())
	screen.open_area_development(coord)
	screen._leave_game(func(): pass)
	screen.retry_lesson()
	assert_eq(screen.modal_kind, "")
	assert_eq(screen._pinned_coord, BoardView.NO_COORD)
	assert_eq(screen._area_panel, null)
	assert_true(screen.session.turn_history().is_empty())
	screen.free()
