extends TestCase
## Soil and selected-field indicators read committed state and exact forecasts.


func _state(ruleset: String = "moisture_v1", moisture: int = 2) -> GameState:
	var result: GameState = TestMaps.small(1, 1)
	result.ruleset = ruleset
	var paddy: Tile = result.get_tile(Vector2i.ZERO)
	paddy.feature = C.Feature.PADDY
	paddy.soil_moisture = moisture
	return result


func _has_baked_color(board: BoardView, color: Color) -> bool:
	for child: Node in board._tiles_root.get_children():
		if not child is MeshInstance3D or not child.name.begins_with("Baked_"):
			continue
		for surface: int in range(child.mesh.get_surface_count()):
			var colors: PackedColorArray = child.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			for tint: Color in colors:
				if absf(tint.r - color.r) < 0.005 and absf(tint.g - color.g) < 0.005 and absf(tint.b - color.b) < 0.005:
					return true
	return false


func test_retained_moisture_darkens_actual_baked_paddy_soil_at_each_level() -> void:
	var state: GameState = _state()
	var board: BoardView = BoardView.new()
	var brightness: Array[float] = []
	for moisture: int in range(3):
		state.get_tile(Vector2i.ZERO).soil_moisture = moisture
		board.set_state(state)
		var field: Node3D = board._tiles_root.get_node("Hex_0_0/Paddy") as Node3D
		var soil: Color = field.get_meta("soil_color")
		brightness.append(soil.get_luminance())
		assert_true(_has_baked_color(board, soil), "the soil tint reaches rendered geometry, not just metadata")
	assert_true(brightness[0] > brightness[1] and brightness[1] > brightness[2])
	assert_eq(board._moisture_status_root.get_child_count(), 0, "unselected fields add no floating badges")
	board.free()


func test_selected_and_hovered_living_fields_have_two_slots_without_duplicate_badges() -> void:
	var state: GameState = _state()
	var second: Tile = state.get_tile(Vector2i(1, 0))
	second.feature = C.Feature.PADDY
	second.soil_moisture = 1
	var board: BoardView = BoardView.new()
	board.set_state(state)
	board.select(Vector2i.ZERO)
	board.hover(Vector2i.ZERO)
	assert_eq(board._moisture_status_root.get_child_count(), 1)
	var status: Node3D = board._moisture_status_root.get_node("Moisture_0_0") as Node3D
	var label: Label3D = status.get_node("Current") as Label3D
	assert_eq(label.text, "2/2")
	for index: int in range(2):
		var drop: Sprite3D = label.get_node("Drop%d" % index) as Sprite3D
		assert_true(drop.texture != null and drop.get_meta("filled"))
	board.hover(second.coord)
	assert_eq(board._moisture_status_root.get_child_count(), 2)
	label = board._moisture_status_root.get_node("Moisture_1_0/Current") as Label3D
	assert_true(label.get_node("Drop0").get_meta("filled"))
	assert_true(not label.get_node("Drop1").get_meta("filled"))
	assert_eq(label.text, "1/2")
	board.clear_hover()
	assert_eq(board._moisture_status_root.get_child_count(), 1)
	board.select(BoardView.NO_COORD)
	assert_eq(board._moisture_status_root.get_child_count(), 0)
	board.free()


func test_forecast_slots_and_moisture_yield_icon_do_not_change_actual_soil_or_state() -> void:
	var state: GameState = _state()
	var before: Dictionary = state.to_dict()
	var rng_before: int = state.rng.state
	var prediction: Dictionary = GameFlow.preview(state)
	var predicted_before: Dictionary = (prediction["state"] as GameState).to_dict()
	var report_before: Dictionary = (prediction["report"] as TurnReport).to_dict()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	board.select(Vector2i.ZERO)
	var color: Color = board._tiles_root.get_node("Hex_0_0/Paddy").get_meta("soil_color")
	board.set_preview(prediction)
	var current: Label3D = board._moisture_status_root.get_node("Moisture_0_0/Current") as Label3D
	var forecast: Label3D = board._moisture_status_root.get_node("Moisture_0_0/Forecast") as Label3D
	assert_eq(current.text, "2/2")
	assert_eq(forecast.text, "1/2")
	assert_eq((forecast.get_node("Arrow") as Label3D).text, "→")
	assert_true(forecast.get_meta("forecast"))
	assert_eq(board._tiles_root.get_node("Hex_0_0/Paddy").get_meta("soil_color"), color)
	assert_eq(board._preview_root.get_node("PaddyGain_0_0").get_meta("icon"), "moisture")
	assert_eq(board._preview_root.get_child_count(), 1, "one stored-rice gain is represented once")
	assert_eq(state.to_dict(), before)
	assert_eq(state.rng.state, rng_before)
	assert_eq((prediction["state"] as GameState).to_dict(), predicted_before)
	assert_eq((prediction["report"] as TurnReport).to_dict(), report_before)
	board.set_preview({}, false)
	assert_true(not board._moisture_status_root.get_node("Moisture_0_0").has_node("Forecast"))
	assert_eq(board._moisture_status_root.get_child_count(), 1, "hiding the forecast retains actual soil status")
	board.free()


