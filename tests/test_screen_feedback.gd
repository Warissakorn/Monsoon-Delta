extends TestCase
## Presentation feedback follows committed actions and isolated player settings.

const DIRECTORY: String = "user://tests/screen_feedback"
const SAVE_PATH: String = DIRECTORY + "/checkpoint.json"
const PREFERENCES_PATH: String = DIRECTORY + "/settings.json"


func before_each() -> void:
	Localization.setup("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", PREFERENCES_PATH, PREFERENCES_PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)


func _state(water: float = 0.0, turn: int = 1) -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 1, "run_mode": "long"})
	# Preserve the generated, serializable map while controlling water levels.
	# Three houses can flood without ending these report-feedback fixtures.
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = water
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	state.tiles[0].building = C.Building.HALL
	for index: int in range(1, 4):
		state.tiles[index].building = C.Building.HOUSE
	state.food = 1000
	state.wood = 50
	state.turn = turn
	state.year_mods.assign([{"key": "hall_lose_level", "op": "set", "value": 4}])
	state.recompute_mods()
	GameFlow.begin_turn(state)
	return state


func _screen(state: GameState) -> GameScreen:
	var session: GameSession = GameSession.new()
	session.save_path = SAVE_PATH
	session.state = state
	assert_eq(session.checkpoint(), "")
	return _screen_for_session(session)


func _screen_for_session(session: GameSession) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = session
	screen.preferences_path = PREFERENCES_PATH
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	screen.confirm_unused_labor = false
	return screen


