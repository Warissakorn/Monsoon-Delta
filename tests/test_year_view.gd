extends TestCase


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _board(year: Dictionary) -> YearBoard3D:
	var result: YearBoard3D = YearBoard3D.new()
	result.size = Vector2(900, 600)
	_root().add_child(result)
	result.model = year
	result.selected = year["structures"].find("hall")
	result.update_view()
	return result


func test_presentation_is_a_detached_copy_for_every_supported_year_ruleset() -> void:
	for year: Dictionary in [YearGame.new_game(42), YearGame.new_expanded(42), YearGame.new_campaign(42, "rice", "food", "fisher", 7)]:
		var before: Dictionary = year.duplicate(true)
		var state: GameState = YearPresentation.board(year)
		assert_eq(state.tiles.size(), year["structures"].size())
		assert_eq(state.population, year["population"])
		state.tiles[0].water += 1.0
		state.population += 1
		assert_eq(year, before)
		assert_true(YearCheckpoint.valid(year))


func test_real_water_recording_is_optional_and_matches_unrecorded_half_gate_resolution() -> void:
	var year: Dictionary = YearGame.new_campaign(42, "none", "water")
	var gate: int = YearStrategy.target(year, "build_gate")
	year["structures"][gate] = "gate"
	year["health"][gate] = 100
	year["board"]["tiles"][gate]["building"] = "gate"
	year["board"]["tiles"][gate]["gate_open"] = true
	year["upgrades"][gate] = "gate_control"
	year["gate_half"][gate] = true
	var recorded: Dictionary = year.duplicate(true)
	var reports: Array[TurnReport] = []
	assert_eq(YearGame.advance(recorded, 7, reports), YearGame.advance(year, 7))
	assert_eq(recorded, year)
	assert_true(not reports.is_empty())
	assert_true(not reports[0].flow_edges.is_empty())
	for edges: PackedFloat32Array in reports[0].flow_edges:
		assert_eq(edges.size(), 127 * 6)
	assert_true(YearCheckpoint.valid(year))


func test_3d_controls_targets_and_preview_preserve_authoritative_year_and_weather() -> void:
	var year: Dictionary = YearGame.new_campaign(73, "none", "water")
	var before: Dictionary = year.duplicate(true)
	var board: YearBoard3D = _board(year)
	board.set_reduced_motion(true)
	var state: GameState = board.village.state
	var hall: int = board.selected
	board.targets.assign([hall])
	var predicted: Dictionary = YearGame.preview(year)["state"]
	predicted["health"][hall] -= 10
	board.predicted = predicted
	board.update_view()
	assert_true(board.village.state == state, "selection-only refresh reuses the rendered state")
	assert_eq(board.village.get_node("Targets").get_child_count(), 1)
	assert_true(board.village.get_node("Preview").has_node("YearDamage_" + str(hall)))
	board.rotate_view(1)
	board.zoom_by(1.5)
	board.focus_selected()
	board.toggle_labels()
	var draft: Dictionary = board.view_draft()
	board.fit_map()
	board.restore_view_draft(draft)
	assert_eq(board.view_draft(), draft)
	assert_eq(year, before)
	assert_eq(board.village.state.tiles[hall].building, C.Building.HALL)
	var flows: Array[TurnReport] = []
	YearGame.advance(before, 1, flows)
	board.show_actual_flow(flows)
	assert_true(board.village._actual_flow_report == flows.back(), "committed flow uses the recorded report")
	board.village.finish_actual_flow()
	board.predicted = {}
	board.update_view()
	assert_true(not board.village.get_node("Preview").has_node("YearDamage_" + str(hall)))
	board.free()


func test_workplace_meshes_and_damaged_health_never_change_year_building_ids() -> void:
	var year: Dictionary = YearGame.new_expanded(42)
	var used: Array[int] = []
	for kind: String in ["sawmill", "kiln", "workshop", "camp"]:
		var index: int = -1
		for candidate: int in range(127):
			if candidate not in used and year["structures"][candidate] == "" and not year["board"]["tiles"][candidate]["is_sea"]:
				index = candidate
				break
		used.append(index)
		year["structures"][index] = kind
		year["health"][index] = 70
	var before: Dictionary = year.duplicate(true)
	var board: YearBoard3D = _board(year)
	board.toggle_labels()
	var labels: Node3D = board.village.get_node("ElevationLabels")
	assert_true(labels.visible)
	assert_true(labels.get_child_count() > 127)
	for index: int in used:
		assert_eq(board.village.state.tiles[index].building, C.Building.GRANARY, "view-only route anchor is restored after meshing")
	assert_eq(year, before)
	board.free()


func test_year_resource_feedback_tracks_all_materials_and_reduce_motion() -> void:
	var year: Dictionary = YearGame.new_expanded(42)
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.year = year
	_root().add_child(screen)
	var before: Dictionary = YearPresentation.resources(year)
	# Fixture deltas exercise every year material without touching a player file.
	for resource: String in YearGame.resources(year):
		year["resources"][resource] += 2
	screen._refresh()
	screen._show_resource_changes(before)
	for resource: String in YearGame.resources(year):
		assert_eq(screen._resource_feedback.last_changes[resource]["delta"], 2)
	var tokens: int = 0
	for entry: Dictionary in screen._resource_feedback._entries:
		tokens += entry["tokens"].size()
	assert_true(tokens <= ResourceFeedback.MAX_TOKENS)
	screen._resource_feedback.set_reduced_motion(true)
	for entry: Dictionary in screen._resource_feedback._entries:
		assert_true(entry["tokens"].is_empty())
	assert_true(not screen._resource_feedback.mouse_filter == Control.MOUSE_FILTER_STOP)
	screen.free()
