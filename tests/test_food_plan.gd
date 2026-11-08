extends TestCase

const F = preload("res://tools/end_turn_fixtures.gd")
const PATH: String = "user://tests/food_plan/checkpoint.json"
const SETTINGS: String = "user://tests/food_plan/settings.json"


func before_each() -> void:
	Localization.setup("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func _screen(state: GameState) -> GameScreen:
	var session: GameSession = GameSession.new()
	session.state = state
	session.save_path = PATH
	assert_eq(session.checkpoint(), "")
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	screen.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	return screen


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func test_budget_uses_active_food_cost_and_keeps_rice_out_of_storage() -> void:
	for ruleset: String in ["legacy", "balanced_v1", "bracing_moisture_irrigation_v1"]:
		var state: GameState = F.create()
		state.ruleset = ruleset
		state.recompute_mods()
		state.food = 12
		state.get_tile(F.FIELD).paddy_yield = 5
		var before: Dictionary = state.to_dict()
		var prediction: Dictionary = GameFlow.preview(state)
		var next_before: Dictionary = prediction["state"].to_dict()
		var report_before: Dictionary = prediction["report"].to_dict()
		var budget: Dictionary = FoodBudget.describe(state, prediction)
		assert_eq(budget["stored"], 12)
		assert_eq(budget["needed"], 48 if ruleset == "balanced_v1" else 6)
		assert_eq(budget["rice"], Harvest.paddy_food_by_tile(state)[F.FIELD])
		assert_eq(budget["next"]["kind"], "turn")
		assert_true(budget["next"]["harvest"].is_empty())
		budget["next"]["stored"] = 999
		assert_eq(state.to_dict(), before)
		assert_eq(prediction["state"].to_dict(), next_before)
		assert_eq(prediction["report"].to_dict(), report_before)


func test_later_hidden_rain_cannot_change_this_turn_food_budget() -> void:
	var first: GameState = F.create(false, 4)
	var second: GameState = first.duplicate_state()
	second.rain_inflows[1] = 1000.0
	second.rain_inflows[2] = 2000.0
	assert_eq(FoodBudget.describe(first, GameFlow.preview(first)), FoodBudget.describe(second, GameFlow.preview(second)))


func test_final_turn_matches_real_harvest_including_births_rot_and_goal() -> void:
	for ruleset: String in ["legacy", "balanced_v1", "bracing_moisture_irrigation_v1"]:
		var state: GameState = F.create(false, 6)
		state.ruleset = ruleset
		state.recompute_mods()
		state.food = 100
		state.population = 8
		state.village_goal = "rice"
		var home: Tile = state.get_tile(Vector2i(-1, -1))
		home.building = C.Building.HOUSE
		home.elevation = 4
		state.get_tile(F.FIELD).paddy_yield = 20
		var before: Dictionary = state.to_dict()
		var budget: Dictionary = FoodBudget.describe(state, GameFlow.preview(state))
		var actual: GameState = state.duplicate_state()
		GameFlow.end_turn(actual)
		assert_eq(budget["next"]["kind"], "harvest")
		assert_eq(budget["next"]["harvest"], actual.harvest_report)
		assert_eq(budget["next"]["outcome"], actual.outcome)
		assert_eq(budget["next"]["new_goal"], actual.goal_achieved_year > 0)
		assert_true(actual.goal_achieved_year > 0)
		assert_eq(state.to_dict(), before, "goal and settlement rewards remain on the prediction copy")
	# Free feeding and births must still agree with Harvest, without division.
	var free: GameState = F.create(false, 6)
	free.population = 3
	free.food = 0
	free.year_mods.assign([{"key": "food_per_person", "op": "set", "value": 0}, {"key": "food_per_growth", "op": "set", "value": 0}])
	free.recompute_mods()
	var budget: Dictionary = FoodBudget.describe(free, GameFlow.preview(free))
	GameFlow.end_turn(free)
	assert_eq(budget["needed"], 0)
	assert_eq(budget["next"]["harvest"], free.harvest_report)
	assert_true(int(free.harvest_report["born"]) > 0)


func test_dead_rice_and_hall_loss_do_not_promise_unearned_food() -> void:
	var state: GameState = F.create(true, 6)
	state.food = 0
	state.get_tile(F.FIELD).paddy_yield = 20
	var budget: Dictionary = FoodBudget.describe(state, GameFlow.preview(state))
	assert_true(int(budget["rice"]) > 0)
	assert_eq(budget["next"]["rice"], 0)
	assert_true(int(budget["next"]["gap"]) > 0)
	state.get_tile(F.HALL).elevation = 0
	state.get_tile(F.HALL).water = 1.5
	budget = FoodBudget.describe(state, GameFlow.preview(state))
	assert_eq(budget["next"]["kind"], "hall_loss")
	assert_true(budget["next"]["harvest"].is_empty())
	assert_eq(budget["next"]["rice"], 0)
	var panel: FoodPlanPanel = FoodPlanPanel.new()
	panel.configure(budget)
	assert_true(panel.find_child("FoodPlanWarning", true, false) != null)
	assert_true(panel.find_child("FoodPlanHarvest", true, false) == null)
	panel.free()


func test_resolved_phase_never_counts_the_harvested_rice_again() -> void:
	var state: GameState = F.create(false, 6)
	state.get_tile(F.FIELD).paddy_yield = 20
	GameFlow.end_turn(state)
	assert_eq(state.phase, C.Phase.HARVEST)
	assert_true(state.get_tile(F.FIELD).paddy_yield > 0)
	var before: Dictionary = state.to_dict()
	var budget: Dictionary = FoodBudget.describe(state, {})
	assert_true(not budget["planning"])
	assert_eq(budget["rice"], 0)
	assert_true(budget["next"].is_empty())
	assert_eq(budget["stored"], state.food)
	assert_eq(state.to_dict(), before)


func test_open_close_and_keyboard_read_preserve_save_rng_and_redo() -> void:
	var screen: GameScreen = _screen(GameFlow.new_game({"seed": 42, "ruleset": "balanced_v1", "living_village": true}))
	var target: Vector2i = screen.valid_targets("chop")[0]
	assert_eq(screen.session.apply(Command.new("chop", target)), "")
	assert_true(screen.session.undo())
	screen.refresh_state()
	screen.select_command("fill")
	var before: Dictionary = screen.session.state.to_dict()
	var redo: Array[Dictionary] = screen.session.state.redo.snapshots()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	for language: String in ["th", "en"]:
		Localization.setup(language)
		screen._unhandled_input(_key(KEY_F2))
		assert_eq(screen.modal_kind, "food_plan")
		assert_eq((screen._modal.find_child("FoodPlanMeal", true, false) as Label).text, String(TranslationServer.translate("foodplan.meal")) % [6, 8, 48])
		var key: InputEventKey = _key(KEY_Y)
		key.ctrl_pressed = true
		screen._unhandled_input(key)
		screen._unhandled_input(_key(KEY_ESCAPE))
		assert_true(screen.modal_kind.is_empty())
		assert_eq(screen.command_mode, "fill")
		assert_eq(screen.session.state.to_dict(), before)
		assert_eq(screen.session.state.redo.snapshots(), redo)
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		assert_true(screen.session.turn_history().is_empty())
	screen.free()


func test_pause_return_and_tool_choice_only_select_a_plan_until_real_command() -> void:
	var screen: GameScreen = _screen(GameFlow.new_game({"seed": 42, "ruleset": "balanced_v1"}))
	var before: Dictionary = screen.session.state.to_dict()
	screen.open_pause()
	screen.open_food_plan()
	screen._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(screen.modal_kind, "pause")
	screen.open_food_plan()
	var button: Button = screen._modal.find_child("FoodPlanCommand_paddy", true, false) as Button
	assert_true(not button.disabled)
	button.pressed.emit()
	assert_true(screen.modal_kind.is_empty())
	assert_eq(screen.command_mode, "paddy")
	assert_eq(screen.session.state.to_dict(), before)
	screen.apply_at(screen.valid_targets("paddy")[0])
	assert_eq(screen._food_budget["stored"], int(before["food"]))
	assert_eq(screen._food_budget["rice"], 0, "newly planted rice has no food yet")
	screen.undo_command()
	assert_eq(screen.session.state.to_dict(), before)
	screen.free()


func test_unavailable_actions_explain_why_and_keep_plan_open() -> void:
	var screen: GameScreen = _screen(F.create(false, 4))
	screen.open_food_plan()
	var button: Button = screen._modal.find_child("FoodPlanCommand_paddy", true, false) as Button
	assert_true(button.disabled)
	assert_true(button.tooltip_text.contains(String(TranslationServer.translate("err.season"))))
	screen._choose_food_command("paddy")
	assert_eq(screen.modal_kind, "food_plan")
	screen.close_food_plan()
	var actual: GameState = screen.session.state.duplicate_state()
	GameFlow.end_turn(actual)
	screen.session.advance_turn()
	screen.refresh_state()
	assert_eq(screen.session.state.to_dict(), actual.to_dict())
	screen.free()


func test_exact_dialog_agrees_with_end_turn_review_and_actual_harvest() -> void:
	var state: GameState = F.create(false, 6)
	state.food = 2
	var screen: GameScreen = _screen(state)
	var next: Dictionary = screen._food_budget["next"]
	assert_eq(screen.harvest_prediction, next["harvest"])
	assert_eq(screen.harvest_projection["available_food"], next["available"])
	assert_eq(screen.harvest_projection["food_needed"], next["needed"])
	assert_true(int(next["gap"]) > 0)
	screen.open_food_plan()
	assert_true(screen._modal.find_child("FoodPlanConditional", true, false) == null)
	assert_true(screen._modal.find_child("FoodPlanPeople", true, false) != null)
	screen.close_food_plan()
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_impact")
	screen._confirm_end_turn()
	assert_eq(screen.session.state.harvest_report, next["harvest"])
	assert_true(not screen._food_plan_summary.visible)
	assert_true(screen._food_plan_button.disabled)
	screen.free()


func test_school_reuses_food_plan_without_touching_normal_checkpoint() -> void:
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 73}), PATH), "")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var lesson: RiverSchoolRun = RiverSchoolRun.new()
	assert_true(lesson.start("river_school_03"))
	var school: RiverSchoolScreen = RiverSchoolScreen.new()
	school.lesson = lesson
	school.preferences_path = SETTINGS
	(Engine.get_main_loop() as SceneTree).root.add_child(school)
	var before: Dictionary = lesson.session.state.to_dict()
	school.open_pause()
	school.open_food_plan()
	school.close_food_plan()
	assert_eq(school.modal_kind, "pause")
	assert_eq(lesson.session.state.to_dict(), before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	school.free()
