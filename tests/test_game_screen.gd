extends TestCase
## Exercise the game controller against real sessions, checkpoints and board views.

const DIRECTORY: String = "user://tests/game_screen"
const CHECKPOINT_PATH: String = DIRECTORY + "/checkpoint.json"


func before_each() -> void:
	Localization.setup("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for path: String in [CHECKPOINT_PATH, CHECKPOINT_PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _open_screen(seed_value: int = 42) -> GameScreen:
	var session: GameSession = GameSession.new()
	session.save_path = CHECKPOINT_PATH
	assert_eq(session.start({"seed": seed_value}), "")
	return _screen_for_session(session)


func _screen_for_session(session: GameSession) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = true
	return screen


func _close_screen(screen: GameScreen) -> void:
	screen.free()
	SaveIO.delete_save(CHECKPOINT_PATH)


func _key(code: int) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _button_with_text(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and child.text == text:
			return child
		var found: Button = _button_with_text(child, text)
		if found != null:
			return found
	return null


func test_command_mode_survives_apply_and_undo_rebinds_board_and_inspector() -> void:
	var screen: GameScreen = _open_screen()
	var initial: GameState = screen.session.state
	var before: Dictionary = initial.to_dict()
	var coord: Vector2i = screen.valid_targets("fill")[0]
	var price: Vector2i = CommandRules.cost(initial, Command.new("fill", coord))
	var elevation: int = initial.get_tile(coord).elevation
	screen.select_command("fill")
	assert_true(screen.board.get_node("Targets").get_child_count() > 0)
	screen.apply_at(coord)
	assert_eq(screen.command_mode, "fill", "repeated construction retains its selected tool")
	assert_eq(screen.session.state.labor, int(before["labor"]) - price.x)
	assert_eq(screen.session.state.wood, int(before["wood"]) - price.y)
	assert_true(screen.session.state.get_tile(coord).elevation > elevation)
	assert_eq(screen.hovered_coord, coord)
	assert_true(screen.board.state == screen.session.state)
	assert_true(screen.prediction["state"] != screen.session.state)
	var after: Dictionary = screen.session.state.to_dict()
	screen.refresh_state()
	assert_eq(screen.session.state.to_dict(), after, "rendering prediction and targets cannot mutate the live run")
	screen.undo_command()
	assert_true(screen.session.state != initial, "undo restores a replacement model")
	assert_true(screen.board.state == screen.session.state)
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.command_mode, "fill")
	assert_eq(screen.hovered_coord, coord, "the inspector keeps a coordinate, never a stale Tile")
	assert_true(screen._tile_details.text.contains("%d" % elevation))
	assert_eq(screen.board._hover_coord, coord, "refresh restores the hover ring against the replacement model")
	assert_eq(SaveIO.load_game(CHECKPOINT_PATH)["state"].to_dict(), before)
	_close_screen(screen)


func test_waterwheel_uses_union_of_direction_targets_then_requires_two_clicks() -> void:
	var screen: GameScreen = _open_screen()
	var state: GameState = screen.session.state
	state.year_mods = [{"key": "unlock_waterwheel", "op": "set", "value": 1}]
	state.recompute_mods()
	screen.refresh_state()
	var origin: Vector2i = BoardView.NO_COORD
	var direction: int = -1
	# A board edge with direction zero blocked catches a toolbar that asks only
	# the default (-1) or one arbitrary direction for legal wheel positions.
	for coord: Vector2i in screen.valid_targets("waterwheel"):
		if CommandRules.check(state, Command.new("waterwheel", coord, 0)).is_empty():
			continue
		for candidate: int in range(1, 6):
			if CommandRules.check(state, Command.new("waterwheel", coord, candidate)).is_empty():
				origin = coord
				direction = candidate
				break
		if direction >= 0:
			break
	assert_true(direction >= 0, "generated map provides a target missed by direction zero")
	if direction < 0:
		_close_screen(screen)
		return
	var neighbor: Vector2i = state.neighbor_in_dir(state.get_tile(origin), direction).coord
	var before: Dictionary = state.to_dict()
	screen.select_command("waterwheel")
	screen.apply_at(origin)
	assert_eq(screen.wheel_origin, origin)
	assert_eq(state.to_dict(), before, "choosing the origin spends nothing until direction selection")
	assert_true(screen.board._target_coords.has(neighbor))
	screen.apply_at(Vector2i(99, 99))
	assert_eq(screen.wheel_origin, origin, "a missing direction cell leaves construction pending")
	screen.apply_at(neighbor)
	assert_eq(state.get_tile(origin).building, C.Building.WATERWHEEL)
	assert_eq(state.get_tile(origin).wheel_dir, direction)
	assert_eq(screen.command_mode, "waterwheel")
	assert_eq(screen.wheel_origin, BoardView.NO_COORD)
	assert_eq(screen.session.last_save_error, "")
	screen.undo_command()
	assert_eq(screen.session.state.to_dict(), before)
	assert_true(screen.board.state == screen.session.state)
	_close_screen(screen)


func test_gate_click_without_tool_toggles_but_right_click_only_cancels() -> void:
	var screen: GameScreen = _open_screen()
	var coord: Vector2i = screen.valid_targets("gate")[0]
	screen.select_command("gate")
	screen.apply_at(coord)
	assert_true(screen.session.state.get_tile(coord).gate_open)
	var labor: int = screen.session.state.labor
	screen._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT))
	assert_eq(screen.command_mode, "")
	assert_true(screen.session.state.get_tile(coord).gate_open)
	screen.apply_at(coord)
	assert_true(not screen.session.state.get_tile(coord).gate_open)
	assert_eq(screen.session.state.labor, labor, "gate controls cost no construction labor")
	screen._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT))
	assert_true(not screen.session.state.get_tile(coord).gate_open, "right click cannot toggle a gate")
	screen.undo_command()
	assert_true(screen.session.state.get_tile(coord).gate_open)
	_close_screen(screen)


