extends SceneTree
## Native bracing evidence. Isolated checkpoints/settings only; no player save.
## DISPLAY=:99 XDG_DATA_HOME=/workspace/Monsoon-Delta/work/bracing-qa/xdg-th \
##   godot --path . --audio-driver Dummy --resolution 1280x720 \
##   --script res://tools/bracing_probe.gd -- \
##   --out-dir=/workspace/Monsoon-Delta/work/bracing-qa/th --lang=th

const TARGET: Vector2i = Vector2i(0, 0)

var _out_dir: String = "/tmp/monsoon-bracing-probe"
var _language: String = "en"
var _screen: GameScreen
var _menu: MainMenu
var _session: GameSession
var _badge: Label
var _started_config: Dictionary = {}
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
		printerr("Bracing probe needs a native display, --lang=th|en and an absolute --out-dir.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var cleared: bool = true
	for filename: String in ["menu-checkpoint.json", "fixture-checkpoint.json", "legacy-checkpoint.json"]:
		for suffix: String in ["", ".tmp"]:
			var old_path: String = _out_dir.path_join(filename + suffix)
			if FileAccess.file_exists(old_path):
				cleared = DirAccess.remove_absolute(old_path) == OK and cleared
	_check("isolated_previous_checkpoints_cleared", cleared)
	Localization.setup(_language)
	root.size = Vector2i(1280, 720)
	root.min_size = root.size
	var settings: String = _out_dir.path_join("settings.json")
	_check("isolated_preferences", GamePreferences.write({"language": _language, "confirm_unused_labor": false, "reduced_motion": false}, settings).is_empty())
	_add_badge()
	await _menu_checks()
	if _screen == null:
		_finish()
		return
	_check("seed_42_start", _session.state.seed == 42 and _session.state.ruleset == "bracing_v1")
	_check("enter_did_not_end_first_turn", _session.state.turn == 1 and _session.state.phase == C.Phase.PLANNING)
	_check("bracing_tool_visible", _screen._command_buttons["brace_house"].is_visible_in_tree())
	await _capture("bracing-start", "LEGAL SEED 42 / NEW BRACING RUN")
	_screen.free()
	_session = GameSession.new()
	_session.save_path = _out_dir.path_join("fixture-checkpoint.json")
	_session.state = _fixture()
	_check("fixture_checkpoint", _session.checkpoint().is_empty())
	_make_screen()
	await _frames(3)
	var initial: Dictionary = _snapshot()
	_check("fixture_predicts_unbraced_loss", ( _screen.prediction["report"] as TurnReport).destroyed.size() == 3)
	await _key(KEY_R)
	_check("native_bracing_shortcut", _screen.command_mode == "brace_house")
	await _key(KEY_ESCAPE)
	await _click_control(_screen._command_buttons["brace_house"])
	_check("native_bracing_tool_click", _screen.command_mode == "brace_house")
	var point: Vector2 = _tile_screen_position(TARGET)
	var picked: Tile = _screen.board.pick(_screen.camera_rig.get_camera(), point)
	_check("native_target_projection", picked != null and picked.coord == TARGET)
	await _click(point)
	_check("native_board_click_braces_house", _session.state.get_tile(TARGET).brace_turns == 1)
	_check("bracing_cost", _session.state.labor == int(initial["state"]["labor"]) - 2 and _session.state.wood == int(initial["state"]["wood"]) - 1)
	_check("shield_visible", _screen.board._brace_status_root.get_child_count() == 1)
	_check("physical_braces_visible", _screen.board.get_node_or_null("Tiles/Hex_0_0/House/EmergencyBracing") != null)
	_check("current_inspector_braced", _screen._tile_note.text.contains(_tr("tile.braced")))
	_check("preview_uses_protected_threshold", _screen._tile_note.text.contains(_tr("tile.brace_forecast") % 2))
	_check("preview_brace_expires_on_copy", (_screen.prediction["state"] as GameState).get_tile(TARGET).brace_turns == 0 and _session.state.get_tile(TARGET).brace_turns == 1)
	_check("preview_shows_held_house", (_screen.prediction["state"] as GameState).get_tile(TARGET).building == C.Building.HOUSE)
	_check("held_preview_icon", _screen.board._preview_root.get_node_or_null("BraceHeld_0_0") != null)
	var braced: Dictionary = _snapshot()
	await _key(KEY_Z, true)
	_check("native_undo_exact_state", _snapshot() == initial)
	_check("undo_removes_brace_geometry", _screen.board._brace_status_root.get_child_count() == 0 and _screen.board.get_node_or_null("Tiles/Hex_0_0/House/EmergencyBracing") == null)
	await _key(KEY_Y, true)
	_check("native_redo_exact_state", _snapshot() == braced)
	_check("redo_restores_geometry", _screen.board._brace_status_root.get_child_count() == 1)
	var before_duplicate: Dictionary = _snapshot()
	_screen.apply_at(TARGET)
	_check("duplicate_command_no_charge", _snapshot() == before_duplicate)
	await _key(KEY_ESCAPE)
	_screen.hovered_coord = TARGET
	_screen._update_inspector()
	await _capture("bracing-ready-fixture", "CONTROLLED FIXTURE / BRACED BEFORE RESOLVE")
	await _capture_detail()
	var render_before: Dictionary = _snapshot()
	await _frames(5)
	_check("rendering_does_not_mutate_run", _snapshot() == render_before)
	await _key(KEY_ESCAPE)
	_check("native_pause", _screen.modal_kind == "pause")
	var paused: Dictionary = _snapshot()
	root.gui_release_focus()
	await _key(KEY_R)
	_check("modal_blocks_gameplay", _snapshot() == paused and _screen.command_mode.is_empty())
	await _click_control(_screen._motion_toggle)
	_check("native_reduce_motion", _screen.reduced_motion and _screen.board._reduced_motion)
	await _key(KEY_ESCAPE)
	_check("native_resume", _screen.modal_kind.is_empty())
	await _capture("bracing-reduced-fixture", "CONTROLLED FIXTURE / REDUCE MOTION")
	_check("motion_setting_keeps_state", _snapshot() == paused)
	await _continue_checks(braced["state"])
	root.gui_release_focus()
	var expected: GameState = (_screen.prediction["state"] as GameState).duplicate_state()
	await _key(KEY_SPACE)
	_screen._feedback.set_process(false)
	_check("native_end_turn", _session.state.turn == 5 and _session.state.phase == C.Phase.PLANNING)
	_check("braced_house_survives", _session.state.get_tile(TARGET).building == C.Building.HOUSE)
	_check("other_houses_lost", _session.state.get_tile(Vector2i(-1, 0)).building == C.Building.NONE and _session.state.get_tile(Vector2i(1, 0)).building == C.Building.NONE)
	_check("brace_expired", _session.state.get_tile(TARGET).brace_turns == 0 and _screen.board._brace_status_root.get_child_count() == 0)
	_check("preview_matches_committed_house", _session.state.get_tile(TARGET).to_dict(true) == expected.get_tile(TARGET).to_dict(true))
	var history: Array[Dictionary] = _session.turn_history()
	_check("history_has_brace_result", history.size() == 1 and history[0]["report"].get("brace_results", []).size() == 1)
	_check("held_feedback_visible", _feedback_contains(_tr("feedback.brace_held")))
	await _capture("bracing-held-fixture", "CONTROLLED FIXTURE / HELD THIS TURN, NOW EXPIRED")
	var final_state: Dictionary = _session.state.to_dict()
	var loaded: Dictionary = SaveIO.load_game(_session.save_path)
	_check("post_turn_exact_load", loaded["error"].is_empty() and loaded["state"] != null and loaded["state"].to_dict() == final_state)
	_screen.free()
	_screen = null
	_session = GameSession.new()
	_session.save_path = _out_dir.path_join("legacy-checkpoint.json")
	_check("legacy_start", _session.start({"seed": 42, "living_village": true}).is_empty())
	_make_screen()
	await _frames(2)
	_check("legacy_tool_hidden", not _screen._command_buttons["brace_house"].visible)
	await _key(KEY_R)
	_check("legacy_shortcut_inactive", _screen.command_mode.is_empty())
	_finish()


func _menu_checks() -> void:
	_menu = MainMenu.new()
	_menu.save_path = _out_dir.path_join("menu-checkpoint.json")
	_menu.initial_seed = 42
	_menu.language = _language
	_menu.start_requested.connect(_start_from_menu)
	root.add_child(_menu)
	await _frames(2)
	await _click_control(_menu._new_game_button)
	_check("native_new_game_setup", _menu._setup.is_visible_in_tree())
	_check("bracing_opt_in_default_off", not _menu._bracing_toggle.button_pressed)
	_menu._bracing_toggle.grab_focus()
	await _frames(2)
	await _click_control(_menu._bracing_toggle)
	_check("native_bracing_opt_in", _menu._bracing_toggle.button_pressed)
	await _capture("bracing-setup", "NEW GAME SETUP / OPTIONAL HOUSE BRACING")
	_menu._seed_input.grab_focus()
	await _frames(2)
	await _key(KEY_ENTER)
	await _frames(2)
	_check("native_menu_start_request", _started_config.get("ruleset", "") == "bracing_v1")


func _start_from_menu(config: Dictionary) -> void:
	_started_config = config.duplicate(true)
	_session = GameSession.new()
	_session.save_path = _out_dir.path_join("menu-checkpoint.json")
	var options: Dictionary = config.duplicate(true)
	options["living_village"] = true
	_check("menu_session_start", _session.start(options).is_empty())
	root.remove_child(_menu)
	_menu.queue_free()
	_menu = null
	_make_screen()


func _make_screen() -> void:
	_screen = GameScreen.new()
	_screen.session = _session
	_screen.preferences_path = _out_dir.path_join("settings.json")
	root.add_child(_screen)
	_screen.confirm_unused_labor = false


func _continue_checks(expected_state: Dictionary) -> void:
	var path: String = _session.save_path
	_screen.free()
	_screen = null
	_menu = MainMenu.new()
	_menu.save_path = path
	_menu.language = _language
	_menu.initial_ruleset = "legacy"
	_menu.continue_requested.connect(func():
		_session = GameSession.new()
		_session.save_path = path
		_check("continue_load_success", _session.load_game().is_empty())
		root.remove_child(_menu)
		_menu.queue_free()
		_menu = null
		_make_screen()
	)
	root.add_child(_menu)
	await _frames(2)
	_check("continue_available", _menu._continue_button.is_visible_in_tree())
	await _click_control(_menu._continue_button)
	await _frames(2)
	_check("native_continue_preserves_braced_state", _session.state.to_dict() == expected_state)
	_check("continue_ignores_menu_legacy_setting", _session.state.ruleset == "bracing_v1" and _screen._command_buttons["brace_house"].visible)
	_check("continue_restores_brace_geometry", _screen.board._brace_status_root.get_child_count() == 1)
	_check("continue_restores_motion_preference", _screen.reduced_motion)


func _fixture() -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 42, "ruleset": "bracing_v1", "living_village": true})
	state.turn = 4
	state.food = 30
	state.wood = 10
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	for tile: Tile in state.tiles:
		tile.elevation = 2
		tile.water = 0.35
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.start_house = false
		tile.paddy_yield = 0
		tile.paddy_rain_turns = 0
		tile.paddy_dead = false
		tile.brace_turns = 0
	for coord: Vector2i in [Vector2i(-1, 0), TARGET, Vector2i(1, 0)]:
		state.get_tile(coord).building = C.Building.HOUSE
	state.get_tile(Vector2i(-1, 1)).building = C.Building.HALL
	SettlementProgress.reconcile(state)
	GameFlow.begin_turn(state)
	return state


