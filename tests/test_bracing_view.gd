extends TestCase
## The protection scene reads committed state and preview reports without rules.


func _state() -> GameState:
	var result: GameState = TestMaps.small(1, 1)
	result.ruleset = "bracing_v1"
	result.get_tile(Vector2i.ZERO).building = C.Building.HOUSE
	return result


func _triangles(board: BoardView) -> int:
	var count: int = 0
	for child: Node in board._tiles_root.get_children():
		if child is MeshInstance3D and child.mesh != null:
			count += child.mesh.get_faces().size() / 3
	return count


func test_braces_are_rendered_geometry_with_duration_for_both_house_types() -> void:
	var state: GameState = _state()
	state.get_tile(Vector2i(1, 0)).building = C.Building.STILT_HOUSE
	var board: BoardView = BoardView.new()
	board.set_state(state)
	var ordinary_triangles: int = _triangles(board)
	assert_eq(board._brace_status_root.get_child_count(), 0)
	for coord: Vector2i in [Vector2i.ZERO, Vector2i(1, 0)]:
		assert_eq(GameFlow.apply_command(state, Command.new("brace_house", coord)), "")
	var before: Dictionary = state.to_dict()
	board.refresh()
	assert_true(_triangles(board) > ordinary_triangles, "additional supports reach the baked rendered mesh")
	assert_eq(board._brace_status_root.get_child_count(), 2)
	assert_true(board._brace_status_root.get_parent() == board, "billboard badges are not baked into terrain")
	for coord: Vector2i in [Vector2i.ZERO, Vector2i(1, 0)]:
		var path: String = "Hex_%d_%d/House/EmergencyBracing" % [coord.x, coord.y]
		assert_true(board._tiles_root.has_node(path))
		assert_eq(board._tiles_root.get_node(path).get_meta("brace_turns"), 1)
		var badge: Label3D = board._brace_status_root.get_node("Brace_%d_%d" % [coord.x, coord.y]) as Label3D
		assert_eq(badge.text, "1")
		assert_eq(badge.get_meta("brace_turns"), 1)
		assert_true((badge.get_node("Shield") as Sprite3D).texture != null)
	assert_eq(state.to_dict(), before)
	board.free()


func test_undo_redo_demolition_and_replacement_remove_stale_protection() -> void:
	var state: GameState = _state()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	var ordinary_triangles: int = _triangles(board)
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", Vector2i.ZERO)), "")
	board.refresh()
	assert_eq(board._brace_status_root.get_child_count(), 1)
	state = GameFlow.undo(state)
	board.set_state(state)
	assert_eq(board._brace_status_root.get_child_count(), 0)
	assert_eq(_triangles(board), ordinary_triangles)
	state = GameFlow.redo(state)
	board.set_state(state)
	assert_eq(board._brace_status_root.get_child_count(), 1)
	assert_eq(GameFlow.apply_command(state, Command.new("demolish", Vector2i.ZERO)), "")
	board.refresh()
	assert_eq(board._brace_status_root.get_child_count(), 0)
	assert_true(not board._tiles_root.has_node("Hex_0_0/House/EmergencyBracing"))
	state = GameFlow.undo(state)
	board.set_state(state.duplicate_state())
	assert_eq(board._brace_status_root.get_child_count(), 1, "a loaded/snapshotted active brace has its status back")
	board.set_state(null)
	assert_eq(board._brace_status_root.get_child_count(), 0)
	board.free()


func test_preview_shows_saved_house_without_expiring_committed_braces() -> void:
	var state: GameState = _state()
	state.turn = 4
	state.rain_inflows = [0.0, 0.0, 0.0]
	for tile: Tile in state.tiles:
		tile.water = 0.3
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", Vector2i.ZERO)), "")
	var before: Dictionary = state.to_dict()
	var prediction: Dictionary = GameFlow.preview(state)
	var prediction_before: Dictionary = (prediction["state"] as GameState).to_dict()
	var report_before: Dictionary = (prediction["report"] as TurnReport).to_dict()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	board.set_preview(prediction)
	assert_true(board._preview_root.has_node("BraceHeld_0_0"), "protection result is read from this turn's report")
	assert_true(not board._preview_root.has_node("Destroyed_0_0"))
	assert_eq(board._brace_status_root.get_child_count(), 1, "preview cannot remove real protection")
	assert_eq(state.to_dict(), before)
	assert_eq((prediction["state"] as GameState).to_dict(), prediction_before)
	assert_eq((prediction["report"] as TurnReport).to_dict(), report_before)
	board.set_preview({}, false)
	assert_eq(board._preview_root.get_child_count(), 0)
	assert_eq(board._brace_status_root.get_child_count(), 1, "hiding preview keeps the committed status visible")
	var resolved: TurnReport = GameFlow.end_turn(state)
	assert_true(bool(resolved.brace_results[0]["prevented_loss"]))
	board.refresh()
	assert_eq(board._brace_status_root.get_child_count(), 0)
	assert_true(not board._tiles_root.has_node("Hex_0_0/House/EmergencyBracing"))
	board.free()


func test_overwhelmed_brace_never_uses_success_forecast_icon() -> void:
	var state: GameState = _state()
	state.turn = 4
	state.rain_inflows = [0.0, 0.0, 0.0]
	for tile: Tile in state.tiles:
		tile.water = 1.2
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", Vector2i.ZERO)), "")
	var prediction: Dictionary = GameFlow.preview(state)
	var board: BoardView = BoardView.new()
	board.set_state(state)
	board.set_preview(prediction)
	assert_true(board._preview_root.has_node("Destroyed_0_0"))
	assert_true(not board._preview_root.has_node("BraceHeld_0_0"), "a failed brace cannot appear to save a house")
	board.free()


func test_legacy_and_ineligible_buildings_do_not_show_protection() -> void:
	var state: GameState = _state()
	state.ruleset = "legacy"
	state.get_tile(Vector2i.ZERO).brace_turns = 1
	var board: BoardView = BoardView.new()
	board.set_state(state)
	assert_eq(board._brace_status_root.get_child_count(), 0)
	assert_true(not board._tiles_root.has_node("Hex_0_0/House/EmergencyBracing"))
	state.ruleset = "bracing_v1"
	for building: int in [C.Building.HALL, C.Building.RAFT_HOUSE, C.Building.GRANARY]:
		state.get_tile(Vector2i.ZERO).building = building
		board.refresh()
		assert_eq(board._brace_status_root.get_child_count(), 0)
		assert_true(not board._tiles_root.has_node("Hex_0_0/House/EmergencyBracing"))
	assert_eq(state.get_tile(Vector2i.ZERO).brace_turns, 1, "rendering does not repair invalid input by mutating it")
	board.free()


func test_motion_pause_and_repeated_refresh_keep_brace_state_and_rng_exact() -> void:
	var state: GameState = _state()
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", Vector2i.ZERO)), "")
	var before: Dictionary = state.to_dict()
	var rng: int = state.rng.state
	var board: BoardView = BoardView.new()
	board.set_state(state)
	var rendered: int = _triangles(board)
	for reduced: bool in [true, false, true]:
		board.set_reduced_motion(reduced)
		board.set_activity_paused(true)
		board.refresh()
		assert_eq(board._brace_status_root.get_child_count(), 1)
		assert_eq(_triangles(board), rendered, "reducing motion preserves useful protection geometry")
		board.set_activity_paused(false)
	assert_eq(state.to_dict(), before)
	assert_eq(state.rng.state, rng)
	board.free()
