extends SceneTree
## Native integration evidence, deliberately labelled as controlled fixtures.
## Run with a rendering display and isolated XDG_DATA_HOME, for example:
## godot --path . --audio-driver Dummy --resolution 1280x720 \
##   --script res://tools/living_village_probe.gd -- --out-dir=/tmp/living-qa --lang=th
## This tool writes only beneath --out-dir; no player checkpoint is opened.

var _out_dir: String = "/tmp/monsoon-living-probe"
var _language: String = "en"
var _screen: GameScreen
var _session: GameSession
var _evidence: Dictionary = {"fixture": true, "observations": [], "checks": {}}
var _badge: Label
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=")
		elif arg.begins_with("--lang="):
			_language = arg.trim_prefix("--lang=")
	if DisplayServer.get_name() == "headless" or _language not in ["th", "en"]:
		printerr("The living-village probe requires a native display and --lang=th or en.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Localization.setup(_language)
	root.min_size = Vector2i(1280, 720)
	_session = GameSession.new()
	_session.save_path = _out_dir.path_join("fixture-checkpoint.json")
	_session.state = _fixture()
	_check("fixture_checkpoint", _session.checkpoint().is_empty())
	_screen = GameScreen.new()
	_screen.session = _session
	_screen.preferences_path = _out_dir.path_join("fixture-settings.json")
	_check("isolated_settings", GamePreferences.write({"language": _language, "confirm_unused_labor": false, "reduced_motion": false}, _screen.preferences_path).is_empty())
	root.add_child(_screen)
	_add_badge()
	await _frames(3)
	for id: String in _screen._resource_chips:
		var resource_label: Label = _screen._resource_chips[id]
		_check("resource_" + id + "_single_line", resource_label.size.y < 45.0 and resource_label.size.x > 45.0)
	_check("condition_single_line", _screen._condition_label.size.y < 45.0)
	var before: Dictionary = _session.state.to_dict()
	var disk_before: PackedByteArray = FileAccess.get_file_as_bytes(_session.save_path)
	var rng_before: int = _session.state.rng.state
	var restored: Dictionary = SaveIO.load_game(_session.save_path)
	_check("fixture_exact_load", restored["error"].is_empty() and restored["state"] != null and restored["state"].to_dict() == before)
	_screen.board.show_command_activity("chop", Vector2i(-2, 2))
	var report: TurnReport = TurnReport.new()
	report.paddy_gains.append(Vector2i(1, 0))
	report.fish_food = 2
	report.fish_food_by_tile[Vector2i(2, -1)] = 2
	_screen.board.show_turn_activity(report)
	_screen.board.show_harvest_activity({Vector2i(1, 1): 4})
	await _frames(2)
	await _capture("fixture-stable-outbound")
	# Advance only the presentation clock, allowing a deterministic work pose
	# without making an automated screenshot wait on wall-clock performance.
	for frame: int in range(100):
		_screen.board._life_view._process(0.15)
		if _has_stage("work"):
			break
	await _capture("fixture-stable-work")
	await _capture_detail("fixture-village-detail")
	await _benchmark()
	for frame: int in range(100):
		_screen.board._life_view._process(0.15)
		if _has_stage("deliver", true):
			break
	await _capture("fixture-stable-delivery")
	_check("committed_job_carry_visible", _has_stage("deliver", true))
	_screen.board.show_actual_flow(_screen.prediction["report"])
	await _capture("fixture-recorded-water-transfers")
	_check("view_state_unchanged", _session.state.to_dict() == before)
	_check("view_rng_unchanged", _session.state.rng.state == rng_before)
	_check("view_checkpoint_unchanged", FileAccess.get_file_as_bytes(_session.save_path) == disk_before)
	_screen._on_motion_toggled(true)
	_screen.board.clear_activity()
	_screen.board.refresh()
	_screen.board.show_command_activity("chop", Vector2i(-2, 2))
	_screen.board.show_turn_activity(report)
	var static_before: Array[Dictionary] = _screen.board._life_view.activity_snapshot()
	_screen.board._life_view._process(0.4)
	_check("reduced_motion_fixed_poses", static_before == _screen.board._life_view.activity_snapshot())
	await _capture("fixture-reduced-motion")
	_screen._on_motion_toggled(false)
	var state: GameState = _session.state
	state.year = 3
	state.stats["reached_year"] = 3
	state.food = 180
	state.wood = 35
	state.settlement_progress["condition"] = "thriving"
	state.settlement_progress["candidate"] = "thriving"
	state.settlement_progress["evaluated_year"] = 2
	for record: Dictionary in state.settlement_progress["buildings"].values():
		record["built_year"] = 1
		record["stage"] = 2
	_screen.refresh_state()
	_check("developed_checkpoint", _session.checkpoint().is_empty())
	await _capture("fixture-thriving-age-two")
	state.settlement_progress["condition"] = "struggling"
	state.settlement_progress["candidate"] = "struggling"
	state.food = 0
	state.wood = 0
	for record: Dictionary in state.settlement_progress["buildings"].values():
		record["stage"] = 0
	_screen.refresh_state()
	await _capture("fixture-struggling")
	# A basin around the hall is a controlled preview fixture. The shared
	# resolver, rather than a fabricated outcome, must identify the danger.
	state.food = 30
	for tile: Tile in state.tiles:
		tile.water = 2.8
	_screen.refresh_state()
	_check("hall_peril_predicted", _screen._advisor.get("kind", "") == "hall")
	await _capture("fixture-hall-peril")
	# Focus the advisor action and verify that the selection reaches the hall.
	_screen._advisor_button.emit_signal("pressed")
	await _frames(2)
	_check("advisor_focus_hall", _screen.board._selected_coord == Vector2i(-1, 0))
	await _capture("fixture-hall-peril-focused")
	_check("advisor_inspector_stays_on_hall", _screen.hovered_coord == Vector2i(-1, 0) and _screen._tile_title.text.contains("-1, 0"))
	var peril_before: Dictionary = state.to_dict()
	await _key(KEY_TAB)
	_check("critical_advice_without_preview", not _screen.preview_enabled and _screen._advisor["kind"] == "hall" and _screen._advisor_panel.is_visible_in_tree())
	await _capture("fixture-critical-advice-preview-hidden")
	_check("peril_inspection_read_only", state.to_dict() == peril_before)
	await _legal_controller_checks()
	_evidence["language"] = _language
	_evidence["engine"] = Engine.get_version_info()["string"]
	_evidence["display"] = DisplayServer.get_name()
	_evidence["isolated_save"] = _session.save_path
	_evidence["isolated_settings"] = _screen.preferences_path
	_evidence["note"] = "Controlled visual/integration fixtures; not a legal playthrough or human playtest. Native software-renderer timings are not a hardware benchmark."
	var file: FileAccess = FileAccess.open(_out_dir.path_join("observations.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_evidence, "  ", true, true))
		file.close()
	else:
		_failed = true
	print("LIVING_VILLAGE_PROBE ", JSON.stringify(_evidence["checks"]))
	quit(1 if _failed else 0)


func _fixture() -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 42, "living_village": true, "run_mode": "long", "village_goal": "forest"})
	state.population = 6
	state.stats["max_population"] = 6
	state.food = 30
	state.wood = 15
	state.labor = 12
	state.labor_max = 12
	for tile: Tile in state.tiles:
		tile.elevation = 2
		tile.water = 0.0
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.start_house = false
		tile.paddy_yield = 0
		tile.paddy_dead = false
		tile.paddy_rain_turns = 0
	for coord: Vector2i in [Vector2i(-2, 0), Vector2i(-1, -1)]:
		state.get_tile(coord).building = C.Building.HOUSE
	state.get_tile(Vector2i(-2, 1)).building = C.Building.STILT_HOUSE
	state.get_tile(Vector2i(-1, 0)).building = C.Building.HALL
	state.get_tile(Vector2i(0, 1)).building = C.Building.GRANARY
	for coord: Vector2i in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2)]:
		state.get_tile(coord).feature = C.Feature.PADDY
		state.get_tile(coord).paddy_yield = 2
	for coord: Vector2i in [Vector2i(-3, 1), Vector2i(-3, 2), Vector2i(-2, -1), Vector2i(-1, -2)]:
		state.get_tile(coord).feature = C.Feature.FOREST
	for tile: Tile in state.tiles:
		if tile.q >= 3 or tile.coord == Vector2i(2, -1):
			tile.is_river = true
			tile.elevation = 1
			tile.water = 0.35 + 0.08 * float(tile.r + 4)
	state.get_tile(Vector2i(2, -1)).building = C.Building.FISH_TRAP
	SettlementProgress.reconcile(state)
	return state