func _close(screen: GameScreen) -> void:
	screen.free()
	SaveIO.delete_save(SAVE_PATH)
	for path: String in [PREFERENCES_PATH, PREFERENCES_PATH + ".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)


func _translate(key: String) -> String:
	return String(TranslationServer.translate(key))


func _capture_run(screen: GameScreen) -> Dictionary:
	return {
		"state": screen.session.state.to_dict(),
		"rng": screen.session.state.rng.state,
		"undo": screen.session.state.undo.snapshots(),
		"redo": screen.session.state.redo.snapshots(),
		"history": screen.session.turn_history(),
		"checkpoint": FileAccess.get_file_as_bytes(SAVE_PATH),
	}


func _marker_text(marker: Node) -> String:
	return (marker.get_node("Label") as Label3D).text


func _marker_at(screen: GameScreen, coord: Vector2i) -> Node3D:
	var at: Vector3 = Hex.to_world(coord)
	for child: Node in screen._feedback.get_children():
		var marker: Node3D = child as Node3D
		if absf(marker.position.x - at.x) < 0.00001 and absf(marker.position.z - at.z) < 0.00001:
			return marker
	return null


func _add_stale_marker(screen: GameScreen) -> void:
	screen._feedback.show_marker(Vector3.ZERO, "previous action", Color.WHITE)
	assert_eq(screen._feedback.get_child_count(), 1)


func _assert_motion(screen: GameScreen, enabled: bool) -> void:
	assert_eq(screen.reduced_motion, enabled)
	assert_eq(screen._feedback._reduced_motion, enabled)
	assert_eq(screen._atmosphere._reduced_motion, enabled)
	assert_eq(screen.camera_rig._reduced_motion, enabled)
	assert_eq(screen.board._reduced_motion, enabled)
	if enabled:
		assert_true(not screen._atmosphere._rain.visible)
		assert_true(not screen._atmosphere._rain.emitting)
	for material: ShaderMaterial in screen.board._water_materials.values():
		assert_near(float(material.get_shader_parameter("motion_scale")), 0.0 if enabled or not screen.modal_kind.is_empty() else 1.0, 0.00001)


func test_only_committed_commands_emit_feedback_and_waterwheel_waits_for_direction() -> void:
	var screen: GameScreen = _screen(_state())
	var before: Dictionary = _capture_run(screen)
	_assert_motion(screen, false)
	assert_true(not FileAccess.file_exists(PREFERENCES_PATH), "default motion does not create settings")
	screen.apply_at(screen.session.state.tiles[20].coord)
	screen.select_command("fill")
	screen.apply_at(Vector2i(99, 99))
	screen.apply_at(screen.session.state.tiles[0].coord)
	assert_eq(screen._feedback.get_child_count(), 0, "selection, missing tiles and an occupied target do not claim success")
	assert_eq(_capture_run(screen), before)
	screen.select_command("waterwheel")
	var origin: Vector2i = screen.valid_targets("waterwheel")[0]
	screen.apply_at(origin)
	assert_eq(screen.wheel_origin, origin)
	assert_eq(screen._feedback.get_child_count(), 0)
	assert_eq(_capture_run(screen), before, "choosing an intake origin spends nothing")
	screen.apply_at(Vector2i(99, 99))
	assert_eq(screen._feedback.get_child_count(), 0)
	assert_eq(_capture_run(screen), before)
	var direction: int = -1
	for candidate: int in range(6):
		if CommandRules.check(screen.session.state, Command.new("waterwheel", origin, candidate)).is_empty():
			direction = candidate
			break
	assert_true(direction >= 0)
	if direction < 0:
		_close(screen)
		return
	var expected: GameState = screen.session.state.duplicate_state()
	assert_eq(GameFlow.apply_command(expected, Command.new("waterwheel", origin, direction)), "")
	var neighbor: Vector2i = screen.session.state.neighbor_in_dir(screen.session.state.get_tile(origin), direction).coord
	screen.apply_at(neighbor)
	assert_eq(screen.session.state.to_dict(), expected.to_dict())
	assert_eq(screen._feedback.get_child_count(), 1, "a two-click command emits one confirmation when complete")
	var marker: Node3D = _marker_at(screen, origin)
	assert_true(marker != null, "the confirmation stays on the built tile rather than its intake")
	if marker != null:
		assert_true(_marker_text(marker).contains(_translate("cmd.waterwheel.name")))
		assert_true(_marker_text(marker).contains(_translate("feedback.labor") % -2))
		assert_true(_marker_text(marker).contains(_translate("feedback.wood") % -2))
	assert_eq(SaveIO.load_game(SAVE_PATH)["state"].to_dict(), expected.to_dict())
	_close(screen)


func test_undo_redo_refresh_and_pause_clear_effects_without_replaying_or_mutating_a_run() -> void:
	var screen: GameScreen = _screen(_state())
	var before: Dictionary = _capture_run(screen)
	var coord: Vector2i = screen.valid_targets("fill")[0]
	screen.select_command("fill")
	screen.apply_at(coord)
	assert_eq(screen._feedback.get_child_count(), 1)
	var after: Dictionary = _capture_run(screen)
	screen._feedback._process(0.4)
	assert_eq(_capture_run(screen), after, "animating confirmation cannot change state, history, RNG or checkpoint")
	screen.apply_at(coord)
	assert_eq(screen._feedback.get_child_count(), 1, "an invalid repeat cannot add a success marker")
	assert_eq(_capture_run(screen), after)
	screen.undo_command()
	assert_eq(screen._feedback.get_child_count(), 0)
	assert_eq(screen.session.state.to_dict(), before["state"])
	assert_eq(FileAccess.get_file_as_bytes(SAVE_PATH), before["checkpoint"])
	_add_stale_marker(screen)
	screen.redo_command()
	assert_eq(screen._feedback.get_child_count(), 0, "redo restores construction without replaying its particles")
	assert_eq(screen.session.state.to_dict(), after["state"])
	assert_eq(FileAccess.get_file_as_bytes(SAVE_PATH), after["checkpoint"])
	var restored: Dictionary = _capture_run(screen)
	_add_stale_marker(screen)
	screen.refresh_state()
	assert_eq(screen._feedback.get_child_count(), 0)
	screen.refresh_state()
	screen.toggle_preview()
	screen.toggle_preview()
	assert_eq(screen._feedback.get_child_count(), 0, "prediction refresh never replays a construction effect")
	assert_eq(_capture_run(screen), restored)
	_add_stale_marker(screen)
	screen.open_pause()
	assert_eq(screen.modal_kind, "pause")
	assert_eq(screen._feedback.get_child_count(), 0)
	screen.close_modal()
	assert_eq(screen._feedback.get_child_count(), 0)
	assert_eq(_capture_run(screen), restored, "opening or closing a modal cannot checkpoint visual changes")
	_close(screen)


func test_rice_fish_and_damage_effects_follow_the_committed_report_instead_of_the_preview() -> void:
	for water: float in [0.3, 0.7]:
		var state: GameState = _state(water, C.DRY_TURNS + 1)
		state.tiles[8].feature = C.Feature.PADDY
		state.tiles[9].building = C.Building.FISH_TRAP
		var expected: GameState = state.duplicate_state()
		var report: TurnReport = GameFlow.end_turn(expected)
		assert_eq(report.destroyed.size(), 3)
		assert_eq(report.fish_food, 1)
		assert_eq(report.paddy_gains.size(), 1 if water < 0.5 else 0)
		assert_eq(report.paddies_died.size(), 0 if water < 0.5 else 1)
		var screen: GameScreen = _screen(state)
		var before: Dictionary = _capture_run(screen)
		screen.refresh_state()
		screen.toggle_preview()
		screen.toggle_preview()
		assert_eq(screen._feedback.get_child_count(), 0, "forecast production and damage have no actual-action effects")
		assert_eq(_capture_run(screen), before)
		# An old or changed preview must never supply the committed effects.
		var stale: TurnReport = screen.prediction["report"]
		stale.destroyed.clear()
		stale.paddies_died.clear()
		stale.paddy_gains.clear()
		stale.fish_food = 0
		screen.request_end_turn()
		assert_eq(screen.modal_kind, "")
		assert_eq(state.to_dict(), expected.to_dict())
		assert_eq(screen.session.turn_history().size(), 1)
		assert_eq(screen.session.turn_history()[0]["report"]["fish_food"], report.fish_food)
		assert_eq(screen._feedback.get_child_count(), 5, "three damaged homes, a paddy and a trap each receive one actual result")
		assert_true(screen._turn_feedback_active)
		assert_eq(screen.board.get_node("Preview").get_child_count(), 0, "future ghost markers cannot overlap committed results")
		var reference: BoardView = BoardView.new()
		reference.set_state(state)
		reference.set_preview(screen.prediction, screen.preview_enabled)
		var next_preview_count: int = reference.get_node("Preview").get_child_count()
		reference.free()
		for item: Dictionary in report.destroyed:
			var marker: Node3D = _marker_at(screen, item["coord"])
			assert_true(marker != null)
			if marker != null:
				var name: String = _translate("building." + C.enum_name(C.Building, int(item["building"])))
				assert_eq(_marker_text(marker), _translate("feedback.destroyed") % name)
		var paddy_marker: Node3D = _marker_at(screen, state.tiles[8].coord)
		assert_true(paddy_marker != null)
		if paddy_marker != null:
			assert_eq(_marker_text(paddy_marker), _translate("feedback.rice_gain" if water < 0.5 else "feedback.rice_lost"))
		var fish_marker: Node3D = _marker_at(screen, state.tiles[9].coord)
		assert_true(fish_marker != null)
		if fish_marker != null:
			assert_eq(_marker_text(fish_marker), _translate("feedback.food_gain") % report.fish_food)
		var committed: Dictionary = _capture_run(screen)
		screen._feedback._process(2.0)
		assert_eq(screen._feedback.get_child_count(), 0)
		assert_true(not screen._turn_feedback_active)
		assert_eq(screen.board.get_node("Preview").get_child_count(), next_preview_count)
		assert_true(screen.board._prediction["state"] == screen.prediction["state"], "expiry restores the current upcoming turn")
		assert_eq(_capture_run(screen), committed, "expiring actual-turn feedback does not repeat production or damage")
		screen._show_turn_feedback(report)
		screen.toggle_preview()
		assert_eq(screen._feedback.get_child_count(), 0, "the player's preview toggle dismisses actual markers immediately")
		assert_true(not screen._turn_feedback_active and not screen.preview_enabled)
		assert_eq(screen.board.get_node("Preview").get_child_count(), 0)
		screen.toggle_preview()
		assert_eq(screen.board.get_node("Preview").get_child_count(), next_preview_count)
		assert_eq(_capture_run(screen), committed)
		_close(screen)


func test_busy_committed_turn_bounds_world_feedback_without_dropping_actual_production() -> void:
	var state: GameState = _state(0.3, C.DRY_TURNS + 1)
	for index: int in range(8, 28):
		state.tiles[index].feature = C.Feature.PADDY
	for index: int in range(28, 41):
		state.tiles[index].building = C.Building.FISH_TRAP
	var expected: GameState = state.duplicate_state()
	var report: TurnReport = GameFlow.end_turn(expected)
	assert_eq(report.paddy_gains.size(), 20)
	assert_eq(report.fish_food, 13)
	assert_eq(report.destroyed.size(), 3)
	var screen: GameScreen = _screen(state)
	screen.request_end_turn()
	assert_eq(screen._feedback.get_child_count(), ActionFeedback.MAX_MARKERS)
	assert_eq(state.to_dict(), expected.to_dict(), "capping visual events cannot cap production or damage")
	assert_eq(state.food, 1013)
	assert_eq(screen.session.turn_history()[0]["report"]["paddy_gains"].size(), 20)
	assert_eq(screen.session.turn_history()[0]["report"]["fish_food"], 13)
	var actual_coords: Array[Vector2i] = []
	for item: Dictionary in report.destroyed:
		actual_coords.append(item["coord"])
		var loss_marker: Node3D = _marker_at(screen, item["coord"])
		assert_true(loss_marker != null, "damage warnings remain visible when many gains exceed the marker limit")
		if loss_marker != null:
			var name: String = _translate("building." + C.enum_name(C.Building, int(item["building"])))
			assert_eq(_marker_text(loss_marker), _translate("feedback.destroyed") % name)
	actual_coords.append_array(report.paddy_gains)
	for index: int in range(28, 41):
		actual_coords.append(state.tiles[index].coord)
	var matched: int = 0
	for coord: Vector2i in actual_coords:
		if _marker_at(screen, coord) != null:
			matched += 1
	assert_eq(matched, ActionFeedback.MAX_MARKERS, "every shown event belongs to a committed result")
	var committed: Dictionary = _capture_run(screen)
	screen._feedback.clear()
	assert_eq(_capture_run(screen), committed)
	_close(screen)


func test_annual_summary_clears_pending_markers_and_does_not_replay_forecast_effects() -> void:
	var state: GameState = _state(0.0, C.TURNS_PER_YEAR)
	state.tiles[8].feature = C.Feature.PADDY
	state.tiles[8].paddy_yield = 3
	var screen: GameScreen = _screen(state)
	assert_true(not screen.harvest_projection.is_empty())
	var expected_food: int = int(screen.harvest_projection["paddy_food"])
	assert_true(expected_food > 0)
	assert_eq(screen._feedback.get_child_count(), 0)
	_add_stale_marker(screen)
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "harvest")
	assert_eq(state.phase, C.Phase.HARVEST)
	assert_eq(state.harvest_report["paddy_food"], expected_food)
	assert_eq(screen._feedback.get_child_count(), 0, "the summary owns harvest feedback while world markers are cleared")
	var committed: Dictionary = _capture_run(screen)
	screen._feedback._process(2.0)
	assert_eq(_capture_run(screen), committed)
	screen.continue_harvest()
	assert_eq(state.year, 2)
	assert_eq(state.phase, C.Phase.PLANNING)
	assert_eq(screen._feedback.get_child_count(), 0, "resuming the next year does not replay the prior result")
	_close(screen)


