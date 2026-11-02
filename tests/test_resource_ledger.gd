extends TestCase
const F = preload("res://tools/end_turn_fixtures.gd")
const DIRECTORY: String = "user://tests/resource_ledger"
const PATH: String = DIRECTORY + "/checkpoint.json"
const SETTINGS: String = DIRECTORY + "/settings.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	Localization.setup("en")


func _session(state: GameState = null) -> GameSession:
	var session: GameSession = GameSession.new()
	session.state = F.create() if state == null else state
	session.save_path = PATH
	assert_eq(session.checkpoint(), "")
	return session


func _screen(session: GameSession) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	return screen


func _amount(ledger: Dictionary, resource: String, reason: String) -> int:
	for cause: Dictionary in ledger["causes"]:
		if cause["resource"] == resource and cause["reason"] == reason:
			return int(cause["amount"])
	return 0


func _balanced(ledger: Dictionary) -> void:
	for key: String in ResourceLedger.KEYS:
		var sum: int = int(ledger["before"][key])
		for cause: Dictionary in ledger["causes"]:
			if cause["resource"] == key:
				sum += int(cause["amount"])
		assert_eq(sum, int(ledger["after"][key]), key)


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func test_ordinary_turn_records_actual_fish_and_labor_without_inventing_rice_food() -> void:
	var state: GameState = F.create()
	state.labor = 2
	var session: GameSession = _session(state)
	var before: Dictionary = ResourceLedger.capture(state)
	session.advance_turn()
	var ledger: Dictionary = session.turn_history()[0]["resources"]
	assert_eq(ledger["before"], before)
	assert_eq(ledger["after"], ResourceLedger.capture(state))
	assert_eq(_amount(ledger, "food", "fish"), 1)
	assert_eq(_amount(ledger, "food", "rice"), 0)
	assert_eq(_amount(ledger, "labor", "next_turn"), 4)
	assert_eq(ledger["before"]["wood"], ledger["after"]["wood"])
	_balanced(ledger)


func test_harvest_reconciles_food_consumption_hunger_and_lost_housing_independently() -> void:
	var state: GameState = F.create(true, 6)
	state.food = 2
	var session: GameSession = _session(state)
	session.advance_turn()
	var ledger: Dictionary = session.turn_history()[0]["resources"]
	assert_eq(_amount(ledger, "food", "fish"), 1)
	assert_eq(_amount(ledger, "food", "feeding"), -3)
	assert_eq(_amount(ledger, "people", "hunger"), -3)
	assert_eq(_amount(ledger, "people", "housing"), 0)
	assert_eq(_amount(ledger, "housing", "homes_lost"), -2)
	assert_eq(_amount(ledger, "labor", "next_turn"), 0)
	_balanced(ledger)


func test_growth_food_and_spoilage_reconcile_with_free_and_paid_births() -> void:
	for cost: int in [0, 2]:
		var state: GameState = F.create(false, 6)
		state.get_tile(Vector2i(0, 1)).building = C.Building.HOUSE
		state.year_mods.assign([{"key": "food_per_growth", "op": "set", "value": cost}])
		state.recompute_mods()
		var session: GameSession = _session(state)
		session.advance_turn()
		var entry: Dictionary = session.turn_history()[0]
		var ledger: Dictionary = entry["resources"]
		assert_true(int(entry["harvest"]["born"]) > 0)
		assert_eq(_amount(ledger, "food", "birth_food"), -int(entry["harvest"]["born"]) * cost)
		assert_eq(_amount(ledger, "people", "births"), int(entry["harvest"]["born"]))
		assert_eq(_amount(ledger, "food", "spoilage"), -int(entry["harvest"]["spoiled"]))
		assert_eq(_amount(ledger, "food", "rice"), int(entry["harvest"]["paddy_food"]))
		_balanced(ledger)


func test_zero_net_food_still_records_the_gain_and_consumption_that_cancel() -> void:
	var state: GameState = F.create(true, 6)
	state.food = 0
	var session: GameSession = _session(state)
	session.advance_turn()
	var ledger: Dictionary = session.turn_history()[0]["resources"]
	assert_eq(ledger["before"]["food"], 0)
	assert_eq(ledger["after"]["food"], 0)
	assert_eq(_amount(ledger, "food", "fish"), 1)
	assert_eq(_amount(ledger, "food", "feeding"), -1)
	_balanced(ledger)


