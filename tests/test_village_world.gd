extends TestCase
## Scene data, placement and lifecycle invariants; no tests for prop minutiae.


func test_contract_is_read_only_stable_after_reload_and_independent_of_tile_order() -> void:
	var state: GameState = VillageWorldFixture.create()
	var before: Dictionary = state.to_dict()
	var plan: Dictionary = VillageScenePlan.build(state, RouteGraph.build(state))
	assert_eq(state.to_dict(), before)
	var restored: GameState = state.duplicate_state()
	assert_eq(VillageScenePlan.build(restored, RouteGraph.build(restored)), plan)
	restored.tiles.reverse()
	restored.rebuild_index()
	assert_eq(VillageScenePlan.build(restored, RouteGraph.build(restored)), plan)
	assert_true(plan["props"].size() > 10)
	assert_true(plan["actors"].size() > 0)


func test_ground_placements_clear_actual_roads_entrances_bodies_and_wet_tiles() -> void:
	var state: GameState = VillageWorldFixture.create()
	var routes: RouteGraph = RouteGraph.build(state)
	var plan: Dictionary = VillageScenePlan.build(state, routes)
	for item: Dictionary in plan["clearance"]:
		assert_true(VillageScenePlan.slot_clear(item["position"], item["radius"], routes, []), "placement must leave room for the full road width")
	var boats: int = 0
	for actor: Dictionary in plan["actors"]:
		if actor["kind"] == "boat":
			boats += 1
			assert_true(VillageScenePlan._boat_clear(state, actor["position"], actor["rotation"]))
	assert_true(boats > 0, "the controlled river has a genuinely wet mooring")


func test_caps_and_all_flooded_banks_remove_unsafe_land_activities() -> void:
	var state: GameState = VillageWorldFixture.create()
	var plan: Dictionary = VillageScenePlan.build(state, RouteGraph.build(state))
	var counts: Dictionary = {}
	for actor: Dictionary in plan["actors"]:
		counts[actor["kind"]] = int(counts.get(actor["kind"], 0)) + 1
	assert_true(int(counts.get("boat", 0)) <= VillageScenePlan.MAX_BOATS)
	assert_true(int(counts.get("chicken", 0)) + int(counts.get("bird", 0)) + int(counts.get("fish", 0)) <= VillageScenePlan.MAX_ANIMALS)
	assert_true(plan["ripples"].size() <= VillageScenePlan.MAX_RIPPLES)
	for tile: Tile in state.tiles:
		tile.water = 2.0
	plan = VillageScenePlan.build(state, RouteGraph.build(state))
	assert_eq(plan["clearance"].size(), 0)
	assert_eq(plan["actors"].size(), 0, "no chickens, land fixtures or docks survive on flooded banks")


func test_rebuild_cache_pause_reduce_motion_and_reset_keep_source_exact() -> void:
	var state: GameState = VillageWorldFixture.create()
	var before: Dictionary = state.to_dict()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	var scenery: VillageScenery = board._scenery
	var count: int = scenery.rebuild_count
	var initial: Dictionary = scenery.snapshot()
	board.refresh()
	assert_eq(scenery.rebuild_count, count)
	assert_eq(scenery.snapshot(), initial)
	scenery._process(0.7)
	assert_true(scenery.snapshot()["actors"] != initial["actors"], "the presentation clock animates a bounded pool")
	board.set_activity_paused(true)
	var paused: Dictionary = scenery.snapshot()
	scenery._process(0.8)
	assert_eq(scenery.snapshot(), paused)
	board.set_activity_paused(false)
	board.set_reduced_motion(true)
	var still: Dictionary = scenery.snapshot()
	scenery._process(0.8)
	assert_eq(scenery.snapshot(), still)
	assert_eq(state.to_dict(), before)
	board.set_state(null)
	assert_eq(scenery.snapshot()["actors"].size(), 0)
	assert_true(not scenery.is_processing())
	board.free()


func test_forecast_never_creates_food_and_committed_harvest_feedback_expires() -> void:
	var state: GameState = VillageWorldFixture.create()
	var before: Dictionary = state.to_dict()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	assert_true(_has_prop(board._scenery.plan, "drying_mat"))
	board.set_preview(GameFlow.preview(state))
	assert_eq(board._scenery.snapshot()["activity"], 0)
	board.show_harvest_activity({Vector2i.ZERO: 0})
	assert_eq(board._scenery.snapshot()["activity"], 0)
	board.show_harvest_activity({Vector2i.ZERO: 4})
	assert_true(board._scenery.snapshot()["activity"] > 0)
	board.set_activity_paused(true)
	board._scenery._process(5.0)
	assert_true(board._scenery.snapshot()["activity"] > 0)
	board.set_activity_paused(false)
	board.set_reduced_motion(true)
	board._scenery._process(3.0)
	assert_eq(board._scenery.snapshot()["activity"], 0, "static feedback still expires without moving actors")
	board.show_harvest_activity({Vector2i.ZERO: 4})
	board.set_state(state.duplicate_state())
	assert_eq(board._scenery.snapshot()["activity"], 0, "load and Undo replacement cannot replay rewards")
	assert_eq(state.to_dict(), before)
	board.free()


func test_season_and_real_stock_change_visuals_without_new_save_fields() -> void:
	var state: GameState = VillageWorldFixture.create()
	var dry: Dictionary = VillageScenePlan.build(state, RouteGraph.build(state))
	assert_true(_has_prop(dry, "dry_cracks"))
	assert_true(not dry["rain"])
	state.turn = 4
	state.wood = 0
	var before: Dictionary = state.to_dict()
	var rain: Dictionary = VillageScenePlan.build(state, RouteGraph.build(state))
	assert_true(rain["rain"])
	assert_true(not _has_prop(rain, "dry_cracks"))
	assert_true(not _has_prop(rain, "wood_rack"), "no stockpile when communal wood is empty")
	assert_eq(state.to_dict(), before)


func _has_prop(plan: Dictionary, kind: String) -> bool:
	for item: Dictionary in plan["props"]:
		if item["kind"] == kind:
			return true
	return false
