extends SceneTree
## Render the same authored settlement through dry/rain/flood/recovery.
## Writes only beneath --out-dir, with an isolated session/settings path.

var _out_dir: String = "res://work/village-world-native"
var _lang: String = "th"
var _screen: GameScreen
var _session: GameSession
var _badge: Label
var _checks: Dictionary = {}
var _shots: Array[Dictionary] = []
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=")
		elif arg.begins_with("--lang="):
			_lang = arg.trim_prefix("--lang=")
	if DisplayServer.get_name() == "headless" or _lang not in ["th", "en"]:
		printerr("Use a native rendering display and --lang=th or en.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Localization.setup(_lang)
	root.size = Vector2i(1280, 720)
	_session = GameSession.new()
	_session.state = VillageWorldFixture.create()
	_session.save_path = _out_dir.path_join("fixture-save.json")
	_check("isolated_checkpoint", _session.checkpoint().is_empty())
	_screen = GameScreen.new()
	_screen.session = _session
	_screen.preferences_path = _out_dir.path_join("fixture-settings.json")
	_check("isolated_settings", GamePreferences.write({"language": _lang, "reduced_motion": true, "confirm_unused_labor": false}, _screen.preferences_path).is_empty())
	root.add_child(_screen)
	var layer: CanvasLayer = CanvasLayer.new()
	root.add_child(layer)
	_badge = Label.new()
	_badge.position = Vector2(24, 142)
	_badge.add_theme_font_override("font", load("res://assets/fonts/NotoSansThai.ttf"))
	_badge.add_theme_font_size_override("font_size", 18)
	_badge.add_theme_color_override("font_color", Color("f0d393"))
	_badge.add_theme_color_override("font_shadow_color", Color("122b30"))
	_badge.add_theme_constant_override("shadow_offset_x", 2)
	_badge.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_badge)
	await _frames(3)
	await _key(KEY_TAB)
	var before: Dictionary = _session.state.to_dict()
	var disk: PackedByteArray = FileAccess.get_file_as_bytes(_session.save_path)
	var scenery: VillageScenery = _screen.board._scenery
	var counts: Dictionary = {}
	for item: Dictionary in scenery.plan["props"]:
		counts[item["kind"]] = int(counts.get(item["kind"], 0)) + 1
	print("WORLD_PROPS ", JSON.stringify(counts))
	_check("courtyards_visible", int(counts.get("courtyard", 0)) >= 3)
	_check("worksites_visible", int(counts.get("drying_mat", 0)) > 0)
	_check("river_docks_visible", int(counts.get("dock", 0)) + int(counts.get("cargo_dock", 0)) + int(counts.get("fishing_dock", 0)) > 0)
	_check("water_gauges_visible", int(counts.get("water_mark", 0)) > 0)
	await _capture("village-ui")
	_screen.hud.hide()
	_badge.position.y = 22
	var camera: Camera3D = _screen.camera_rig.get_camera()
	camera.size = 8.0
	camera.h_offset = 0.0
	_screen.camera_rig.position = Vector3(-0.4, 1.1, 0.2)
	scenery.hide()
	await _capture("village-before")
	scenery.show()
	await _capture("village-dry")
	var dock_position: Vector3 = Vector3.ZERO
	for item: Dictionary in scenery.plan["props"]:
		if item["kind"] in ["dock", "cargo_dock", "fishing_dock"]:
			dock_position = item["position"]
			break
	_screen.camera_rig.position = dock_position + Vector3.UP * 0.2
	camera.size = 6.0
	await _capture("riverbank-detail")
	_screen._on_motion_toggled(false)
	var moving_before: Dictionary = scenery.snapshot()
	await _frames(12)
	_check("ambience_moves", scenery.snapshot()["actors"] != moving_before["actors"])
	scenery.set_paused(true)
	var paused: Dictionary = scenery.snapshot()
	await _frames(6)
	_check("pause_freezes_scenery", paused == scenery.snapshot())
	scenery.set_paused(false)
	_screen._on_motion_toggled(true)
	var still: Dictionary = scenery.snapshot()
	await _frames(6)
	_check("reduce_motion_static", still == scenery.snapshot())
	_check("render_state_unchanged", _session.state.to_dict() == before)
	_check("render_checkpoint_unchanged", FileAccess.get_file_as_bytes(_session.save_path) == disk)
	_screen.board.show_harvest_activity({Vector2i.ZERO: 4})
	_check("committed_harvest_only", scenery.snapshot()["activity"] > 0)
	await _capture("harvest-activity")
	scenery._process(3.0)
	_check("feedback_expires_in_reduced_motion", scenery.snapshot()["activity"] == 0)
	_screen.board.set_preview(GameFlow.preview(_session.state))
	_check("forecast_never_adds_cargo", scenery.snapshot()["activity"] == 0)
	_screen.board.set_preview({}, false)
	_session.state.turn = 4
	_screen.refresh_state()
	_screen.board.set_preview({}, false)
	_screen.camera_rig.position = Vector3(-0.4, 1.1, 0.2)
	camera.size = 8.0
	_check("rain_uses_current_season", scenery.plan["rain"])
	await _capture("village-rain")
	for tile: Tile in _session.state.tiles:
		if tile.q >= 0:
			tile.water = 2.0 if tile.elevation == 1 else 1.0
	_screen.refresh_state()
	_screen.board.set_preview({}, false)
	_check("flooded_bank_removes_moorings", _all_banks_safe(scenery.plan))
	await _capture("village-flood")
	# Reload the exact isolated checkpoint; this restores the prepared village,
	# not a fabricated water-recovery simulation or an extra harvest.
	_check("load_fixture", _session.load_game().is_empty())
	_screen.board.set_state(_session.state)
	_screen.refresh_state()
	_screen.board.set_preview({}, false)
	_check("load_restores_exact_state", _session.state.to_dict() == before)
	_check("load_clears_activity", scenery.snapshot()["activity"] == 0)
	_check("load_keeps_checkpoint", FileAccess.get_file_as_bytes(_session.save_path) == disk)
	await _capture("village-restored")
	var evidence: Dictionary = {"fixture": true, "language": _lang, "engine": Engine.get_version_info()["string"], "checks": _checks, "captures": _shots, "note": "Authored settlement fixtures; flood is prepared state and restoration is checkpoint loading. Not a legal seasonal playthrough, human playtest, or hardware benchmark."}
	var file: FileAccess = FileAccess.open(_out_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		_failed = true
	else:
		file.store_string(JSON.stringify(evidence, "  ", true, true))
		file.close()
	print("VILLAGE_WORLD_PROBE ", JSON.stringify(_checks))
	quit(1 if _failed else 0)


func _all_banks_safe(plan: Dictionary) -> bool:
	var routes: RouteGraph = _screen.board._route_view.graph
	for item: Dictionary in plan["clearance"]:
		if not VillageScenePlan.slot_clear(item["position"], item["radius"], routes, []):
			return false
	return true


func _frames(count: int) -> void:
	for frame: int in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(id: String) -> void:
	_badge.text = "CONTROLLED FIXTURE / " + _lang.to_upper() + " / " + id
	await _frames(3)
	_check(id + "_image", root.get_texture().get_image().save_png(_out_dir.path_join(id + ".png")) == OK)
	_shots.append({"id": id, "props": _screen.board._scenery.plan.get("props", []).size(), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})


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
	await _frames(2)


func _check(id: String, result: bool) -> void:
	_checks[id] = result
	if not result:
		_failed = true
		printerr("FAIL ", id)