func test_pause_blocks_model_input_and_camera_until_resumed() -> void:
	var screen: GameScreen = _open_screen()
	var coord: Vector2i = screen.valid_targets("fill")[0]
	screen.select_command("fill")
	screen.apply_at(coord)
	screen.open_pause()
	assert_eq(screen.modal_kind, "pause")
	var before: Dictionary = screen.session.state.to_dict()
	var camera_position: Vector3 = screen.camera_rig.position
	var camera_yaw: float = screen.camera_rig._yaw_target
	var zoom: float = screen.camera_rig._zoom_target
	screen.apply_at(coord)
	screen.undo_command()
	screen.request_end_turn()
	screen.select_command("dig")
	screen._unhandled_input(_key(KEY_SPACE))
	screen._unhandled_input(_key(KEY_Q))
	screen._unhandled_input(_mouse(MOUSE_BUTTON_WHEEL_UP))
	screen._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT))
	screen._process(0.25)
	assert_eq(screen.session.state.to_dict(), before)
	assert_eq(screen.hovered_coord, coord, "the continuous frame path also stops at the modal")
	assert_eq(screen.command_mode, "fill")
	assert_eq(screen.camera_rig.position, camera_position)
	assert_eq(screen.camera_rig._yaw_target, camera_yaw)
	assert_eq(screen.camera_rig._zoom_target, zoom)
	assert_eq(screen.modal_kind, "pause")
	screen._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(screen.modal_kind, "")
	screen.undo_command()
	assert_true(screen.session.state.to_dict() != before, "resume restores gameplay interaction")
	_close_screen(screen)


func test_final_turn_hunger_requires_loss_confirmation_even_with_preview_off() -> void:
	var screen: GameScreen = _open_screen()
	var state: GameState = screen.session.state
	# Isolate the annual starvation trigger from river and tide damage without
	# replacing the generated map or manufacturing a terminal outcome.
	for tile: Tile in state.tiles:
		tile.water = 0.0
		tile.is_source = false
		tile.is_sea = false
	state.turn = C.TURNS_PER_YEAR
	state.food = 0
	screen.refresh_state()
	assert_eq(screen.prediction["state"].outcome, C.Outcome.NONE, "turn preview intentionally stops before harvest")
	screen.toggle_preview()
	assert_true(not screen.preview_enabled)
	var before: Dictionary = state.to_dict()
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_loss", "annual hunger still protects the End Turn action")
	screen.undo_command()
	screen.apply_at(screen.valid_targets("fill")[0])
	screen._unhandled_input(_key(KEY_SPACE))
	assert_eq(state.to_dict(), before, "confirmation blocks accidental actions and repeated end turn")
	screen._confirm_end_turn()
	assert_eq(state.phase, C.Phase.HARVEST)
	assert_eq(state.outcome, C.Outcome.LOSE_POPULATION)
	assert_eq(screen.modal_kind, "harvest")
	assert_true(state.harvest_report["left_hunger"] > 0)
	screen.continue_harvest()
	assert_eq(state.phase, C.Phase.GAME_OVER)
	assert_eq(screen.modal_kind, "game_over")
	assert_eq(state.final_score, Scoring.score(state))
	assert_true(not SaveIO.has_save(CHECKPOINT_PATH))
	_close_screen(screen)


