extends "res://tools/end_turn_probe.gd"
## Native food planning, ordinary commands and real harvest on isolated saves.


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
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_check("isolated_settings", GamePreferences.write({"language": language, "confirm_unused_labor": false, "reduced_motion": true}, settings).is_empty())
	_case(GameFlow.new_game({"seed": 42, "ruleset": "balanced_v1", "living_village": true}))
	await _frames(3)
	var before: Dictionary = screen.session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_check("summary_is_visible_and_fits", screen._food_plan_summary.is_visible_in_tree() and root.get_visible_rect().encloses(screen._food_plan_summary.get_global_rect()))
	root.gui_release_focus()
	await _key(KEY_F2)
	_check("f2_opens_food_plan", screen.modal_kind == "food_plan")
	_check("active_meal_cost", _text("FoodPlanMeal") == _tr("foodplan.meal") % [6, 8, 48])
	_check("stored_food_separate_from_fields", _text("FoodPlanNow_stored") == "72" and _text("FoodPlanNow_rice") == "0")
	_check("early_plan_is_conditional", screen._modal.find_child("FoodPlanConditional", true, false) != null and screen._modal.find_child("FoodPlanHarvest", true, false) == null)
	_check("dialog_and_choices_fit", root.get_visible_rect().encloses(screen._modal_content.get_global_rect()) and root.get_visible_rect().encloses(screen._modal.find_child("FoodPlanChoices", true, false).get_global_rect()))
	_check("view_does_not_change_rng_save_or_history", screen.session.state.to_dict() == before and FileAccess.get_file_as_bytes(path) == bytes and screen.session.turn_history().is_empty())
	await _capture("food-plan-balanced")
	var scroll: ScrollContainer = screen._modal.find_child("FoodPlanScroll", true, false) as ScrollContainer
	scroll.ensure_control_visible(screen._modal.find_child("FoodPlanStorageHelp", true, false) as Control)
	await _frames(2)
	_check("help_is_reachable_by_scrolling", scroll.get_global_rect().intersects((screen._modal.find_child("FoodPlanStorageHelp", true, false) as Control).get_global_rect()))
	await _burst(screen._modal.find_child("CloseFoodPlan", true, false) as Control)
	_check("close_burst_never_ends_turn", screen.modal_kind.is_empty() and screen.session.state.to_dict() == before and screen.session.turn_history().is_empty())
	if not screen.modal_kind.is_empty():
		_finish()
		return
	await _key(KEY_ESCAPE)
	await _click(screen._modal.find_child("PauseFoodPlan", true, false) as Control)
	_check("pause_opens_food_plan", screen.modal_kind == "food_plan")
	await _key(KEY_ESCAPE)
	_check("escape_returns_to_pause", screen.modal_kind == "pause")
	await _key(KEY_ESCAPE)
	root.gui_release_focus()
	await _key(KEY_F2)
	await _click(screen._modal.find_child("FoodPlanCommand_paddy", true, false) as Control)
	_check("choice_only_selects_tool", screen.modal_kind.is_empty() and screen.command_mode == "paddy" and screen.session.state.to_dict() == before)
	await _wait_for_input()
	var site: Dictionary = _field_site()
	_check("field_has_pickable_target", not site.is_empty())
	if site.is_empty():
		_finish()
		return
	var expected: GameState = screen.session.state.duplicate_state()
	_check("reference_command_legal", GameFlow.apply_command(expected, Command.new("paddy", site["coord"])).is_empty())
	await _click_at(site["point"])
	_check("real_planting_updates_state_and_food_budget", screen.session.state.to_dict() == expected.to_dict() and screen._food_budget["stored"] == 72 and screen._food_budget["rice"] == 0)
	await _key(KEY_Z, true)
	_check("undo_restores_food_plan", screen.session.state.to_dict() == before and screen._food_budget["stored"] == 72)
	await _key(KEY_Y, true)
	_check("redo_restores_real_planting", screen.session.state.to_dict() == expected.to_dict())
	await _key(KEY_F2)
	_check("spent_labor_disables_unaffordable_action", (screen._modal.find_child("FoodPlanCommand_paddy", true, false) as Button).disabled)
	await _key(KEY_ESCAPE)

	var harvest: GameState = Fixtures.create(false, 6)
	harvest.food = 2
	_case(harvest)
	await _frames(3)
	before = screen.session.state.to_dict()
	var exact: Dictionary = screen.harvest_prediction.duplicate(true)
	root.gui_release_focus()
	await _key(KEY_F2)
	_check("last_turn_shows_exact_harvest", screen._modal.find_child("FoodPlanHarvest", true, false) != null and screen._modal.find_child("FoodPlanConditional", true, false) == null)
	_check("shortfall_and_hunger_match_actual_forecast", _text("FoodPlanNext_gap") == "1" and int(exact["left_hunger"]) == 1)
	await _capture("food-plan-harvest")
	await _key(KEY_ESCAPE)
	await _wait_for_input()
	await _click(screen._end_button)
	_check("harvest_risk_still_requires_review", screen.modal_kind == "confirm_impact")
	await _click(screen._modal.find_child("ConfirmEndTurn", true, false) as Control)
	_check("actual_harvest_equals_food_plan", screen.session.state.harvest_report == exact and screen.session.turn_history().size() == 1)
	_check("resolved_board_never_counts_rice_twice", not screen._food_plan_summary.visible and screen._food_plan_button.disabled)
	await _key(KEY_F2)
	_check("f2_cannot_skip_harvest", screen.modal_kind == "harvest" and screen.session.state.phase == C.Phase.HARVEST)

	var flooded: GameState = Fixtures.create(true, 6)
	flooded.get_tile(Fixtures.HALL).elevation = 0
	flooded.get_tile(Fixtures.HALL).water = 1.5
	flooded.get_tile(Fixtures.FIELD).paddy_yield = 20
	_case(flooded)
	await _frames(3)
	before = screen.session.state.to_dict()
	bytes = FileAccess.get_file_as_bytes(path)
	root.gui_release_focus()
	await _key(KEY_F2)
	_check("hall_loss_has_no_harvest_promise", screen._modal.find_child("FoodPlanWarning", true, false) != null and screen._modal.find_child("FoodPlanHarvest", true, false) == null and _text("FoodPlanNext_rice") == "—")
	_check("rain_disables_rice_tool_with_reason", (screen._modal.find_child("FoodPlanCommand_paddy", true, false) as Button).disabled and (screen._modal.find_child("FoodPlanCommand_paddy", true, false) as Button).tooltip_text.contains(_tr("err.season")))
	await _capture("food-plan-hall-loss")
	await _key(KEY_ESCAPE)
	_check("warning_is_read_only", screen.session.state.to_dict() == before and FileAccess.get_file_as_bytes(path) == bytes)
	var lesson: RiverSchoolRun = RiverSchoolRun.new()
	_check("school_starts", lesson.start("river_school_03"))
	root.remove_child(screen)
	screen.queue_free()
	var school: RiverSchoolScreen = RiverSchoolScreen.new()
	school.lesson = lesson
	school.preferences_path = settings
	screen = school
	root.add_child(screen)
	await _frames(3)
	before = lesson.session.state.to_dict()
	await _click(screen._food_plan_button)
	_check("school_shares_food_plan", screen.modal_kind == "food_plan")
	await _key(KEY_ESCAPE)
	_check("school_and_normal_save_unchanged", lesson.session.state.to_dict() == before and FileAccess.get_file_as_bytes(path) == bytes)
	_finish()


