extends "res://tools/resource_feedback_probe.gd"
## Ledger input uses real turns and ordinary player commands on authored boards.


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

	var initial: GameState = Fixtures.create()
	initial.labor = 2
	var before: Dictionary = ResourceLedger.capture(initial)
	var reference: GameState = initial.duplicate_state()
	GameFlow.end_turn(reference)
	_case(initial)
	await _frames(3)
	await _burst(screen._end_button)
	_check("one_commit_one_ledger", screen.session.state.to_dict() == reference.to_dict() and screen.session.turn_history().size() == 1)
	var ledger: Dictionary = screen.session.turn_history()[0]["resources"]
	_check("actual_before_after_captured", ledger["before"] == before and ledger["after"] == ResourceLedger.capture(reference))
	_check("effect_matches_ledger_net", screen._resource_feedback.last_changes == ResourceFeedback.difference(ledger["before"], ledger["after"]))
	_check("net_summary_visible_and_fits", screen._turn_receipt_resources.visible and screen._turn_receipt_resources.text.contains(_tr("resource.food") + " +1") and root.get_visible_rect().encloses(screen._turn_receipt.get_global_rect()))
	await _wait_for_input()
	(screen._turn_receipt.find_child("TurnReceiptHistory", true, false) as Button).grab_focus()
	await _key(KEY_ENTER)
	_check("native_keyboard_opens_ledger", screen.modal_kind == "turn_history" and _panel() != null)
	_check("fish_cause_is_actual", _cause_text("food", "fish") == _tr("ledger.cause") % [_tr("ledger.reason.fish"), 1])
	_check("labor_before_after_is_actual", _total_text("labor") == _tr("ledger.total") % [_tr("resource.labor"), 2, 6, 4])
	_check("dialog_fits", root.get_visible_rect().encloses(screen._modal_content.get_global_rect()))
	_balanced(ledger, "ordinary")
	await _capture("ledger-gains")
	await _click(screen._modal.find_child("CloseTurnHistory", true, false) as Button)
	_check("history_closed_before_next_plan", screen.modal_kind.is_empty())
	await _end_from_input()
	await _wait_for_input()
	root.gui_release_focus()
	await _click(screen._command_buttons["house"])
	var site: Dictionary = _house_site()
	_check("house_tool_has_pickable_target", screen.command_mode == "house" and not site.is_empty())
	if site.is_empty():
		quit(1)
		return
	await _click_at(site["point"])
	_check("real_command_changes_current_resources", screen.session.state.get_tile(site["coord"]).building == C.Building.HOUSE and screen.session.state.wood == 0)
	var committed: Dictionary = screen.session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var undo: Array[Dictionary] = screen.session.state.undo.snapshots()
	await _key(KEY_H)
	await _click(screen._history_previous)
	_check("old_food_totals_ignore_current_board", screen.history_index == 0 and _total_text("food") == _tr("ledger.total") % [_tr("resource.food"), 50, 51, 1])
	_check("old_wood_totals_ignore_current_spending", _total_text("wood") == _tr("ledger.total") % [_tr("resource.wood"), 2, 2, 0])
	await _key(KEY_ESCAPE)
	_check("ledger_read_preserves_plan_rng_undo_checkpoint", screen.session.state.to_dict() == committed and screen.session.state.undo.snapshots() == undo and FileAccess.get_file_as_bytes(path) == bytes)

	initial = Fixtures.create(true, 6)
	initial.food = 2
	_case(initial)
	await _frames(3)
	await _end_from_input()
	ledger = screen.session.turn_history()[0]["resources"]
	committed = screen.session.state.to_dict()
	bytes = FileAccess.get_file_as_bytes(path)
	await _key(KEY_H)
	_check("harvest_net_food", _total_text("food") == _tr("ledger.total") % [_tr("resource.food"), 2, 0, -2])
	_check("harvest_gross_fish_and_feeding", _cause_text("food", "fish") == _tr("ledger.cause") % [_tr("ledger.reason.fish"), 1] and _cause_text("food", "feeding") == _tr("ledger.cause") % [_tr("ledger.reason.feeding"), -3])
	_check("hunger_and_home_loss_are_distinct", _cause_text("people", "hunger") == _tr("ledger.cause") % [_tr("ledger.reason.hunger"), -3] and _cause_text("housing", "homes_lost") == _tr("ledger.cause") % [_tr("ledger.reason.homes_lost"), -2])
	_balanced(ledger, "loss")
	await _capture("ledger-harvest")
	await _key(KEY_ESCAPE)
	_check("return_to_harvest_does_not_resolve_again", screen.modal_kind == "harvest" and screen.session.state.to_dict() == committed and FileAccess.get_file_as_bytes(path) == bytes)
	await _wait_for_input()
	await _click(screen._modal.find_child("ContinueHarvest", true, false) as Button)
	_check("new_year_preserves_recorded_ledger", screen.session.state.year == 2 and screen.session.turn_history()[0]["resources"] == ledger)
	await _end_from_input()
	var next: Dictionary = screen.session.turn_history()[1]
	_check("new_year_turn_has_no_stale_harvest_causes", next["year"] == 2 and next["harvest"].is_empty() and _amount(next["resources"], "food", "feeding") == 0 and _amount(next["resources"], "food", "rice") == 0)
	_balanced(next["resources"], "new_year")

	initial = Fixtures.create(false, 6)
	initial.get_tile(Vector2i(0, 1)).building = C.Building.HOUSE
	initial.year_mods.assign([{"key": "food_per_growth", "op": "set", "value": 2}])
	initial.recompute_mods()
	_case(initial)
	await _frames(3)
	await _end_from_input()
	var entry: Dictionary = screen.session.turn_history()[0]
	ledger = entry["resources"]
	_check("birth_food_is_recorded_from_actual_harvest", _amount(ledger, "food", "birth_food") == -int(entry["harvest"]["born"]) * 2 and int(entry["harvest"]["born"]) > 0)
	_check("spoilage_is_recorded_from_actual_harvest", _amount(ledger, "food", "spoilage") == -int(entry["harvest"]["spoiled"]) and int(entry["harvest"]["spoiled"]) > 0)
	_balanced(ledger, "growth")
	await _key(KEY_H)
	var birth_food: Control = _panel().find_child("LedgerCause_food_birth_food", true, false) as Control
	screen._history_scroll.ensure_control_visible(birth_food)
	await _frames(3)
	_check("growth_food_cause_reachable", birth_food.is_visible_in_tree() and screen._history_scroll.get_global_rect().intersects(birth_food.get_global_rect()))
	await _capture("ledger-growth")

	initial = Fixtures.create(true, 6)
	initial.food = 0
	_case(initial)
	await _frames(3)
	await _end_from_input()
	_check("zero_net_food_has_no_effect_badge", not screen._resource_feedback.last_changes.has("food"))
	await _key(KEY_H)
	_check("zero_net_food_keeps_both_causes", _total_text("food") == _tr("ledger.total") % [_tr("resource.food"), 0, 0, 0] and _cause_text("food", "fish") == _tr("ledger.cause") % [_tr("ledger.reason.fish"), 1] and _cause_text("food", "feeding") == _tr("ledger.cause") % [_tr("ledger.reason.feeding"), -1])
	await _capture("ledger-zero-net")
	var restored: GameSession = GameSession.new()
	restored.save_path = path
	_check("load_preserves_state_and_clears_session_ledger", restored.load_game().is_empty() and restored.state.to_dict() == screen.session.state.to_dict() and restored.turn_history().is_empty())

	var normal_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	_school_case()
	await _frames(3)
	await _end_from_input()
	await _key(KEY_H)
	_check("school_result_shares_ledger", _panel() != null and _total_text("food") != "")
	await _click(screen._modal.find_child("CloseTurnHistory", true, false) as Button)
	_check("school_result_restored", screen.modal_kind == "school_result")
	if screen.modal_kind != "school_result":
		printerr("School history returned to: ", screen.modal_kind)
		quit(1)
		return
	await _wait_for_input()
	await _click(screen._modal.find_child("SchoolRetry", true, false) as Button)
	_check("school_retry_clears_ledger", screen.session.turn_history().is_empty() and screen._turn_receipt_resources.text.is_empty())
	_check("school_keeps_normal_checkpoint", FileAccess.get_file_as_bytes(path) == normal_bytes)

	var output: Dictionary = {
		"engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(), "language": language,
		"viewport": [1280, 720], "checks": checks, "captures": captures,
		"fixture_sha256": FileAccess.get_sha256("res://tools/end_turn_fixtures.gd"),
		"probe_sha256": FileAccess.get_sha256("res://tools/resource_ledger_probe.gd"),
		"balance_sha256": FileAccess.get_sha256("res://data/balance.json"),
		"note": "Automated native mouse/keyboard at 1280x720. Safe, loss, growth, zero-net and school UI cases use authored initial boards and isolated checkpoint/settings paths. A growth-price modifier is installed before its case starts. Later spending uses a real toolbar house command on a pickable valid target. No gameplay state is injected during a case. UI focus and one scroll position are set to expose controls. Screenshots label authored fixtures. Resource equations are checked for all five metrics. This is not a generated-map playthrough, human playtest, balance validation or performance benchmark.",
	}
	var file: FileAccess = FileAccess.open(out_dir.path_join("resource-ledger-qa-" + language + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "  ", true, true))
	file.close()
	print("RESOURCE_LEDGER_QA ", language, " ", checks.size(), " checks; failed=", failed)
	quit(1 if failed else 0)