func test_hall_loss_does_not_record_production_or_harvest_that_never_happened() -> void:
	var state: GameState = F.create(true, 6)
	state.get_tile(F.HALL).elevation = 0
	state.get_tile(F.HALL).water = 0.8
	var session: GameSession = _session(state)
	session.advance_turn()
	assert_eq(state.outcome, C.Outcome.LOSE_HALL)
	var entry: Dictionary = session.turn_history()[0]
	assert_true(entry["harvest"].is_empty())
	for cause: Dictionary in entry["resources"]["causes"]:
		assert_true(cause["resource"] != "food")
	_balanced(entry["resources"])


func test_ordinary_turn_after_new_year_does_not_reuse_the_previous_harvest() -> void:
	var state: GameState = F.create(false, 6)
	var session: GameSession = _session(state)
	session.advance_turn()
	assert_true(not state.harvest_report.is_empty())
	assert_true(session.continue_year())
	var before: Dictionary = ResourceLedger.capture(state)
	session.advance_turn()
	var entry: Dictionary = session.turn_history()[1]
	assert_eq(entry["year"], 2)
	assert_true(entry["harvest"].is_empty())
	assert_eq(entry["resources"]["before"], before)
	assert_eq(_amount(entry["resources"], "food", "rice"), 0)
	assert_eq(_amount(entry["resources"], "food", "feeding"), 0)
	_balanced(entry["resources"])


func test_nested_ledgers_are_detached_from_callers_state_rng_and_checkpoints() -> void:
	var session: GameSession = _session()
	session.advance_turn()
	var recorded: Array[Dictionary] = session.turn_history()
	var before: Dictionary = session.state.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var changed: Array[Dictionary] = session.turn_history()
	changed[0]["resources"]["before"]["food"] = 999
	changed[0]["resources"]["causes"][0]["amount"] = 999
	changed[0]["resources"]["causes"].clear()
	assert_eq(session.turn_history(), recorded)
	assert_eq(session.state.to_dict(), before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)


func test_failed_checkpoint_records_one_actual_ledger_and_noop_cannot_duplicate_it() -> void:
	var session: GameSession = _session(F.create(false, 6))
	var blocked: String = ProjectSettings.globalize_path(DIRECTORY + "/blocked")
	DirAccess.make_dir_recursive_absolute(blocked)
	session.save_path = DIRECTORY + "/blocked"
	assert_true(session.advance_turn() != null)
	assert_eq(session.last_save_error, "msg.save_failed")
	var actual: Array[Dictionary] = session.turn_history()
	assert_eq(actual.size(), 1)
	_balanced(actual[0]["resources"])
	assert_eq(session.advance_turn(), null)
	assert_eq(session.turn_history(), actual)


func test_checkpoints_and_load_do_not_persist_or_fabricate_the_session_ledger() -> void:
	var session: GameSession = _session(F.create(false, 6))
	session.advance_turn()
	assert_true(session.turn_history()[0].has("resources"))
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_true(not envelope["state"].has("resources"))
	assert_true(not JSON.stringify(envelope).contains('"causes"'))
	var loaded: GameSession = GameSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_game(), "")
	assert_eq(loaded.state.to_dict(), session.state.to_dict())
	assert_true(loaded.turn_history().is_empty())


