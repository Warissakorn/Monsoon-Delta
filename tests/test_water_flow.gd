extends TestCase

const FlowOverlay = preload("res://view/flow_view.gd")


func _index(state: GameState, coord: Vector2i) -> int:
	return int(state.index[coord])


func _report(result: Dictionary) -> TurnReport:
	var report: TurnReport = TurnReport.new()
	report.flow_edges.assign(result.flow_edges)
	report.wheel_transfers.assign(result.wheel_transfers)
	report.snapshots.assign(result.snapshots)
	return report


func test_exact_shares_reconstruct_snapshots_without_any_new_water() -> void:
	var state: GameState = TestMaps.small(1, 0)
	state.mods["water_iterations"] = 3
	state.mods["flow_rate"] = 0.5
	state.get_tile(Vector2i.ZERO).water = 1.0
	var result: Dictionary = WaterSim.simulate(state, 0.0, true)
	assert_eq(result.flow_edges.size(), 3)
	var center: int = _index(state, Vector2i.ZERO)
	for direction: int in 6:
		assert_near(float(result.flow_edges[0][center * 6 + direction]), 1.0 / 14.0, 1e-7)
	for step: int in result.flow_edges.size():
		var reconstructed: PackedFloat64Array = PackedFloat64Array(Array(result.snapshots[step]))
		var edge: PackedFloat32Array = result.flow_edges[step]
		for index: int in state.tiles.size():
			for direction: int in 6:
				var target: Tile = state.neighbor_in_dir(state.tiles[index], direction)
				var amount: float = edge[index * 6 + direction]
				if target != null:
					reconstructed[index] -= amount
					reconstructed[_index(state, target.coord)] += amount
		for index: int in state.tiles.size():
			assert_near(reconstructed[index], float(result.snapshots[step + 1][index]), 1e-6)


func test_recording_is_optional_and_does_not_change_float64_state_or_rng() -> void:
	var state: GameState = GameFlow.new_game({"seed": 42})
	var copy: GameState = state.duplicate_state()
	var before_rng: int = state.rng.state
	var visible: TurnReport = TurnResolver.resolve_turn(state, true)
	var cheap: TurnReport = TurnResolver.resolve_turn(copy, false)
	assert_eq(state.to_dict(), copy.to_dict(), "visual recording cannot affect any gameplay field")
	assert_eq(state.rng.state, before_rng)
	assert_true(not visible.flow_edges.is_empty())
	assert_eq(cheap.flow_edges.size(), 0)
	assert_eq(cheap.wheel_transfers.size(), 0)
	assert_eq(cheap.fish_food_by_tile.size(), 0)
	assert_eq(visible.to_dict().keys(), cheap.to_dict().keys(), "visual telemetry is excluded from report serialization")
	assert_true(not state.to_dict().has("flow_edges"))


func test_closed_gate_has_zero_flux_on_both_sides() -> void:
	var state: GameState = TestMaps.small(1, 4)
	state.mods["water_iterations"] = 4
	TestMaps.set_tile(state, -1, 0, {"elevation": 0, "water": 2.0})
	TestMaps.set_tile(state, 0, 0, {"elevation": 0, "water": 0.7, "building": C.Building.GATE, "gate_open": false})
	TestMaps.set_tile(state, 1, 0, {"elevation": 0})
	var result: Dictionary = WaterSim.simulate(state, 0.0, true)
	var gate: int = _index(state, Vector2i.ZERO)
	var upstream: int = _index(state, Vector2i(-1, 0))
	for edge: PackedFloat32Array in result.flow_edges:
		assert_near(float(edge[upstream * 6]), 0.0, 1e-9)
		for direction: int in 6:
			assert_near(float(edge[gate * 6 + direction]), 0.0, 1e-9)
	state.get_tile(Vector2i.ZERO).gate_open = true
	var open: Dictionary = WaterSim.simulate(state, 0.0, true)
	assert_true(float(open.flow_edges[0][upstream * 6]) > 0.0)