func _end_from_input() -> void:
	await _wait_for_input()
	await _click(screen._end_button)
	if screen.modal_kind in GameScreen.END_TURN_CONFIRMATIONS:
		await _click(screen._modal.find_child("ConfirmEndTurn", true, false) as Button)


func _house_site() -> Dictionary:
	for coord: Vector2i in screen.valid_targets("house"):
		var tile: Tile = screen.session.state.get_tile(coord)
		var at: Vector3 = Hex.to_world(coord)
		at.y = screen.board._surface_y(tile)
		var point: Vector2 = screen.camera_rig.get_camera().unproject_position(screen.board.to_global(at))
		if point.x < 360 or point.x > 1400 or point.y < 270 or point.y > 800:
			continue
		var picked: Tile = screen.board.pick(screen.camera_rig.get_camera(), point)
		if picked != null and picked.coord == coord:
			return {"coord": coord, "point": point}
	return {}


func _panel() -> ResourceLedgerPanel:
	return screen._history_details.find_child("TurnResourceLedger", true, false) as ResourceLedgerPanel


func _total_text(key: String) -> String:
	var label: Label = _panel().find_child("LedgerTotal_" + key, true, false) as Label
	return "" if label == null else label.text


func _cause_text(key: String, reason: String) -> String:
	var label: Label = _panel().find_child("LedgerCause_" + key + "_" + reason, true, false) as Label
	return "" if label == null else label.text


func _amount(ledger: Dictionary, key: String, reason: String) -> int:
	for cause: Dictionary in ledger["causes"]:
		if cause["resource"] == key and cause["reason"] == reason:
			return int(cause["amount"])
	return 0


func _balanced(ledger: Dictionary, prefix: String) -> void:
	for key: String in ResourceLedger.KEYS:
		var sum: int = int(ledger["before"][key])
		for cause: Dictionary in ledger["causes"]:
			if cause["resource"] == key:
				sum += int(cause["amount"])
		_check(prefix + "_balanced_" + key, sum == int(ledger["after"][key]))


func _check(name: String, ok: bool) -> void:
	checks[name] = ok
	if not ok:
		failed = true
		printerr("RESOURCE LEDGER CHECK FAILED: ", name)