func test_pause_motion_choice_updates_every_live_view_persists_and_leaves_the_checkpoint_untouched() -> void:
	var legacy: String = '{"language":"en","confirm_unused_labor":false,"future":{"volume":0.75}}'
	var file: FileAccess = FileAccess.open(PREFERENCES_PATH, FileAccess.WRITE)
	file.store_string(legacy)
	file.close()
	var screen: GameScreen = _screen(_state(0.3, C.DRY_TURNS + 1))
	_assert_motion(screen, false)
	assert_eq(FileAccess.get_file_as_string(PREFERENCES_PATH), legacy, "loading legacy preferences does not migrate them")
	assert_true(not screen.board._water_materials.is_empty())
	var before: Dictionary = _capture_run(screen)
	screen.camera_rig.rotate_step(1)
	screen.camera_rig.zoom_step(-1)
	screen.open_pause()
	assert_true(not screen._motion_toggle.button_pressed)
	assert_eq(screen._motion_toggle.text, _translate("pause.reduced_motion"))
	screen._motion_toggle.button_pressed = true
	_assert_motion(screen, true)
	assert_true(screen.camera_rig._orbit_tween == null and screen.camera_rig._zoom_tween == null)
	assert_near(screen.camera_rig.rotation.y, screen.camera_rig._yaw_target, 0.00001)
	assert_near(screen.camera_rig.camera.size, screen.camera_rig._zoom_target, 0.00001)
	assert_true(not screen._motion_error.visible)
	assert_eq(GamePreferences.read(PREFERENCES_PATH)["reduced_motion"], true)
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREFERENCES_PATH))
	assert_eq(stored["future"], {"volume": 0.75})
	assert_eq(stored["language"], "en")
	assert_eq(stored["confirm_unused_labor"], false)
	assert_eq(_capture_run(screen), before, "a visual preference cannot save or alter the simulation")
	var session: GameSession = screen.session
	screen.free()
	screen = _screen_for_session(session)
	_assert_motion(screen, true)
	screen.open_pause()
	assert_true(screen._motion_toggle.button_pressed, "the next screen loads the persisted choice before rendering")
	screen._motion_toggle.button_pressed = false
	_assert_motion(screen, false)
	assert_true(screen._atmosphere._rain.visible and screen._atmosphere._rain.emitting)
	assert_eq(GamePreferences.read(PREFERENCES_PATH)["reduced_motion"], false)
	assert_eq(_capture_run(screen), before)
	_close(screen)