func test_panel_is_localized_and_shows_exact_causes_and_signed_summary() -> void:
	for locale: String in ["en", "th"]:
		Localization.setup(locale)
		var state: GameState = F.create(true, 6)
		state.food = 2
		var screen: GameScreen = _screen(_session(state))
		screen._finish_turn()
		assert_true(screen._turn_receipt_resources.text.contains(_tr("resource.food") + " -2"))
		screen.open_turn_history()
		var panel: ResourceLedgerPanel = screen._history_details.find_child("TurnResourceLedger", true, false) as ResourceLedgerPanel
		var feeding: Label = panel.find_child("LedgerCause_food_feeding", true, false) as Label
		assert_eq(feeding.text, _tr("ledger.cause") % [_tr("ledger.reason.feeding"), -3])
		assert_eq(feeding.get_theme_color("font_color"), Color(ThemeBuilder.palette()["danger"]))
		var food: Label = panel.find_child("LedgerTotal_food", true, false) as Label
		assert_eq(food.text, _tr("ledger.total") % [_tr("resource.food"), 2, 0, -2])
		assert_eq(screen.get_viewport().gui_get_focus_owner().name, &"CloseTurnHistory")
		screen.free()


func test_historical_panel_does_not_read_current_resources_or_mutate_the_plan() -> void:
	var state: GameState = F.create()
	state.labor = 2
	var screen: GameScreen = _screen(_session(state))
	screen._finish_turn()
	screen._finish_turn()
	assert_eq(screen.session.apply(Command.new("house", Vector2i.ZERO)), "")
	screen.refresh_state()
	var before: Dictionary = screen.session.state.to_dict()
	var undo: Array[Dictionary] = screen.session.state.undo.snapshots()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen.open_turn_history()
	screen._change_history(-1)
	var food: Label = screen._history_details.find_child("LedgerTotal_food", true, false) as Label
	assert_eq(food.text, _tr("ledger.total") % [_tr("resource.food"), 50, 51, 1])
	var wood: Label = screen._history_details.find_child("LedgerTotal_wood", true, false) as Label
	assert_eq(wood.text, _tr("ledger.total") % [_tr("resource.wood"), 2, 2, 0])
	assert_eq(screen.session.state.wood, 0)
	screen.close_turn_history()
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.session.state.undo.snapshots(), undo)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen.free()


func test_legacy_missing_data_is_explicit_and_zero_net_still_has_visible_causes() -> void:
	var panel: ResourceLedgerPanel = ResourceLedgerPanel.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	panel.configure({})
	assert_eq((panel.get_child(1) as Label).text, _tr("ledger.unavailable"))
	assert_true(panel.find_child("LedgerTotal_food", true, false) == null)
	var state: GameState = F.create(true, 6)
	state.food = 0
	var session: GameSession = _session(state)
	session.advance_turn()
	panel.configure(session.turn_history()[0]["resources"])
	assert_eq((panel.find_child("LedgerTotal_food", true, false) as Label).text, _tr("ledger.total") % [_tr("resource.food"), 0, 0, 0])
	assert_true(panel.find_child("LedgerCause_food_fish", true, false) != null)
	assert_true(panel.find_child("LedgerCause_food_feeding", true, false) != null)
	panel.free()


func test_school_result_uses_the_same_ledger_and_retry_erases_the_old_record() -> void:
	var lesson: RiverSchoolRun = RiverSchoolRun.new()
	assert_true(lesson.start("river_school_01"))
	lesson.session.state = F.create(false, 6)
	lesson.session.state.is_tutorial = true
	var screen: RiverSchoolScreen = RiverSchoolScreen.new()
	screen.lesson = lesson
	screen.session = lesson.session
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen._finish_turn()
	var ledger: Dictionary = screen.session.turn_history()[0]["resources"]
	_balanced(ledger)
	screen.open_turn_history()
	assert_true(screen._history_details.find_child("TurnResourceLedger", true, false) != null)
	screen.close_turn_history()
	assert_eq(screen.modal_kind, "school_result")
	screen.retry_lesson()
	assert_true(screen.session.turn_history().is_empty())
	assert_eq(screen._turn_receipt_resources.text, "")
	screen.free()


func test_unclassified_changes_are_balanced_without_guessing_a_rule() -> void:
	var state: GameState = F.create()
	var before: Dictionary = ResourceLedger.capture(state)
	state.wood -= 1
	var ledger: Dictionary = ResourceLedger.for_turn(before, state, TurnReport.new(), {}, 0)
	assert_eq(_amount(ledger, "wood", "other"), -1)
	assert_eq(_amount(ledger, "food", "fish"), 0)
	_balanced(ledger)
