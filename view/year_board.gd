class_name YearBoard
extends Control
## Read-only 2D hex presentation of the shared water simulation.

signal tile_selected(index: int)
signal cancel_requested()
var model: Dictionary = {}
var selected: int = -1
var targets: Array[int] = []
var predicted: Dictionary = {}
var _radius: float = 30.0
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	resized.connect(queue_redraw)


func zoom_by(factor: float, anchor: Vector2 = Vector2.INF) -> void:
	var before: float = zoom
	zoom = clampf(zoom * factor, 1.0, 3.0)
	if anchor == Vector2.INF:
		anchor = size * 0.5
	pan = anchor - size * 0.5 - (anchor - size * 0.5 - pan) * zoom / before
	queue_redraw()


func fit_map() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()


func focus_selected() -> void:
	if selected < 0 or model.is_empty():
		return
	pan += size * 0.5 - center_of(selected)
	queue_redraw()


func center_of(index: int) -> Vector2:
	var tile: Dictionary = model["board"]["tiles"][index]
	return size * 0.5 + pan + Vector2(Hex.SQRT_3 * (float(tile["q"]) + float(tile["r"]) * 0.5), float(tile["r"]) * 1.5) * _radius


func polygon_of(index: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for corner: int in range(6):
		var angle: float = deg_to_rad(60.0 * corner - 30.0)
		points.append(center_of(index) + Vector2(cos(angle), sin(angle)) * (_radius - 2.0))
	return points


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_requested.emit()
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_by(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2, event.position)
		accept_event()
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		pan += event.relative
		queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not model.is_empty():
		for index: int in range(model["structures"].size()):
			if Geometry2D.is_point_in_polygon(event.position, polygon_of(index)):
				accept_event()
				tile_selected.emit(index)
				return


func _draw() -> void:
	if model.is_empty():
		return
	var radius: int = 6 if YearGame.expanded(model) else 4
	_radius = maxf(8.0, minf((size.x - 24.0) / ((2 * radius + 1) * Hex.SQRT_3), (size.y - 24.0) / (3 * radius + 2))) * zoom
	var font: Font = get_theme_default_font()
	var font_size: int = clampi(roundi(_radius * 0.42), 10, 24)
	for index: int in range(model["structures"].size()):
		var tile: Dictionary = model["board"]["tiles"][index]
		var water: float = float(tile["water"])
		var polygon: PackedVector2Array = polygon_of(index)
		var land: Color = Color("#476b4f").lightened(clampf(float(tile["elevation"]) * 0.055, -0.15, 0.3))
		if tile["feature"] == "forest":
			land = Color("#285741")
		elif tile["feature"] == "paddy":
			land = Color("#75834a")
		if tile["is_sea"]:
			land = Color("#194c66")
		elif water > 0.04:
			land = land.lerp(Color("#2584a2"), clampf(water, 0.15, 0.9))
		draw_colored_polygon(polygon, land)
		var outline: PackedVector2Array = polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color("#152d32"), 1.5, true)
		if index in targets:
			draw_polyline(outline, Color("#9bd0a1"), 2.0, true)
		if not predicted.is_empty() and int(predicted["health"][index]) < int(model["health"][index]):
			draw_polyline(outline, Color("#e77962"), 3.0, true)
		if selected == index:
			draw_polyline(outline, Color("#f2d58e"), 4.0, true)
		var structure: String = model["structures"][index]
		var key: String = structure
		if key.is_empty():
			key = String(tile["feature"])
			if not String(model["deposits"][index]).is_empty():
				key = model["deposits"][index]
			elif tile["is_source"]:
				key = "source"
			elif tile["is_sea"]:
				key = "sea"
			elif tile["is_river"]:
				key = "river"
		var label: String = tr("year.site." + key)
		var center: Vector2 = center_of(index)
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, center + Vector2(-width * 0.5, 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#f1ead7"))
		var detail: String = "%d · %.2f" % [int(tile["elevation"]), water]
		var small: int = maxi(9, font_size - 3)
		width = font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		draw_string(font, center + Vector2(-width * 0.5, _radius * 0.43), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color("#d3dfdb"))
		if not structure.is_empty():
			draw_rect(Rect2(center + Vector2(-_radius * 0.45, -_radius * 0.45), Vector2(_radius * 0.9, 4)), Color("#223431"))
			draw_rect(Rect2(center + Vector2(-_radius * 0.45, -_radius * 0.45), Vector2(_radius * 0.9 * float(model["health"][index]) / 100.0, 4)), Color("#d6b56e"))


func update_view() -> void:
	queue_redraw()


func set_reduced_motion(_enabled: bool) -> void:
	pass


func set_suspended(_enabled: bool) -> void:
	pass


func show_order(_id: String, _index: int, _error: String = "") -> void:
	pass


func show_day_changes(_before: Dictionary) -> void:
	pass


func view_draft() -> Dictionary:
	return {"zoom": zoom, "pan": pan}


func restore_view_draft(draft: Dictionary) -> void:
	zoom = draft["zoom"]
	pan = draft["pan"]
	update_view()


func set_forecast_flow(_report: TurnReport) -> void:
	pass


func show_actual_flow(_reports: Array[TurnReport]) -> void:
	pass


func clear_feedback() -> void:
	pass