func test_reservoir_rice_uses_ordinary_yield_icon_without_a_second_moisture_gain() -> void:
	var state: GameState = _state()
	var reservoir: Tile = state.get_tile(Vector2i(1, 0))
	reservoir.building = C.Building.RESERVOIR
	reservoir.elevation = 0
	reservoir.water = 1.0
	var prediction: Dictionary = GameFlow.preview(state)
	var board: BoardView = BoardView.new()
	board.set_state(state)
	board.set_preview(prediction)
	assert_eq(board._preview_root.get_node("PaddyGain_0_0").get_meta("icon"), "paddy")
	var gains: int = 0
	for child: Node in board._preview_root.get_children():
		if child.name.begins_with("PaddyGain_"):
			gains += 1
	assert_eq(gains, 1)
	board.free()


func test_death_demolition_undo_and_state_replacement_remove_stale_moisture_badges() -> void:
	var state: GameState = _state()
	var board: BoardView = BoardView.new()
	board.set_state(state)
	board.select(Vector2i.ZERO)
	assert_eq(board._moisture_status_root.get_child_count(), 1)
	assert_eq(GameFlow.apply_command(state, Command.new("demolish", Vector2i.ZERO)), "")
	board.refresh()
	assert_eq(board._moisture_status_root.get_child_count(), 0)
	state = GameFlow.undo(state)
	board.set_state(state)
	board.select(Vector2i.ZERO)
	assert_eq(board._moisture_status_root.get_node("Moisture_0_0").get_meta("soil_moisture"), 2)
	state.get_tile(Vector2i.ZERO).paddy_dead = true
	state.get_tile(Vector2i.ZERO).soil_moisture = 0
	board.refresh()
	assert_eq(board._moisture_status_root.get_child_count(), 0)
	board.set_state(null)
	assert_eq(board._moisture_status_root.get_child_count(), 0)
	board.free()


func test_legacy_soil_and_dead_fields_ignore_unsupported_moisture_without_repairing_it() -> void:
	var legacy: GameState = _state("legacy", 2)
	var board: BoardView = BoardView.new()
	board.set_state(legacy)
	board.select(Vector2i.ZERO)
	assert_eq(board._moisture_status_root.get_child_count(), 0)
	var dry_soil: Color = board._tiles_root.get_node("Hex_0_0/Paddy").get_meta("soil_color")
	legacy.get_tile(Vector2i.ZERO).soil_moisture = 0
	board.refresh()
	assert_eq(board._tiles_root.get_node("Hex_0_0/Paddy").get_meta("soil_color"), dry_soil)
	legacy.ruleset = "moisture_v1"
	legacy.get_tile(Vector2i.ZERO).soil_moisture = 2
	legacy.get_tile(Vector2i.ZERO).paddy_dead = true
	board.refresh()
	assert_eq(board._tiles_root.get_node("Hex_0_0/Paddy").get_meta("soil_color"), dry_soil)
	assert_eq(board._moisture_status_root.get_child_count(), 0)
	assert_eq(legacy.get_tile(Vector2i.ZERO).soil_moisture, 2, "the view never fixes invalid input by changing it")
	board.free()


func test_combined_ruleset_keeps_brace_geometry_and_moisture_through_reduced_motion() -> void:
	var state: GameState = _state("bracing_moisture_v1")
	var house: Tile = state.get_tile(Vector2i(1, 0))
	house.building = C.Building.HOUSE
	assert_eq(GameFlow.apply_command(state, Command.new("brace_house", house.coord)), "")
	var before: Dictionary = state.to_dict()
	var rng_before: int = state.rng.state
	var board: BoardView = BoardView.new()
	board.set_state(state)
	board.select(Vector2i.ZERO)
	for reduced: bool in [true, false, true]:
		board.set_reduced_motion(reduced)
		board.set_activity_paused(true)
		board.refresh()
		assert_eq(board._moisture_status_root.get_child_count(), 1)
		assert_eq(board._brace_status_root.get_child_count(), 1)
		assert_true(board._tiles_root.has_node("Hex_1_0/House/EmergencyBracing"))
		board.set_activity_paused(false)
	assert_eq(state.to_dict(), before)
	assert_eq(state.rng.state, rng_before)
	board.free()
