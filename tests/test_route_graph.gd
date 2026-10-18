extends TestCase

const Graph = preload("res://view/route_graph.gd")
const Roads = preload("res://view/route_network_view.gd")


func test_default_village_has_deterministic_entrance_routes_without_state_or_rng_writes() -> void:
	var state: GameState = MapGen.generate(42)
	var before: Dictionary = state.to_dict()
	var graph: RouteGraph = Graph.build(state)
	var second: RouteGraph = Graph.build(state)
	assert_eq(state.to_dict(), before, "rendering roads cannot alter the run or RNG")
	assert_true(graph.routes.size() >= 2, "the actual default map has visible village paths")
	assert_eq(graph.signature, second.signature)
	assert_eq(graph.routes, second.routes)
	var connected_homes: int = 0
	for tile: Tile in state.tiles:
		if tile.building == C.Building.HOUSE:
			if graph.can_access(tile.coord):
				connected_homes += 1
			var entrance: Vector3 = graph.access_point(tile.coord) - Hex.to_world(tile.coord, tile.elevation)
			assert_true(entrance.length() > 0.5, "road meets the porch rather than the centre of the home")
	assert_true(connected_homes >= 1, "default map has a connected home; isolated e4 homes cannot gain invisible cliff crossings")
	_assert_routes_clear(graph)


func test_hall_corner_clearance_preserves_real_seed_zero_connections() -> void:
	# A square-expanded collision box overblocked the hall corners even though
	# a circular-width path fits around the actual rotated floor footprint.
	var graph: RouteGraph = Graph.build(MapGen.generate(0))
	assert_true(graph.can_access(Vector2i(0, -3)))
	assert_true(graph.can_access(Vector2i(0, -2)))
	assert_true(graph.routes.size() >= 2)
	_assert_routes_clear(graph)


func test_paths_go_around_bodies_and_paddies_and_fishing_ends_on_a_dry_bank() -> void:
	var state: GameState = TestMaps.small(2, 1)
	TestMaps.set_tile(state, -1, 0, {"building": C.Building.HALL})
	TestMaps.set_tile(state, 1, 0, {"building": C.Building.HOUSE})
	TestMaps.set_tile(state, 0, 0, {"feature": C.Feature.PADDY})
	TestMaps.set_tile(state, 0, -1, {"feature": C.Feature.FOREST})
	TestMaps.set_tile(state, 1, -1, {"building": C.Building.FISH_TRAP, "is_river": true, "water": 0.8})
	var graph: RouteGraph = Graph.build(state)
	assert_true(graph.can_access(Vector2i(1, 0)))
	assert_true(graph.can_access(Vector2i.ZERO), "rice workers use a bank anchor")
	assert_true(graph.can_access(Vector2i(1, -1)), "fish workers use a shore anchor")
	assert_true(Hex.world_to_hex(graph.access_point(Vector2i.ZERO)) != Vector2i.ZERO, "paddy interior is not a road")
	var bank: Tile = state.get_tile(Hex.world_to_hex(graph.access_point(Vector2i(1, -1))))
	assert_true(bank != null and bank.water < 0.05 and not bank.is_river)
	assert_true(not graph.point_clear(Hex.to_world(Vector2i.ZERO, 1)))
	assert_true(not graph.point_clear(Hex.to_world(Vector2i(1, 0), 1)))
	_assert_routes_clear(graph)


func test_flood_river_and_open_gate_cannot_be_used_as_a_bridge() -> void:
	for obstacle: String in ["flood", "river", "sea", "gate", "reservoir"]:
		var state: GameState = _line()
		var middle: Tile = state.get_tile(Vector2i.ZERO)
		match obstacle:
			"flood": middle.water = 0.05
			"river": middle.is_river = true
			"sea": middle.is_sea = true
			"gate":
				middle.building = C.Building.GATE
				middle.gate_open = true
			"reservoir": middle.building = C.Building.RESERVOIR
		var graph: RouteGraph = Graph.build(state)
		assert_true(graph.path_between(Vector2i(-1, 0), Vector2i(1, 0)).is_empty(), obstacle + " blocks pedestrians")


func test_one_level_terrain_has_solid_steps_and_higher_cliffs_have_no_route() -> void:
	var state: GameState = _line()
	state.get_tile(Vector2i(1, 0)).elevation = 2
	var graph: RouteGraph = Graph.build(state)
	assert_true(graph.can_access(Vector2i(1, 0)))
	assert_true(not graph.steps.is_empty(), "a height transition has explicit renderable steps")
	for step: Dictionary in graph.steps:
		assert_near((step["high"] as Vector3).y - (step["low"] as Vector3).y, C.HEIGHT_UNIT, 0.000001)
	state.get_tile(Vector2i(1, 0)).elevation = 3
	graph = Graph.build(state)
	assert_true(not graph.can_access(Vector2i(1, 0)), "no invisible ladder over a two-level cliff")


