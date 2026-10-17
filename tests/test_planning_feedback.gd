extends TestCase
## Planning information must agree with actual resolution and stay read-only.

const DIRECTORY: String = "user://tests/planning_feedback"
const CHECKPOINT_PATH: String = DIRECTORY + "/checkpoint.json"
const REPORT_KEYS: PackedStringArray = [
	"paddy_food", "eaten", "left_hunger", "left_housing", "born", "spoiled", "food_after", "population_after",
]


func before_each() -> void:
	Localization.setup("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for path: String in [CHECKPOINT_PATH, CHECKPOINT_PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _state(population: int = 6, food: int = 12, homes: int = 3, year: int = 1) -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 1})
	# Keep the serializable generated map while isolating annual accounting
	# from river strategy. Individual tests add crops or water as required.
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	state.tiles[0].building = C.Building.HALL
	for index: int in range(1, homes + 1):
		state.tiles[index].building = C.Building.HOUSE
	state.population = population
	state.food = food
	state.year = year
	state.turn = C.TURNS_PER_YEAR
	state.stats["max_population"] = maxi(population, int(state.stats["max_population"]))
	state.stats["reached_year"] = year
	return state


func _screen(state: GameState) -> GameScreen:
	var session: GameSession = GameSession.new()
	session.save_path = CHECKPOINT_PATH
	session.state = state
	assert_eq(session.checkpoint(), "")
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = true
	return screen


func _close(screen: GameScreen) -> void:
	screen.free()
	SaveIO.delete_save(CHECKPOINT_PATH)


func _translate(key: String) -> String:
	return String(TranslationServer.translate(key))


func _label_texts(node: Node) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for child: Node in node.get_children():
		if child is Label:
			result.append(child.text)
		result.append_array(_label_texts(child))
	return result


func _modal_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button:
			result.append(child)
		result.append_array(_modal_buttons(child))
	return result


func _assert_safe_focus(screen: GameScreen, caption: String) -> void:
	var buttons: Array[Button] = _modal_buttons(screen._modal)
	assert_true(not buttons.is_empty())
	for button: Button in buttons:
		assert_eq(button.focus_mode, Control.FOCUS_ALL, "modal choices are reachable by keyboard")
	var focused: Control = screen.get_viewport().gui_get_focus_owner()
	assert_true(focused is Button, "the dialog assigns a default keyboard choice")
	if focused is Button:
		assert_eq(focused.text, _translate(caption), "the initial focus selects the safe action")


func test_harvest_projection_matches_resolution_without_mutating_live_prediction_or_save() -> void:
	var fixtures: Array[GameState] = [
		_state(6, 1),
		_state(8, 14, 2),
		_state(1, 12),
		_state(4, 10, 3, C.YEARS),
	]
	fixtures[2].tiles[8].feature = C.Feature.PADDY
	fixtures[2].tiles[8].paddy_yield = 3
	fixtures[2].tiles[8].paddy_rain_turns = 2
	fixtures[2].tiles[9].building = C.Building.FISH_TRAP
	fixtures[2].tiles[9].elevation = -3
	fixtures[2].tiles[9].water = 0.3
	var saw_hunger: bool = false
	var saw_housing: bool = false
	var saw_births_and_rot: bool = false
	var saw_win: bool = false
	for state: GameState in fixtures:
		assert_eq(GameFlow.apply_command(state, Command.new("fill", state.tiles[-1].coord)), "")
		var original: Dictionary = state.to_dict()
		var history: Array[Dictionary] = state.undo.snapshots()
		var original_rng: int = state.rng.state
		var preview: Dictionary = GameFlow.preview(state)
		var preview_state: Dictionary = preview["state"].to_dict()
		var preview_report: Dictionary = preview["report"].to_dict()
		var resolved: GameState = state.duplicate_state()
		var turn_report: TurnReport = GameFlow.end_turn(resolved)
		assert_eq(resolved.phase, C.Phase.HARVEST)
		var screen: GameScreen = _screen(state)
		var checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
		for key: String in REPORT_KEYS:
			assert_eq(screen.harvest_projection[key], resolved.harvest_report[key], key)
		assert_eq(screen.harvest_projection["available_food"], state.food + turn_report.fish_food + int(resolved.harvest_report["paddy_food"]))
		assert_eq(screen.harvest_projection["food_needed"], state.population * roundi(float(state.mod("food_per_person"))))
		assert_eq(screen.harvest_projection["capacity"], resolved.capacity())
		assert_eq(screen._predicted_outcome, resolved.outcome)
		assert_eq(screen.prediction["state"].to_dict(), preview_state, "annual projection cannot harvest the turn-only prediction")
		assert_eq(screen.prediction["report"].to_dict(), preview_report)
		var lines: PackedStringArray = screen._harvest_preview_lines()
		assert_eq(lines.size(), 7)
		assert_true(lines.has(_translate("preview.harvest_food") % [
			state.food + turn_report.fish_food + int(resolved.harvest_report["paddy_food"]),
			state.population * roundi(float(state.mod("food_per_person"))),
			int(resolved.harvest_report["eaten"]),
		]), "food availability, need and actual eating retain their distinct meanings")
		assert_true(lines.has(_translate("preview.harvest_migration") % [
			int(resolved.harvest_report["left_hunger"]), int(resolved.harvest_report["left_housing"]),
		]), "the forecast names both causes of population loss")
		assert_true(lines.has(_translate("preview.harvest_people") % [
			int(resolved.harvest_report["population_after"]), resolved.capacity(),
		]))
		for line: String in lines:
			assert_true(screen._preview_label.text.contains(line))
		screen.toggle_preview()
		assert_eq(screen._preview_label.text, _translate("preview.disabled"))
		screen.refresh_state()
		assert_eq(state.to_dict(), original)
		assert_eq(state.rng.state, original_rng)
		assert_eq(state.undo.snapshots(), history, "preview must preserve actual undo snapshots")
		assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), checkpoint, "read-only planning feedback cannot checkpoint")
		saw_hunger = saw_hunger or int(resolved.harvest_report["left_hunger"]) > 0
		saw_housing = saw_housing or int(resolved.harvest_report["left_housing"]) > 0
		saw_births_and_rot = saw_births_and_rot or (int(resolved.harvest_report["born"]) > 0 and int(resolved.harvest_report["spoiled"]) > 0)
		saw_win = saw_win or resolved.outcome == C.Outcome.WIN
		_close(screen)
	assert_true(saw_hunger and saw_housing and saw_births_and_rot and saw_win, "fixtures exercise distinct annual accounting outcomes")


