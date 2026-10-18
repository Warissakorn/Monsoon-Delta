class_name FlowView
extends Node3D

signal actual_finished

## Read-only water transfers. Forecasts use dashed amber arrows; a committed
## turn briefly sends pale streaks along the actual recorded edges.
const MAX_EDGES: int = 48
const MIN_TRANSFER: float = 0.001
const RECENT_SECONDS: float = 2.6

var _state: GameState
var _prediction: Dictionary = {}
var _preview_enabled: bool = true
var _reduced_motion: bool = false
var _paused: bool = false
var _preview_root: Node3D
var _recent_root: Node3D
var _recent_report: TurnReport
var _recent_markers: Array[Dictionary] = []
var _elapsed: float = 0.0
var _arrow: ArrayMesh
var _dash: BoxMesh
var _materials: Dictionary = {}


func _ready() -> void:
	_ensure_nodes()
	set_process(not _recent_markers.is_empty())


func set_state(next_state: GameState) -> void:
	clear()
	_state = next_state


func set_preview(prediction: Dictionary, enabled: bool = true) -> void:
	_prediction = prediction
	_preview_enabled = enabled
	_refresh_preview()


func show_report(report: TurnReport, current_state: GameState) -> void:
	_ensure_nodes()
	_state = current_state
	_recent_report = report
	_elapsed = 0.0
	_refresh_recent()


func is_showing_actual() -> bool:
	return not _recent_markers.is_empty()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if _recent_report != null:
		_refresh_recent()


func set_paused(enabled: bool) -> void:
	_paused = enabled


func clear() -> void:
	_ensure_nodes()
	_clear_root(_preview_root)
	_clear_root(_recent_root)
	_prediction = {}
	_recent_report = null
	_recent_markers.clear()
	_elapsed = 0.0
	set_process(false)


## Net natural transfer per edge, with uphill pumps kept separate. Combining
## depth snapshots cannot recover these movements or the sea's boundary sink.
static func transfers(state: GameState, report: TurnReport) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state == null or report == null:
		return result
	var count: int = state.tiles.size()
	var sums: Dictionary = {}
	for iteration: PackedFloat32Array in report.flow_edges:
		if iteration.size() != count * 6:
			continue
		for index: int in count:
			for direction: int in 6:
				var amount: float = iteration[index * 6 + direction]
				if not is_finite(amount) or amount <= 0.0:
					continue
				var neighbor: Tile = state.neighbor_in_dir(state.tiles[index], direction)
				if neighbor == null:
					continue
				var other: int = int(state.index[neighbor.coord])
				var key: int = mini(index, other) * count + maxi(index, other)
				sums[key] = float(sums.get(key, 0.0)) + (amount if index < other else -amount)
	for key: int in sums:
		var amount: float = float(sums[key])
		if absf(amount) < MIN_TRANSFER:
			continue
		var first: int = key / count
		var second: int = key % count
		result.append({"from": first if amount > 0.0 else second,
			"to": second if amount > 0.0 else first, "amount": absf(amount), "pump": false})
	for transfer: Dictionary in report.wheel_transfers:
		var first: int = int(transfer.get("from", -1))
		var second: int = int(transfer.get("to", -1))
		var amount: float = float(transfer.get("amount", 0.0))
		if first >= 0 and first < count and second >= 0 and second < count and is_finite(amount) and amount >= MIN_TRANSFER:
			result.append({"from": first, "to": second, "amount": amount, "pump": true})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.amount), float(b.amount)):
			return float(a.amount) > float(b.amount)
		if int(a.from) != int(b.from):
			return int(a.from) < int(b.from)
		if int(a.to) != int(b.to):
			return int(a.to) < int(b.to)
		return bool(a.pump) and not bool(b.pump))
	return result


## Values are board-local x/z velocities, including incoming movement. The
## result is bounded and can drive distinct per-tile Compatibility materials.
static func tile_velocities(state: GameState, report: TurnReport) -> Dictionary:
	var result: Dictionary = {}
	for transfer: Dictionary in transfers(state, report):
		var first: Tile = state.tiles[int(transfer.from)]
		var second: Tile = state.tiles[int(transfer.to)]
		var difference: Vector3 = Hex.to_world(second.coord) - Hex.to_world(first.coord)
		var velocity: Vector2 = Vector2(difference.x, difference.z).normalized() * float(transfer.amount)
		result[first.coord] = Vector2(result.get(first.coord, Vector2.ZERO)) + velocity
		result[second.coord] = Vector2(result.get(second.coord, Vector2.ZERO)) + velocity
	var maximum: float = 0.001
	for velocity: Vector2 in result.values():
		maximum = maxf(maximum, velocity.length())
	for coord: Vector2i in result:
		result[coord] = Vector2(result[coord]) / maximum
	return result


func _ensure_nodes() -> void:
	if _preview_root != null:
		return
	_preview_root = Node3D.new()
	_preview_root.name = "PreviewFlow"
	add_child(_preview_root)
	_recent_root = Node3D.new()
	_recent_root.name = "RecentFlow"
	add_child(_recent_root)
	_arrow = _arrow_mesh()
	_dash = BoxMesh.new()
	_dash.size = Vector3(0.11, 0.008, 0.029)


