extends "res://tools/irrigation_probe.gd"
## Reuses native mouse/keyboard helpers; every case starts from its own fixture.
const Fixtures = preload("res://tools/end_turn_fixtures.gd")


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
	_case(Fixtures.create())
	await _frames(3)
	var initial: Dictionary = screen.session.state.to_dict()
	await _burst(screen._end_button)
	_check("mouse_and_keyboard_burst_commits_once", screen.session.state.turn == 5 and screen.session.turn_history().size() == 1)
	_check("actual_receipt_visible", screen._turn_receipt.visible and screen._turn_receipt_label.text.contains(_tr("history.turn") % [1, _tr("season.rain"), 4]))
	_check("receipt_matches_actual_production", screen._turn_receipt_label.text.contains(_tr("turn.receipt") % [screen._turn_stamp(screen.session.turn_history()[0]), 1, 1, 0, 0]))
	_check("receipt_fits", root.get_visible_rect().encloses(screen._turn_receipt.get_global_rect()))
	await _capture("end-turn-receipt")
	var before: Dictionary = screen.session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	await _wait_for_input()
	(screen._turn_receipt.find_child("TurnReceiptHistory", true, false) as Button).grab_focus()
	await _frames(2)
	await _key(KEY_ENTER)
	_check("native_keyboard_receipt_details", screen.modal_kind == "turn_history" and screen.history_index == 0)
	await _click(screen._modal.find_child("CloseTurnHistory", true, false) as Button)
	(screen._turn_receipt.find_child("DismissTurnReceipt", true, false) as Button).grab_focus()
	await _frames(2)
	await _key(KEY_SPACE)
	_check("native_receipt_dismissal_is_read_only", not screen._turn_receipt.visible and screen.session.state.to_dict() == before and FileAccess.get_file_as_bytes(path) == bytes)
	await _wait_for_input()
	_check("end_button_ready_after_guard", not screen._end_button.disabled)
	await _click(screen._end_button)
	_check("fresh_activation_commits_next_turn", screen.session.state.turn == 6 and screen.session.turn_history().size() == 2 and screen._turn_receipt.visible)
	_check("rng_unchanged_by_ui_or_resolution", screen.session.state.to_dict()["rng_state"] == initial["rng_state"])

	_case(Fixtures.create(true))
	await _frames(3)
	before = screen.session.state.to_dict()
	bytes = FileAccess.get_file_as_bytes(path)
	await _click(screen._end_button)
	_check("native_damage_review", screen.modal_kind == "confirm_impact" and screen.session.turn_history().is_empty())
	_check("review_cancel_has_focus", root.gui_get_focus_owner() == screen._modal.find_child("CancelEndTurn", true, false))
	_check("review_fits", root.get_visible_rect().encloses(screen._modal_content.get_global_rect()))
	await _capture("end-turn-review")
	var inspect: Button = screen._modal.find_child("EndTurnRisk_-1_0", true, false) as Button
	inspect.grab_focus()
	await _frames(2)
	await _click(inspect)
	_check("native_risk_inspection_read_only", screen.modal_kind.is_empty() and screen.board._selected_coord == Fixtures.HOME and screen.session.state.to_dict() == before and FileAccess.get_file_as_bytes(path) == bytes)
	root.gui_release_focus()
	await _key(KEY_2)
	_check("construction_tool_active_before_confirmation", screen.command_mode == "fill")
	await _click(screen._end_button)
	var predicted: GameState = screen.session.state.duplicate_state()
	var predicted_report: TurnReport = GameFlow.end_turn(predicted)
	await _burst(screen._modal.find_child("ConfirmEndTurn", true, false) as Button)
	_check("confirmation_burst_commits_once", screen.session.state.to_dict() == predicted.to_dict() and screen.session.turn_history().size() == 1)
	_check("actual_damage_receipt", screen._turn_receipt_label.text.contains(_tr("turn.receipt") % [screen._turn_stamp(screen.session.turn_history()[0]), predicted_report.paddy_gains.size(), predicted_report.fish_food, 1, 1]))
	_check("actual_checkpoint_matches", SaveIO.load_game(path)["state"].to_dict() == screen.session.state.to_dict())
	await _capture("end-turn-damage-result")

	var harvest: GameState = Fixtures.create(false, 6)
	harvest.food = 2
	harvest.get_tile(Fixtures.FIELD).feature = C.Feature.NONE
	harvest.get_tile(Vector2i(1, 0)).building = C.Building.NONE
	_case(harvest)
	await _frames(3)
	before = screen.session.state.to_dict()
	root.gui_release_focus()
	await _key(KEY_SPACE)
	_check("partial_migration_gets_review", screen.modal_kind == "confirm_impact" and screen._predicted_outcome == C.Outcome.NONE and int(screen.harvest_projection["left_hunger"]) > 0)
	var scroll: ScrollContainer = screen._modal.find_child("EndTurnReviewScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 190
	await _frames(2)
	await _capture("end-turn-harvest-review")
	await _click(screen._modal.find_child("CancelEndTurn", true, false) as Button)
	_check("migration_review_cancel_is_read_only", screen.session.state.to_dict() == before)
	await _click(screen._end_button)
	await _burst(screen._modal.find_child("ConfirmEndTurn", true, false) as Button)
	_check("harvest_is_not_skipped_by_burst", screen.modal_kind == "harvest" and screen.session.state.year == 1 and screen.session.state.phase == C.Phase.HARVEST and screen.session.turn_history().size() == 1)
	_check("actual_migration_matches", int(screen.session.state.harvest_report["left_hunger"]) > 0 and screen.session.state.outcome == C.Outcome.NONE)
	await _capture("end-turn-harvest-result")
	await _wait_for_input()
	_check("harvest_keyboard_focus_restored", root.gui_get_focus_owner() == screen._modal.find_child("ContinueHarvest", true, false))
	for code: Key in [KEY_ENTER, KEY_SPACE]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = true
		Input.parse_input_event(event)
		event = event.duplicate() as InputEventKey
		event.pressed = false
		Input.parse_input_event(event)
	await _frames(2)
	_check("continue_harvest_does_not_end_next_years_first_turn", screen.session.state.year == 2 and screen.session.state.turn == 1 and screen.session.turn_history().size() == 1 and screen.modal_kind.is_empty())
	_check("year_two_checkpoint_matches", SaveIO.load_game(path)["state"].to_dict() == screen.session.state.to_dict())
	var report: Dictionary = {
		"engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(), "language": language,
		"viewport": [1280, 720], "checks": checks, "captures": captures,
		"fixture_sha256": FileAccess.get_sha256("res://tools/end_turn_fixtures.gd"),
		"balance_sha256": FileAccess.get_sha256("res://data/balance.json"),
		"note": "Automated native mouse/keyboard at 1280x720. Safe, damage and partial-migration cases use separately authored initial boards and isolated checkpoint/settings files. No gameplay state is injected after each case starts. Burst inputs are queued in one frame; real input-guard expiry is awaited. Focus and one review scroll position are set to expose controls. Screenshot status text labels authored fixtures. This is not a generated-map playthrough, human playtest, balance validation or performance benchmark.",
	}
	var file: FileAccess = FileAccess.open(out_dir.path_join("end-turn-qa-" + language + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", true, true))
	file.close()
	print("END_TURN_QA ", language, " ", checks.size(), " checks; failed=", failed)
	quit(1 if failed else 0)


func _case(state: GameState) -> void:
	var session: GameSession = GameSession.new()
	session.save_path = path
	session.state = state
	_check("fixture_checkpoint_%d" % checks.size(), session.checkpoint().is_empty())
	_show(session)


func _wait_for_input() -> void:
	while Time.get_ticks_msec() < screen._end_input_locked_until:
		await _frames(1)
	await _frames(2)


func _burst(control: Control) -> void:
	var pixels: Vector2 = control.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	Input.warp_mouse(pixels)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pixels
	motion.global_position = pixels
	motion.relative = Vector2.ONE
	Input.parse_input_event(motion)
	await process_frame
	for repetition: int in range(2):
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.position = pixels
		click.global_position = pixels
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.double_click = repetition > 0
		Input.parse_input_event(click)
		click = click.duplicate() as InputEventMouseButton
		click.pressed = false
		Input.parse_input_event(click)
	for code: Key in [KEY_ENTER, KEY_SPACE]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = true
		Input.parse_input_event(event)
		event = event.duplicate() as InputEventKey
		event.pressed = false
		Input.parse_input_event(event)
	await _frames(2)


func _capture(name: String) -> void:
	var previous: String = screen._status_label.text
	screen._status_label.text = "AUTHORED GAMEPLAY FIXTURE / " + language.to_upper()
	await super._capture(name)
	screen._status_label.text = previous


func _check(name: String, ok: bool) -> void:
	checks[name] = ok
	if not ok:
		failed = true
		printerr("END TURN CHECK FAILED: ", name)