func _add_badge() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	_badge = Label.new()
	_badge.text = "CONTROLLED FIXTURE / " + _language.to_upper()
	_badge.position = Vector2(555, 1030)
	_badge.add_theme_font_size_override("font_size", 18)
	_badge.add_theme_color_override("font_color", Color("ffdf94"))
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_badge)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _has_stage(stage: String, carrying: bool = false) -> bool:
	for activity: Dictionary in _screen.board._life_view.activity_snapshot():
		if activity["stage"] == stage and (not carrying or activity["carrying"]):
			return true
	return false


func _capture_detail(id: String) -> void:
	_screen.hud.hide()
	var camera: Camera3D = _screen.camera_rig.get_camera()
	var previous_size: float = camera.size
	var previous_offset: float = camera.h_offset
	camera.size = 16.0
	camera.h_offset = 0.0
	await _capture(id)
	camera.size = previous_size
	camera.h_offset = previous_offset
	_screen.hud.show()


func _capture(id: String) -> void:
	_badge.text = ("LEGAL SEED 42 / " if id.begins_with("legal-") else "CONTROLLED FIXTURE / ") + id
	var previous_paused: bool = _screen.board._activity_paused
	_screen.board.set_activity_paused(true)
	await _frames(2)
	var path: String = _out_dir.path_join(id + ".png")
	var error: Error = root.get_texture().get_image().save_png(path)
	_check(id + "_screenshot", error == OK)
	var activities: Array[Dictionary] = _screen.board._life_view.activity_snapshot()
	var jobs: Array[Dictionary] = []
	for activity: Dictionary in activities:
		jobs.append({"kind": activity["kind"], "stage": activity["stage"], "carrying": activity["carrying"], "position": str(activity["position"]), "coord": str(activity["coord"])})
	_evidence["observations"].append({
		"id": id, "screenshot": path, "viewport": str(root.size),
		"advisor": _screen._advisor.get("kind", ""), "actor_pool": _screen.board._life_view.actor_count(),
		"inspector": _screen._tile_title.text,
		"active_jobs": jobs, "queued_jobs": _screen.board._life_view.queued_job_count(),
		"road_routes": _screen.board._route_view.graph.routes.size(),
		"flow_preview_nodes": _screen.board._flow_view._preview_root.get_child_count(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"process_seconds": Performance.get_monitor(Performance.TIME_PROCESS),
	})
	print("CAPTURE ", path)
	_screen.board.set_activity_paused(previous_paused)


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
	await process_frame


func _legal_controller_checks() -> void:
	_screen.free()
	_session = GameSession.new()
	_session.save_path = _out_dir.path_join("legal-controller-checkpoint.json")
	_check("legal_session_start", _session.start({"seed": 42, "living_village": true}).is_empty())
	_screen = GameScreen.new()
	_screen.session = _session
	_screen.preferences_path = _out_dir.path_join("fixture-settings.json")
	root.add_child(_screen)
	await _frames(2)
	var original: Dictionary = _session.state.to_dict()
	var targets: Array[Vector2i] = _screen.valid_targets("chop")
	_check("legal_chop_target_exists", not targets.is_empty())
	if targets.is_empty():
		return
	await _key(KEY_C)
	_check("native_chop_shortcut", _screen.command_mode == "chop")
	_screen.apply_at(targets[0])
	_check("legal_chop_committed", _session.state.wood > int(original["wood"]))
	_check("legal_chop_activity", not _screen.board._life_view.activity_snapshot().is_empty())
	var chopped: Dictionary = _session.state.to_dict()
	await _capture("legal-chop-command")
	await _key(KEY_Z, true)
	_check("native_undo_exact_state", _session.state.to_dict() == original)
	_check("native_undo_clears_activity", _screen.board._life_view.activity_snapshot().is_empty())
	await _key(KEY_Y, true)
	_check("native_redo_exact_state", _session.state.to_dict() == chopped)
	_check("native_redo_clears_activity", _screen.board._life_view.activity_snapshot().is_empty())
	await _key(KEY_ESCAPE)
	_check("native_escape_cancels_tool", _screen.command_mode.is_empty())
	await _key(KEY_ESCAPE)
	_check("native_pause_open", _screen.modal_kind == "pause" and _screen.board._activity_paused)
	await _key(KEY_ESCAPE)
	_check("native_pause_resume", _screen.modal_kind.is_empty() and not _screen.board._activity_paused)
	_check("legal_load", _session.load_game().is_empty())
	_screen.refresh_state()
	_check("legal_load_exact_state", _session.state.to_dict() == chopped)
	_check("legal_load_clears_activity", _screen.board._life_view.activity_snapshot().is_empty())
	await _capture("legal-after-undo-redo-load")


func _benchmark() -> void:
	# Same scene, presentation-only layers visible versus hidden and paused.
	# This is a software-renderer comparison, not an old-branch baseline.
	var board: BoardView = _screen.board
	var layers: Array[Node3D] = [board._route_view, board._life_view, board._flow_view]
	board.set_activity_paused(true)
	var results: Dictionary = {}
	for visible: bool in [true, false]:
		for layer: Node3D in layers:
			layer.visible = visible
		await _frames(2)
		var start: int = Time.get_ticks_usec()
		await _frames(8)
		results["visible" if visible else "hidden"] = {
			"mean_rendered_frame_ms": float(Time.get_ticks_usec() - start) / 8000.0,
			"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"render_objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		}
	for layer: Node3D in layers:
		layer.show()
	board.set_activity_paused(false)
	_evidence["same_scene_software_comparison"] = results


func _check(id: String, passed: bool) -> void:
	_evidence["checks"][id] = passed
	if not passed:
		_failed = true
		printerr("PROBE CHECK FAILED: ", id)
