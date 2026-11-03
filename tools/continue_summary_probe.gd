extends SceneTree
## Native resume-card checks. Use an isolated XDG_DATA_HOME below --out-dir.

class MenuBoot extends "res://ui/boot.gd":
	func _ready() -> void:
		pass


var _out_dir: String = ""
var _language: String = "en"
var _boot: MenuBoot
var _menu: MainMenu
var _checks: Dictionary = {}
var _captures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			_out_dir = argument.trim_prefix("--out-dir=")
		elif argument.begins_with("--lang="):
			_language = argument.trim_prefix("--lang=")
	if DisplayServer.get_name() == "headless" or _language not in ["en", "th"] or not _out_dir.is_absolute_path():
		printerr("Use a native display, --lang=en|th and an absolute --out-dir.")
		quit(2)
		return
	if not ProjectSettings.globalize_path(GamePreferences.DEFAULT_PATH).begins_with(_out_dir.trim_suffix("/") + "/"):
		printerr("Set XDG_DATA_HOME below --out-dir to isolate the language preference.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1280, 720)
	root.min_size = root.size
	Localization.setup(_language)
	_check("isolated_preferences", GamePreferences.write({"language": _language, "reduced_motion": true}).is_empty())
	_boot = MenuBoot.new()
	_boot._save_path = _out_dir.path_join("continue-summary-fixture.json")
	if not SaveIO.delete_save(_boot._save_path).is_empty():
		printerr("Could not reset the probe's isolated checkpoint fixture.")
		quit(1)
		return
	_boot._language = _language
	root.add_child(_boot)
	_boot._show_menu()
	_menu = _boot._screen as MainMenu
	await _frames(3)
	_check("missing_save_hides_card", not _menu._continue_group.is_visible_in_tree() and _menu._continue_summary.text.is_empty())
	_check("missing_save_not_created", not FileAccess.file_exists(_boot._save_path))
	var state: GameState = GameFlow.new_game({
		"seed": 73, "leader": "fisher", "difficulty": 7, "run_mode": "long",
		"village_goal": "forest", "ruleset": "bracing_moisture_irrigation_v1", "living_village": true,
	})
	_check("planning_fixture_saved", SaveIO.save(state, _boot._save_path).is_empty())
	var expected: Dictionary = state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_boot._save_path)
	_boot._show_menu()
	_menu = _boot._screen as MainMenu
	await _frames(3)
	_check_card("planning", state)
	await _capture("continue-summary-planning")
	# Language buttons rebuild the real menu; the saved village remains fixed.
	for language: String in ["th" if _language == "en" else "en", _language]:
		await _click(_find_button(_menu._home, _tr("menu.language") + " · ", true))
		_menu = _boot._screen as MainMenu
		_check("language_" + language, _menu.language == language and TranslationServer.get_locale() == language)
		_check_card("language_" + language, state)
		_check("language_checkpoint_" + language, FileAccess.get_file_as_bytes(_boot._save_path) == bytes)
	await _reveal(_menu._continue_button)
	_menu._continue_button.grab_focus()
	await _key(KEY_ENTER)
	_check("keyboard_continue_opens_game", _boot._screen is GameScreen)
	_check("keyboard_continue_state_exact", _boot._session != null and _boot._session.state.to_dict() == expected)
	_check("keyboard_continue_checkpoint_exact", FileAccess.get_file_as_bytes(_boot._save_path) == bytes)
	# A separate fixture reaches harvest through six actual, unedited turns.
	var session: GameSession = GameSession.new()
	session.save_path = _boot._save_path
	_check("harvest_fixture_started", session.start({"seed": 1}).is_empty())
	for turn: int in range(C.TURNS_PER_YEAR):
		_check("harvest_real_turn_%d" % (turn + 1), session.advance_turn() != null)
	_check("harvest_fixture_reached", session.state.phase == C.Phase.HARVEST)
	expected = session.state.to_dict()
	bytes = FileAccess.get_file_as_bytes(_boot._save_path)
	_boot._show_menu()
	_menu = _boot._screen as MainMenu
	await _frames(3)
	_check_card("harvest", session.state)
	_check("harvest_stage_label", _menu._continue_summary.text.begins_with(_tr("menu.continue_harvest") % [1, 5]))
	await _capture("continue-summary-harvest")
	await _click(_menu._continue_button)
	_check("mouse_continue_opens_harvest", _boot._screen is GameScreen and _boot._screen.modal_kind == "harvest")
	_check("harvest_not_reapplied", _boot._session.state.to_dict() == expected)
	_check("harvest_checkpoint_exact", FileAccess.get_file_as_bytes(_boot._save_path) == bytes)
	_finish()


func _check_card(prefix: String, state: GameState) -> void:
	_check(prefix + "_card_visible", _menu._continue_group.is_visible_in_tree())
	_check(prefix + "_mode", _menu._continue_summary.text.contains(_tr("run_mode." + state.run_mode + ".name")))
	_check(prefix + "_leader_difficulty", _menu._continue_summary.text.contains(_tr("menu.continue_run") % [_tr("run_mode." + state.run_mode + ".name"), _tr("leader." + state.leader + ".name"), state.difficulty]))
	_check(prefix + "_resources", _menu._continue_summary.text.contains(_tr("menu.continue_resources") % [state.population, state.food, state.wood]))
	_check(prefix + "_exact_seed", _menu._continue_button.tooltip_text.contains(_tr("menu.continue_seed") % str(state.seed)))
	_check(prefix + "_panel_fits", root.get_visible_rect().encloses(_menu._menu_panel.get_global_rect()))
	_check(prefix + "_summary_width", _menu._continue_summary.size.x <= _menu._menu_panel.size.x)
	_check(prefix + "_all_text_laid_out", _menu._continue_summary.get_visible_line_count() == _menu._continue_summary.get_line_count())


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func _find_button(node: Node, text: String, prefix: bool = false) -> Button:
	for child: Node in node.get_children():
		if child is Button and (child.text.begins_with(text) if prefix else child.text == text):
			return child
		var found: Button = _find_button(child, text, prefix)
		if found != null:
			return found
	return null


func _reveal(control: Control) -> void:
	await _frames(2)
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _frames(2)


func _click(control: Control) -> void:
	if control == null:
		_check("requested_control_exists", false)
		return
	await _reveal(control)
	var point: Vector2 = control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	Input.warp_mouse(point)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2.ONE
	Input.parse_input_event(motion)
	await process_frame
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(3)


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
	await _frames(3)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	await _reveal(_menu._continue_group)
	var filename: String = name + "-" + _language + ".png"
	_check("capture_" + name, root.get_texture().get_image().save_png(_out_dir.path_join(filename)) == OK)
	_captures.append(filename)


func _check(name: String, passed: bool) -> void:
	_checks[name] = passed
	print("%s %s" % ["PASS" if passed else "FAIL", name])


func _finish() -> void:
	var failed: int = 0
	for passed: bool in _checks.values():
		if not passed:
			failed += 1
	var report: Dictionary = {
		"engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(),
		"resolution": "1280x720", "language": _language,
		"fixture": "v6 planning seed 73; seed 1 harvest reached through actual turns",
		"input": "Godot GUI mouse/keyboard events on a native rendering window",
		"passed": _checks.size() - failed, "failed": failed, "checks": _checks, "captures": _captures,
	}
	var file: FileAccess = FileAccess.open(_out_dir.path_join("continue-summary-qa-" + _language + ".json"), FileAccess.WRITE)
	if file == null:
		printerr("Could not write native QA report.")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	file.close()
	print("%d passed, %d failed" % [report["passed"], failed])
	quit(0 if failed == 0 else 1)
