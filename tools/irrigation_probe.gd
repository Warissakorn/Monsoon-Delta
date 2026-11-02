extends SceneTree
## Native input on an authored main-game fixture. All files are isolated in out-dir.
const F = preload("res://tools/irrigation_fixtures.gd")
var screen: GameScreen
var language: String = "en"
var out_dir: String = ""
var path: String
var settings: String
var checks: Dictionary = {}
var captures: Array[String] = []
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			language = arg.trim_prefix("--lang=")
		elif arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	if DisplayServer.get_name() == "headless" or language not in ["en", "th"] or not out_dir.is_absolute_path():
		printerr("Use a native display, --lang=en|th and an absolute --out-dir.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	path = out_dir.path_join("checkpoint.json")
	settings = out_dir.path_join("settings.json")
	Localization.setup(language)
	root.size = Vector2i(1280, 720)
	_check("isolated_preferences", GamePreferences.write({"language": language, "confirm_unused_labor": false, "reduced_motion": false}, settings).is_empty())
	var normal_path: String = out_dir.path_join("normal-save.json")
	_check("normal_save_created", SaveIO.save(GameFlow.new_game({"seed": 98, "living_village": true}), normal_path).is_empty())
	var normal_bytes: PackedByteArray = FileAccess.get_file_as_bytes(normal_path)
	var menu: MainMenu = MainMenu.new()
	menu.save_path = normal_path
	menu.initial_ruleset = "moisture_v1"
	root.add_child(menu)
	menu._show_page(menu._setup)
	await _frames(2)
	menu._irrigation_toggle.grab_focus()
	await _frames(2)
	await _click(menu._irrigation_toggle)
	_check("native_new_run_opt_in", menu._irrigation_toggle.button_pressed and menu._moisture_toggle.button_pressed)
	_check("menu_does_not_replace_continue", FileAccess.get_file_as_bytes(normal_path) == normal_bytes)
	var draft: Dictionary = menu.setup_draft()
	var play: Button = (menu._setup.get_child(menu._setup.get_child_count() - 1) as HBoxContainer).get_child(1) as Button
	play.grab_focus()
	await _frames(2)
	await _click(play)
	_check("native_overwrite_confirmation", menu._overwrite_dialog.visible)
	await _click(menu._overwrite_dialog.get_cancel_button())
	_check("cancel_preserves_draft_and_continue", menu.setup_draft() == draft and FileAccess.get_file_as_bytes(normal_path) == normal_bytes)
	root.remove_child(menu)
	menu.queue_free()
	var session: GameSession = GameSession.new()
	session.save_path = path
	session.state = F.create("moisture_irrigation_v1", true)
	_check("fixture_checkpoint_v6", session.checkpoint().is_empty() and int(JSON.parse_string(FileAccess.get_file_as_string(path))["version"]) == 6)
	_show(session)
	await _frames(3)
	var initial: Dictionary = screen.session.state.to_dict()
	await _tile(F.FIELDS[0])
	_check("native_field_selection", screen._irrigation_coord == F.FIELDS[0] and screen._irrigation_controls.visible)
	await _policy("skip")
	_check("native_skip_changes_policy_only", screen.session.state.get_tile(F.FIELDS[0]).irrigation_policy == "skip" and screen.session.state.turn == 1 and screen.session.state.labor == int(initial["labor"]))
	_check("preview_uses_moisture_and_preserves_water_for_others", (screen.prediction["report"] as TurnReport).paddy_gains.size() == 3 and screen.session.state.get_tile(F.RESERVOIR).water == 1.0)
	await _tile(F.FIELDS[2])
	var first: Button = screen._irrigation_buttons["first"]
	first.grab_focus()
	await _frames(2)
	await _key(KEY_ENTER)
	_check("native_enter_policy_cannot_end_turn", screen.session.state.get_tile(F.FIELDS[2]).irrigation_policy == "first" and screen.session.state.turn == 1 and screen.session.turn_history().is_empty())
	await _key(KEY_Z, true)
	_check("native_undo_policy", screen.session.state.get_tile(F.FIELDS[2]).irrigation_policy == "normal")
	await _key(KEY_Y, true)
	_check("native_redo_policy", screen.session.state.get_tile(F.FIELDS[2]).irrigation_policy == "first")
	_check("board_markers_follow_policy", screen.board._irrigation_status_root.get_child_count() == 2)
	var before: Dictionary = screen.session.state.to_dict()
	root.gui_release_focus()
	await _key(KEY_ESCAPE)
	_check("native_pause", screen.modal_kind == "pause")
	await _click(screen._motion_toggle)
	_check("native_reduce_motion_read_only", screen.reduced_motion and screen.session.state.to_dict() == before)
	await _click(screen._modal.find_child("Resume", true, false) as Button)
	_check("native_resume_returns_to_board", screen.modal_kind.is_empty())
	await _tile(F.FIELDS[0])
	var normal: Button = screen._irrigation_buttons["normal"]
	normal.grab_focus()
	await _frames(2)
	_check("policy_buttons_fit", root.get_visible_rect().encloses(normal.get_global_rect()))
	await _capture("irrigation-planning")
	var predicted: Dictionary = GameFlow.preview(screen.session.state)
	root.gui_release_focus()
	await _key(KEY_SPACE)
	_check("native_commit_matches_preview", screen.session.state.turn == 2 and screen.session.turn_history().size() == 1 and screen.session.turn_history()[0]["report"]["irrigation_results"] == (predicted["report"] as TurnReport).irrigation_results)
	_check("actual_allocation_once", screen.session.state.get_tile(F.RESERVOIR).water == 0.25 and screen.session.state.get_tile(F.FIELDS[0]).soil_moisture == 0)
	await _key(KEY_H)
	_check("native_history_has_receipts", screen.modal_kind == "turn_history" and _labels(screen._history_details).contains(_tr("irrigation.from_moisture") % [1, 0]))
	_check("history_fits", root.get_visible_rect().encloses(screen._modal_content.get_global_rect()))
	await _capture("irrigation-history")
	await _key(KEY_ESCAPE)
	var saved: Dictionary = screen.session.state.to_dict()
	var restored: GameSession = GameSession.new()
	restored.save_path = path
	_check("continue_exact_policy_float64_rng", restored.load_game().is_empty() and restored.state.to_dict() == saved)
	_show(restored)
	await _frames(2)
	await _tile(F.FIELDS[0])
	_check("continue_renders_saved_policy", screen.session.state.get_tile(F.FIELDS[0]).irrigation_policy == "skip" and screen._irrigation_buttons["skip"].button_pressed)
	await _capture("irrigation-continue")
	_check("normal_continue_untouched", FileAccess.get_file_as_bytes(normal_path) == normal_bytes)
	var report: Dictionary = {
		"engine": Engine.get_version_info()["string"], "language": language, "display": DisplayServer.get_name(),
		"viewport": [1280, 720], "checks": checks, "captures": captures,
		"fixture_sha256": FileAccess.get_sha256("res://tools/irrigation_fixtures.gd"), "balance_sha256": FileAccess.get_sha256("res://data/balance.json"),
		"note": "Automated native mouse/keyboard checks on an authored main-game fixture. The initial board has a 1.0-water reservoir, three fields and one stored moisture unit. No gameplay state is injected after start. Policies, undo/redo, commit and load use actual game commands, resolver and isolated checkpoint I/O. Focus is set programmatically to reveal controls in scroll areas. This is not a generated-map playthrough, human playtest, balance validation or performance benchmark.",
	}
	var file: FileAccess = FileAccess.open(out_dir.path_join("irrigation-qa-" + language + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", true, true))
	file.close()
	print("IRRIGATION_QA ", language, " ", checks.size(), " checks; failed=", failed)
	quit(1 if failed else 0)


func _show(session: GameSession) -> void:
	if is_instance_valid(screen):
		root.remove_child(screen)
		screen.queue_free()
	screen = GameScreen.new()
	screen.session = session
	screen.preferences_path = settings
	root.add_child(screen)
	screen.confirm_unused_labor = false


func _policy(policy: String) -> void:
	var button: Button = screen._irrigation_buttons[policy]
	button.grab_focus()
	await _frames(2)
	await _click(button)


func _tile(coord: Vector2i) -> void:
	root.gui_release_focus()
	var tile: Tile = screen.session.state.get_tile(coord)
	var at: Vector3 = Hex.to_world(coord, tile.elevation)
	at.y = screen.board._surface_y(tile)
	await _click_at(screen.camera_rig.get_camera().unproject_position(screen.board.to_global(at)))


func _click(control: Control) -> void:
	_check("visible_control_%d" % checks.size(), control.is_visible_in_tree() and root.get_visible_rect().intersects(control.get_global_rect()))
	await _click_at(control.get_global_rect().get_center())


func _click_at(position: Vector2) -> void:
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
	await _frames(2)


func _key(code: Key, control: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = control
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	await _frames(2)
	var file: String = name + "-" + language + ".png"
	_check(name + "_capture", root.get_texture().get_image().save_png(out_dir.path_join(file)) == OK)
	captures.append(file)


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func _labels(node: Node) -> String:
	var result: PackedStringArray = []
	for child: Node in node.get_children():
		if child is Label:
			result.append(child.text)
		result.append(_labels(child))
	return "\n".join(result)


func _check(name: String, ok: bool) -> void:
	checks[name] = ok
	if not ok:
		failed = true
		printerr("IRRIGATION CHECK FAILED: ", name)