func test_failed_motion_preference_write_keeps_the_live_choice_and_reports_the_failure() -> void:
	assert_eq(GamePreferences.write({"language": "en", "confirm_unused_labor": false, "reduced_motion": false}, PREFERENCES_PATH), "")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(PREFERENCES_PATH)
	var screen: GameScreen = _screen(_state(0.3, C.DRY_TURNS + 1))
	var before: Dictionary = _capture_run(screen)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PREFERENCES_PATH + ".tmp")), OK)
	screen.open_pause()
	screen._motion_toggle.button_pressed = true
	_assert_motion(screen, true)
	assert_true(screen._motion_toggle.button_pressed, "a persistence failure does not discard the current accessibility choice")
	assert_true(screen._motion_error.is_visible_in_tree())
	assert_eq(screen._motion_error.text, _translate("msg.settings_failed"))
	assert_eq(screen._save_label.text, _translate("msg.settings_failed"))
	assert_eq(FileAccess.get_file_as_bytes(PREFERENCES_PATH), original)
	assert_eq(GamePreferences.read(PREFERENCES_PATH)["reduced_motion"], false)
	assert_eq(_capture_run(screen), before)
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFERENCES_PATH + ".tmp")), OK)
	screen._motion_toggle.button_pressed = false
	screen._motion_toggle.button_pressed = true
	_assert_motion(screen, true)
	assert_true(not screen._motion_error.visible, "a later successful choice clears the settings warning")
	assert_eq(GamePreferences.read(PREFERENCES_PATH)["reduced_motion"], true)
	assert_eq(_capture_run(screen), before)
	_close(screen)


