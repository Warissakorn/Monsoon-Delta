extends TestCase

const Life = preload("res://view/village_life_view.gd")
const Routes = preload("res://view/route_graph.gd")
const Maps = preload("res://tests/test_maps.gd")


func _fixture() -> GameState:
	var state: GameState = Maps.small(2, 2)
	state.population = 5
	Maps.set_tile(state, 0, 0, {"building": C.Building.HALL})
	Maps.set_tile(state, -1, 0, {"building": C.Building.HOUSE})
	Maps.set_tile(state, 1, 0, {"building": C.Building.GRANARY})
	Maps.set_tile(state, 1, -1, {"feature": C.Feature.PADDY})
	Maps.set_tile(state, 0, 1, {"building": C.Building.FISH_TRAP, "water": 0.2})
	return state


func test_committed_jobs_use_actual_report_entries_without_state_or_rng_changes() -> void:
	var state: GameState = _fixture()
	var before: Dictionary = state.to_dict()
	var life: Node3D = Life.new()
	life.set_state(state, Routes.build(state))
	var report: TurnReport = TurnReport.new()
	report.paddy_gains.append(Vector2i(1, -1))
	report.fish_food = 2
	report.fish_food_by_tile[Vector2i(0, 1)] = 2
	var report_before: Dictionary = report.to_dict()
	life.show_report(report)
	var activities: Array[Dictionary] = life.activity_snapshot()
	assert_eq(activities.size(), 2)
	var kinds: Array[String] = []
	for activity: Dictionary in activities:
		kinds.append(activity["kind"])
	assert_true(kinds.has("farm") and kinds.has("fish"))
	for _frame: int in range(80):
		life._process(0.2)
	assert_eq(state.to_dict(), before, "people, tools and carrying never change resources, saves or RNG")
	assert_eq(report.to_dict(), report_before, "the presentation does not edit its report")
	life.free()


func test_zero_catches_and_empty_reports_do_not_invent_production_jobs() -> void:
	var state: GameState = _fixture()
	var life: Node3D = Life.new()
	life.set_state(state, Routes.build(state))
	var report: TurnReport = TurnReport.new()
	report.fish_food = 5
	report.fish_food_by_tile[Vector2i(0, 1)] = 0
	life.show_report(report)
	life.show_harvest({Vector2i(1, -1): 0})
	assert_eq(life.activity_snapshot().size(), 0, "an aggregate total cannot identify a productive trap")
	assert_true(not life.show_command("unknown", Vector2i.ZERO))
	life.free()


func test_command_retains_chopped_target_and_harvest_carry_occurs_only_after_work() -> void:
	var state: GameState = _fixture()
	var life: Node3D = Life.new()
	life.set_state(state, Routes.build(state))
	var chopped: Vector2i = Vector2i(-1, 1)
	assert_eq(state.get_tile(chopped).feature, C.Feature.NONE)
	assert_true(life.show_command("chop", chopped), "removed trees still have a dry command target")
	life.show_harvest({Vector2i(1, -1): 4})
	var seen_wood: bool = false
	var seen_rice: bool = false
	for _frame: int in range(120):
		for activity: Dictionary in life.activity_snapshot():
			if activity["kind"] == "chop":
				assert_eq(activity["coord"], chopped)
				seen_wood = seen_wood or bool(activity["carrying"])
			elif activity["kind"] == "harvest":
				seen_rice = seen_rice or bool(activity["carrying"])
			if activity["stage"] in ["outbound", "work"]:
				assert_true(not activity["carrying"], "loads appear after actual work, never on idle or outbound travel")
		life._process(0.15)
	assert_true(seen_wood, "a committed chop returns with timber")
	assert_true(seen_rice, "an exact positive harvest returns with rice")
	life.free()


func test_actor_pool_and_queue_are_bounded_by_population_and_reuse_meshes() -> void:
	var state: GameState = _fixture()
	state.population = 40
	var life: Node3D = Life.new()
	life.set_state(state, Routes.build(state))
	assert_eq(life.actor_count(), 12)
	for _event: int in range(60):
		life.show_command("dig", Vector2i(-1, 1))
	assert_true(life.queued_job_count() <= 24)
	assert_eq(life.get_child_count(), 12, "jobs reuse pooled actors")
	var first_mesh: Mesh = life.get_child(0).get_node("Body/head").mesh
	assert_eq(life.get_child(1).get_node("Body/head").mesh, first_mesh, "all actor heads share geometry")
	state.population = 2
	life.set_state(state, Routes.build(state))
	assert_eq(life.actor_count(), 2)
	assert_eq(life.get_child_count(), 2)
	life.free()


