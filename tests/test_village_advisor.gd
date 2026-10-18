extends TestCase
## Visual warnings distinguish an exact turn forecast from current preparations.

const Advisor = preload("res://ui/village_advisor.gd")
const Progress = preload("res://core/settlement_progress.gd")
const PATH: String = "user://tests/village_advisor/checkpoint.json"
const SETTINGS: String = "user://tests/village_advisor/settings.json"


func before_each() -> void:
	Localization.setup("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func _state(living: bool = false) -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 1, "living_village": living})
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	state.tiles[0].building = C.Building.HALL
	for index: int in range(1, 4):
		state.tiles[index].building = C.Building.HOUSE
	state.population = 6
	state.food = 0
	state.turn = 1
	if living:
		Progress.reconcile(state)
	return state


func _screen(state: GameState) -> GameScreen:
	var screen := GameScreen.new()
	screen.session = GameSession.new()
	screen.session.state = state
	screen.session.save_path = PATH
	screen.preferences_path = SETTINGS
	assert_eq(screen.session.checkpoint(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	return screen


func _forecast(people: int = 6, hunger: int = 0, housing: int = 0) -> Dictionary:
	return {"population_after": people, "left_hunger": hunger, "left_housing": housing}


func test_priority_names_certain_hall_loss_before_other_damage_and_harvest() -> void:
	var state: GameState = _state()
	var report := TurnReport.new()
	report.outcome = C.Outcome.LOSE_HALL
	report.destroyed.append({"coord": state.tiles[1].coord, "building": C.Building.HOUSE})
	var before: Dictionary = state.to_dict()
	var warning: Dictionary = Advisor.describe(state, {"report": report}, _forecast(0, 6))
	assert_eq(warning["kind"], "hall")
	assert_eq(warning["severity"], "critical")
	assert_eq(warning["coord"], state.tiles[0].coord)
	assert_eq(warning["timing"], "advisor.this_turn")
	assert_eq(state.to_dict(), before)


func test_population_hunger_and_housing_warnings_keep_their_separate_causes() -> void:
	var state: GameState = _state()
	var prediction: Dictionary = {"report": TurnReport.new()}
	var lost: Dictionary = Advisor.describe(state, prediction, _forecast(0, 6))
	assert_eq(lost["kind"], "population")
	assert_eq(lost["action"], "food")
	assert_eq(Advisor.describe(state, prediction, _forecast(0, 0, 6))["action"], "housing")
	var hunger: Dictionary = Advisor.describe(state, prediction, _forecast(4, 2, 1))
	assert_eq(hunger["kind"], "hunger")
	assert_eq(hunger["values"], [2])
	var housing: Dictionary = Advisor.describe(state, prediction, _forecast(5, 0, 1))
	assert_eq(housing["kind"], "housing")
	assert_eq(housing["values"], [1])


func test_low_stores_before_harvest_are_preparation_not_a_prediction_of_death() -> void:
	var state: GameState = _state()
	var prediction: Dictionary = {"report": TurnReport.new()}
	var warning: Dictionary = Advisor.describe(state, prediction, {})
	assert_eq(warning["kind"], "prepare_food")
	assert_eq(warning["severity"], "prepare")
	assert_eq(warning["timing"], "advisor.stored")
	assert_eq(warning["values"], [0, 6 * roundi(float(state.mod("food_per_person")))])
	state.food = 100
	state.population = state.capacity() + 1
	assert_eq(Advisor.describe(state, prediction, {})["kind"], "prepare_housing")
	# Once the shared harvest forecast exists, current low food cannot overrule it.
	state.food = 0
	assert_eq(Advisor.describe(state, prediction, _forecast(6))["kind"], "safe")


func test_primary_goal_and_icon_chips_remain_visible_without_optional_objective() -> void:
	for language: String in ["th", "en"]:
		Localization.setup(language)
		var state: GameState = _state()
		var screen: GameScreen = _screen(state)
		assert_true(screen._survival_help.is_visible_in_tree())
		assert_true(screen._survival_progress.is_visible_in_tree())
		assert_true(not screen._goal_panel.visible)
		assert_true(not screen._resources_label.visible)
		for id: String in ["food", "wood", "people", "labor"]:
			assert_true(screen._resource_chips[id].is_visible_in_tree())
			assert_true(screen._resource_chips[id].text.contains(String(TranslationServer.translate("resource." + id))))
		assert_eq(screen._advisor["kind"], "prepare_food")
		assert_true(not screen._condition_label.visible, "legacy runs do not invent settlement history")
		screen.free()
		SaveIO.delete_save(PATH)


func test_hidden_overlay_preserves_critical_advice_and_focus_action_is_read_only() -> void:
	var state: GameState = _state()
	for tile: Tile in state.tiles:
		tile.water = 1.0
	var screen: GameScreen = _screen(state)
	assert_eq(screen._advisor["kind"], "hall")
	var original: Dictionary = state.to_dict()
	var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var rng_before: int = state.rng.state
	screen.toggle_preview()
	assert_true(screen._advisor_panel.is_visible_in_tree())
	assert_true(screen._advisor_button.visible)
	screen._act_on_advice()
	assert_eq(screen.hovered_coord, state.tiles[0].coord)
	assert_eq(screen.board._selected_coord, state.tiles[0].coord)
	assert_eq(state.to_dict(), original)
	assert_eq(state.rng.state, rng_before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), checkpoint)
	screen.free()
	SaveIO.delete_save(PATH)


func test_harvest_advice_agrees_with_projection_and_does_not_suggest_unproductive_fish_traps() -> void:
	var state: GameState = _state()
	state.food = 1
	state.turn = C.TURNS_PER_YEAR
	var screen: GameScreen = _screen(state)
	assert_eq(screen._advisor["kind"], "hunger")
	assert_eq(screen._advisor["values"], [int(screen.harvest_projection["left_hunger"])])
	var original: Dictionary = state.to_dict()
	var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	assert_eq(screen._advisor_command, "", "a legal dry fish trap cannot rescue this harvest")
	assert_true(screen._advisor_review)
	assert_true(screen._advisor_button.visible)
	screen._act_on_advice()
	assert_eq(screen.modal_kind, "advice")
	assert_eq(state.to_dict(), original)
	assert_eq(FileAccess.get_file_as_bytes(PATH), checkpoint)
	screen.free()
	SaveIO.delete_save(PATH)


func test_advice_inspection_survives_a_frame_until_pointer_motion_restores_hover() -> void:
	var state: GameState = _state()
	for tile: Tile in state.tiles:
		tile.water = 1.0
	var screen: GameScreen = _screen(state)
	var original: Dictionary = state.to_dict()
	var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen._act_on_advice()
	var hall: Tile = state.tiles[0]
	var title: String = screen._tile_title.text
	screen._process(0.0)
	assert_eq(screen.hovered_coord, hall.coord, "a stationary advice-button pointer cannot clear the chosen hall")
	assert_eq(screen._tile_title.text, title)
	assert_true(title.contains(String(TranslationServer.translate("building.hall"))))
	# Motion is observed before GUI filtering, including motion over the button.
	var motion := InputEventMouseMotion.new()
	motion.position = screen.get_viewport().get_mouse_position() + Vector2(1, 0)
	motion.relative = Vector2(1, 0)
	screen._input(motion)
	screen._process(0.0)
	var normal_hover: Vector2i = BoardView.NO_COORD
	if screen.get_viewport().gui_get_hovered_control() == null:
		var picked: Tile = screen.board.pick(screen.camera_rig.get_camera(), screen.get_viewport().get_mouse_position())
		if picked != null:
			normal_hover = picked.coord
	assert_eq(screen.hovered_coord, normal_hover, "mouse motion restores the ordinary board/UI hover result")
	assert_eq(screen._inspection_focus, BoardView.NO_COORD)
	assert_eq(state.to_dict(), original)
	assert_eq(FileAccess.get_file_as_bytes(PATH), checkpoint)
	screen.free()
	SaveIO.delete_save(PATH)


func test_preparation_action_selects_a_legal_tool_without_spending_resources() -> void:
	var state: GameState = _state()
	var screen: GameScreen = _screen(state)
	var original: Dictionary = state.to_dict()
	var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var chosen: String = screen._advisor_command
	assert_true(not chosen.is_empty())
	assert_true(not screen._targets[chosen].is_empty())
	screen._act_on_advice()
	assert_eq(screen.command_mode, chosen)
	assert_eq(state.to_dict(), original)
	assert_eq(FileAccess.get_file_as_bytes(PATH), checkpoint)
	screen.free()
	SaveIO.delete_save(PATH)


func test_enabled_settlement_shows_translated_condition_and_building_history() -> void:
	for language: String in ["th", "en"]:
		Localization.setup(language)
		var state: GameState = _state(true)
		var screen: GameScreen = _screen(state)
		assert_true(screen._condition_label.is_visible_in_tree())
		assert_eq(screen._condition_label.text, String(TranslationServer.translate(Progress.condition_key(state))))
		screen.hovered_coord = state.tiles[1].coord
		screen._update_inspector()
		assert_true(screen._tile_note.text.contains(String(TranslationServer.translate("settlement.building_age")) % 0))
		assert_true(screen._tile_note.text.contains(String(TranslationServer.translate("settlement.stage.0"))))
		screen.free()
		SaveIO.delete_save(PATH)