func test_successful_motion_write_recovers_an_earlier_failed_labor_confirmation_choice() -> void:
	var legacy: String = '{"language":"en","confirm_unused_labor":true,"reduced_motion":false,"future":{"volume":0.75}}'
	var file: FileAccess = FileAccess.open(PREFERENCES_PATH, FileAccess.WRITE)
	file.store_string(legacy)
	file.close()
	var screen: GameScreen = _screen(_state(0.0, C.DRY_TURNS + 1))
	screen.confirm_unused_labor = true
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PREFERENCES_PATH + ".tmp")), OK)
	screen.request_end_turn()
	assert_eq(screen.modal_kind, "confirm_labor")
	if screen.modal_kind != "confirm_labor":
		_close(screen)
		return
	screen._skip_confirmation.button_pressed = true
	screen._confirm_end_turn()
	assert_eq(screen.session.state.turn, C.DRY_TURNS + 2, "the accepted turn advances even if the preferences write fails")
	assert_true(not screen.confirm_unused_labor, "the live choice survives the failed settings write")
	assert_eq(screen._preferences_error, "msg.settings_failed")
	assert_eq(FileAccess.get_file_as_string(PREFERENCES_PATH), legacy)
	assert_eq(GamePreferences.read(PREFERENCES_PATH)["confirm_unused_labor"], true)
	var committed: Dictionary = _capture_run(screen)
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFERENCES_PATH + ".tmp")), OK)
	screen.open_pause()
	screen._motion_toggle.button_pressed = true
	_assert_motion(screen, true)
	assert_true(not screen.confirm_unused_labor)
	assert_eq(GamePreferences.read(PREFERENCES_PATH), {
		"language": "en", "confirm_unused_labor": false, "reduced_motion": true,
	}, "a later successful setting write persists both live choices")
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREFERENCES_PATH))
	assert_eq(stored["future"], {"volume": 0.75})
	assert_eq(screen._preferences_error, "")
	assert_true(not screen._motion_error.visible)
	assert_eq(_capture_run(screen), committed, "recovering preferences cannot rewrite the committed game checkpoint")
	_close(screen)
