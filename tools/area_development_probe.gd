extends "res://tools/end_turn_probe.gd"
const Areas = preload("res://tools/area_development_fixtures.gd")


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
	_case(Areas.create())
	await _frames(3)
	var original: Dictionary = screen.session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	await _open_area(Areas.LAND)
	_check("opening_area_is_read_only", screen.session.state.to_dict() == original and FileAccess.get_file_as_bytes(path) == bytes)
	_check("safe_default_keyboard_focus", root.gui_get_focus_owner() == screen._area_panel._back)
	await _choose_action("house")
	_check("house_preview_is_local_and_read_only", screen._area_panel._command.coord == Areas.LAND and (screen._area_panel._plan["state"] as GameState).get_tile(Areas.LAND).building == C.Building.HOUSE and screen.session.state.to_dict() == original)
	_check("planning_dialog_fits", root.get_visible_rect().encloses(screen._modal_content.get_global_rect()))
	_check("area_role_localized", _labels(screen._area_panel).contains(_tr("area.role.upland")))
	await _capture("area-house-plan")
	await _key(KEY_ESCAPE)
	_check("escape_cancel_preserves_checkpoint", screen.modal_kind.is_empty() and FileAccess.get_file_as_bytes(path) == bytes)

	await _open_area(Areas.FOREST)
	await _choose_action("chop")
	var plan: Dictionary = (screen._area_panel._plan["state"] as GameState).to_dict()
	await _capture("area-forest-plan")
	await _burst(screen._area_panel._apply)
	_check("mouse_keyboard_burst_commits_one_command", screen.modal_kind == "area_development" and screen.session.state.to_dict() == plan and screen.session.state.undo.size() == 1 and screen.session.turn_history().is_empty())
	var burst_focus: Control = root.gui_get_focus_owner()
	var burst_focus_description: String = "none" if burst_focus == null else burst_focus.get_class() + "/" + String(burst_focus.name)
	# A second mouse press can focus the now-disabled apply button. It is safe
	# just like the receipt or no focus; an enabled button would accept a key.
	_check("burst_focus_is_safe", screen._area_panel._apply.disabled and (not (burst_focus is BaseButton) or (burst_focus as BaseButton).disabled))
	_check("applied_dialog_fits", root.get_visible_rect().encloses(screen._modal_content.get_global_rect()))
	_check("command_saved_exactly", SaveIO.load_game(path)["state"].to_dict() == plan)
	await _capture("area-applied")
	await _key(KEY_ESCAPE)
	await _key(KEY_Z, true)
	_check("native_undo_restores_original", screen.session.state.to_dict() == original)
	await _key(KEY_Y, true)
	_check("native_redo_restores_applied", screen.session.state.to_dict() == plan)
	await _expose(screen._unpin_area_button)
	await _click(screen._unpin_area_button)
	_check("native_unpin_is_read_only", screen._pinned_coord == BoardView.NO_COORD and screen.session.state.to_dict() == plan)

	for coord: Vector2i in [Areas.SOURCE, Areas.SEA, Areas.HALL]:
		await _open_area(coord)
		var before: Dictionary = screen.session.state.to_dict()
		_check("non_developable_%d_%d" % [coord.x, coord.y], screen._area_panel._apply.disabled and not screen._area_panel._choice.visible and _labels(screen._area_panel).contains(_tr("area.no_actions")))
		if coord == Areas.SEA:
			await _capture("area-sea")
		await _key(KEY_ENTER)
		_check("safe_return_%d_%d" % [coord.x, coord.y], screen.modal_kind.is_empty() and screen.session.state.to_dict() == before)

	await _open_area(Areas.GATE)
	await _choose_action("toggle_gate")
	var gate_before: bool = screen.session.state.get_tile(Areas.GATE).gate_open
	var labor_before: int = screen.session.state.labor
	await _click(screen._area_panel._apply)
	_check("gate_plan_uses_real_free_command", screen.session.state.get_tile(Areas.GATE).gate_open != gate_before and screen.session.state.labor == labor_before)
	await _key(KEY_ESCAPE)

	var rain: GameState = Areas.create(true)
	rain.wood = 0
	_case(rain)
	await _frames(3)
	await _open_area(Areas.LAND)
	await _choose_action("paddy")
	_check("rain_season_failure_explained", screen._area_panel._apply.disabled and _labels(screen._area_panel).contains(_tr("err.season")))
	await _choose_action("house")
	_check("resource_failure_explained", screen._area_panel._apply.disabled and _labels(screen._area_panel).contains(_tr("err.wood")))
	await _capture("area-blocked")
	await _key(KEY_ESCAPE)

	_case(Areas.create(false, "bracing_moisture_irrigation_v1", "long"))
	await _frames(3)
	await _open_area(Areas.FIELD)
	await _choose_action("irrigation_policy")
	await _choose_parameter(2)
	_check("irrigation_plan_uses_selected_policy", (screen._area_panel._plan["state"] as GameState).get_tile(Areas.FIELD).irrigation_policy == "skip")
	await _capture("area-irrigation-plan")
	await _click(screen._area_panel._apply)
	_check("irrigation_applies_to_selected_field", screen.session.state.get_tile(Areas.FIELD).irrigation_policy == "skip")
	await _key(KEY_ESCAPE)
	await _open_area(Areas.HOUSE)
	await _choose_action("brace_house")
	await _click(screen._area_panel._apply)
	_check("bracing_applies_to_selected_home", screen.session.state.get_tile(Areas.HOUSE).brace_turns == 1)
	await _key(KEY_ESCAPE)
	await _open_area(Areas.LAND)
	await _choose_action("waterwheel")
	await _choose_parameter(1)
	_check("waterwheel_preview_has_intake", (screen._area_panel._plan["state"] as GameState).get_tile(Areas.LAND).wheel_dir == 1)
	await _capture("area-waterwheel-plan")
	await _click(screen._area_panel._apply)
	_check("waterwheel_commits_selected_intake", screen.session.state.get_tile(Areas.LAND).building == C.Building.WATERWHEEL and screen.session.state.get_tile(Areas.LAND).wheel_dir == 1)
	_check("combined_save_preserves_all_ruleset_fields", SaveIO.load_game(path)["state"].to_dict() == screen.session.state.to_dict())
	_check("development_never_ends_a_turn", screen.session.state.turn == 1 and screen.session.turn_history().is_empty())
	var output: Dictionary = {
		"engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(), "language": language,
		"viewport": [1280, 720], "checks": checks, "captures": captures,
		"focus_after_burst": burst_focus_description,
		"fixture_sha256": FileAccess.get_sha256("res://tools/area_development_fixtures.gd"),
		"probe_sha256": FileAccess.get_sha256("res://tools/area_development_probe.gd"),
		"balance_sha256": FileAccess.get_sha256("res://data/balance.json"),
		"note": "Automated native mouse/keyboard at 1280x720. Separate authored initial boards use isolated checkpoint/settings paths. No gameplay state is injected after a case starts. Camera position, report scroll and keyboard focus are set to expose controls; pickable tile points are searched, with real camera rotation when needed. Option buttons use actual popup keyboard input. Legacy direct gate clicks still toggle before the area dialog opens. Mouse/key bursts are queued in one frame. School suspension and stale-controller changes are covered by headless tests, not this native probe. Screenshots label authored fixtures. This is not a generated-map playthrough, human playtest, balance validation or performance benchmark.",
	}
	var file: FileAccess = FileAccess.open(out_dir.path_join("area-development-qa-" + language + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  ", true, true))
	file.close()
	print("AREA_DEVELOPMENT_QA ", language, " ", checks.size(), " checks; failed=", failed)
	quit(1 if failed else 0)


func _open_area(coord: Vector2i) -> void:
	root.gui_release_focus()
	var at: Vector3 = Hex.to_world(coord)
	screen.camera_rig.position.x = clampf(at.x, -5.0, 5.0)
	screen.camera_rig.position.z = clampf(at.z, -5.0, 5.0)
	await _frames(3)
	var point: Vector2 = _pickable_point(coord)
	for _attempt: int in range(6):
		if point != Vector2.INF:
			break
		await _key(KEY_Q)
		await create_timer(0.35).timeout
		point = _pickable_point(coord)
	_check("pickable_area_%d_%d_%d" % [coord.x, coord.y, checks.size()], point != Vector2.INF)
	if point == Vector2.INF:
		quit(1)
		return
	await _click_at(point)
	_check("native_pin_%d_%d_%d" % [coord.x, coord.y, checks.size()], screen._pinned_coord == coord)
	await _expose(screen._area_button)
	await _click(screen._area_button)
	_check("native_area_dialog_%d_%d_%d" % [coord.x, coord.y, checks.size()], screen.modal_kind == "area_development" and screen._area_coord == coord)


func _pickable_point(coord: Vector2i) -> Vector2:
	var tile: Tile = screen.session.state.get_tile(coord)
	var origin: Vector3 = Hex.to_world(coord)
	origin.y = screen.board._surface_y(tile)
	for x: float in [0.0, -0.45, 0.45]:
		for z: float in [0.0, -0.45, 0.45]:
			var point: Vector2 = screen.camera_rig.get_camera().unproject_position(screen.board.to_global(origin + Vector3(x, 0, z)))
			if point.x < 340 or point.x > 1470 or point.y < 255 or point.y > 810:
				continue
			var picked: Tile = screen.board.pick(screen.camera_rig.get_camera(), point)
			if picked != null and picked.coord == coord:
				return point
	return Vector2.INF


func _expose(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			(ancestor as ScrollContainer).ensure_control_visible(control)
			break
		ancestor = ancestor.get_parent()
	await _frames(3)


func _choose_action(id: String) -> void:
	var panel: AreaDevelopmentPanel = screen._area_panel
	var index: int = panel._options.find(id)
	_check("action_available_" + id + "_%d" % checks.size(), index >= 0)
	var offset: int = index - panel._choice.selected
	panel._choice.grab_focus()
	await _key(KEY_SPACE)
	for _step: int in range(absi(offset)):
		await _key(KEY_DOWN if offset > 0 else KEY_UP)
	await _key(KEY_ENTER)
	_check("native_action_selected_" + id + "_%d" % checks.size(), panel._command.id == id)


func _choose_parameter(index: int) -> void:
	var control: OptionButton = screen._area_panel._parameter
	var offset: int = index - control.selected
	control.grab_focus()
	await _key(KEY_SPACE)
	for _step: int in range(absi(offset)):
		await _key(KEY_DOWN if offset > 0 else KEY_UP)
	await _key(KEY_ENTER)
	_check("native_parameter_selected_%d" % checks.size(), screen._area_panel._command.param == index)


func _check(name: String, ok: bool) -> void:
	checks[name] = ok
	if not ok:
		failed = true
		printerr("AREA DEVELOPMENT CHECK FAILED: ", name)
