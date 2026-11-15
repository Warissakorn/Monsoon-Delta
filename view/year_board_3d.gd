class_name YearBoard3D
extends YearBoard
## A 3D viewport behind the existing year board interaction contract.

var village: YearVillageView
var rig: CameraRig
var atmosphere: DeltaAtmosphere
var feedback: ActionFeedback
var viewport: SubViewport
var forecast_flow: TurnReport
var labels_visible: bool = false
var _last_model: Dictionary = {}
var _fitted_size: float = 27.0
var _reduced_motion: bool = false
var _suspended: bool = false


func _ready() -> void:
	super._ready()
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var texture: TextureRect = TextureRect.new()
	texture.texture = viewport.get_texture()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(texture)
	atmosphere = DeltaAtmosphere.new()
	viewport.add_child(atmosphere)
	village = YearVillageView.new()
	viewport.add_child(village)
	rig = CameraRig.new()
	viewport.add_child(rig)
	feedback = ActionFeedback.new()
	viewport.add_child(feedback)
	resized.connect(_resize_view)
	mouse_exited.connect(func(): village.clear_hover())
	_resize_view()


func _draw() -> void:
	pass


func _resize_view() -> void:
	if viewport == null:
		return
	viewport.size = Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))
	var radius: float = 6.0 if YearGame.expanded(model) else 4.0
	_fitted_size = maxf(radius * 2.5 + 4.0, (2.0 * radius + 1.0) * Hex.SQRT_3 * size.y / maxf(1.0, size.x)) * 1.12
	_apply_camera()


func _apply_camera() -> void:
	if rig == null:
		return
	rig.get_camera().size = _fitted_size / zoom
	rig._zoom_target = rig.camera.size
	rig.position = Vector3(pan.x, 0.3, pan.y)


func update_view() -> void:
	if village == null or model.is_empty():
		return
	if model != _last_model:
		_last_model = model.duplicate(true)
		village.year = _last_model
		village.set_state(YearPresentation.board(model))
		atmosphere.set_rain(village.state.is_rain())
		# Jobs are visual activity only; they never move gameplay goods or people.
		for job: Dictionary in model["jobs"]:
			if not job["paused"]:
				village.show_command_activity(_activity_id(job["id"]), village.state.tiles[int(job["tile"])].coord)
		_resize_view()
	var coords: Array[Vector2i] = []
	for index: int in targets:
		coords.append(village.state.tiles[index].coord)
	village.set_targets(coords)
	village.select(village.state.tiles[selected].coord if selected >= 0 else BoardView.NO_COORD)
	village.year_predicted = predicted
	var prediction: Dictionary = YearPresentation.preview(model, predicted, forecast_flow)
	village.set_preview(prediction, not predicted.is_empty())
	village.set_labels_visible(labels_visible)


func zoom_by(factor: float, _anchor: Vector2 = Vector2.INF) -> void:
	zoom = clampf(zoom * factor, 1.0, 4.0)
	_apply_camera()


func fit_map() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_resize_view()


func focus_selected() -> void:
	if village == null or village.state == null or selected < 0:
		return
	var at: Vector3 = Hex.to_world(village.state.tiles[selected].coord)
	pan = Vector2(at.x, at.z)
	_apply_camera()


func rotate_view(direction: int) -> void:
	rig.rotate_step(direction)


func toggle_labels() -> void:
	labels_visible = not labels_visible
	village.set_labels_visible(labels_visible)


func center_of(index: int) -> Vector2:
	if village == null or village.state == null:
		return Vector2.ZERO
	var tile: Tile = village.state.tiles[index]
	var at: Vector3 = Hex.to_world(tile.coord)
	at.y = (float(tile.elevation) + maxf(tile.water, 0.0)) * C.HEIGHT_UNIT + 0.03
	return rig.get_camera().unproject_position(at) * size / Vector2(viewport.size)


func pick_index(point: Vector2) -> int:
	if village == null or village.state == null:
		return -1
	var tile: Tile = village.pick(rig.get_camera(), point * Vector2(viewport.size) / size)
	return -1 if tile == null else int(village.state.index[tile.coord])