func test_projection_is_absent_before_harvest_or_when_hall_loss_prevents_harvest() -> void:
	var state: GameState = _state()
	state.turn = C.TURNS_PER_YEAR - 1
	var screen: GameScreen = _screen(state)
	assert_true(screen.harvest_projection.is_empty())
	assert_true(screen._harvest_preview_lines().is_empty())
	state.turn = C.TURNS_PER_YEAR
	for tile: Tile in state.tiles:
		tile.water = 1.0
	screen.refresh_state()
	assert_eq(screen._predicted_outcome, C.Outcome.LOSE_HALL)
	assert_true(screen.harvest_projection.is_empty(), "a game ending during flood resolution never forecasts a harvest")
	assert_true(screen._harvest_preview_lines().is_empty())
	assert_true(not screen._preview_label.text.contains(_translate("preview.harvest_title")))
	_close(screen)


func test_loss_confirmation_shows_the_same_harvest_forecast_with_preview_hidden() -> void:
	var screen: GameScreen = _screen(_state(6, 0))
	var forecast: Dictionary = screen.harvest_projection.duplicate(true)
	var lines: PackedStringArray = screen._harvest_preview_lines()
	assert_eq(forecast["population_after"], 0)
	screen.toggle_preview()
	var original: Dictionary = screen.session.state.to_dict()
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_loss")
	var dialog_labels: PackedStringArray = _label_texts(screen._modal)
	for line: String in lines:
		assert_true(dialog_labels.has(line), "the confirmation must explain the same annual forecast: " + line)
	_assert_safe_focus(screen, "action.cancel")
	screen.close_modal()
	assert_eq(screen.session.state.to_dict(), original)
	assert_eq(screen.harvest_projection, forecast)
	_close(screen)


func test_inspector_distinguishes_dead_crops_and_newly_predicted_crop_death() -> void:
	var state: GameState = _state()
	var paddy: Tile = state.tiles[8]
	paddy.feature = C.Feature.PADDY
	paddy.paddy_yield = 9
	paddy.paddy_rain_turns = 2
	paddy.paddy_dead = true
	var screen: GameScreen = _screen(state)
	screen.hovered_coord = paddy.coord
	screen.refresh_state()
	assert_true(screen._tile_note.text.contains(_translate("tile.paddy_dead")))
	assert_true(not screen._tile_note.text.contains(_translate("tile.paddy") % [9, 2]), "stored yield on a dead crop cannot promise harvest food")
	assert_true(not screen._tile_note.text.contains(_translate("tile.paddy_dies")), "an already dead crop has no new death forecast")
	paddy.paddy_dead = false
	paddy.elevation = -3
	paddy.water = 1.0
	screen.refresh_state()
	assert_true(screen.prediction["state"].get_tile(paddy.coord).paddy_dead)
	assert_true(screen._tile_note.text.contains(_translate("tile.paddy_dies")))
	assert_true(not paddy.paddy_dead, "the warning cannot apply damage to the live crop")
	screen.toggle_preview()
	assert_true(not screen._tile_note.text.contains(_translate("tile.paddy_dies")), "hidden prediction also hides inspector forecast text")
	_close(screen)


