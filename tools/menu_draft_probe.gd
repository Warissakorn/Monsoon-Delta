extends SceneTree
## Native menu/language regression evidence; XDG_DATA_HOME must be below out-dir.
## DISPLAY=:100 godot --path . --audio-driver Dummy --resolution 1280x720 \
##   --script res://tools/menu_draft_probe.gd -- --out-dir=/absolute/work/menu-qa/en --lang=en

class MenuBoot extends "res://ui/boot.gd":
	func _ready() -> void:
		pass # Keep real menu/session behavior, skipping command-line startup only.


const SEED_TEXT: String = "  หมู่บ้าน monsoon 007  "
var _out_dir: String = ""
var _language: String = "en"
var _boot: MenuBoot
var _menu: MainMenu
var _normal_path: String
var _normal_bytes: PackedByteArray
var _checks: Dictionary = {}
var _captures: Array[Dictionary] = []
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			_out_dir = argument.trim_prefix("--out-dir=")
		elif argument.begins_with("--lang="):
			_language = argument.trim_prefix("--lang=")
	if DisplayServer.get_name() == "headless" or _language not in ["th", "en"] or not _out_dir.is_absolute_path():
		printerr("Menu draft probe needs a native display, --lang=th|en and an absolute --out-dir.")
		quit(2)
		return
	# Boot writes its language preference to the usual user path. Refuse to
	# touch that path unless the caller explicitly isolated it inside out-dir.
	if not ProjectSettings.globalize_path(GamePreferences.DEFAULT_PATH).begins_with(_out_dir.trim_suffix("/") + "/"):
		printerr("Set XDG_DATA_HOME below --out-dir to isolate Boot's settings.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1280, 720)
	root.min_size = root.size
	Localization.setup(_language)
	_check("isolated_preferences", GamePreferences.write({"language": _language, "confirm_unused_labor": false, "reduced_motion": true}).is_empty())
	_normal_path = _out_dir.path_join("normal-checkpoint.json")
	_check("normal_checkpoint_created", SaveIO.save(GameFlow.new_game({"seed": 91}), _normal_path).is_empty())
	_normal_bytes = FileAccess.get_file_as_bytes(_normal_path)
	_boot = MenuBoot.new()
	_boot._save_path = _normal_path
	_boot._language = _language
	root.add_child(_boot)
	_boot._show_menu()
	_menu = _boot._screen as MainMenu
	await _frames(3)
	_check("continue_initially_available", _menu._continue_button.is_visible_in_tree())
	await _click_control(_menu._new_game_button)
	_check("native_new_game_opens_setup", _menu._setup.visible)
	if not _menu._setup.visible:
		_finish()
		return
	# Prepared form fixture: option/seed entry is outside this regression's
	# scope. All subsequent navigation and confirmation uses real GUI input.
	for choice: Dictionary in [
		{"control": _menu._leader_option, "index": 2, "name": "fisher"},
		{"control": _menu._run_mode_option, "index": 1, "name": "long"},
		{"control": _menu._goal_option, "index": 2, "name": "forest"},
		{"control": _menu._difficulty_option, "index": 7, "name": "difficulty_7"},
	]:
		var option: OptionButton = choice["control"]
		option.select(int(choice["index"]))
		option.item_selected.emit(int(choice["index"]))
	_menu._bracing_toggle.set_pressed_no_signal(true)
	_menu._moisture_toggle.set_pressed_no_signal(true)
	_menu._seed_input.text = SEED_TEXT
	_check_draft("prepared_setup")
	var destinations: Array[String] = ["th" if _language == "en" else "en", _language]
	for language: String in destinations:
		await _click_control(_find_button(_menu._setup, _tr("menu.back")))
		await _click_control(_find_button(_menu._home, _tr("menu.language") + " · ", true))
		_menu = _boot._screen as MainMenu
		_check("language_" + language, _menu.language == language and GamePreferences.read()["language"] == language)
		_check("checkpoint_after_language_" + language, FileAccess.get_file_as_bytes(_normal_path) == _normal_bytes)
		await _click_control(_menu._new_game_button)
		_check_draft("retained_" + language)
		_check("leader_description_" + language, _menu._leader_description.text == _tr("leader.fisher.desc"))
		_check("mode_description_" + language, _menu._run_mode_description.text == _tr("run_mode.long.desc"))
		_check("goal_description_" + language, _menu._goal_description.text == _tr("goal.forest.desc"))
		_check("difficulty_description_" + language, _menu._difficulty_description.text == DifficultyInfo.description(7, "fisher", "long"))
		_check("menu_panel_fits_" + language, root.get_visible_rect().encloses(_menu._menu_panel.get_global_rect()))
		await _reveal(_menu._leader_option)
		await _capture("menu-draft-options", language)
		await _reveal(_menu._seed_input)
		_check("seed_field_reachable_" + language, root.get_visible_rect().encloses(_menu._seed_input.get_global_rect()))
		await _capture("menu-draft-seed", language)
	await _key(KEY_ENTER)
	await _frames(2)
	_check("play_requires_overwrite_confirmation", _menu._overwrite_dialog.visible)
	_check("checkpoint_before_confirmation", FileAccess.get_file_as_bytes(_normal_path) == _normal_bytes)
	if not _menu._overwrite_dialog.visible:
		_finish()
		return
	_menu._overwrite_dialog.get_cancel_button().grab_focus()
	await _key(KEY_ENTER, _menu._overwrite_dialog)
	await _frames(2)
	_check("cancel_preserves_setup", not _menu._overwrite_dialog.visible and _menu._setup.visible)
	_check("cancel_preserves_checkpoint", FileAccess.get_file_as_bytes(_normal_path) == _normal_bytes)
	# Native Play/Cancel above exercise the dialog. Complete the final request
	# programmatically so subwindow focus does not widen this regression's scope.
	_menu._request_start()
	await _frames(2)
	_check("play_reopens_confirmation", _menu._overwrite_dialog.visible)
	_menu._overwrite_dialog.confirmed.emit()
	await _frames(4)
	_check("confirmed_play_starts_game", _boot._screen is GameScreen and _boot._session != null)
	if _boot._session != null:
		var expected: GameState = GameFlow.new_game({
			"seed": SeedUtil.parse_seed_text(SEED_TEXT), "leader": "fisher", "difficulty": 7,
			"run_mode": "long", "village_goal": "forest", "ruleset": "bracing_moisture_v1", "living_village": true,
		})
		_check("started_config_exact", _boot._session.state.to_dict() == expected.to_dict())
		_check("activation_preserves_turn_one", _boot._session.state.turn == 1 and _boot._session.state.phase == C.Phase.PLANNING)
		_check("confirmed_checkpoint_matches", SaveIO.load_game(_normal_path)["state"].to_dict() == expected.to_dict())
	_finish()


func _check_draft(context: String) -> void:
	_check(context + "_seed_text", _menu._seed_input.text == SEED_TEXT)
	_check(context + "_leader", _menu._leader_option.selected == 2)
	_check(context + "_mode", _menu._run_mode_option.selected == 1)
	_check(context + "_goal", _menu._goal_option.selected == 2)
	_check(context + "_difficulty", _menu._difficulty_option.get_selected_id() == 7)
	_check(context + "_ruleset", _menu._bracing_toggle.button_pressed and _menu._moisture_toggle.button_pressed)


func _find_button(node: Node, text: String, prefix: bool = false) -> Button:
	for child: Node in node.get_children():
		if child is Button and ((prefix and child.text.begins_with(text)) or child.text == text):
			return child
		var found: Button = _find_button(child, text, prefix)
		if found != null:
			return found
	return null


func _click_control(control: Control) -> void:
	if control == null:
		_check("control_available_" + str(_checks.size()), false)
		return
	await _reveal(control)
	_check("clickable_" + str(_checks.size()), control.is_visible_in_tree() and root.get_visible_rect().encloses(control.get_global_rect()))
	var pixels: Vector2 = control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
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
	await _frames(2)


func _reveal(control: Control) -> void:
	await _frames(2)
	control.grab_focus()
	await _frames(2)
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _frames(2)


func _key(code: Key, window: Window = null) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	if window == null:
		Input.parse_input_event(event)
	else:
		window.push_input(event, true)
	await process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	if window == null:
		Input.parse_input_event(event)
	else:
		window.push_input(event, true)
	await _frames(2)


func _frames(count: int) -> void:
	for index: int in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(id: String, language: String) -> void:
	var filename: String = id + "-" + language + ".png"
	_check(id + "_capture_" + language, root.get_texture().get_image().save_png(_out_dir.path_join(filename)) == OK)
	_captures.append({"file": filename, "language": language, "viewport": [root.size.x, root.size.y]})


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func _check(id: String, passed: bool) -> void:
	_checks[id] = passed
	if not passed:
		_failed = true
		printerr("MENU DRAFT PROBE CHECK FAILED: ", id)


func _finish() -> void:
	var passed: int = 0
	for value: bool in _checks.values():
		passed += 1 if value else 0
	var evidence: Dictionary = {
		"initial_language": _language, "engine": Engine.get_version_info()["string"],
		"display": DisplayServer.get_name(), "viewport": [root.size.x, root.size.y],
		"passed": passed, "total": _checks.size(), "checks": _checks, "captures": _captures,
		"note": "Prepared new-game form fixture sets options, toggles and raw seed text through their ordinary control API. Subsequent Back/language/New Game navigation, initial Play and overwrite cancellation use native mouse/keyboard GUI input through real Boot methods, skipping CLI startup only. Final Play re-request and confirmation are programmatic; the real Boot creates the actual session and checkpoint. Selected options, localized descriptions and checkpoint protection are checked before confirmation. All saves/preferences are isolated under out-dir via XDG_DATA_HOME. Screenshots are captured directly from Godot without editing. This is not a native test of option/seed entry or final OK activation, human playtesting or balance validation.",
	}
	var file: FileAccess = FileAccess.open(_out_dir.path_join("menu-draft-qa-" + _language + ".json"), FileAccess.WRITE)
	if file == null:
		_failed = true
	else:
		file.store_string(JSON.stringify(evidence, "  ", true, true))
		file.close()
	print("MENU_DRAFT_PROBE %d/%d passed" % [passed, _checks.size()])
	quit(1 if _failed else 0)
