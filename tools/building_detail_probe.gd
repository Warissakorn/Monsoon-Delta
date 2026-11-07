extends SceneTree
## Rendered architecture fixtures, never a player save or legal playthrough.
## DISPLAY=:1 godot --path . --audio-driver Dummy --resolution 1280x720 \
##   --script res://tools/building_detail_probe.gd -- --out-dir=work/buildings

var _out_dir: String = "res://work/buildings"
var _board: BoardView
var _camera: Camera3D
var _atmosphere: DeltaAtmosphere
var _caption: Label
var _checks: Dictionary = {}
var _captures: Array[Dictionary] = []
var _failed: bool = false
var _coords: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
var _names: Array[String] = ["house", "stilt-house", "raft-house", "hall", "granary"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=")
	if DisplayServer.get_name() == "headless":
		printerr("Architecture capture requires a rendering display.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1280, 720)
	_atmosphere = DeltaAtmosphere.new()
	root.add_child(_atmosphere)
	_atmosphere.set_reduced_motion(true)
	_atmosphere.set_rain(false)
	_board = BoardView.new()
	_board.set_reduced_motion(true)
	root.add_child(_board)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	root.add_child(_camera)
	var layer: CanvasLayer = CanvasLayer.new()
	root.add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(28, 22)
	_caption.add_theme_font_override("font", load("res://assets/fonts/NotoSansThai.ttf"))
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color("f4efdb"))
	_caption.add_theme_color_override("font_shadow_color", Color("122b30"))
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_caption)
	var state: GameState = _fixture()
	var before: Dictionary = state.to_dict()
	_board.set_state(state)
	_board._life_view.hide()
	var center: Vector3 = Hex.to_world(Vector2i.ZERO, 2) + Vector3(0.0, 0.3, 0.6)
	_aim(center, 6.5)
	await _capture("village-dry", "บ้านและอาคารหมู่บ้าน · ฤดูแล้ง")
	for index: int in range(_coords.size()):
		_isolate(state, _coords[index])
		_aim(Hex.to_world(_coords[index], 2) + Vector3.UP * 0.55, 2.4)
		await _capture(_names[index], _names[index])
	_check("render_did_not_change_state_or_rng", state.to_dict() == before)
	_board.set_state(state)
	_check("refresh_did_not_change_state_or_rng", state.to_dict() == before)
	state.year = 3
	state.stats["reached_year"] = 3
	state.settlement_progress["condition"] = "thriving"
	state.settlement_progress["candidate"] = "thriving"
	for record: Dictionary in state.settlement_progress["buildings"].values():
		record["stage"] = 2
	before = state.to_dict()
	_board.refresh()
	_aim(center, 6.5)
	await _capture("village-developed", "หมู่บ้านพัฒนาแล้ว · อายุสองปี")
	_check("development_is_read_only", state.to_dict() == before)
	state.settlement_progress["condition"] = "struggling"
	state.settlement_progress["candidate"] = "struggling"
	_isolate(state, _coords[0])
	_aim(Hex.to_world(_coords[0], 2) + Vector3.UP * 0.55, 2.4)
	await _capture("house-weathered", "บ้านเก่า · แผ่นซ่อมบำรุง")
	state.turn = 4
	state.get_tile(_coords[2]).water = 1.5
	_board.set_state(state)
	_atmosphere.set_rain(true)
	_aim(center, 6.5)
	await _capture("village-rain", "บ้านและอาคารหมู่บ้าน · ฤดูฝน")
	_aim(Hex.to_world(_coords[2], 2) + Vector3.UP * 1.0, 2.8)
	_isolate(state, _coords[2])
	await _capture("raft-high-water", "เรือนแพ · ระดับน้ำสูง")
	_board.set_state(state)
	var session: GameSession = GameSession.new()
	session.state = state
	session.save_path = _out_dir.path_join("fixture-checkpoint.json")
	_check("isolated_checkpoint", session.checkpoint().is_empty())
	var disk: PackedByteArray = FileAccess.get_file_as_bytes(session.save_path)
	var loaded: Dictionary = SaveIO.load_game(session.save_path)
	_check("exact_checkpoint_load", loaded["error"].is_empty() and loaded["state"] != null and loaded["state"].to_dict() == state.to_dict())
	before = state.to_dict()
	_board.set_reduced_motion(false)
	_board.set_activity_paused(true)
	_board.set_preview(GameFlow.preview(state))
	await process_frame
	_check("preview_and_motion_are_read_only", state.to_dict() == before)
	_check("view_did_not_write_checkpoint", FileAccess.get_file_as_bytes(session.save_path) == disk)
	var fine_details: MeshInstance3D = _board.get("_fine_details") as MeshInstance3D
	if is_instance_valid(fine_details):
		_camera.size = 22.5
		await process_frame
		await process_frame
		_check("overview_hides_fine_details", not fine_details.visible)
		_camera.size = 12.0
		await process_frame
		await process_frame
		_check("zoom_restores_fine_details", fine_details.visible)
	var evidence: Dictionary = {"fixture": true, "engine": Engine.get_version_info()["string"], "display": DisplayServer.get_name(), "checks": _checks, "captures": _captures, "note": "Authored architecture fixtures; not human playtesting or a hardware performance benchmark."}
	var file: FileAccess = FileAccess.open(_out_dir.path_join("observations.json"), FileAccess.WRITE)
	if file == null:
		_failed = true
	else:
		file.store_string(JSON.stringify(evidence, "  ", true, true))
		file.close()
	print("BUILDING_DETAIL_PROBE ", JSON.stringify(_checks))
	quit(1 if _failed else 0)


func _fixture() -> GameState:
	var state: GameState = GameFlow.new_game({"seed": 42, "living_village": true, "run_mode": "long"})
	for tile: Tile in state.tiles:
		tile.elevation = 2
		tile.water = 0.0
		tile.feature = C.Feature.NONE
		tile.building = C.Building.NONE
		tile.is_source = false
		tile.is_sea = false
		tile.is_river = false
		tile.start_house = false
	var kinds: Array[int] = [C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.RAFT_HOUSE, C.Building.HALL, C.Building.GRANARY]
	for index: int in range(_coords.size()):
		state.get_tile(_coords[index]).building = kinds[index]
	state.get_tile(_coords[2]).water = 0.45
	state.food = 30
	SettlementProgress.reconcile(state)
	return state


func _aim(at: Vector3, size: float) -> void:
	_camera.position = at + Vector3(2.0, 2.6, 4.0) * 3.0
	_camera.look_at(at)
	_camera.size = size


func _isolate(source: GameState, coord: Vector2i) -> void:
	var isolated: GameState = source.duplicate_state()
	for tile: Tile in isolated.tiles:
		if tile.coord != coord:
			tile.building = C.Building.NONE
	SettlementProgress.reconcile(isolated)
	_board.set_state(isolated)
	_board._life_view.hide()


func _capture(id: String, title: String) -> void:
	_caption.text = title + "\nCONTROLLED FIXTURE · " + id
	for frame: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	_check(id + "_image", root.get_texture().get_image().save_png(_out_dir.path_join(id + ".png")) == OK)
	_captures.append({"id": id, "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})


func _check(id: String, result: bool) -> void:
	_checks[id] = result
	if not result:
		_failed = true
		printerr("FAIL ", id)