func _refresh_preview() -> void:
	_ensure_nodes()
	_clear_root(_preview_root)
	if _state == null or not _preview_enabled or _prediction.is_empty():
		return
	var report: TurnReport = _prediction.get("report") as TurnReport
	var predicted: GameState = _prediction.get("state") as GameState
	if report == null or predicted == null:
		return
	var edges: Array[Dictionary] = transfers(predicted, report)
	var visible_edges: int = mini(MAX_EDGES, edges.size())
	if visible_edges == 0:
		return
	# One indexed mesh keeps a dense forecast to a single draw submission.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in visible_edges:
		var edge: Dictionary = edges[index]
		var start: Vector3 = _surface(predicted.tiles[int(edge.from)])
		var finish: Vector3 = _surface(predicted.tiles[int(edge.to)])
		for fraction: float in [0.26, 0.37, 0.48]:
			surface.append_from(_dash, 0, _at_fraction(start, finish, fraction))
		surface.append_from(_arrow, 0, _at_fraction(start, finish, 0.65))
	var batch: MeshInstance3D = MeshInstance3D.new()
	batch.name = "ForecastArrows"
	batch.mesh = surface.commit()
	batch.material_override = _material("preview")
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta("edge_count", visible_edges)
	_preview_root.add_child(batch)
	_preview_root.visible = _recent_markers.is_empty()


func _refresh_recent() -> void:
	_ensure_nodes()
	_clear_root(_recent_root)
	_recent_markers.clear()
	var groups: Dictionary = {"recent": [], "pump": []}
	var edges: Array[Dictionary] = transfers(_state, _recent_report)
	for index: int in mini(MAX_EDGES, edges.size()):
		var edge: Dictionary = edges[index]
		var first: Tile = _state.tiles[int(edge.from)]
		var second: Tile = _state.tiles[int(edge.to)]
		# A past transfer is not a current surface on a fully drained pair.
		if first.water < 0.05 and second.water < 0.05 and not first.is_sea and not second.is_sea:
			continue
		var start: Vector3 = _surface(first)
		var finish: Vector3 = _surface(second)
		var phase: float = float(index % 7) / 7.0
		var item: Dictionary = {"start": start, "finish": finish,
			"phase": phase, "speed": clampf(sqrt(float(edge.amount)), 0.2, 1.0)}
		_recent_markers.append(item)
		groups["pump" if bool(edge.pump) else "recent"].append(item)
	# Natural flow and pump color each require at most one draw submission.
	# Independent instance transforms retain the true direction of every edge.
	for style: String in groups:
		var items: Array = groups[style]
		if items.is_empty():
			continue
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _arrow
		multimesh.instance_count = items.size()
		var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
		batch.name = "PumpTransfers" if style == "pump" else "NaturalTransfers"
		batch.multimesh = multimesh
		batch.material_override = _material(style)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_recent_root.add_child(batch)
		for index: int in items.size():
			var item: Dictionary = items[index]
			item["batch"] = multimesh
			item["instance"] = index
			_move_marker(item, 0.5 if _reduced_motion else 0.18 + float(item.phase) * 0.64)
	_preview_root.visible = _recent_markers.is_empty()
	set_process(not _recent_markers.is_empty())


func _process(delta: float) -> void:
	if _paused:
		return
	_elapsed += delta
	if _elapsed >= RECENT_SECONDS:
		_clear_root(_recent_root)
		_recent_markers.clear()
		_recent_report = null
		_preview_root.visible = true
		set_process(false)
		actual_finished.emit()
		return
	if _reduced_motion:
		return
	for item: Dictionary in _recent_markers:
		var progress: float = fposmod(float(item.phase) + _elapsed * (0.32 + float(item.speed) * 0.2), 1.0)
		_move_marker(item, 0.18 + progress * 0.64)


func _surface(tile: Tile) -> Vector3:
	var at: Vector3 = Hex.to_world(tile.coord, tile.elevation)
	at.y += maxf(tile.water * C.HEIGHT_UNIT, 0.015) + 0.075
	return at


func _at_fraction(start: Vector3, finish: Vector3, fraction: float) -> Transform3D:
	var difference: Vector3 = finish - start
	var yaw: float = atan2(-difference.z, difference.x)
	var slope: float = atan2(difference.y, Vector2(difference.x, difference.z).length())
	return Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, slope), start.lerp(finish, fraction))


func _move_marker(item: Dictionary, fraction: float) -> void:
	var multimesh: MultiMesh = item.batch as MultiMesh
	multimesh.set_instance_transform(int(item.instance), _at_fraction(item.start, item.finish, fraction))


func _material(style: String) -> StandardMaterial3D:
	if not _materials.has(style):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color("#e3b666") if style == "preview" else (Color("#f1d58c") if style == "pump" else Color("#d7f2e7"))
		material.roughness = 1.0
		_materials[style] = material
	return _materials[style] as StandardMaterial3D


func _arrow_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Array[Vector3] = [
		Vector3(-0.14, 0, -0.018), Vector3(0.035, 0, -0.018), Vector3(0.035, 0, 0.018),
		Vector3(-0.14, 0, -0.018), Vector3(0.035, 0, 0.018), Vector3(-0.14, 0, 0.018),
		Vector3(0.015, 0, -0.065), Vector3(0.16, 0, 0), Vector3(0.015, 0, 0.065),
	]
	for point: Vector3 in vertices:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(point)
	# append_from mixes this mesh with indexed BoxMeshes in the preview batch.
	# Giving every input indices prevents orphan vertices in that mixed batch.
	surface.index()
	return surface.commit()


func _clear_root(root: Node3D) -> void:
	for child: Node in root.get_children():
		root.remove_child(child)
		child.free()
