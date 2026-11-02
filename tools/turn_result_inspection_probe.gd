extends "res://tools/end_turn_probe.gd"
## Native UI checks. All authored state is installed before each case begins.


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

	_case(Fixtures.create(true))
	await _frames(3)
	await _click(screen._end_button)
	await _click(screen._modal.find_child("ConfirmEndTurn", true, false) as Button)
	await _wait_for_input()
	await _key(KEY_2)
	var site: Vector2i = Vector2i.ZERO
	var height: int = screen.session.state.get_tile(site).elevation
	await _tile(site)
	_check("real_planning_command_before_inspection", screen.session.state.get_tile(site).elevation == height + 1)
	var before: Dictionary = screen.session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var history: Array[Dictionary] = screen.session.turn_history()
	await _key(KEY_H)
	var report: Control = screen._modal
	await _expose_location(Fixtures.HOME)
	_check("report_locations_fit", root.get_visible_rect().encloses(screen._modal_content.get_global_rect()))
	await _capture("turn-locations-report")
	var origin: Button = _location_button(Fixtures.HOME)
	await _click(origin)
	var offset: int = screen._history_scroll.scroll_vertical
	_check("native_damage_location", screen.modal_kind == "history_map" and screen.board._selected_coord == Fixtures.HOME)
	_check("inspection_panel_fits", root.get_visible_rect().encloses(screen._history_map_panel.get_global_rect()))
	_check("historical_damage_is_recorded_fact", _labels(screen._history_map_panel).contains(_tr("feedback.destroyed") % _tr("building.house")))
	_check("current_board_disclaimer_visible", _labels(screen._history_map_panel).contains(_tr("history.map_current")))
	_check("next_forecast_temporarily_hidden", not screen.preview_enabled and screen.board._prediction.is_empty())
	var current: Tile = screen.session.state.get_tile(Fixtures.HOME)
	_check("current_site_in_inspector", screen._tile_details.text.contains(_tr("tile.details") % [current.elevation, current.water, _tr("level.%d" % screen.session.state.level_of(current))]))
	_check("occluded_location_has_inspection_overlay", screen.board._result_marker.visible and (screen.board._result_marker.material_override as StandardMaterial3D).no_depth_test)
	await _capture("turn-location-damage")
	await _key(KEY_1)
	await _key(KEY_Z, true)
	await _key(KEY_Y, true)
	await _key(KEY_TAB)
	await _key(KEY_H)
	await _tile(Fixtures.HOME)
	_check("world_click_and_shortcuts_are_read_only", screen.session.state.to_dict() == before and screen.command_mode == "fill" and screen.session.turn_history() == history and FileAccess.get_file_as_bytes(path) == bytes)
	await _click(screen._history_map_panel.find_child("NextHistoryLocation", true, false) as Button)
	_check("native_dead_field_location", screen.board._selected_coord == Fixtures.FIELD and _labels(screen._history_map_panel).contains(_tr("feedback.rice_lost")))
	await _click(screen._history_map_panel.find_child("NextHistoryLocation", true, false) as Button)
	_check("native_fish_location", screen.board._selected_coord == Vector2i(1, 0) and _labels(screen._history_map_panel).contains(_tr("history.map_fish") % 1))
	_check("last_location_has_no_next", (screen._history_map_panel.find_child("NextHistoryLocation", true, false) as Button).disabled)
	await _capture("turn-location-fish")
	await _key(KEY_ESCAPE)
	_check("escape_restores_exact_report_and_focus", screen.modal_kind == "turn_history" and screen._modal == report and screen.history_index == 0 and screen._history_scroll.scroll_vertical == offset and root.gui_get_focus_owner() == origin)
	_check("preview_and_tool_restored", screen.preview_enabled and screen.command_mode == "fill")
	_check("inspection_overlay_cleared_on_return", not screen.board._result_marker.visible)
	await _key(KEY_ESCAPE)
	_check("inspection_did_not_change_save_or_history", screen.session.state.to_dict() == before and FileAccess.get_file_as_bytes(path) == bytes and screen.session.turn_history() == history)

	_case(Fixtures.create())
	await _frames(3)
	await _click(screen._end_button)
	await _wait_for_input()
	await _key(KEY_H)
	await _expose_location(Fixtures.FIELD)
	_location_button(Fixtures.FIELD).grab_focus()
	await _key(KEY_ENTER)
	_check("native_keyboard_location_activation", screen.modal_kind == "history_map" and screen.board._selected_coord == Fixtures.FIELD)
	_check("rice_is_yield_waiting_for_harvest", _labels(screen._history_map_panel).contains(_tr("feedback.rice_gain")) and _labels(screen._history_map_panel).contains(_tr("history.yield_note")))
	await _capture("turn-location-rice")
	var safe: Dictionary = screen.session.state.to_dict()
	await _key(KEY_ENTER)
	_check("keyboard_return_does_not_end_turn", screen.modal_kind == "turn_history" and screen.session.state.to_dict() == safe and screen.session.turn_history().size() == 1)
	await _key(KEY_ESCAPE)
	await _click(screen._end_button)
	await _wait_for_input()
	await _key(KEY_H)
	await _click(screen._history_previous)
	await _expose_location(Fixtures.FIELD)
	await _click(_location_button(Fixtures.FIELD))
	_check("older_report_keeps_original_stamp", screen.history_index == 0 and screen.session.state.turn == 6 and _labels(screen._history_map_panel).contains(_tr("history.map_stamp") % (_tr("history.turn") % [1, _tr("season.rain"), 4])))
	await _click(screen._history_map_panel.find_child("ReturnToTurnReport", true, false) as Button)
	_check("native_back_button_restores_older_report", screen.modal_kind == "turn_history" and screen.history_index == 0)

	_case(Fixtures.create(false, 6))
	await _frames(3)
	await _click(screen._end_button)
	await _wait_for_input()
	var harvest: Dictionary = screen.session.state.to_dict()
	bytes = FileAccess.get_file_as_bytes(path)
	await _key(KEY_H)
	await _expose_location(Fixtures.FIELD)
	await _click(_location_button(Fixtures.FIELD))
	_check("harvest_location_is_read_only", screen.modal_kind == "history_map" and screen.session.state.to_dict() == harvest)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check("harvest_restored_without_repeating_it", screen.modal_kind == "harvest" and screen.session.state.to_dict() == harvest and FileAccess.get_file_as_bytes(path) == bytes)
	await _click(screen._modal.find_child("ContinueHarvest", true, false) as Button)
	_check("harvest_continues_once_after_inspection", screen.session.state.year == 2 and screen.session.state.turn == 1 and screen.session.turn_history().size() == 1)

	_school_case(4)
	await _frames(3)
	await _click(screen._end_button)
	await _wait_for_input()
	await _key(KEY_H)
	await _expose_location(Fixtures.FIELD)
	await _click(_location_button(Fixtures.FIELD))
	_check("school_shares_native_inspection", screen.modal_kind == "history_map" and screen.board._selected_coord == Fixtures.FIELD)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _click(screen.hud.find_child("Pause", true, false) as Button)
	await _click(screen._modal.find_child("SchoolPauseRetry", true, false) as Button)
	_check("school_retry_clears_history_and_inspection", screen.modal_kind.is_empty() and screen.session.turn_history().is_empty() and screen._history_map_panel == null and screen._history_map_context.is_empty() and screen.preview_enabled)

	_school_case(6)
	await _frames(3)
	await _click(screen._end_button)
	await _wait_for_input()
	var result: Dictionary = (screen as RiverSchoolScreen).lesson.result()
	await _key(KEY_H)
	await _expose_location(Fixtures.FIELD)
	await _click(_location_button(Fixtures.FIELD))
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check("completed_school_result_restored", screen.modal_kind == "school_result" and (screen as RiverSchoolScreen).lesson.result() == result)

	var output: Dictionary = {
		"engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(), "language": language,
		"viewport": [1280, 720], "checks": checks, "captures": captures,
		"fixture_sha256": FileAccess.get_sha256("res://tools/end_turn_fixtures.gd"),
		"probe_sha256": FileAccess.get_sha256("res://tools/turn_result_inspection_probe.gd"),
		"balance_sha256": FileAccess.get_sha256("res://data/balance.json"),
		"note": "Automated native mouse/keyboard at 1280x720. Separate authored damage, production, harvest and school UI boards use isolated checkpoint/settings paths. All fixture state is installed before each case starts; subsequent site changes use real player commands. Location controls are exposed by setting report scroll and keyboard focus. No gameplay state is injected during a case. Screenshots label authored fixtures. This is not a generated-map playthrough, human playtest, balance validation or performance benchmark. School exit suspension is covered by headless tests, not this native probe.",
	}
	var file: FileAccess = FileAccess.open(out_dir.path_join("turn-result-inspection-qa-" + language + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  ", true, true))
	file.close()
	print("TURN_RESULT_INSPECTION_QA ", language, " ", checks.size(), " checks; failed=", failed)
	quit(1 if failed else 0)


func _location_button(coord: Vector2i) -> Button:
	return screen._modal.find_child("HistoryLocation_%d_%d" % [coord.x, coord.y], true, false) as Button


func _expose_location(coord: Vector2i) -> void:
	screen._history_scroll.ensure_control_visible(_location_button(coord))
	await _frames(3)


func _school_case(turn: int) -> void:
	if is_instance_valid(screen):
		root.remove_child(screen)
		screen.queue_free()
	var lesson: RiverSchoolRun = RiverSchoolRun.new()
	_check("school_fixture_%d" % checks.size(), lesson.start("river_school_01"))
	lesson.session.state = Fixtures.create(false, turn)
	lesson.session.state.is_tutorial = true
	var school: RiverSchoolScreen = RiverSchoolScreen.new()
	school.lesson = lesson
	school.session = lesson.session
	school.preferences_path = settings
	screen = school
	root.add_child(screen)
	screen.confirm_unused_labor = false


func _check(name: String, ok: bool) -> void:
	checks[name] = ok
	if not ok:
		failed = true
		printerr("TURN RESULT INSPECTION CHECK FAILED: ", name)
