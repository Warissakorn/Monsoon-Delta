extends TestCase
## Per-tile explanations must use the resolved report without changing the run.

const PATH: String = "user://tests/tile_preview/checkpoint.json"


func before_each() -> void:
	Localization.setup("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	SaveIO.delete_save(PATH)


func _state(water: float = 0.3) -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 1})
	for tile: Tile in state.tiles:
		tile.elevation = 3
		tile.water = water
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
	state.tiles[0].building = C.Building.HALL
	for index: int in range(1, 4):
		state.tiles[index].building = C.Building.HOUSE
	state.turn = C.DRY_TURNS + 1
	return state


func _screen(state: GameState) -> GameScreen:
	var screen: GameScreen = GameScreen.new()
	screen.session = GameSession.new()
	screen.session.save_path = PATH
	screen.session.state = state
	assert_eq(screen.session.checkpoint(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.set_process(false)
	screen.set_process_unhandled_input(false)
	return screen


func _close(screen: GameScreen) -> void:
	screen.free()
	SaveIO.delete_save(PATH)


func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


func _marker(prefix: String, tile: Tile) -> String:
	return "Preview/%s_%d_%d" % [prefix, tile.q, tile.r]


func test_building_consequences_match_real_damage_and_keep_raft_safe() -> void:
	var state: GameState = _state(0.7)
	state.tiles[2].building = C.Building.STILT_HOUSE
	state.tiles[3].building = C.Building.GRANARY
	state.tiles[4].building = C.Building.RAFT_HOUSE
	var screen: GameScreen = _screen(state)
	var original: Dictionary = state.to_dict()
	var resolved: GameState = state.duplicate_state()
	var report: TurnReport = GameFlow.end_turn(resolved)
	assert_eq(report.destroyed.size(), 3)
	for index: int in [1, 2, 3]:
		var tile: Tile = state.tiles[index]
		screen.hovered_coord = tile.coord
		screen._update_inspector()
		var name: String = _tr("building." + C.enum_name(C.Building, tile.building))
		assert_true(screen._tile_note.text.contains(_tr("tile.destroyed_forecast") % name))
		assert_true(screen._tile_note.text.contains("Damage starts at level"))
		assert_eq(resolved.get_tile(tile.coord).building, C.Building.NONE)
	assert_true(screen._tile_preview_lines(state.tiles[4]).is_empty(), "raft survives this flood")
	assert_eq(resolved.get_tile(state.tiles[4].coord).building, C.Building.RAFT_HOUSE)
	assert_eq(state.to_dict(), original)
	_close(screen)


func test_hall_warning_distinguishes_wet_from_losing_and_keeps_other_damage() -> void:
	var state: GameState = _state()
	state.tiles[8].feature = C.Feature.PADDY
	state.tiles[9].building = C.Building.FISH_TRAP
	var screen: GameScreen = _screen(state)
	var hall: Tile = state.tiles[0]
	assert_true(screen.prediction["report"].hall_wet)
	assert_eq(screen.prediction["report"].outcome, C.Outcome.NONE)
	assert_true(screen._tile_preview_lines(hall).is_empty())
	assert_true(not screen.board.has_node(_marker("HallRisk", hall)))
	for tile: Tile in state.tiles:
		tile.water = 0.7
	screen.refresh_state()
	var report: TurnReport = screen.prediction["report"]
	assert_eq(report.outcome, C.Outcome.LOSE_HALL)
	assert_true(screen._tile_preview_lines(hall).has(_tr("preview.lose_hall")))
	assert_eq((screen.board.get_node(_marker("HallRisk", hall)) as Label3D).get_meta("icon"), "hall")
	assert_true(screen._tile_preview_lines(state.tiles[1])[0].contains("destroyed"))
	assert_true(screen._tile_preview_lines(state.tiles[8]).has(_tr("tile.paddy_dies")))
	assert_true(not screen._tile_preview_lines(state.tiles[8]).has(_tr("tile.paddy_gain")))
	assert_true(screen._tile_preview_lines(state.tiles[9]).is_empty(), "hall loss skips fish production")
	assert_true(not screen.board.has_node(_marker("FishFood", state.tiles[9])))
	_close(screen)


func test_fish_text_and_marker_allocate_resolved_total_only_to_wet_traps() -> void:
	var state: GameState = _state()
	state.year_mods.assign([
		{"key": "fish_trap_yield", "op": "set", "value": 2},
		{"key": "fish_trap_multiplier", "op": "set", "value": 1.5},
	])
	state.recompute_mods()
	for index: int in [8, 9, 10]:
		state.tiles[index].building = C.Building.FISH_TRAP
	state.tiles[10].elevation = 4
	state.tiles[10].water = 0.0
	var screen: GameScreen = _screen(state)
	assert_eq(screen.prediction["report"].fish_food, 6)
	for index: int in [8, 9]:
		var tile: Tile = state.tiles[index]
		assert_true(screen._tile_preview_lines(tile).has(_tr("tile.fish_gain") % 3))
		assert_eq((screen.board.get_node(_marker("FishFood", tile)) as Label3D).text, "+3")
	assert_true(screen._tile_preview_lines(state.tiles[10]).is_empty())
	assert_true(not screen.board.has_node(_marker("FishFood", state.tiles[10])))
	assert_eq(screen.prediction["state"].food, state.food + 6)
	_close(screen)


func test_rain_and_irrigation_explain_yield_without_promising_immediate_food() -> void:
	for rain: bool in [true, false]:
		var state: GameState = _state(0.3 if rain else 0.0)
		var crop: Tile = state.tiles[8]
		crop.feature = C.Feature.PADDY
		if not rain:
			state.turn = 1
			var reservoir: Tile = state.neighbors(crop)[0]
			reservoir.building = C.Building.RESERVOIR
			reservoir.elevation = -3
			reservoir.water = 0.75
		var screen: GameScreen = _screen(state)
		assert_true(screen.prediction["report"].paddy_gains.has(crop.coord))
		assert_true(screen._tile_preview_lines(crop).has(_tr("tile.paddy_gain")))
		assert_eq((screen.board.get_node(_marker("PaddyGain", crop)) as Label3D).text, "+1")
		assert_eq(screen.prediction["state"].food, state.food, "crop yield waits for harvest")
		crop.paddy_dead = true
		screen.refresh_state()
		assert_true(not screen._tile_preview_lines(crop).has(_tr("tile.paddy_gain")))
		assert_true(not screen.board.has_node(_marker("PaddyGain", crop)))
		_close(screen)


func test_preview_toggle_and_undo_clear_stale_consequences_without_writing_save() -> void:
	var state: GameState = _state(0.7)
	assert_eq(GameFlow.apply_command(state, Command.new("fill", state.tiles[20].coord)), "")
	var screen: GameScreen = _screen(state)
	var before: Dictionary = state.to_dict()
	var history: Array[Dictionary] = state.undo.snapshots()
	var predicted: Dictionary = screen.prediction["state"].to_dict()
	var report: Dictionary = screen.prediction["report"].to_dict()
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	for tile: Tile in state.tiles:
		screen.hovered_coord = tile.coord
		screen._update_inspector()
	assert_true(screen._preview_legend.visible)
	screen.toggle_preview()
	assert_true(not screen._preview_legend.visible)
	assert_eq(screen.board.get_node("Preview").get_child_count(), 0)
	assert_true(screen._tile_preview_lines(state.tiles[0]).is_empty())
	screen.toggle_preview()
	assert_true(screen._preview_legend.visible)
	assert_eq(state.to_dict(), before)
	assert_eq(state.undo.snapshots(), history)
	assert_eq(screen.prediction["state"].to_dict(), predicted)
	assert_eq(screen.prediction["report"].to_dict(), report)
	assert_eq(FileAccess.get_file_as_bytes(PATH), saved)
	screen.undo_command()
	assert_true(screen.session.state != state)
	assert_true(screen._tile_preview_lines(screen.session.state.tiles[0]).has(_tr("preview.lose_hall")))
	for tile: Tile in screen.session.state.tiles:
		tile.water = 0.0
	screen.refresh_state()
	assert_true(not screen.board.has_node(_marker("HallRisk", screen.session.state.tiles[0])))
	assert_true(screen._tile_preview_lines(screen.session.state.tiles[0]).is_empty())
	screen.session.state.phase = C.Phase.HARVEST
	screen.refresh_state()
	assert_true(not screen._preview_legend.visible, "no turn preview during annual summary")
	_close(screen)


func test_legend_and_inspector_are_translated_in_both_languages() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var state: GameState = _state(0.7)
		var screen: GameScreen = _screen(state)
		screen.hovered_coord = state.tiles[0].coord
		screen._update_inspector()
		assert_true(screen._tile_note.text.contains(_tr("preview.lose_hall")))
		assert_true(screen._tile_note.text.contains(_tr("tile.flood_limit") % [2, _tr("level.2")]))
		assert_eq(screen._preview_legend.text, _tr("preview.legend"))
		assert_true(not screen._preview_legend.text.contains("R+1"), "legend uses localized icon names")
		assert_true(screen._preview_legend.text.length() > 20)
		assert_true(not screen._tile_note.text.contains("tile."))
		_close(screen)
	Localization.setup("en")