func test_failed_checkpoint_banner_prevents_silent_menu_exit_and_retry_saves() -> void:
	var screen: GameScreen = _open_screen()
	var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH + ".tmp")), OK)
	screen.select_command("fill")
	screen.apply_at(screen.valid_targets("fill")[0])
	assert_eq(screen.session.last_save_error, "msg.save_failed")
	assert_eq(screen._save_label.text, String(TranslationServer.translate("msg.save_failed")))
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), old_bytes)
	var exits: Array[bool] = []
	screen.menu_requested.connect(func(): exits.append(true))
	screen.open_pause()
	var menu_button: Button = _button_with_text(screen._modal, TranslationServer.translate("action.menu"))
	assert_true(menu_button != null)
	if menu_button != null:
		menu_button.pressed.emit()
	assert_eq(screen.modal_kind, "save_error")
	assert_true(exits.is_empty(), "a failed save offers a choice before leaving the live run")
	assert_true(_button_with_text(screen._modal, TranslationServer.translate("action.leave_without_save")) != null)
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), old_bytes)
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH + ".tmp")), OK)
	var retry: Button = _button_with_text(screen._modal, TranslationServer.translate("action.retry_save"))
	assert_true(retry != null)
	if retry != null:
		retry.pressed.emit()
	assert_eq(exits.size(), 1)
	assert_eq(screen.session.last_save_error, "")
	assert_eq(SaveIO.load_game(CHECKPOINT_PATH)["state"].to_dict(), screen.session.state.to_dict())
	_close_screen(screen)


func _play_farmer_commands(screen: GameScreen) -> void:
	var reference: GameState = screen.session.state.duplicate_state()
	assert_true(BotFarmer.play_turn(reference) >= 0)
	for tile: Tile in reference.tiles:
		if tile.feature == C.Feature.PADDY and screen.session.state.get_tile(tile.coord).feature != C.Feature.PADDY:
			screen.select_command("paddy")
			screen.apply_at(tile.coord)
	assert_eq(screen.session.state.to_dict(), reference.to_dict(), "the UI accepts the real farmer policy's complete turn")


func test_seeded_game_runs_through_annual_summaries_resume_and_terminal_score() -> void:
	var screen: GameScreen = _open_screen(1)
	var completed_turns: int = 0
	var harvests: int = 0
	var reached_year_two: bool = false
	while screen.session.state.phase != C.Phase.GAME_OVER and completed_turns < C.YEARS * C.TURNS_PER_YEAR:
		_play_farmer_commands(screen)
		screen.request_end_turn()
		if screen.modal_kind in ["confirm_loss", "confirm_labor"]:
			screen._confirm_end_turn()
		completed_turns += 1
		if screen.session.state.phase != C.Phase.HARVEST:
			continue
		harvests += 1
		assert_eq(screen.modal_kind, "harvest")
		assert_true(screen.session.state.harvest_report.has("population_after"))
		if harvests == 1:
			var checkpoint: Dictionary = screen.session.state.to_dict()
			screen.free()
			var resumed: GameSession = GameSession.new()
			resumed.save_path = CHECKPOINT_PATH
			assert_eq(resumed.load_game(), "")
			screen = _screen_for_session(resumed)
			assert_eq(screen.modal_kind, "harvest", "Continue opens the saved annual summary")
			assert_eq(screen.session.state.to_dict(), checkpoint, "reopening the summary cannot harvest twice")
		screen.continue_harvest()
		if screen.session.state.year == 2:
			reached_year_two = true
	assert_true(reached_year_two)
	assert_eq(harvests, C.YEARS, "seed 1 farmer play reaches all annual summaries")
	assert_eq(completed_turns, C.YEARS * C.TURNS_PER_YEAR)
	assert_eq(screen.session.state.phase, C.Phase.GAME_OVER)
	assert_eq(screen.session.state.outcome, C.Outcome.WIN)
	assert_eq(screen.modal_kind, "game_over")
	assert_eq(screen.session.state.final_score, Scoring.score(screen.session.state))
	assert_true(not SaveIO.has_save(CHECKPOINT_PATH))
	_close_screen(screen)


func test_failed_window_close_from_harvest_can_resume_the_same_summary() -> void:
	var screen: GameScreen = _open_screen(1)
	for turn_number: int in range(C.TURNS_PER_YEAR):
		_play_farmer_commands(screen)
		screen.request_end_turn()
		if screen.modal_kind in ["confirm_loss", "confirm_labor"]:
			screen._confirm_end_turn()
	assert_eq(screen.modal_kind, "harvest")
	var summary: Dictionary = screen.session.state.to_dict()
	var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH + ".tmp")), OK)
	screen.request_quit()
	assert_eq(screen.modal_kind, "save_error", "a failed window-close checkpoint must keep the run open")
	assert_eq(screen.session.state.to_dict(), summary)
	assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), old_bytes)
	var resume: Button = _button_with_text(screen._modal, TranslationServer.translate("action.resume"))
	assert_true(resume != null)
	if resume != null:
		resume.pressed.emit()
	assert_eq(screen.modal_kind, "harvest", "resume restores the annual summary instead of exposing its board")
	assert_eq(screen.session.state.to_dict(), summary, "restoring a modal cannot apply harvest twice")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH + ".tmp")), OK)
	screen.continue_harvest()
	assert_eq(screen.session.state.phase, C.Phase.PLANNING)
	assert_eq(screen.session.state.year, 2)
	assert_eq(screen.session.last_save_error, "")
	_close_screen(screen)


