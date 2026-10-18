extends TestCase


func test_targets_follow_surface_refresh_and_clear_on_state_replacement() -> void:
	var state: GameState = TestMaps.small(1, 1)
	var board: BoardView = BoardView.new()
	board.set_state(state)
	var targets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i.ZERO, Vector2i(99, 99)]
	board.set_targets(targets, Vector2i(0, 1))
	var root: Node3D = board.get_node("Targets")
	assert_eq(root.get_child_count(), 3, "one ring per real target plus the invalid hover")
	assert_true(root.has_node("InvalidTarget"))
	state.get_tile(Vector2i.ZERO).elevation = 3
	state.get_tile(Vector2i.ZERO).water = 0.5
	board.refresh()
	assert_eq(root.get_child_count(), 3, "refresh preserves target selection")
	var ring: Node3D = root.get_node("Target_0_0")
	assert_near(ring.position.y, 3.0 * C.HEIGHT_UNIT + 0.5 * C.HEIGHT_UNIT + 0.015 + 0.075, 0.00001)
	board.clear_targets()
	assert_eq(root.get_child_count(), 0)
	board.set_targets(targets)
	board.set_state(state.duplicate_state())
	assert_eq(root.get_child_count(), 0, "a replacement state cannot retain stale command targets")
	board.free()


func test_preview_marks_only_water_changes_and_report_production_without_mutation() -> void:
	var state: GameState = TestMaps.small(2, 1)
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.HOUSE})
	TestMaps.set_tile(state, 1, 0, {"feature": C.Feature.PADDY})
	TestMaps.set_tile(state, 0, 1, {"feature": C.Feature.PADDY})
	TestMaps.set_tile(state, -1, 0, {"building": C.Building.FISH_TRAP})
	var predicted: GameState = state.duplicate_state()
	TestMaps.set_tile(predicted, 0, 0, {"building": C.Building.NONE, "water": 1.2})
	TestMaps.set_tile(predicted, 1, 0, {"paddy_dead": true, "water": 1.3})
	TestMaps.set_tile(predicted, 0, 1, {"paddy_yield": 1, "water": 0.3})
	TestMaps.set_tile(predicted, -1, 0, {"water": 0.2})
	TestMaps.set_tile(predicted, 0, -1, {"water": 0.03})
	var report: TurnReport = TurnReport.new()
	report.destroyed.append({"coord": Vector2i.ZERO, "building": C.Building.HOUSE})
	report.paddies_died.append(Vector2i(1, 0))
	report.paddy_gains.append(Vector2i(0, 1))
	var food: int = roundi(roundf(float(predicted.mod("fish_trap_yield"))) * float(predicted.mod("fish_trap_multiplier")))
	report.fish_food = food
	for tile: Tile in predicted.tiles:
		report.levels_after.append(predicted.level_of(tile))
	var before_state: Dictionary = state.to_dict()
	var before_prediction: Dictionary = predicted.to_dict()
	var before_report: Dictionary = report.to_dict()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	board.set_preview({"state": predicted, "report": report})
	var root: Node3D = board.get_node("Preview")
	assert_eq(root.get_child_count(), 8, "four changed surfaces and four report markers")
	assert_true(not root.has_node("GhostWater_0_-1"), "changes below the display threshold stay hidden")
	assert_eq((root.get_node("Destroyed_0_0") as Label3D).text, "!")
	assert_eq((root.get_node("PaddyDied_1_0") as Label3D).text, "x")
	assert_eq((root.get_node("PaddyGain_0_1") as Label3D).text, "R+1")
	assert_eq((root.get_node("FishFood_-1_0") as Label3D).text, "F+%d" % food)
	assert_eq((root.get_node("PaddyGain_0_1") as Label3D).font.resource_path, "res://assets/fonts/NotoSansThai.ttf")
	board.refresh()
	assert_eq(root.get_child_count(), 8, "refresh preserves the prediction")
	assert_eq(state.to_dict(), before_state)
	assert_eq(predicted.to_dict(), before_prediction)
	assert_eq(report.to_dict(), before_report)
	board.set_preview({}, false)
	assert_eq(root.get_child_count(), 0)
	board.free()