func test_refresh_preserves_work_and_clear_cancels_every_job_and_actor() -> void:
	var state: GameState = _fixture()
	var graph: RefCounted = Routes.build(state)
	var life: Node3D = Life.new()
	life.set_state(state, graph)
	life.show_command("plant", Vector2i(-1, 1))
	life._process(0.5)
	var before: Array[Dictionary] = life.activity_snapshot()
	var actor_reference: WeakRef = weakref(life.get_child(0))
	life.set_state(state, graph)
	assert_eq(life.activity_snapshot(), before, "ordinary UI refresh does not restart work")
	assert_true(actor_reference.get_ref() != null)
	life.clear()
	assert_eq(life.actor_count(), 0)
	assert_eq(life.queued_job_count(), 0)
	assert_eq(life.activity_snapshot().size(), 0)
	assert_eq(actor_reference.get_ref(), null)
	assert_true(not life.is_processing())
	life.set_state(state, graph)
	assert_eq(life.activity_snapshot().size(), 0, "reset villagers never replay old work")
	life.free()


func test_reduced_motion_and_pause_freeze_positions_without_losing_task_cues() -> void:
	var state: GameState = _fixture()
	var life: Node3D = Life.new()
	life.set_state(state, Routes.build(state))
	life.show_command("dig", Vector2i(-1, 1))
	life._process(0.2)
	life.set_paused(true)
	var paused: Array[Dictionary] = life.activity_snapshot()
	life._process(1.0)
	assert_eq(life.activity_snapshot(), paused)
	assert_true(not life.is_processing())
	life.set_paused(false)
	life.set_reduced_motion(true)
	var static_activity: Array[Dictionary] = life.activity_snapshot()
	assert_eq(static_activity[0]["stage"], "work")
	assert_true(life.get_child(0).get_node("Body/RightArm/Hoe").visible)
	life._process(0.6)
	assert_eq(life.activity_snapshot(), static_activity, "reduced motion holds a fixed worker and tool pose")
	life._process(10.0)
	assert_eq(life.activity_snapshot().size(), 0, "static work cues still expire without movement")
	assert_true(not life.is_processing())
	life.free()


func test_people_use_dry_shared_paths_and_cancel_jobs_when_access_is_lost() -> void:
	var state: GameState = _fixture()
	var graph: RefCounted = Routes.build(state)
	var life: Node3D = Life.new()
	life.set_state(state, graph)
	life.show_report(_fish_report())
	for _frame: int in range(40):
		for activity: Dictionary in life.activity_snapshot():
			assert_true(graph.point_clear(activity["position"]), "feet stay on dry geometry outside buildings")
		life._process(0.1)
	for tile: Tile in state.tiles:
		if tile.building != C.Building.HALL and tile.building != C.Building.HOUSE:
			tile.water = 1.0
	graph = Routes.build(state)
	life.set_state(state, graph)
	assert_eq(life.activity_snapshot().size(), 1, "a fisherman can still work from the connected dry hall bank")
	for activity: Dictionary in life.activity_snapshot():
		assert_true(graph.point_clear(activity["position"]))
	state.get_tile(Vector2i.ZERO).water = 1.0
	graph = Routes.build(state)
	life.set_state(state, graph)
	assert_eq(life.activity_snapshot().size(), 0, "a new flood cancels a now inaccessible job")
	assert_true(not life.show_command("dig", Vector2i(-1, 1)))
	life.free()


func test_idle_people_visit_hall_without_tools_or_resource_carry() -> void:
	var state: GameState = _fixture()
	var before: Dictionary = state.to_dict()
	var life: Node3D = Life.new()
	life.set_state(state, Routes.build(state))
	life._process(5.0)
	var activities: Array[Dictionary] = life.activity_snapshot()
	assert_true(not activities.is_empty(), "the starting village has a modest home-to-hall commute")
	assert_true(activities.size() <= 2)
	for activity: Dictionary in activities:
		assert_eq(activity["source"], "ambient")
		assert_true(not activity["carrying"])
	assert_eq(state.to_dict(), before)
	life.set_reduced_motion(true)
	assert_eq(life.activity_snapshot().size(), 0, "reduced motion removes ambient commuting")
	life.free()


func _fish_report() -> TurnReport:
	var report: TurnReport = TurnReport.new()
	report.fish_food = 2
	report.fish_food_by_tile[Vector2i(0, 1)] = 2
	return report