func test_network_rebuilds_only_for_topology_and_clears_when_state_is_removed() -> void:
	var state: GameState = TestMaps.small(1, 1)
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.HALL})
	TestMaps.set_tile(state, 1, 0, {"building": C.Building.HOUSE})
	var roads: RouteNetworkView = Roads.new()
	roads.set_state(state)
	assert_eq(roads.rebuild_count, 1)
	assert_true((roads.get_node("RoadRibbons") as MeshInstance3D).mesh != null)
	state.population += 1
	state.year += 1
	state.get_tile(Vector2i(-1, 0)).water = 0.01
	roads.set_state(state)
	assert_eq(roads.rebuild_count, 1, "population, time and subthreshold water do not redraw roads")
	state.get_tile(Vector2i(-1, 0)).water = 0.1
	roads.set_state(state)
	assert_eq(roads.rebuild_count, 2)
	roads.set_state(state.duplicate_state())
	assert_eq(roads.rebuild_count, 2, "equivalent replacement state keeps the cache")
	roads.set_state(null)
	assert_true((roads.get_node("RoadRibbons") as MeshInstance3D).mesh == null)
	roads.free()


func test_arc_length_sampling_clamps_and_uses_uniform_travel_distance() -> void:
	var points: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3(2, 0, 0), Vector3(2, 0, 3)])
	assert_near(Graph.path_length(points), 5.0, 0.000001)
	assert_eq(Graph.sample_path(points, -10.0)["position"], Vector3.ZERO)
	assert_eq(Graph.sample_path(points, 3.0)["position"], Vector3(2, 0, 1))
	assert_eq(Graph.sample_path(points, 3.0)["tangent"], Vector3(0, 0, 1))
	assert_eq(Graph.sample_path(points, 10.0)["position"], Vector3(2, 0, 3))
	assert_eq(Graph.sample_path(PackedVector3Array(), 1.0)["position"], Vector3.ZERO)


func test_tile_order_does_not_change_road_choice_and_temporary_jobs_keep_safe_paths() -> void:
	var state: GameState = TestMaps.small(2, 1)
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.HALL})
	TestMaps.set_tile(state, 1, 0, {"building": C.Building.HOUSE})
	var first: RouteGraph = Graph.build(state)
	state.tiles.reverse()
	state.rebuild_index()
	var second: RouteGraph = Graph.build(state)
	assert_eq(first.signature, second.signature)
	assert_eq(first.routes, second.routes)
	var path: PackedVector3Array = first.path_between(Vector2i(1, 0), Vector2i(-2, 0))
	assert_true(path.size() > 1, "dig/fill/cleared forest work can target ordinary dry ground")
	for point: Vector3 in path:
		assert_true(first.point_clear(point), "the whole road width fits, including rounded corners")


func _line() -> GameState:
	var state: GameState = TestMaps.small(1, 1)
	var tiles: Array[Tile] = []
	for q: int in range(-1, 2):
		tiles.append(state.get_tile(Vector2i(q, 0)))
	state.tiles = tiles
	state.rebuild_index()
	state.get_tile(Vector2i(-1, 0)).building = C.Building.HALL
	state.get_tile(Vector2i(1, 0)).building = C.Building.HOUSE
	return state


func _assert_routes_clear(graph: RouteGraph) -> void:
	for route: Dictionary in graph.routes:
		var points: PackedVector3Array = route["points"]
		assert_true(points.size() >= 2)
		assert_near(Graph.path_length(points), float(route["length"]), 0.000001)
		for index: int in range(points.size()):
			assert_true(graph.point_clear(points[index]), "road ribbon plus every curved fillet fits on dry land")
			var tile: Tile = graph._tiles.get(Hex.world_to_hex(points[index])) as Tile
			if tile != null:
				assert_true(points[index].y >= float(tile.elevation) * C.HEIGHT_UNIT + Graph.SURFACE_LIFT - 0.00001, "stairs reach the upper surface before its terrain begins")
			if index > 0:
				var count: int = maxi(1, ceili(points[index - 1].distance_to(points[index]) / 0.04))
				for sample: int in range(count + 1):
					assert_true(graph.point_clear(points[index - 1].lerp(points[index], float(sample) / float(count))))