func test_preview_fish_is_suppressed_when_the_report_has_no_production() -> void:
	var state: GameState = TestMaps.small(1, 1)
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.FISH_TRAP, "water": 0.5})
	var report: TurnReport = TurnReport.new()
	report.outcome = C.Outcome.LOSE_HALL
	var board: BoardView = BoardView.new()
	board.set_state(state)
	board.set_preview({"state": state.duplicate_state(), "report": report})
	assert_eq(board.get_node("Preview").get_child_count(), 0, "a losing turn skips all food production")
	board.set_state(null)
	assert_eq(board.get_node("Preview").get_child_count(), 0)
	board.free()


func test_every_new_structure_has_a_model_and_gate_opening_is_visible() -> void:
	var state: GameState = TestMaps.small(2, 1)
	var buildings: Array[int] = [C.Building.GATE, C.Building.GRANARY, C.Building.FISH_TRAP, C.Building.RESERVOIR, C.Building.WATERWHEEL]
	var names: Array[String] = ["Gate", "Granary", "FishTrap", "Reservoir", "Waterwheel"]
	for index: int in range(buildings.size()):
		state.tiles[index].building = buildings[index]
		state.tiles[index].wheel_dir = index % 6
	state.tiles[5].feature = C.Feature.PADDY
	state.tiles[6].feature = C.Feature.PADDY
	state.tiles[6].paddy_dead = true
	var original: Dictionary = state.to_dict()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	var root: Node3D = board.get_node("Tiles")
	for index: int in range(buildings.size()):
		var coord: Vector2i = state.tiles[index].coord
		assert_true(root.has_node("Hex_%d_%d/%s" % [coord.x, coord.y, names[index]]))
	var gate_coord: Vector2i = state.tiles[0].coord
	var panel_path: String = "Hex_%d_%d/Gate/GatePanel" % [gate_coord.x, gate_coord.y]
	var open_height: float = (root.get_node(panel_path) as Node3D).position.y
	assert_eq(state.to_dict(), original, "building view geometry cannot modify the board")
	state.tiles[0].gate_open = false
	board.refresh()
	assert_true((root.get_node(panel_path) as Node3D).position.y < open_height, "closed gate visibly lowers its panel")
	for index: int in [5, 6]:
		var coord: Vector2i = state.tiles[index].coord
		assert_true(root.has_node("Hex_%d_%d/Paddy" % [coord.x, coord.y]))
	board.free()


func test_batched_geometry_references_every_terrain_top_with_indexed_buildings_and_trees() -> void:
	# Procedural hexes start unindexed; primitive boxes and spheres have indices.
	# A mixed batch can contain terrain vertices that no triangle references.
	var state: GameState = TestMaps.small(1, 1)
	state.tiles[0].feature = C.Feature.FOREST
	state.tiles[1].building = C.Building.HOUSE
	var before: Dictionary = state.to_dict()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	_assert_rendered_terrain_centers(board, state)
	assert_eq(state.to_dict(), before, "batching only reads the simulation")
	state.get_tile(Vector2i.ZERO).elevation = 3
	before = state.to_dict()
	board.refresh()
	_assert_rendered_terrain_centers(board, state)
	assert_eq(state.to_dict(), before, "refresh cannot edit terrain or RNG")
	board.free()


func _assert_rendered_terrain_centers(board: BoardView, state: GameState) -> void:
	var rendered: Array[Vector3] = []
	_collect_referenced_vertices(board.get_node("Tiles") as Node3D, Transform3D.IDENTITY, rendered)
	for tile: Tile in state.tiles:
		var expected: Vector3 = Hex.to_world(tile.coord, tile.elevation)
		var found: bool = false
		for point: Vector3 in rendered:
			if point.distance_squared_to(expected) < 0.00000001:
				found = true
				break
		assert_true(found, "a rendered triangle must reference the terrain top at %s" % tile.coord)


func _collect_referenced_vertices(node: Node3D, parent_transform: Transform3D, rendered: Array[Vector3]) -> void:
	var transform: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for point: Vector3 in vertices:
					rendered.append(transform * point)
			else:
				for index: int in indices:
					rendered.append(transform * vertices[index])
	for child: Node in node.get_children():
		if child is Node3D:
			_collect_referenced_vertices(child as Node3D, transform, rendered)