func test_uphill_pumping_is_logged_before_initial_snapshot_separate_from_gravity() -> void:
	var state: GameState = TestMaps.small(1, 4)
	state.mods["water_iterations"] = 1
	state.mods["wheel_amount"] = 0.5
	TestMaps.set_tile(state, 0, 0, {"building": C.Building.WATERWHEEL, "wheel_dir": 3})
	TestMaps.set_tile(state, -1, 0, {"elevation": 0, "water": 0.8})
	var result: Dictionary = WaterSim.simulate(state, 0.0, true)
	var wheel: int = _index(state, Vector2i.ZERO)
	var source: int = _index(state, Vector2i(-1, 0))
	assert_eq(result.wheel_transfers.size(), 1)
	assert_eq(int(result.wheel_transfers[0].from), source)
	assert_eq(int(result.wheel_transfers[0].to), wheel)
	assert_near(float(result.wheel_transfers[0].amount), 0.5, 1e-9)
	assert_near(float(result.snapshots[0][wheel]), 0.5, 1e-6)
	assert_near(float(result.flow_edges[0][source * 6]), 0.0, 1e-9, "uphill pump is not a natural outflow")
	var transfers: Array[Dictionary] = FlowOverlay.transfers(state, _report(result))
	assert_true(transfers.any(func(edge: Dictionary) -> bool: return bool(edge.pump) and int(edge.from) == source and int(edge.to) == wheel))


func test_sinks_are_not_reported_as_directional_edges_and_fish_use_committed_tiles() -> void:
	var state: GameState = TestMaps.small(1, 0)
	state.mods["water_iterations"] = 1
	state.turn = 1
	for tile: Tile in state.tiles:
		tile.water = 0.4
	TestMaps.set_tile(state, 0, 0, {"feature": C.Feature.FOREST})
	TestMaps.set_tile(state, 1, 0, {"building": C.Building.FISH_TRAP})
	var report: TurnReport = TurnResolver.resolve_turn(state)
	assert_true(report.absorbed > 0.0 and report.evaporated > 0.0)
	assert_eq(FlowOverlay.transfers(state, report).size(), 0, "equal surfaces stay still even when sinks remove water")
	assert_eq(int(report.fish_food_by_tile.get(Vector2i(1, 0), 0)), report.fish_food)
	assert_true(report.fish_food > 0)
	assert_true(not report.to_dict().has("fish_food_by_tile"))
	var lost: GameState = TestMaps.small(1, 0)
	lost.turn = 4
	for tile: Tile in lost.tiles:
		tile.water = 0.7
	TestMaps.set_tile(lost, 0, 0, {"building": C.Building.HALL})
	TestMaps.set_tile(lost, 1, 0, {"building": C.Building.FISH_TRAP})
	assert_eq(TurnResolver.resolve_turn(lost).fish_food_by_tile.size(), 0, "a losing turn cannot invent production jobs")


func test_overlay_is_bounded_read_only_and_preview_differs_from_recent_motion() -> void:
	var state: GameState = TestMaps.small(1, 0)
	state.turn = 4
	state.get_tile(Vector2i.ZERO).water = 1.0
	var prediction: Dictionary = GameFlow.preview(state)
	var report: TurnReport = prediction.report
	var predicted: GameState = prediction.state
	var before: Dictionary = state.to_dict()
	var predicted_before: Dictionary = predicted.to_dict()
	var view := FlowOverlay.new()
	view.set_state(state)
	view.set_preview(prediction)
	assert_eq(view.get_node("PreviewFlow").get_child_count(), 1, "all dashed forecast edges share one draw batch")
	var forecast: MeshInstance3D = view.get_node("PreviewFlow").get_child(0)
	assert_true(int(forecast.get_meta("edge_count")) > 0)
	assert_true(int(forecast.get_meta("edge_count")) <= FlowOverlay.MAX_EDGES)
	view.show_report(report, predicted)
	assert_true(view.is_showing_actual())
	assert_true(not view.get_node("PreviewFlow").visible)
	var batch: MultiMeshInstance3D = view.get_node("RecentFlow").get_child(0)
	var start: Transform3D = batch.multimesh.get_instance_transform(0)
	var elapsed: float = view._elapsed
	view._process(0.2)
	assert_true(view._elapsed > elapsed, "the actual flow timeline advances")
	# The dummy headless renderer discards MultiMesh instance transforms. Run
	# this same suite with a native Compatibility window to verify GPU updates.
	if DisplayServer.get_name() != "headless":
		assert_true(batch.multimesh.get_instance_transform(0) != start, "committed instances move in their actual transfer direction")
	view.set_reduced_motion(true)
	batch = view.get_node("RecentFlow").get_child(0)
	start = batch.multimesh.get_instance_transform(0)
	view._process(0.2)
	assert_eq(batch.multimesh.get_instance_transform(0), start, "reduced motion preserves a static direction")
	view.set_paused(true)
	view._process(10.0)
	assert_true(view.is_showing_actual(), "a modal pauses actual flow expiry")
	view.set_paused(false)
	view._process(FlowOverlay.RECENT_SECONDS)
	assert_true(not view.is_showing_actual())
	assert_true(view.get_node("PreviewFlow").visible)
	assert_eq(state.to_dict(), before)
	assert_eq(predicted.to_dict(), predicted_before)
	view.clear()
	assert_eq(view.get_node("PreviewFlow").get_child_count(), 0)
	view.free()