func test_gate_status_and_wheel_intake_follow_live_state_and_undo() -> void:
	var state: GameState = _state()
	var gate_coord: Vector2i = state.tiles[8].coord
	state.tiles[8].building = C.Building.GATE
	var wheel: Tile = state.tiles[9]
	wheel.building = C.Building.WATERWHEEL
	for direction: int in range(6):
		if state.neighbor_in_dir(wheel, direction) != null:
			wheel.wheel_dir = direction
			break
	var intake: Vector2i = state.neighbor_in_dir(wheel, wheel.wheel_dir).coord
	var screen: GameScreen = _screen(state)
	screen.hovered_coord = gate_coord
	screen.refresh_state()
	assert_true(screen._tile_note.text.contains(_translate("tile.gate_open")))
	assert_true(screen._tile_note.text.contains(_translate("tile.gate_hint")))
	screen.apply_at(gate_coord)
	assert_true(screen._tile_note.text.contains(_translate("tile.gate_closed")))
	assert_true(not screen._tile_note.text.contains(_translate("tile.gate_open")))
	screen.undo_command()
	assert_true(screen._tile_note.text.contains(_translate("tile.gate_open")))
	screen.open_pause()
	assert_eq(screen.board._hover_coord, BoardView.NO_COORD)
	screen.close_modal()
	assert_eq(screen.board._hover_coord, gate_coord, "closing a dialog restores hover against the current model")
	screen.hovered_coord = wheel.coord
	screen.refresh_state()
	assert_true(screen._tile_note.text.contains(_translate("tile.wheel_intake") % [intake.x, intake.y]))
	_close(screen)


func test_disabled_shortcuts_leave_mode_and_exhausted_tool_reports_the_reason() -> void:
	var state: GameState = _state()
	state.turn = C.DRY_TURNS + 1
	var screen: GameScreen = _screen(state)
	screen.select_command("fill")
	assert_true(screen._command_buttons["paddy"].disabled)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_3
	event.pressed = true
	screen._unhandled_input(event)
	assert_eq(screen.command_mode, "fill", "a disabled seasonal shortcut cannot replace the active tool")
	var price: Vector2i = CommandRules.cost(state, Command.new("fill"))
	state.labor = price.x
	screen.refresh_state()
	screen.apply_at(screen.valid_targets("fill")[0])
	assert_eq(state.labor, 0)
	assert_eq(screen.command_mode, "fill", "an accepted last action retains the active tool")
	assert_true(screen._command_buttons["fill"].disabled)
	assert_true(screen._status_label.text.contains(_translate("err.labor")), "the retained tool explains why another action is unavailable")
	screen.select_command("dig")
	assert_eq(screen.command_mode, "fill", "direct command selection obeys the disabled toolbar too")
	_close(screen)


func test_each_modal_offers_keyboard_focus_on_its_safe_default_action() -> void:
	var screen: GameScreen = _screen(_state())
	screen.hovered_coord = screen.session.state.tiles[8].coord
	screen.open_pause()
	_assert_safe_focus(screen, "action.resume")
	screen.close_modal()
	screen.session.state.turn = C.DRY_TURNS + 1
	screen.refresh_state()
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_labor")
	_assert_safe_focus(screen, "action.cancel")
	screen.close_modal()
	_close(screen)
	var annual: GameState = _state()
	GameFlow.end_turn(annual)
	screen = _screen(annual)
	assert_eq(screen.modal_kind, "harvest")
	_assert_safe_focus(screen, "action.continue")
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH + ".tmp")), OK)
	screen.request_quit()
	assert_eq(screen.modal_kind, "save_error")
	_assert_safe_focus(screen, "action.resume")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH + ".tmp")), OK)
	_close(screen)
	var terminal: GameState = _state(4, 12, 3, C.YEARS)
	GameFlow.end_turn(terminal)
	GameFlow.continue_after_harvest(terminal)
	screen = _screen(terminal)
	assert_eq(screen.modal_kind, "game_over")
	_assert_safe_focus(screen, "action.menu")
	_close(screen)