func _gui_input(event: InputEvent) -> void:
	if _suspended or model.is_empty():
		return
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var scale: float = rig.get_camera().size / maxf(1.0, size.y)
			var movement: Vector3 = Vector3(-event.relative.x, 0, -event.relative.y).rotated(Vector3.UP, rig.rotation.y) * scale
			pan += Vector2(movement.x, movement.z)
			pan = pan.clamp(Vector2(-14, -14), Vector2(14, 14))
			_apply_camera()
			accept_event()
		else:
			var index: int = pick_index(event.position)
			village.hover(village.state.tiles[index].coord if index >= 0 else BoardView.NO_COORD)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_requested.emit()
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var index: int = pick_index(event.position)
			if index >= 0:
				accept_event()
				tile_selected.emit(index)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	village.set_reduced_motion(enabled)
	atmosphere.set_reduced_motion(enabled)
	rig.set_reduced_motion(enabled)
	feedback.set_reduced_motion(enabled)


func set_suspended(enabled: bool) -> void:
	if _suspended == enabled:
		return
	_suspended = enabled
	village.set_activity_paused(enabled)
	atmosphere.set_reduced_motion(enabled or _reduced_motion)
	feedback.set_process(not enabled and not feedback._markers.is_empty())


func show_order(id: String, index: int, error: String = "") -> void:
	if index < 0 or village.state == null:
		return
	var tile: Tile = village.state.tiles[index]
	var at: Vector3 = Hex.to_world(tile.coord, tile.elevation)
	at.y += maxf(0, tile.water) * C.HEIGHT_UNIT
	feedback.show_marker(at, tr(error) if not error.is_empty() else tr("year3d.assigned"), Color("ef8c76") if not error.is_empty() else Color("b8d68b"))


func show_day_changes(before: Dictionary) -> void:
	if before.is_empty() or village.state == null:
		return
	for index: int in range(model["structures"].size()):
		var change: String = ""
		if int(model["health"][index]) < int(before["health"][index]):
			change = tr("year3d.damage") % (int(model["health"][index]) - int(before["health"][index]))
		elif model["structures"][index] != before["structures"][index]:
			change = tr("year.event.work_complete")
		if not change.is_empty():
			var tile: Tile = village.state.tiles[index]
			feedback.show_marker(Hex.to_world(tile.coord, tile.elevation), change, Color("ef8c76") if int(model["health"][index]) < int(before["health"][index]) else Color("b8d68b"))


func view_draft() -> Dictionary:
	return {"zoom": zoom, "pan": pan, "yaw": rig._yaw_target, "labels": labels_visible}


func restore_view_draft(draft: Dictionary) -> void:
	zoom = draft["zoom"]
	pan = draft["pan"]
	rig._yaw_target = draft["yaw"]
	rig.rotation.y = rig._yaw_target
	labels_visible = draft["labels"]
	_apply_camera()
	update_view()


static func _activity_id(id: String) -> String:
	if id == "fish":
		return "fish"
	if id == "clear_land":
		return "demolish"
	if id == "plant_paddy" or id == "harvest":
		return "paddy"
	if id == "gather_wood":
		return "chop"
	if id == "plant_forest":
		return "plant"
	return id if id in ["dig", "fill", "demolish"] else "house"


func set_forecast_flow(report: TurnReport) -> void:
	forecast_flow = report


func show_actual_flow(reports: Array[TurnReport]) -> void:
	if reports.is_empty():
		return
	# Show only the last resolved day, never combine different daily trajectories.
	village.show_actual_flow(reports.back())
	village.show_turn_activity(reports.back())
	village.show_harvest_activity(reports.back().year_harvest_food_by_tile)


func clear_feedback() -> void:
	feedback.clear()


func pan_view(direction: Vector2) -> void:
	var movement: Vector3 = Vector3(direction.x, 0, direction.y).rotated(Vector3.UP, rig.rotation.y)
	pan = (pan + Vector2(movement.x, movement.z)).clamp(Vector2(-14, -14), Vector2(14, 14))
	_apply_camera()