func test_stationary_water_never_creates_arrows_or_shader_velocity() -> void:
	var state: GameState = TestMaps.small(1, 0)
	for tile: Tile in state.tiles:
		tile.water = 0.7
	var report: TurnReport = _report(WaterSim.simulate(state, 0.0, true))
	var view := FlowOverlay.new()
	view.set_state(state)
	view.set_preview({"state": state, "report": report})
	view.show_report(report, state)
	assert_eq(view.get_node("PreviewFlow").get_child_count(), 0)
	assert_eq(view.get_node("RecentFlow").get_child_count(), 0)
	assert_eq(FlowOverlay.tile_velocities(state, report).size(), 0)
	view.free()


func test_receiver_shader_velocity_points_downstream_and_geometry_has_a_hard_limit() -> void:
	var channel: GameState = TestMaps.small(1, 4)
	channel.mods["water_iterations"] = 1
	TestMaps.set_tile(channel, -1, 0, {"elevation": 0, "water": 1.0})
	TestMaps.set_tile(channel, 0, 0, {"elevation": 0})
	var report: TurnReport = _report(WaterSim.simulate(channel, 0.0, true))
	var velocities: Dictionary = FlowOverlay.tile_velocities(channel, report)
	assert_true(Vector2(velocities[Vector2i(-1, 0)]).x > 0.0)
	assert_true(Vector2(velocities[Vector2i.ZERO]).x > 0.0, "incoming flow points downstream on the receiving tile too")
	assert_near(Vector2(velocities[Vector2i.ZERO]).y, 0.0, 1e-9)
	var broad: GameState = TestMaps.small(4, 0)
	broad.mods["water_iterations"] = 1
	for tile: Tile in broad.tiles:
		tile.water = 0.1 + float(posmod(tile.q * 7 + tile.r * 3, 5)) * 0.3
	var many: TurnReport = _report(WaterSim.simulate(broad, 0.0, true))
	assert_true(FlowOverlay.transfers(broad, many).size() > FlowOverlay.MAX_EDGES)
	var view := FlowOverlay.new()
	view.set_state(broad)
	view.set_preview({"state": broad, "report": many})
	view.show_report(many, broad)
	assert_eq(view.get_node("PreviewFlow").get_child_count(), 1)
	var forecast: MeshInstance3D = view.get_node("PreviewFlow").get_child(0)
	assert_eq(int(forecast.get_meta("edge_count")), FlowOverlay.MAX_EDGES)
	assert_true(view.get_node("RecentFlow").get_child_count() <= 2, "natural/pump batches cap actual-flow draw submissions")
	var instance_count: int = 0
	for batch: MultiMeshInstance3D in view.get_node("RecentFlow").get_children():
		instance_count += batch.multimesh.instance_count
	assert_true(instance_count > 0 and instance_count <= FlowOverlay.MAX_EDGES)
	view.free()
