extends SceneTree
## Reproducible native moisture/input evidence; saves and settings stay isolated.
## DISPLAY=:99 godot --path . --audio-driver Dummy --resolution 1280x720 \
##   --script res://tools/moisture_probe.gd -- --out-dir=/absolute/work/moisture-qa/th --lang=th

const TARGET: Vector2i = Vector2i.ZERO

var _out_dir: String = ""
var _language: String = "en"
var _screen: GameScreen
var _menu: MainMenu
var _session: GameSession
var _badge: Label
var _checks: Dictionary = {}
var _captures: Array[Dictionary] = []
var _failed: bool = false
var _started_config: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			_out_dir = argument.trim_prefix("--out-dir=")
		elif argument.begins_with("--lang="):
			_language = argument.trim_prefix("--lang=")
	if DisplayServer.get_name() == "headless" or _language not in ["th", "en"] or not _out_dir.is_absolute_path():
		printerr("Moisture probe needs a native display, --lang=th|en and an absolute --out-dir.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	for filename: String in ["menu-checkpoint.json", "fixture-checkpoint.json"]:
		_check("clear_" + filename, SaveIO.delete_save(_out_dir.path_join(filename)).is_empty())
	Localization.setup(_language)
	root.size = Vector2i(1280, 720)
	root.min_size = root.size
	_check("isolated_preferences", GamePreferences.write({"language": _language, "confirm_unused_labor": false, "reduced_motion": false}, _out_dir.path_join("settings.json")).is_empty())
	_add_badge()
	await _menu_checks()
	if _screen == null:
		_finish()
		return
	_check("new_game_config", _started_config.get("ruleset", "") == "bracing_moisture_v1")
	_check("enter_preserves_first_turn", _session.state.seed == 42 and _session.state.turn == 1 and _session.state.phase == C.Phase.PLANNING)
	_check("combined_bracing_tool_visible", _screen._command_buttons["brace_house"].visible)
	await _replace_fixture(_fixture(0.35, 0, 6))
	await _select_target()
	var before: Dictionary = _snapshot()
	_check("rain_preview_recharges_two", (_screen.prediction["state"] as GameState).get_tile(TARGET).soil_moisture == 2)
	_check("rain_inspector_current", _screen._tile_note.text.contains(_tr("tile.moisture") % [0, 2]))
	_check("rain_inspector_forecast", _screen._tile_note.text.contains(_tr("tile.moisture_forecast") % [0, 2]))
	_check("selected_moisture_badge", _screen.board._moisture_status_root.get_child_count() > 0)
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	_check("preview_toggle_read_only", _snapshot() == before)
	await _capture("moisture-rain-fixture", "CONTROLLED FIXTURE / RAIN RECHARGES SOIL 0 TO 2")
	root.gui_release_focus()
	await _key(KEY_SPACE)
	_check("rain_actual_recharge", _session.state.get_tile(TARGET).soil_moisture == 2 and _screen.modal_kind == "harvest")
	var next_year: Button = _screen._modal.find_child("ContinueHarvest", true, false) as Button
	_check("harvest_continue_available", next_year != null)
	if next_year == null:
		_finish()
		return
	await _click_control(next_year)
	_check("moisture_survives_next_year", _session.state.year == 2 and _session.state.turn == 1 and _session.state.get_tile(TARGET).soil_moisture == 2 and _session.state.get_tile(TARGET).paddy_yield == 0)
	# Explicit dry presentation fixture: drain surface water after the annual
	# transition, keeping actual carried moisture and the resulting paddy yield.
	for tile: Tile in _session.state.tiles:
		tile.water = 0.0
	_check("dry_fixture_checkpoint", _session.checkpoint().is_empty())
	_screen.refresh_state()
	await _select_target()
	_check("dry_preview_uses_moisture", (_screen.prediction["state"] as GameState).get_tile(TARGET).soil_moisture == 1 and (_screen.prediction["state"] as GameState).get_tile(TARGET).paddy_yield == 1)
	_check("dry_inspector_source", _screen._tile_note.text.contains(_tr("tile.moisture_yield")))
	await _capture("moisture-dry-fixture", "CONTROLLED DRAINED FIXTURE / CARRIED SOIL 2, PREVIEW 1")
	await _command_checks()
	await _continue_checks()
	await _select_target()
	var motion_before: Dictionary = _snapshot()
	await _key(KEY_ESCAPE)
	_check("pause_open", _screen.modal_kind == "pause")
	await _click_control(_screen._motion_toggle)
	_check("reduce_motion", _screen.reduced_motion and _screen.board._reduced_motion)
	_check("pause_content_fits_viewport", root.get_visible_rect().encloses(_screen._modal_content.get_global_rect()))
	await _capture("moisture-pause-fixture", "CONTROLLED FIXTURE / PAUSE AND REDUCE MOTION")
	await _key(KEY_ESCAPE)
	_check("motion_read_only", _snapshot() == motion_before)
	var food_before: int = _session.state.food
	root.gui_release_focus()
	await _key(KEY_SPACE)
	_screen._feedback.set_process(false)
	_check("dry_actual_decrements_once", _session.state.turn == 2 and _session.state.get_tile(TARGET).soil_moisture == 1 and _session.state.get_tile(TARGET).paddy_yield == 1)
	_check("dry_yield_is_not_food", _session.state.food == food_before)
	_check("actual_moisture_feedback", _feedback_contains(_tr("feedback.moisture_yield")))
	_check("actual_history_semantics", _session.turn_history().size() == 1 and not _session.turn_history()[0]["report"].get("moisture_changes", []).is_empty())
	await _capture("moisture-yield-fixture", "CONTROLLED FIXTURE / SOIL YIELD, REDUCE MOTION ON")
	_screen._feedback.set_process(true)
	await _key(KEY_H)
	_check("native_history_open", _screen.modal_kind == "turn_history")
	_check("history_source_visible", _labels(_screen._history_details).contains(_tr("feedback.moisture_yield")))
	await _key(KEY_ESCAPE)
	root.gui_release_focus()
	await _key(KEY_SPACE)
	_check("second_dry_yield_exhausts_soil", _session.state.get_tile(TARGET).soil_moisture == 0 and _session.state.get_tile(TARGET).paddy_yield == 2)
	root.gui_release_focus()
	await _key(KEY_SPACE)
	_check("third_dry_no_free_yield", _session.state.get_tile(TARGET).soil_moisture == 0 and _session.state.get_tile(TARGET).paddy_yield == 2 and _session.state.food == food_before)
	await _replace_fixture(_fixture(0.0, 2, 4))
	root.gui_release_focus()
	await _key(KEY_SPACE)
	_check("unsuitable_rain_decays_without_yield", _session.state.get_tile(TARGET).soil_moisture == 1 and _session.state.get_tile(TARGET).paddy_yield == 0)
	await _replace_fixture(_fixture(0.7, 2, 4))
	root.gui_release_focus()
	await _key(KEY_SPACE)
	_check("flood_kills_and_clears_soil", _session.state.get_tile(TARGET).paddy_dead and _session.state.get_tile(TARGET).soil_moisture == 0)
	_finish()


func _menu_checks() -> void:
	_menu = MainMenu.new()
	_menu.save_path = _out_dir.path_join("menu-checkpoint.json")
	_menu.language = _language
	_menu.start_requested.connect(_start_from_menu)
	root.add_child(_menu)
	await _frames(2)
	await _click_control(_menu._new_game_button)
	_check("both_options_default_off", not _menu._bracing_toggle.button_pressed and not _menu._moisture_toggle.button_pressed)
	_menu._bracing_toggle.grab_focus()
	await _frames(2)
	await _click_control(_menu._bracing_toggle)
	_menu._moisture_toggle.grab_focus()
	await _frames(2)
	await _click_control(_menu._moisture_toggle)
	_check("both_options_native_click", _menu._bracing_toggle.button_pressed and _menu._moisture_toggle.button_pressed)
	await _capture("moisture-setup", "NEW GAME SETUP / OPTIONAL SOIL MOISTURE")
	_menu._seed_input.grab_focus()
	await _frames(2)
	await _key(KEY_ENTER)
	await _frames(2)


func _start_from_menu(config: Dictionary) -> void:
	_started_config = config.duplicate(true)
	_session = GameSession.new()
	_session.save_path = _out_dir.path_join("menu-checkpoint.json")
	var options: Dictionary = config.duplicate(true)
	options["living_village"] = true
	_check("menu_start_saves", _session.start(options).is_empty() and _session.last_save_error.is_empty())
	root.remove_child(_menu)
	_menu.queue_free()
	_menu = null
	_make_screen()


func _fixture(depth: float, moisture: int, turn: int) -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 42, "ruleset": "bracing_moisture_v1", "living_village": true})
	state.turn = turn
	state.food = 100
	state.wood = 20
	state.rain_inflows.assign([0.0, 0.0, 0.0])
	state.year_mods.assign([{"key": "hall_lose_level", "op": "set", "value": 4}])
	state.recompute_mods()
	for tile: Tile in state.tiles:
		tile.elevation = 2
		tile.water = depth
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
		tile.soil_moisture = 0
	for coord: Vector2i in [Vector2i(-1, 0), TARGET, Vector2i(1, 0)]:
		state.get_tile(coord).feature = C.Feature.PADDY
		state.get_tile(coord).soil_moisture = moisture
	for coord: Vector2i in [Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		state.get_tile(coord).building = C.Building.STILT_HOUSE
	state.get_tile(Vector2i(-1, -1)).building = C.Building.HALL
	SettlementProgress.reconcile(state)
	GameFlow.begin_turn(state)
	return state


func _replace_fixture(state: GameState) -> void:
	if is_instance_valid(_screen):
		_screen.free()
	_session = GameSession.new()
	_session.save_path = _out_dir.path_join("fixture-checkpoint.json")
	_session.state = state
	_check("fixture_checkpoint_" + str(_checks.size()), _session.checkpoint().is_empty())
	_make_screen()
	await _frames(2)


func _make_screen() -> void:
	_screen = GameScreen.new()
	_screen.session = _session
	_screen.preferences_path = _out_dir.path_join("settings.json")
	root.add_child(_screen)
	_screen.confirm_unused_labor = false


func _command_checks() -> void:
	var before: Dictionary = _snapshot()
	root.gui_release_focus()
	await _key(KEY_X)
	await _click(_tile_screen_position(TARGET))
	_check("native_demolish_clears_moisture", _session.state.get_tile(TARGET).feature == C.Feature.NONE and _session.state.get_tile(TARGET).soil_moisture == 0)
	var demolished: Dictionary = _snapshot()
	root.gui_release_focus()
	await _key(KEY_Z, true)
	_check("native_undo_restores_moisture", _snapshot() == before)
	root.gui_release_focus()
	await _key(KEY_Y, true)
	_check("native_redo_clears_moisture", _snapshot() == demolished)
	root.gui_release_focus()
	await _key(KEY_Z, true)
	await _key(KEY_ESCAPE)
	_check("native_restore_before_continue", _snapshot() == before)


func _continue_checks() -> void:
	var expected: Dictionary = _session.state.to_dict()
	var path: String = _session.save_path
	_screen.free()
	_menu = MainMenu.new()
	_menu.save_path = path
	_menu.language = _language
	_menu.initial_ruleset = "legacy"
	_menu.continue_requested.connect(func():
		_session = GameSession.new()
		_session.save_path = path
		_check("continue_load", _session.load_game().is_empty())
		root.remove_child(_menu)
		_menu.queue_free()
		_menu = null
		_make_screen()
	)
	root.add_child(_menu)
	await _frames(2)
	await _click_control(_menu._continue_button)
	_check("native_continue_exact_state", _session.state.to_dict() == expected)
	_check("continue_ruleset_independent_of_menu", _session.state.ruleset == "bracing_moisture_v1")


func _select_target() -> void:
	root.gui_release_focus()
	await _click(_tile_screen_position(TARGET))
	_check("native_inspection_target_" + str(_checks.size()), _screen.hovered_coord == TARGET and _screen.board._selected_coord == TARGET)


func _snapshot() -> Dictionary:
	return {"state": _session.state.to_dict(), "rng": _session.state.rng.state, "disk": FileAccess.get_file_as_bytes(_session.save_path)}


func _tile_screen_position(coord: Vector2i) -> Vector2:
	var tile: Tile = _session.state.get_tile(coord)
	var local: Vector3 = Hex.to_world(coord, tile.elevation)
	local.y = _screen.board._surface_y(tile)
	return _screen.camera_rig.get_camera().unproject_position(_screen.board.to_global(local))


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
	await _frames(1)


func _frames(count: int) -> void:
	for index: int in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _feedback_contains(value: String) -> bool:
	for marker: Node in _screen._feedback.get_children():
		var label: Label3D = marker.get_node_or_null("Label") as Label3D
		if label != null and label.text.contains(value):
			return true
	return false


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
		printerr("MOISTURE PROBE CHECK FAILED: ", id)


func _finish() -> void:
	var evidence: Dictionary = {
		"language": _language, "engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(),
		"checks": _checks, "captures": _captures,
		"fixture": "Controlled flat elevation-2 board, three paddies and three stilt houses, hall threshold4, no sources/sea/inflow. Rain turn6 depth0.35; next-year surface water explicitly drained for dry visual fixture. Unsuitable-rain depth0 and flood depth0.7 are independent controlled fixtures. Not a legal playthrough.",
		"note": "Automated native mouse/keyboard integration at 1280x720; not human playtesting, balance validation or a performance benchmark. Images captured directly from Godot viewport without editing. All saves/settings isolated under out-dir.",
	}
	var file: FileAccess = FileAccess.open(_out_dir.path_join("moisture-qa-" + _language + ".json"), FileAccess.WRITE)
	if file == null:
		_failed = true
	else:
		file.store_string(JSON.stringify(evidence, "  ", true, true))
		file.close()
	print("MOISTURE_PROBE ", JSON.stringify(_checks))
	quit(1 if _failed else 0)