func test_harvest_preview_matches_real_resolution_without_writing_checkpoint() -> void:
	for seed_value: int in [1, 42, 100]:
		for food: int in [0, 8, 40]:
			var screen: GameScreen = _open_screen(seed_value)
			Localization.setup("th" if seed_value == 42 else "en")
			var state: GameState = screen.session.state
			var coord: Vector2i = screen.valid_targets("paddy")[0]
			state.turn = C.TURNS_PER_YEAR
			state.food = food
			state.year = C.YEARS if food == 40 else 1
			# Keep the hall safe while exercising water, paddy production and harvest.
			state.year_mods = [{"key": "hall_lose_level", "op": "set", "value": 100}]
			state.recompute_mods()
			state.get_tile(coord).feature = C.Feature.PADDY
			state.get_tile(coord).paddy_yield = 3
			var before: Dictionary = state.to_dict()
			var saved: PackedByteArray = FileAccess.get_file_as_bytes(CHECKPOINT_PATH)
			screen.refresh_state()
			assert_true(not screen.harvest_prediction.is_empty())
			assert_eq(state.to_dict(), before, "harvest forecast preserves live state and RNG")
			assert_eq(FileAccess.get_file_as_bytes(CHECKPOINT_PATH), saved, "forecast cannot autosave")
			var expected: Dictionary = screen.harvest_prediction.duplicate(true)
			# The compact forecast groups related counters while retaining every
			# annual total, and adds available food, demand and housing capacity.
			var projected: GameState = screen.prediction["state"]
			var available: int = projected.food + int(expected["paddy_food"])
			var needed: int = projected.population * maxi(0, roundi(float(projected.mod("food_per_person"))))
			var displayed: PackedStringArray = PackedStringArray([
				String(TranslationServer.translate("preview.harvest_paddy")) % int(expected["paddy_food"]),
				String(TranslationServer.translate("preview.harvest_food")) % [available, needed, int(expected["eaten"])],
				String(TranslationServer.translate("preview.harvest_migration")) % [int(expected["left_hunger"]), int(expected["left_housing"])],
				String(TranslationServer.translate("preview.harvest_growth")) % [int(expected["born"]), int(expected["spoiled"])],
				String(TranslationServer.translate("preview.harvest_food_after")) % int(expected["food_after"]),
				String(TranslationServer.translate("preview.harvest_people")) % [int(expected["population_after"]), projected.capacity()],
			])
			for line: String in displayed:
				assert_true(screen._preview_label.text.contains(line), "forecast displays all annual accounting totals")
			screen.toggle_preview()
			assert_eq(screen._preview_label.text, String(TranslationServer.translate("preview.disabled")))
			screen.toggle_preview()
			screen.session.advance_turn()
			assert_eq(state.harvest_report, expected, "forecast includes the final water/production step")
			screen.refresh_state()
			assert_true(screen.harvest_prediction.is_empty(), "leaving planning clears the forecast")
			_close_screen(screen)


func test_hall_loss_skips_harvest_forecast_and_earlier_turn_clears_it() -> void:
	var screen: GameScreen = _open_screen()
	var state: GameState = screen.session.state
	state.turn = C.TURNS_PER_YEAR
	state.year_mods = [{"key": "hall_lose_level", "op": "set", "value": 100}]
	state.recompute_mods()
	screen.refresh_state()
	assert_true(not screen.harvest_prediction.is_empty())
	state.turn = C.TURNS_PER_YEAR - 1
	screen.refresh_state()
	assert_true(screen.harvest_prediction.is_empty())
	assert_true(not screen._preview_label.text.contains(String(TranslationServer.translate("preview.harvest"))))
	state.turn = C.TURNS_PER_YEAR
	state.year_mods = [{"key": "hall_lose_level", "op": "set", "value": 0}]
	state.recompute_mods()
	screen.refresh_state()
	assert_eq(screen._predicted_outcome, C.Outcome.LOSE_HALL)
	assert_true(screen.harvest_prediction.is_empty(), "a flooded hall ends the game before harvest")
	assert_true(not screen._preview_label.text.contains(String(TranslationServer.translate("preview.harvest"))))
	_close_screen(screen)
