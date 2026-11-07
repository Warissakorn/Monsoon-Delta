extends TestCase
## Presentation invariants for the detailed models and shared baked geometry.


func _fixture() -> GameState:
	var state: GameState = TestMaps.small(1, 2)
	var kinds: Array[int] = [C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.RAFT_HOUSE, C.Building.HALL, C.Building.GRANARY]
	for index: int in range(kinds.size()):
		state.tiles[index].building = kinds[index]
	state.tiles[2].water = 0.7
	SettlementProgress.initialize(state)
	return state


func _geometry_digest(board: BoardView) -> String:
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	for child: Node in board._tiles_root.get_children():
		if child is MeshInstance3D:
			for surface: int in range(child.mesh.get_surface_count()):
				digest.update(var_to_bytes(child.mesh.surface_get_arrays(surface)))
	return digest.finish().hex_encode()


func test_refresh_reload_and_motion_preserve_geometry_state_and_rng() -> void:
	var state: GameState = _fixture()
	var original: Dictionary = state.to_dict()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	var first: String = _geometry_digest(board)
	var meshes: int = board._meshes.size()
	var materials: int = board._materials.size()
	board.refresh()
	assert_eq(_geometry_digest(board), first, "refresh must keep every decorative variant and its vertex colors")
	board.set_reduced_motion(true)
	board.set_activity_paused(true)
	board.set_state(state.duplicate_state())
	assert_eq(_geometry_digest(board), first, "a restored state draws the same architecture")
	assert_eq(board._meshes.size(), meshes, "shared primitive cache does not grow on identical rebuilds")
	assert_eq(board._materials.size(), materials)
	assert_eq(state.to_dict(), original, "drawing and variants do not consume gameplay RNG")
	board.free()


func test_fine_geometry_is_one_separate_batch_with_structures_remaining_visible() -> void:
	var board: BoardView = BoardView.new()
	board.set_state(_fixture())
	assert_true(is_instance_valid(board._fine_details))
	assert_true(board._fine_details.mesh.get_faces().size() > 0)
	var bodies: MeshInstance3D = board._tiles_root.get_node("Baked_Solids")
	var structure_faces: PackedVector3Array = bodies.mesh.get_faces()
	board._fine_details.hide()
	assert_true(bodies.visible, "zooming out retains the actual buildings")
	assert_eq(bodies.mesh.get_faces(), structure_faces)
	var batches: int = 0
	for child: Node in board._tiles_root.get_children():
		if child is MeshInstance3D and child.name.begins_with("Baked_"):
			batches += 1
	assert_true(batches <= 4, "small architectural pieces are batched, not independent draw submissions")
	board.set_state(null)
	assert_true(board._fine_details == null, "loading an empty board releases the previous detail batch")
	board.free()


func test_all_raft_architecture_follows_water_including_props_and_rope() -> void:
	var state: GameState = _fixture()
	var tile: Tile = state.tiles[2]
	var board: BoardView = BoardView.new()
	board.state = state
	var low: Node3D = Node3D.new()
	board._build_house(low, tile)
	var points_low: PackedVector3Array = []
	_collect_points(low, Transform3D.IDENTITY, points_low)
	tile.water += 1.2
	var before: Dictionary = state.to_dict()
	var high: Node3D = Node3D.new()
	board._build_house(high, tile)
	var points_high: PackedVector3Array = []
	_collect_points(high, Transform3D.IDENTITY, points_high)
	assert_eq(points_low.size(), points_high.size())
	var aligned: bool = true
	for index: int in range(points_low.size()):
		if not (points_high[index] - points_low[index]).is_equal_approx(Vector3.UP * 1.2 * C.HEIGHT_UNIT):
			aligned = false
			break
	assert_true(aligned, "the entire raft house, including porch details, moves with its platform")
	assert_eq(state.to_dict(), before)
	low.free()
	high.free()
	board.free()


func test_routes_avoid_expanded_porch_and_still_reach_entrance() -> void:
	var state: GameState = TestMaps.small(2, 2)
	state.get_tile(Vector2i(-1, 0)).building = C.Building.HALL
	var coord: Vector2i = Vector2i(1, 0)
	state.get_tile(coord).building = C.Building.HOUSE
	var original: Dictionary = state.to_dict()
	var graph: RouteGraph = RouteGraph.build(state)
	var center: Vector3 = Hex.to_world(coord, 2)
	var on_porch: Vector3 = center + Vector3(0.22, 0.0, 0.50).rotated(Vector3.UP, RouteGraph.BODY_ROTATION)
	assert_true(not graph.point_clear(on_porch, 0.0), "the wider porch is not a through road")
	assert_true(graph.path_to(coord).size() > 1, "the front entrance remains reachable")
	var path: PackedVector3Array = graph.path_to(coord)
	var clear: bool = true
	for point: Vector3 in path:
		if not graph.point_clear(point):
			clear = false
	assert_true(clear, "road width and smoothed corners clear the new footprint")
	assert_eq(state.to_dict(), original)


func _collect_points(node: Node3D, parent_transform: Transform3D, points: PackedVector3Array) -> void:
	var transform: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D:
		for point: Vector3 in node.mesh.get_faces():
			points.append(transform * point)
	for child: Node in node.get_children():
		if child is Node3D:
			_collect_points(child, transform, points)