func _capture(name: String) -> void:
	var previous: String = screen._status_label.text
	var origin: String = "GENERATED BALANCED SEED 42" if name == "food-plan-balanced" else "AUTHORED GAMEPLAY FIXTURE"
	screen._status_label.text = origin + " / " + language.to_upper()
	await _frames(2)
	var file: String = name + "-" + language + ".png"
	_check(name + "_capture", root.get_texture().get_image().save_png(out_dir.path_join(file)) == OK)
	captures.append(file)
	screen._status_label.text = previous


func _text(node_name: String) -> String:
	var label: Label = screen._modal.find_child(node_name, true, false) as Label
	return "" if label == null else label.text


func _field_site() -> Dictionary:
	for coord: Vector2i in screen.valid_targets("paddy"):
		var tile: Tile = screen.session.state.get_tile(coord)
		var world: Vector3 = Hex.to_world(coord)
		world.y = screen.board._surface_y(tile)
		var point: Vector2 = screen.camera_rig.get_camera().unproject_position(screen.board.to_global(world))
		if point.x < 100 or point.x > 1400 or point.y < 310 or point.y > 800:
			continue
		var picked: Tile = screen.board.pick(screen.camera_rig.get_camera(), point)
		if picked != null and picked.coord == coord:
			return {"coord": coord, "point": point}
	return {}


func _finish() -> void:
	var report: Dictionary = {
		"engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(), "language": language,
		"viewport": [1280, 720], "checks": checks, "captures": captures,
		"probe_sha256": FileAccess.get_sha256("res://tools/food_plan_probe.gd"),
		"balance_sha256": FileAccess.get_sha256("res://data/balance.json"),
		"note": "Automated native mouse/keyboard. The first case uses a generated balanced_v1 seed 42 and a real planting command with Undo/Redo. Harvest and hall-loss cases start from separately authored initial boards; no gameplay state is injected during a case. School uses its real lesson board. Isolated checkpoint/settings paths, native key/click bursts, actual harvest compared with the plan, and state/RNG/save preservation checked. This is UI verification, not human playtesting or new balance evidence.",
	}
	var file: FileAccess = FileAccess.open(out_dir.path_join("food-plan-qa-" + language + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", true, true))
	file.close()
	print("FOOD_PLAN_QA ", language, " ", checks.size(), " checks; failed=", failed)
	quit(1 if failed else 0)


func _check(name: String, ok: bool) -> void:
	checks[name] = ok
	if not ok:
		failed = true
		printerr("FOOD PLAN CHECK FAILED: ", name)