func _snapshot() -> Dictionary:
	return {"state": _session.state.to_dict(), "rng": _session.state.rng.state, "disk": FileAccess.get_file_as_bytes(_session.save_path)}


func _tile_screen_position(coord: Vector2i) -> Vector2:
	var tile: Tile = _session.state.get_tile(coord)
	var local: Vector3 = Hex.to_world(coord, tile.elevation)
	local.y = _screen.board._surface_y(tile)
	return _screen.camera_rig.get_camera().unproject_position(_screen.board.to_global(local))


func _click_control(control: Control) -> void:
	_check("clickable_" + control.name, control.is_visible_in_tree() and control.get_global_rect().intersects(root.get_visible_rect()))
	await _click(control.get_global_rect().get_center())


func _click(position: Vector2) -> void:
	# Native input uses window pixels; Controls/camera use the stretched canvas.
	var pixel_position: Vector2 = position * Vector2(root.size) / root.get_visible_rect().size
	Input.warp_mouse(pixel_position)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pixel_position
	motion.global_position = pixel_position
	motion.relative = Vector2(1.0, 0.0)
	Input.parse_input_event(motion)
	await process_frame
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = pixel_position
	event.global_position = pixel_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)


func _key(code: Key, control: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.ctrl_pressed = control
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
	var paused: bool = false
	if is_instance_valid(_screen):
		paused = _screen.board._activity_paused
		_screen.board.set_activity_paused(true)
	await _frames(2)
	var filename: String = id + "-" + _language + ".png"
	_check(id + "_screenshot", root.get_texture().get_image().save_png(_out_dir.path_join(filename)) == OK)
	_captures.append({"file": filename, "context": context, "viewport": [root.size.x, root.size.y]})
	if is_instance_valid(_screen):
		_screen.board.set_activity_paused(paused)


func _capture_detail() -> void:
	var before: Dictionary = _snapshot()
	# A separate, labelled presentation fixture makes the timber visible above
	# dry ground. Do not change the session, its checkpoint or the flood test.
	var dry: GameState = _session.state.duplicate_state()
	for tile: Tile in dry.tiles:
		tile.water = 0.0
	_screen.board.set_state(dry)
	_screen.board.set_preview({}, false)
	_screen.hud.hide()
	var camera: Camera3D = _screen.camera_rig.get_camera()
	var previous_size: float = camera.size
	var previous_offset: float = camera.h_offset
	camera.size = 7.5
	camera.h_offset = 0.0
	await _capture("bracing-detail-fixture", "CONTROLLED DRY VISUAL FIXTURE / TIMBER AND ONE-TURN SHIELD")
	camera.size = previous_size
	camera.h_offset = previous_offset
	_screen.hud.show()
	_screen.board.set_state(_session.state)
	_screen.board.set_preview(_screen.prediction, _screen.preview_enabled)
	_check("dry_visual_fixture_preserves_run", _snapshot() == before)


func _feedback_contains(value: String) -> bool:
	for marker: Node in _screen._feedback.get_children():
		var label: Label3D = marker.get_node_or_null("Label") as Label3D
		if label != null and label.text.contains(value):
			return true
	return false


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func _check(id: String, passed: bool) -> void:
	_checks[id] = passed
	if not passed:
		_failed = true
		printerr("BRACING PROBE CHECK FAILED: ", id)


func _finish() -> void:
	var evidence: Dictionary = {
		"language": _language,
		"engine": Engine.get_version_info()["string"],
		"display": DisplayServer.get_name(),
		"run": {
			"working_directory": ProjectSettings.globalize_path("res://"),
			"environment": {"DISPLAY": OS.get_environment("DISPLAY"), "XDG_DATA_HOME": OS.get_environment("XDG_DATA_HOME")},
			"argv": ["godot", "--path", ".", "--audio-driver", "Dummy", "--resolution", "1280x720", "--script", "res://tools/bracing_probe.gd", "--", "--out-dir=" + _out_dir, "--lang=" + _language],
		},
		"checks": _checks,
		"captures": _captures,
		"fixtures": {
			"new_game": "Legal seed 42 start through native menu with house bracing opted in.",
			"flood": "Controlled turn 4 board: 61 flat tiles at elevation 2, water 0.35, no rain inflow/source/sea/features; three houses and one hall. Not a legal playthrough.",
			"detail": "Separate presentation clone of the braced board with water 0; HUD hidden and camera zoomed to expose timber. Session and checkpoint unchanged.",
		},
		"note": "Native automated mouse/keyboard integration, not a human playtest or performance benchmark. Screenshot pixels are captured directly from the Godot viewport without image editing. Checkpoints/settings isolated beneath the output directory.",
	}
	var file: FileAccess = FileAccess.open(_out_dir.path_join("bracing-qa-" + _language + ".json"), FileAccess.WRITE)
	if file == null:
		_failed = true
	else:
		file.store_string(JSON.stringify(evidence, "  ", true, true))
		file.close()
	print("BRACING_PROBE ", JSON.stringify(_checks))
	quit(1 if _failed else 0)
