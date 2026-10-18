extends TestCase
## Integration of read-only living layers with the actual board renderer.


func _triangles(board: BoardView) -> int:
	var result: int = 0
	for child: Node in board._tiles_root.get_children():
		if child is MeshInstance3D and child.mesh != null:
			result += child.mesh.get_faces().size() / 3
	return result


func test_living_layers_survive_static_batching_and_keep_state_exact() -> void:
	var state: GameState = GameFlow.new_game({"seed": 42, "living_village": true})
	var before: Dictionary = state.to_dict()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	assert_true(board._route_view.graph.routes.size() > 0)
	assert_true(board._life_view.actor_count() > 0)
	assert_true(board._life_view.get_parent() == board, "workers stay outside baked static geometry")
	assert_true(board._route_view.get_parent() == board)
	var count: int = board._route_view.rebuild_count
	board.refresh()
	assert_eq(board._route_view.rebuild_count, count, "an unchanged board does not recompute pedestrian routes")
	assert_eq(state.to_dict(), before)
	board.free()


func test_per_coordinate_water_currents_restore_preview_after_committed_effect() -> void:
	var state: GameState = GameFlow.new_game({"seed": 42})
	state.turn = 4
	var prediction: Dictionary = GameFlow.preview(state)
	var before: Dictionary = state.to_dict()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	board.set_preview(prediction)
	var preview_count: int = board._preview_root.get_child_count()
	assert_true(preview_count > 0)
	var expected: Dictionary = FlowView.tile_velocities(state, prediction["report"])
	var materials: Array = board._water_materials.values()
	assert_true(materials.size() > 1)
	assert_true(materials[0] != materials[1], "Compatibility currents have independent tile uniforms")
	for coord: Vector2i in board._water_materials:
		assert_eq(board._water_materials[coord].get_shader_parameter("flow_velocity"), expected.get(coord, Vector2.ZERO))
	board.show_actual_flow(prediction["report"])
	assert_eq(board._preview_root.get_child_count(), 0, "upcoming water and risk icons wait while actual flow is shown")
	board.set_preview(prediction)
	assert_eq(board._preview_root.get_child_count(), 0, "a forecast refresh cannot overlap committed flow")
	board.set_activity_paused(true)
	board._flow_view._process(9.0)
	assert_true(board._actual_flow_report != null, "paused feedback does not expire")
	board.set_activity_paused(false)
	board._flow_view._process(9.0)
	assert_true(board._actual_flow_report == null)
	assert_eq(board._preview_root.get_child_count(), preview_count, "effect expiry restores the current forecast icons")
	for coord: Vector2i in board._water_materials:
		assert_eq(board._water_materials[coord].get_shader_parameter("flow_velocity"), expected.get(coord, Vector2.ZERO))
	assert_eq(state.to_dict(), before)
	board.free()


func test_persistent_building_stages_change_referenced_geometry_without_rules() -> void:
	var state: GameState = GameFlow.new_game({"seed": 42, "living_village": true})
	var board: BoardView = BoardView.new()
	board.set_state(state)
	var initial: int = _triangles(board)
	state.year = 3
	state.settlement_progress["condition"] = "thriving"
	for record: Dictionary in state.settlement_progress["buildings"].values():
		record["stage"] = 2
	var before: Dictionary = state.to_dict()
	var capacity: int = state.capacity()
	board.refresh()
	assert_true(_triangles(board) > initial, "upkeep decorations reach the rendered baked mesh")
	for tile: Tile in state.tiles:
		if tile.building == C.Building.NONE:
			continue
		var details: Node3D = board._tiles_root.get_node("Hex_%d_%d/SettlementDetails" % [tile.q, tile.r])
		assert_eq(details.get_meta("stage"), 2)
		assert_eq(details.get_meta("age"), 2)
	assert_eq(state.to_dict(), before)
	assert_eq(state.capacity(), capacity)
	board.free()
