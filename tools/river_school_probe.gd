extends SceneTree
## Native input/visual evidence for the playable prepared River School boards.
## DISPLAY=:99 godot --path . --audio-driver Dummy --resolution 1280x720 \
##   --script res://tools/river_school_probe.gd -- --out-dir=/absolute/work/river-school-qa/en --lang=en
## Add --modal-only to check interrupted dialogs on the real prepared board.

var _out_dir: String = ""
var _language: String = "en"
var _modal_only: bool = false
var _normal_path: String
var _preferences_path: String
var _normal_bytes: PackedByteArray
var _screen: RiverSchoolScreen
var _menu: MainMenu
var _lesson: RiverSchoolRun
var _badge: Label
var _checks: Dictionary = {}
var _captures: Array[Dictionary] = []
var _failed: bool = false
var _started: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			_out_dir = argument.trim_prefix("--out-dir=")
		elif argument.begins_with("--lang="):
			_language = argument.trim_prefix("--lang=")
		elif argument == "--modal-only":
			_modal_only = true
	if DisplayServer.get_name() == "headless" or _language not in ["th", "en"] or not _out_dir.is_absolute_path():
		printerr("River School probe needs a native display, --lang=th|en and an absolute --out-dir.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_normal_path = _out_dir.path_join("normal-checkpoint.json")
	_preferences_path = _out_dir.path_join("settings.json")
	Localization.setup(_language)
	root.size = Vector2i(1280, 720)
	root.min_size = root.size
	_check("isolated_preferences", GamePreferences.write({"language": _language, "confirm_unused_labor": false, "reduced_motion": false}, _preferences_path).is_empty())
	_check("normal_checkpoint_created", SaveIO.save(GameFlow.new_game({"seed": 91, "ruleset": "bracing_moisture_v1", "living_village": true}), _normal_path).is_empty())
	_normal_bytes = FileAccess.get_file_as_bytes(_normal_path)
	_add_badge()
	if _modal_only:
		_start_lesson("river_school_01")
		await _frames(2)
		await _modal_restoration_checks()
		_finish()
		return
	_show_menu(false)
	await _frames(2)
	_check("normal_continue_initially_visible", _menu._continue_button.is_visible_in_tree())
	await _click_control(_menu._school_button)
	_check("native_school_selector", _menu._school.is_visible_in_tree() and not _menu._home.visible)
	_check("selector_explains_memory_only", _labels(_menu._school).contains(_tr("school.no_checkpoint")))
	await _capture("school-choose", "PLAYABLE PREPARED BOARDS / CHOOSE A LESSON")
	var first: Button = _menu._school.find_child("Lesson_river_school_01", true, false) as Button
	first.grab_focus()
	await _frames(2)
	await _key(KEY_ENTER)
	_check("native_enter_starts_first_lesson", _started == "river_school_01" and _screen != null)
	if _screen == null:
		_finish()
		return
	_check("start_activation_does_not_end_turn", _lesson.turns_resolved == 0 and _lesson.session.state.turn == 1)
	_check("lesson_banner_not_saved", _screen._save_label.text == _tr("school.no_checkpoint") and _screen._save_label.text != _tr("msg.saved"))
	var initial: Dictionary = _snapshot()
	var preferences_before: PackedByteArray = FileAccess.get_file_as_bytes(_preferences_path)
	root.gui_release_focus()
	await _key(KEY_F1)
	_check("native_hint_opens", _screen.modal_kind == "school_hint" and _screen.hint_level == 1)
	await _click_named("SchoolNextHint")
	await _click_named("SchoolNextHint")
	_check("voluntary_third_hint", _screen.hint_level == 3 and _labels(_screen._modal_content).contains(_tr("school.solution_turn") % 1))
	_check("hint_panel_fits", root.get_visible_rect().encloses(_screen._modal_content.get_global_rect()))
	await _capture("school-hint", "PLAYABLE PREPARED BOARD / VOLUNTARY VERIFIED PLAN")
	await _key(KEY_ESCAPE)
	_check("hints_and_focus_read_only", _snapshot() == initial and FileAccess.get_file_as_bytes(_preferences_path) == preferences_before)
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	_check("preview_read_only", _snapshot() == initial)
	await _replay(RiverSchoolFixtures.solutions("river_school_01")[0])
	_check("first_lesson_actual_success", _lesson.completed and _lesson.passed and _lesson.mastered and _screen.modal_kind == "school_result")
	if not _lesson.completed or _screen.modal_kind != "school_result":
		_finish()
		return
	_check("short_result_not_five_year_win", _lesson.session.state.phase == C.Phase.HARVEST and _lesson.session.state.outcome == C.Outcome.NONE and _lesson.session.state.year == 1)
	_check("first_result_fits", root.get_visible_rect().encloses(_screen._modal_content.get_global_rect()))
	await _capture("school-first-success", "PLAYABLE PREPARED BOARD / FIRST RAIN COMPLETED")
	var completed: Dictionary = _snapshot()
	await _key(KEY_H)
	_check("result_history_native", _screen.modal_kind == "turn_history" and _lesson.session.turn_history().size() == 6)
	await _key(KEY_ESCAPE)
	_check("history_returns_to_lesson_result", _screen.modal_kind == "school_result" and _snapshot() == completed)
	await _click_named("SchoolRetry")
	_check("native_retry_exact_board_rng", _snapshot() == initial and _screen.hint_level == 0 and _screen.modal_kind.is_empty())
	await _modal_restoration_checks()
	_check("modal_checks_retry_exact_board_rng", _snapshot() == initial and _screen.hint_level == 0 and _screen.modal_kind.is_empty())
	for turn: int in range(6):
		await _end_turn("do_nothing_%d" % (turn + 1))
	_check("do_nothing_is_factual_failure", _lesson.completed and not _lesson.passed and _lesson.result()["reasons"].has("school.reason.no_rice"))
	_check("failed_result_fits", root.get_visible_rect().encloses(_screen._modal_content.get_global_rect()))
	await _capture("school-failure", "PLAYABLE PREPARED BOARD / NO RICE AT HARVEST")
	await _click_named("SchoolRetry")
	await _exit_confirmation_checks()
	if _menu == null:
		_finish()
		return
	var third: Button = _menu._school.find_child("Lesson_river_school_03", true, false) as Button
	third.grab_focus()
	await _frames(2)
	await _click_control(third)
	_check("native_second_challenge_start", _started == "river_school_03" and _lesson.session.state.food == 0 and _lesson.turns_resolved == 0)
	root.gui_release_focus()
	await _key(KEY_ESCAPE)
	_check("native_pause", _screen.modal_kind == "pause")
	await _click_control(_screen._motion_toggle)
	_check("native_reduce_motion", _screen.reduced_motion and _screen.board._reduced_motion)
	_check("pause_fits", root.get_visible_rect().encloses(_screen._modal_content.get_global_rect()))
	await _capture("school-pause", "PLAYABLE PREPARED BOARD / PAUSE AND REDUCE MOTION")
	await _click_named("Resume")
	_check("native_pause_resumes", _screen.modal_kind.is_empty())
	var mixed: Dictionary = {}
	for solution: Dictionary in RiverSchoolFixtures.solutions("river_school_03"):
		if solution["id"] == "mixed":
			mixed = solution
	_check("mixed_solution_available", not mixed.is_empty())
	if mixed.is_empty():
		_finish()
		return
	await _replay(mixed)
	_check("mixed_path_actual_mastery", _lesson.completed and _lesson.passed and _lesson.mastered and _lesson.fish_food > 0 and int(_lesson.result()["harvest"].get("paddy_food", 0)) > 0)
	if not _lesson.completed or _screen.modal_kind != "school_result":
		_finish()
		return
	_check("mastery_result_fits", root.get_visible_rect().encloses(_screen._modal_content.get_global_rect()))
	await _capture("school-food-mastery", "PLAYABLE PREPARED BOARD / RICE AND FISH MASTERY")
	await _click_named("SchoolChoose")
	_check("completed_attempt_returns_selector", _menu != null and _menu._school.visible)
	if _menu == null:
		_finish()
		return
	var back: Button = _menu._school.get_child(_menu._school.get_child_count() - 1) as Button
	back.grab_focus()
	await _frames(2)
	await _click_control(back)
	_check("normal_continue_preserved_after_lessons", _menu._continue_button.is_visible_in_tree() and FileAccess.get_file_as_bytes(_normal_path) == _normal_bytes)
	_check("no_lesson_checkpoint_written", not FileAccess.file_exists("user://river-school-unused.json"))
	_finish()


func _show_menu(school: bool) -> void:
	if is_instance_valid(_screen):
		root.remove_child(_screen)
		_screen.queue_free()
		_screen = null
	_menu = MainMenu.new()
	_menu.save_path = _normal_path
	_menu.language = _language
	_menu.lesson_requested.connect(_start_lesson)
	root.add_child(_menu)
	if school:
		_menu.show_school()


func _start_lesson(id: String) -> void:
	if is_instance_valid(_screen):
		root.remove_child(_screen)
		_screen.queue_free()
		_screen = null
	if is_instance_valid(_menu):
		root.remove_child(_menu)
		_menu.queue_free()
		_menu = null
	_lesson = RiverSchoolRun.new()
	_check("start_" + id, _lesson.start(id))
	_started = id
	_screen = RiverSchoolScreen.new()
	_screen.lesson = _lesson
	_screen.preferences_path = _preferences_path
	_screen.school_requested.connect(func(): _show_menu(true))
	_screen.menu_requested.connect(func(): _show_menu(false))
	_screen.lesson_requested.connect(_start_lesson)
	root.add_child(_screen)
	_screen.confirm_unused_labor = false


func _replay(solution: Dictionary) -> void:
	var turns: Array = solution["turns"]
	for index: int in range(turns.size()):
		for command: Dictionary in turns[index]:
			await _command(command, "%s_turn_%d" % [solution["id"], index + 1])
		await _end_turn("%s_turn_%d" % [solution["id"], index + 1])


func _command(command: Dictionary, context: String) -> void:
	var expected: GameState = _lesson.session.state.duplicate_state()
	var coord: Vector2i = command["coord"]
	var id: String = command["id"]
	var error: String = GameFlow.apply_command(expected, Command.new(id, coord, int(command.get("param", -1))))
	_check("legal_%s_%s_%d_%d" % [context, id, coord.x, coord.y], error.is_empty())
	root.gui_release_focus()
	for shortcut: int in GameScreen.SHORTCUTS:
		if GameScreen.SHORTCUTS[shortcut] == id:
			await _key(shortcut)
			break
	await _click(_tile_position(coord))
	_check("native_%s_%s_%d_%d" % [context, id, coord.x, coord.y], _lesson.session.state.to_dict() == expected.to_dict())


func _end_turn(context: String) -> void:
	var count: int = _lesson.turns_resolved
	root.gui_release_focus()
	await _key(KEY_SPACE)
	if _screen.modal_kind in ["confirm_loss", "confirm_labor"]:
		await _click_named("ConfirmEndTurn")
	_check("commit_" + context, _lesson.turns_resolved == count + 1)
	_check("save_preserved_" + context, FileAccess.get_file_as_bytes(_normal_path) == _normal_bytes)


func _exit_confirmation_checks() -> void:
	var before: Dictionary = _snapshot()
	root.gui_release_focus()
	await _key(KEY_ESCAPE)
	await _click_named("SchoolPauseChoose")
	_check("unfinished_exit_warns", _screen.modal_kind == "school_exit")
	await _click_named("SchoolCancelLeave")
	_check("cancel_exit_returns_pause_read_only", _screen.modal_kind == "pause" and _snapshot() == before)
	await _click_named("SchoolPauseChoose")
	await _click_named("SchoolLeave")
	_check("confirmed_exit_returns_selector", _menu != null and _menu._school.visible and FileAccess.get_file_as_bytes(_normal_path) == _normal_bytes)


func _modal_restoration_checks() -> void:
	# Reach the first rain turn using the actual prepared board and commands.
	var solution: Dictionary = RiverSchoolFixtures.solutions("river_school_01")[0]
	for index: int in range(3):
		for command: Dictionary in solution["turns"][index]:
			await _command(command, "modal_setup_turn_%d" % (index + 1))
		await _end_turn("modal_setup_turn_%d" % (index + 1))
	var before: Dictionary = _snapshot()
	var preferences_before: PackedByteArray = FileAccess.get_file_as_bytes(_preferences_path)
	root.gui_release_focus()
	await _click_control(_screen.hud.find_child("Pause", true, false) as Button)
	_check("modal_history_setup_opens_pause", _screen.modal_kind == "pause")
	if _screen.modal_kind != "pause":
		_screen.retry_lesson()
		return
	await _click_named("PauseHistory")
	await _click_named("PreviousTurnResult")
	_check("interrupted_history_has_previous_turn", _screen.modal_kind == "turn_history" and _screen.history_index == 1 and _screen._history_return == "pause")
	if _screen.modal_kind != "turn_history" or not is_instance_valid(_screen._history_scroll):
		_screen.retry_lesson()
		return
	var history_modal: Control = _screen._modal
	var history_content: VBoxContainer = _screen._modal_content
	var history_scroll: ScrollContainer = _screen._history_scroll
	history_scroll.scroll_vertical = 80
	await _frames(2)
	var scroll_before: int = history_scroll.scroll_vertical
	var focus_before: Control = root.gui_get_focus_owner()
	_screen.request_quit()
	await _frames(2)
	_check("native_close_interrupts_history", _screen.modal_kind == "school_exit" and not history_modal.visible and _screen.board._activity_paused)
	var exit_modal: Control = _screen._modal
	_screen.request_quit()
	_check("repeated_native_close_preserves_exit_dialog", _screen._modal == exit_modal and _screen._suspended_modal == history_modal)
	await _key(KEY_ESCAPE)
	_check("history_cancel_restores_same_controls", _screen.modal_kind == "turn_history" and _screen._modal == history_modal and _screen._modal_content == history_content and history_modal.visible)
	_check("history_cancel_preserves_index_scroll_focus", _screen.history_index == 1 and _screen._history_return == "pause" and history_scroll.scroll_vertical == scroll_before and root.gui_get_focus_owner() == focus_before)
	_check("history_cancel_read_only", _snapshot() == before and FileAccess.get_file_as_bytes(_preferences_path) == preferences_before and _screen.board._activity_paused)
	await _capture("school-restored-history", "PLAYABLE PREPARED BOARD / HISTORY RESTORED AFTER CANCELING EXIT")
	await _key(KEY_ESCAPE)
	_check("restored_history_returns_pause", _screen.modal_kind == "pause")
	await _click_named("SchoolPauseHint")
	await _click_named("SchoolNextHint")
	await _click_named("SchoolNextHint")
	var hint_modal: Control = _screen._modal
	var hint_scroll: ScrollContainer = hint_modal.find_child("SchoolHintDetailsScroll", true, false) as ScrollContainer
	hint_scroll.scroll_vertical = 80
	await _frames(2)
	var hint_offset: int = hint_scroll.scroll_vertical
	var hint_close: Button = hint_modal.find_child("SchoolCloseHint", true, false) as Button
	hint_close.grab_focus()
	_check("third_hint_has_real_scroll_offset", hint_offset > 0)
	_screen.request_quit()
	await _frames(2)
	await _key(KEY_ESCAPE)
	_check("nested_hint_cancel_preserves_scroll_focus_and_return", _screen.modal_kind == "school_hint" and _screen._modal == hint_modal and hint_scroll.scroll_vertical == hint_offset and root.gui_get_focus_owner() == hint_close and _screen._hint_modal_return == "pause" and _screen.hint_level == 3)
	_check("nested_hint_exit_cancel_read_only", _snapshot() == before and FileAccess.get_file_as_bytes(_preferences_path) == preferences_before)
	await _key(KEY_ESCAPE)
	_check("restored_nested_hint_returns_pause", _screen.modal_kind == "pause")
	await _click_named("Resume")
	_check("restored_pause_resumes_board", _screen.modal_kind.is_empty() and not _screen.board._activity_paused)
	# This is a presentation preference, not a change to the game state.
	_screen.confirm_unused_labor = true
	_check("labor_warning_uses_real_rain_and_labor", _lesson.session.state.is_rain() and _lesson.session.state.labor >= 2 and _screen._predicted_outcome not in [C.Outcome.LOSE_HALL, C.Outcome.LOSE_POPULATION])
	root.gui_release_focus()
	await _key(KEY_SPACE)
	_check("native_labor_warning_opens", _screen.modal_kind == "confirm_labor" and _screen._skip_confirmation != null)
	if _screen.modal_kind != "confirm_labor" or _screen._skip_confirmation == null:
		_screen.retry_lesson()
		return
	var labor_modal: Control = _screen._modal
	var checkbox: CheckBox = _screen._skip_confirmation
	await _click_control(checkbox)
	var confirm: Button = _screen._modal.find_child("ConfirmEndTurn", true, false) as Button
	confirm.grab_focus()
	await _frames(2)
	_screen.request_quit()
	await _frames(2)
	_check("exit_interrupts_checked_labor_warning", _screen.modal_kind == "school_exit" and checkbox.button_pressed and not labor_modal.visible)
	# Enter accepts only Cancel Exit, even as focus returns to Confirm End Turn.
	await _key(KEY_ENTER)
	_check("enter_cancel_restores_labor_focus_without_commit", _screen.modal_kind == "confirm_labor" and _screen._modal == labor_modal and _screen._skip_confirmation == checkbox and root.gui_get_focus_owner() == confirm and _snapshot() == before)
	_check("labor_cancel_preserves_unsaved_checkbox", checkbox.button_pressed and _screen.confirm_unused_labor and FileAccess.get_file_as_bytes(_preferences_path) == preferences_before)
	_screen.request_quit()
	await _frames(2)
	await _click_named("SchoolCancelLeave")
	_check("repeated_labor_cancel_restores_same_checkbox", _screen.modal_kind == "confirm_labor" and _screen._modal == labor_modal and _screen._skip_confirmation == checkbox and checkbox.button_pressed and _snapshot() == before)
	await _capture("school-restored-labor-warning", "PLAYABLE PREPARED BOARD / UNSAVED LABOR CHECKBOX RESTORED")
	await _click_named("ConfirmEndTurn")
	_check("restored_labor_warning_commits_only_explicitly", _lesson.turns_resolved == 4 and _lesson.session.state.turn == 5 and not _screen.confirm_unused_labor and not GamePreferences.read(_preferences_path)["confirm_unused_labor"])
	_check("labor_confirmation_preserves_normal_checkpoint", FileAccess.get_file_as_bytes(_normal_path) == _normal_bytes)
	# Isolated warning-presentation fixture: supply a predicted loss to the UI,
	# without changing board, resources, RNG, commands or the lesson outcome.
	before = _snapshot()
	preferences_before = FileAccess.get_file_as_bytes(_preferences_path)
	_screen._predicted_outcome = C.Outcome.LOSE_HALL
	root.gui_release_focus()
	await _key(KEY_SPACE)
	_check("controlled_loss_warning_opens", _screen.modal_kind == "confirm_loss")
	if _screen.modal_kind != "confirm_loss":
		_screen.retry_lesson()
		return
	var loss_modal: Control = _screen._modal
	var cancel: Button = _screen._modal.find_child("CancelEndTurn", true, false) as Button
	_check("controlled_loss_warning_focuses_cancel", root.gui_get_focus_owner() == cancel)
	_screen.request_quit()
	await _frames(2)
	await _click_named("SchoolCancelLeave")
	_check("controlled_loss_cancel_restores_warning_and_focus", _screen.modal_kind == "confirm_loss" and _screen._modal == loss_modal and _labels(_screen._modal_content).contains(_tr("preview.lose_hall")) and root.gui_get_focus_owner() == cancel)
	_check("controlled_loss_cancel_read_only", _snapshot() == before and FileAccess.get_file_as_bytes(_preferences_path) == preferences_before)
	await _capture("school-restored-loss-warning", "CONTROLLED UI FIXTURE / PREDICTED LOSS WARNING RESTORED")
	await _key(KEY_ESCAPE)
	_check("restored_loss_warning_escape_cancels_turn", _screen.modal_kind.is_empty() and _snapshot() == before)
	_screen.retry_lesson()
	await _frames(2)


func _snapshot() -> Dictionary:
	return {"state": _lesson.session.state.to_dict(), "rng": _lesson.session.state.rng.state, "history": _lesson.session.turn_history(), "result": _lesson.result(), "normal": FileAccess.get_file_as_bytes(_normal_path)}


func _tile_position(coord: Vector2i) -> Vector2:
	var tile: Tile = _lesson.session.state.get_tile(coord)
	var local: Vector3 = Hex.to_world(coord, tile.elevation)
	local.y = _screen.board._surface_y(tile)
	return _screen.camera_rig.get_camera().unproject_position(_screen.board.to_global(local))


func _click_named(name: String) -> void:
	if _screen == null or _screen._modal == null:
		_check("available_" + name + "_" + str(_checks.size()), false)
		return
	var control: Button = _screen._modal.find_child(name, true, false) as Button
	_check("available_" + name + "_" + str(_checks.size()), control != null)
	if control == null:
		return
	control.grab_focus()
	await _frames(2)
	await _click_control(control)


func _click_control(control: Control) -> void:
	_check("clickable_" + control.name + "_" + str(_checks.size()), control.is_visible_in_tree() and control.get_global_rect().intersects(root.get_visible_rect()))
	await _click(control.get_global_rect().get_center())


func _click(position: Vector2) -> void:
	var pixels: Vector2 = position * Vector2(root.size) / root.get_visible_rect().size
	Input.warp_mouse(pixels)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pixels
	motion.global_position = pixels
	motion.relative = Vector2.ONE
	Input.parse_input_event(motion)
	await process_frame
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = pixels
	click.global_position = pixels
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click = click.duplicate() as InputEventMouseButton
	click.pressed = false
	Input.parse_input_event(click)
	await _frames(1)


func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)


func _frames(count: int) -> void:
	for index: int in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _labels(node: Node) -> String:
	var lines: PackedStringArray = []
	for child: Node in node.get_children():
		if child is Label:
			lines.append(child.text)
		lines.append(_labels(child))
	return "\n".join(lines)


func _add_badge() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	_badge = Label.new()
	_badge.position = Vector2(24, root.get_visible_rect().size.y - 34)
	_badge.add_theme_font_size_override("font_size", 18)
	_badge.add_theme_color_override("font_color", Color("ffdf94"))
	_badge.add_theme_color_override("font_outline_color", Color("16363a"))
	_badge.add_theme_constant_override("outline_size", 4)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_badge)


func _capture(id: String, context: String) -> void:
	_badge.text = context + " / " + _language.to_upper()
	await _frames(2)
	var filename: String = id + "-" + _language + ".png"
	_check(id + "_screenshot", root.get_texture().get_image().save_png(_out_dir.path_join(filename)) == OK)
	_captures.append({"file": filename, "context": context, "viewport": [root.size.x, root.size.y]})


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func _check(id: String, passed: bool) -> void:
	_checks[id] = passed
	if not passed:
		_failed = true
		printerr("RIVER SCHOOL PROBE CHECK FAILED: ", id)


func _finish() -> void:
	var evidence: Dictionary = {
		"language": _language, "engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(),
		"scope": "modal_restoration" if _modal_only else "full",
		"checks": _checks, "captures": _captures,
		"scenarios": RiverSchoolFixtures.IDS, "revision": RiverSchoolFixtures.REVISION,
		"balance_sha256": FileAccess.get_sha256("res://data/balance.json"),
		"note": "Automated native mouse/keyboard integration at 1280x720 on the actual playable prepared lesson boards. No gameplay state is injected after lesson start. Verified command replays use the live rules; hints, interrupted-dialog cancellation and retry do not change player saves or RNG. The loss-warning restoration check is a labeled controlled UI fixture: only the screen's predicted-outcome presentation field is supplied; no board, resources, commands, state, RNG or lesson outcome changes. All normal-save/settings files are isolated under out-dir. Screenshots are captured directly from Godot without editing. This is not human playtesting, proof of fun, balance validation, or a performance benchmark.",
	}
	var file: FileAccess = FileAccess.open(_out_dir.path_join("river-school-qa-" + _language + ".json"), FileAccess.WRITE)
	if file == null:
		_failed = true
	else:
		file.store_string(JSON.stringify(evidence, "  ", true, true))
		file.close()
	print("RIVER_SCHOOL_PROBE ", JSON.stringify(_checks))
	quit(1 if _failed else 0)
