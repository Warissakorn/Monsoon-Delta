class_name RouteGraph
extends RefCounted
## A deterministic, view-only pedestrian network. No state, RNG or save writes.
## Roads use building entrances and dry field/river banks, never tile centres
## inside buildings. The same sampled curves are used by roads and villagers.

const NO_COORD: Vector2i = Vector2i(2147483647, 2147483647)
const HALF_WIDTH: float = 0.055
const SURFACE_LIFT: float = 0.025
const EDGE_RADIUS: float = 0.755
const MAX_STEP: int = 1
const CURVE_TRIM: float = 0.19
const BODY_ROTATION: float = deg_to_rad(20.0)

var signature: String = ""
var anchors: Dictionary = {}
var hub_coord: Vector2i = NO_COORD
var routes: Array[Dictionary] = []
var steps: Array[Dictionary] = []
var _tiles: Dictionary = {}
var _nodes: Array[Dictionary] = []
var _tile_nodes: Dictionary = {}
var _paths: Dictionary = {}
var _used_edges: Dictionary = {}
var _shore_candidates: Dictionary = {}
var _ground_nodes: Dictionary = {}


static func topology_signature(state: GameState) -> String:
	if state == null:
		return ""
	var rows: PackedStringArray = PackedStringArray()
	for tile: Tile in state.tiles:
		# Changes within a dry/wet class do not alter pedestrian topology.
		rows.append("%d,%d:%d:%d:%d:%d:%d:%d:%d" % [tile.q, tile.r, tile.elevation,
			tile.feature, tile.building, int(tile.water >= 0.05), int(tile.is_river),
			int(tile.is_sea), int(tile.is_source)])
	rows.sort()
	return "|".join(rows)


static func build(state: GameState) -> RouteGraph:
	var graph: RouteGraph = RouteGraph.new()
	graph.signature = topology_signature(state)
	if state == null:
		return graph
	var tiles: Array[Tile] = []
	tiles.assign(state.tiles)
	tiles.sort_custom(func(a: Tile, b: Tile) -> bool:
		return a.q < b.q or (a.q == b.q and a.r < b.r))
	for tile: Tile in tiles:
		graph._tiles[tile.coord] = tile
		if tile.building == C.Building.HALL:
			graph.hub_coord = tile.coord
	for tile: Tile in tiles:
		if graph._walkable(tile):
			graph._add_tile_nodes(tile)
	graph._connect_tiles(tiles)
	for tile: Tile in tiles:
		graph._add_anchor(tile)
	if not graph.anchors.has(graph.hub_coord):
		return graph
	graph._choose_reachable_shores()
	var targets: Array[Vector2i] = []
	for coord: Vector2i in graph.anchors:
		if coord != graph.hub_coord and graph.anchors[coord]["kind"] != "ground":
			targets.append(coord)
	# Nearby homes establish trunks before distant work sites branch off.
	targets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = Hex.distance(graph.hub_coord, a)
		var db: int = Hex.distance(graph.hub_coord, b)
		return da < db or (da == db and (a.x < b.x or (a.x == b.x and a.y < b.y))))
	graph._paths[graph.hub_coord] = PackedVector3Array([graph.access_point(graph.hub_coord)])
	for coord: Vector2i in targets:
		var node_path: Array[int] = graph._find_nodes(int(graph.anchors[graph.hub_coord]["node"]), int(graph.anchors[coord]["node"]))
		var points: PackedVector3Array = graph._curve_nodes(node_path)
		graph._paths[coord] = points
		if points.size() < 2:
			continue
		for index: int in range(node_path.size() - 1):
			graph._used_edges[graph._edge_key(node_path[index], node_path[index + 1])] = true
		graph.routes.append({"from": graph.hub_coord, "to": coord, "points": points, "length": path_length(points)})
	graph._collect_steps()
	return graph


func can_access(coord: Vector2i) -> bool:
	return not path_to(coord).is_empty()


func access_point(coord: Vector2i) -> Vector3:
	return anchors[coord]["position"] if anchors.has(coord) else Vector3.ZERO


func path_to(coord: Vector2i) -> PackedVector3Array:
	if not anchors.has(coord) or not anchors.has(hub_coord):
		return PackedVector3Array()
	if not _paths.has(coord):
		# Empty ground has no permanent road. A committed job can still walk
		# safely to it; these temporary connectors do not change the simulation.
		_paths[coord] = _curve_nodes(_find_nodes(int(anchors[hub_coord]["node"]), int(anchors[coord]["node"])))
	return _paths[coord]


func path_between(from_coord: Vector2i, to_coord: Vector2i) -> PackedVector3Array:
	if from_coord == to_coord:
		return PackedVector3Array([access_point(from_coord)]) if anchors.has(from_coord) else PackedVector3Array()
	var home: PackedVector3Array = path_to(from_coord)
	var work: PackedVector3Array = path_to(to_coord)
	if home.is_empty() or work.is_empty():
		return PackedVector3Array()
	# Join at the longest common trunk. Villagers retain exactly the curves
	# rendered on either branch rather than cutting a new corner at a junction.
	var join: int = 0
	while join + 1 < mini(home.size(), work.size()) and home[join + 1].is_equal_approx(work[join + 1]):
		join += 1
	var result: PackedVector3Array = PackedVector3Array()
	for index: int in range(home.size() - 1, join - 1, -1):
		_append_distinct(result, home[index])
	for index: int in range(join + 1, work.size()):
		_append_distinct(result, work[index])
	return result


func find_path(from_coord: Vector2i, to_coord: Vector2i) -> PackedVector3Array:
	return path_between(from_coord, to_coord)


static func path_length(points: PackedVector3Array) -> float:
	var result: float = 0.0
	for index: int in range(1, points.size()):
		result += points[index - 1].distance_to(points[index])
	return result


static func sample_path(points: PackedVector3Array, distance: float) -> Dictionary:
	if points.is_empty():
		return {"position": Vector3.ZERO, "tangent": Vector3.FORWARD}
	var remaining: float = maxf(0.0, distance)
	for index: int in range(1, points.size()):
		var delta: Vector3 = points[index] - points[index - 1]
		var length: float = delta.length()
		if length < 0.00001:
			continue
		if remaining <= length:
			return {"position": points[index - 1].lerp(points[index], remaining / length), "tangent": delta / length}
		remaining -= length
	var tangent: Vector3 = (points[-1] - points[-2]).normalized() if points.size() >= 2 else Vector3.FORWARD
	return {"position": points[-1], "tangent": tangent}


func _walkable(tile: Tile) -> bool:
	return tile != null and tile.water < 0.05 and not tile.is_sea and not tile.is_river and not tile.is_source \
		and tile.feature != C.Feature.PADDY and tile.building not in [C.Building.GATE, C.Building.RESERVOIR, C.Building.RAFT_HOUSE]


func _add_tile_nodes(tile: Tile) -> void:
	var ring: Array[int] = []
	var center: Vector3 = Hex.to_world(tile.coord, tile.elevation) + Vector3.UP * SURFACE_LIFT
	for index: int in range(12):
		var angle: float = float(index) * PI / 6.0
		var radius: float = EDGE_RADIUS if index % 2 == 0 else EDGE_RADIUS / cos(PI / 6.0)
		var point: Vector3 = center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		ring.append(_add_node(tile.coord, point) if _point_body_clear(point, tile) else -1)
	_tile_nodes[tile.coord] = ring
	for index: int in range(12):
		_link_in_tile(ring[index], ring[(index + 1) % 12], tile)
	if tile.building == C.Building.NONE and tile.feature == C.Feature.NONE:
		var middle: int = _add_node(tile.coord, center)
		_ground_nodes[tile.coord] = middle
		for index: int in range(0, 12, 2):
			_link_known(middle, ring[index])


func _add_node(coord: Vector2i, point: Vector3) -> int:
	_nodes.append({"coord": coord, "point": point, "links": []})
	return _nodes.size() - 1


func _connect_tiles(tiles: Array[Tile]) -> void:
	for tile: Tile in tiles:
		if not _tile_nodes.has(tile.coord):
			continue
		var ring: Array = _tile_nodes[tile.coord]
		for direction: int in range(6):
			var neighbor_coord: Vector2i = Hex.neighbor(tile.coord, direction)
			if not _tile_nodes.has(neighbor_coord):
				continue
			var neighbor: Tile = _tiles[neighbor_coord]
			if absi(tile.elevation - neighbor.elevation) > MAX_STEP:
				continue
			# Axial directions run clockwise; the perimeter's angles run CCW.
			var side: int = posmod(-direction * 2, 12)
			var opposite: int = posmod(side + 6, 12)
			_link_known(int(ring[side]), int(_tile_nodes[neighbor_coord][opposite]))


func _add_anchor(tile: Tile) -> void:
	var kind: String = _kind(tile)
	if kind.is_empty():
		return
	var chosen: int = -1
	if kind == "ground" and _ground_nodes.has(tile.coord):
		chosen = int(_ground_nodes[tile.coord])
	elif _tile_nodes.has(tile.coord):
		var center: Vector3 = Hex.to_world(tile.coord, tile.elevation) + Vector3.UP * SURFACE_LIFT
		var offset: Vector3 = Vector3.ZERO
		if kind in ["house", "hall", "granary"]:
			offset = Vector3(0.0, 0.0, 0.73 if kind == "hall" else (0.79 if tile.building == C.Building.STILT_HOUSE else 0.59)).rotated(Vector3.UP, BODY_ROTATION)
		elif kind in ["forest", "sapling", "waterwheel", "fish"]:
			offset = Vector3(EDGE_RADIUS, 0.0, 0.0)
		var at: Vector3 = center + offset
		if point_clear(at, HALF_WIDTH):
			chosen = _add_node(tile.coord, at)
			for other: int in _tile_nodes[tile.coord]:
				_link_in_tile(chosen, other, tile)

	elif kind in ["paddy", "fish", "waterwheel", "reservoir", "gate"]:
		# Work on water or rice is reached from a dry bank, never by granting
		# passability to the work tile or treating an open gate as a bridge.
		var best: float = INF
		_shore_candidates[tile.coord] = []
		for direction: int in range(6):
			var shore: Vector2i = Hex.neighbor(tile.coord, direction)
			if not _tile_nodes.has(shore):
				continue
			var neighbor: Tile = _tiles[shore]
			if absi(neighbor.elevation - tile.elevation) > MAX_STEP and kind not in ["fish", "waterwheel", "reservoir", "gate"]:
				continue
			var side: int = posmod(-(direction + 3) * 2, 12)
			var candidate: int = int(_tile_nodes[shore][side])
			if candidate < 0:
				continue
			_shore_candidates[tile.coord].append(candidate)
			var score: float = float(Hex.distance(hub_coord, shore))
			if score < best:
				best = score
				chosen = candidate
	if chosen >= 0:
		anchors[tile.coord] = {"coord": tile.coord, "kind": kind, "position": _nodes[chosen]["point"], "node": chosen}


func _choose_reachable_shores() -> void:
	var hub: int = int(anchors[hub_coord]["node"])
	var visited: Dictionary = {hub: true}
	var pending: Array[int] = [hub]
	var cursor: int = 0
	while cursor < pending.size():
		var current: int = pending[cursor]
		cursor += 1
		for next: int in _nodes[current]["links"]:
			if not visited.has(next):
				visited[next] = true
				pending.append(next)
	for coord: Vector2i in _shore_candidates:
		var best: int = -1
		var best_distance: float = INF
		for candidate: int in _shore_candidates[coord]:
			if not visited.has(candidate):
				continue
			var distance: float = (_nodes[hub]["point"] as Vector3).distance_to(_nodes[candidate]["point"])
			if distance < best_distance:
				best = candidate
				best_distance = distance
		if best >= 0:
			anchors[coord]["node"] = best
			anchors[coord]["position"] = _nodes[best]["point"]


func _kind(tile: Tile) -> String:
	match tile.building:
		C.Building.HALL: return "hall"
		C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.RAFT_HOUSE: return "house"
		C.Building.GRANARY: return "granary"
		C.Building.FISH_TRAP: return "fish"
		C.Building.WATERWHEEL: return "waterwheel"
		C.Building.GATE: return "gate"
		C.Building.RESERVOIR: return "reservoir"
	match tile.feature:
		C.Feature.FOREST: return "forest"
		C.Feature.SAPLING: return "sapling"
		C.Feature.PADDY: return "paddy"
	return "ground" if _walkable(tile) else ""


func _link_known(a: int, b: int) -> void:
	if a < 0 or b < 0 or a == b or _nodes[a]["links"].has(b):
		return
	_nodes[a]["links"].append(b)
	_nodes[b]["links"].append(a)


func _link_in_tile(a: int, b: int, tile: Tile) -> void:
	if a < 0 or b < 0 or a == b:
		return
	var first: Vector3 = _nodes[a]["point"] - Hex.to_world(tile.coord, tile.elevation)
	var second: Vector3 = _nodes[b]["point"] - Hex.to_world(tile.coord, tile.elevation)
	if tile.building in [C.Building.HALL, C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.GRANARY]:
		first = first.rotated(Vector3.UP, -BODY_ROTATION)
		second = second.rotated(Vector3.UP, -BODY_ROTATION)
		var half: Vector2 = Vector2(0.515, 0.45) if tile.building == C.Building.HALL else Vector2(0.415, 0.40)
		half += Vector2.ONE * 0.005
		if not _segment_rect_clear(Vector2(first.x, first.z), Vector2(second.x, second.z), half, HALF_WIDTH):
			return
	elif tile.feature in [C.Feature.FOREST, C.Feature.SAPLING] or tile.building in [C.Building.WATERWHEEL, C.Building.FISH_TRAP]:
		var begin: Vector2 = Vector2(first.x, first.z)
		var delta: Vector2 = Vector2(second.x, second.z) - begin
		var along: float = clampf(-begin.dot(delta) / maxf(delta.length_squared(), 0.000001), 0.0, 1.0)
		if (begin + along * delta).length() < 0.57 + HALF_WIDTH:
			return
	# All points lie in the same inset convex hex: a capsule between them
	# stays on this dry tile. Obstacle intersection above includes road width.
	_link_known(a, b)


func _point_body_clear(point: Vector3, tile: Tile) -> bool:
	var local: Vector3 = point - Hex.to_world(tile.coord, tile.elevation)
	if tile.building in [C.Building.HALL, C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.GRANARY]:
		local = local.rotated(Vector3.UP, -BODY_ROTATION)
		var half: Vector2 = Vector2(0.515, 0.45) if tile.building == C.Building.HALL else Vector2(0.415, 0.40)
		half += Vector2.ONE * 0.005
		return _point_rect_distance(Vector2(local.x, local.z), half) >= HALF_WIDTH
	if tile.feature in [C.Feature.FOREST, C.Feature.SAPLING] or tile.building in [C.Building.WATERWHEEL, C.Building.FISH_TRAP]:
		return Vector2(local.x, local.z).length() >= 0.57 + HALF_WIDTH
	return true


func _point_rect_distance(point: Vector2, half: Vector2) -> float:
	return Vector2(maxf(absf(point.x) - half.x, 0.0), maxf(absf(point.y) - half.y, 0.0)).length()


func _segment_rect_clear(a: Vector2, b: Vector2, half: Vector2, radius: float) -> bool:
	if _intersects_rect(a, b, half) or _point_rect_distance(a, half) < radius or _point_rect_distance(b, half) < radius:
		return false
	var delta: Vector2 = b - a
	for x: float in [-half.x, half.x]:
		for z: float in [-half.y, half.y]:
			var corner: Vector2 = Vector2(x, z)
			var along: float = clampf((corner - a).dot(delta) / maxf(delta.length_squared(), 0.000001), 0.0, 1.0)
			if corner.distance_to(a + delta * along) < radius:
				return false
	return true


func _intersects_rect(a: Vector2, b: Vector2, half: Vector2) -> bool:
	var delta: Vector2 = b - a
	var enter: float = 0.0
	var leave: float = 1.0
	for axis: int in range(2):
		if absf(delta[axis]) < 0.000001:
			if absf(a[axis]) > half[axis]:
				return false
			continue
		var first: float = (-half[axis] - a[axis]) / delta[axis]
		var last: float = (half[axis] - a[axis]) / delta[axis]
		enter = maxf(enter, minf(first, last))
		leave = minf(leave, maxf(first, last))
		if enter > leave:
			return false
	return true


## Exposed for focused geometry tests and placement diagnostics.
func point_clear(point: Vector3, radius: float = HALF_WIDTH) -> bool:
	# A disk, not just a centre line, must fit on dry terrain and around bodies.
	for index: int in range(9):
		var sample: Vector3 = point
		if index > 0:
			var angle: float = float(index - 1) * TAU / 8.0
			sample += Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var coord: Vector2i = Hex.world_to_hex(sample)
		var tile: Tile = _tiles.get(coord) as Tile
		if not _walkable(tile):
			return false
		var local: Vector3 = sample - Hex.to_world(coord, tile.elevation)
		if tile.building in [C.Building.HALL, C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.GRANARY]:
			local = local.rotated(Vector3.UP, -BODY_ROTATION)
			var half: Vector2 = Vector2(0.515, 0.45) if tile.building == C.Building.HALL else Vector2(0.415, 0.40)
			if absf(local.x) < half.x + 0.005 and absf(local.z) < half.y + 0.005:
				return false
		elif tile.feature in [C.Feature.FOREST, C.Feature.SAPLING] or tile.building in [C.Building.WATERWHEEL, C.Building.FISH_TRAP]:
			if Vector2(local.x, local.z).length() < 0.57:
				return false
	return true


func _segment_clear(a: Vector3, b: Vector3) -> bool:
	var count: int = maxi(2, ceili(a.distance_to(b) / 0.055))
	for index: int in range(count + 1):
		if not point_clear(a.lerp(b, float(index) / float(count))):
			return false
	return true


func _find_nodes(start: int, target: int) -> Array[int]:
	var open: Array[int] = [start]
	var costs: Dictionary = {start: 0.0}
	var previous: Dictionary = {}
	var closed: Dictionary = {}
	while not open.is_empty():
		var best_index: int = 0
		var best_score: float = INF
		for index: int in range(open.size()):
			var id: int = open[index]
			var score: float = float(costs[id]) + (_nodes[id]["point"] as Vector3).distance_to(_nodes[target]["point"]) * 0.6
			if score < best_score - 0.000001 or (is_equal_approx(score, best_score) and id < open[best_index]):
				best_index = index
				best_score = score
		var current: int = open[best_index]
		open.remove_at(best_index)
		if current == target:
			var result: Array[int] = [target]
			while previous.has(result[-1]):
				result.append(int(previous[result[-1]]))
			result.reverse()
			return result
		closed[current] = true
		for next: int in _nodes[current]["links"]:
			if closed.has(next):
				continue
			var edge: Vector3 = _nodes[next]["point"] - _nodes[current]["point"]
			var cost: float = edge.length() * (0.62 if _used_edges.has(_edge_key(current, next)) else 1.0)
			cost += absf(edge.y) * 0.8
			if previous.has(current):
				var before: Vector3 = _nodes[current]["point"] - _nodes[int(previous[current])]["point"]
				cost += (1.0 - before.normalized().dot(edge.normalized())) * 0.045
			var total: float = float(costs[current]) + cost
			if total < float(costs.get(next, INF)) - 0.000001:
				costs[next] = total
				previous[next] = current
				if not open.has(next):
					open.append(next)
	return []


func _curve_nodes(node_path: Array[int]) -> PackedVector3Array:
	var raw: PackedVector3Array = PackedVector3Array()
	for id: int in node_path:
		_append_distinct(raw, _nodes[id]["point"])
	if raw.size() < 3:
		return _step_profile(raw)
	var points: PackedVector3Array = PackedVector3Array([raw[0]])
	for index: int in range(1, raw.size() - 1):
		var before: Vector3 = raw[index - 1]
		var corner: Vector3 = raw[index]
		var after: Vector3 = raw[index + 1]
		# Keep tile-height transitions straight so visible stairs remain aligned.
		if not is_equal_approx(before.y, corner.y) or not is_equal_approx(corner.y, after.y):
			_append_distinct(points, corner)
			continue
		var trim: float = minf(CURVE_TRIM, minf(before.distance_to(corner), corner.distance_to(after)) * 0.38)
		var samples: PackedVector3Array = PackedVector3Array()
		for attempt: int in range(5):
			samples.clear()
			var entry: Vector3 = corner.move_toward(before, trim)
			var exit: Vector3 = corner.move_toward(after, trim)
			var clear: bool = true
			for step: int in range(7):
				var t: float = float(step) / 6.0
				var point: Vector3 = (1.0 - t) * (1.0 - t) * entry + 2.0 * (1.0 - t) * t * corner + t * t * exit
				if not point_clear(point):
					clear = false
					break
				samples.append(point)
			if clear:
				break
			trim *= 0.5
			samples.clear()
		if samples.is_empty():
			_append_distinct(points, corner)
		else:
			for point: Vector3 in samples:
				_append_distinct(points, point)
	_append_distinct(points, raw[-1])
	return _step_profile(points)


func _step_profile(points: PackedVector3Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for index: int in range(points.size()):
		var at: Vector3 = points[index]
		if index > 0 and absf(at.y - points[index - 1].y) > 0.01:
			var before: Vector3 = points[index - 1]
			var low: Vector3 = before if before.y < at.y else at
			var high: Vector3 = at if before.y < at.y else before
			var profile: PackedVector3Array = PackedVector3Array([low])
			var count: int = maxi(2, ceili((high.y - low.y) / 0.1))
			# Reach the upper height before the shared tile boundary. A linear
			# slope all the way to the upper node would cut through its terrain.
			var landing: Vector3 = low.lerp(high, 0.5)
			landing.y = high.y
			for step: int in range(count):
				var begin: Vector3 = low.lerp(landing, float(step) / float(count))
				var end: Vector3 = low.lerp(landing, float(step + 1) / float(count))
				_append_distinct(profile, Vector3(begin.x, end.y, begin.z))
				_append_distinct(profile, end)
			_append_distinct(profile, high)
			if before.y > at.y:
				profile.reverse()
			for point: Vector3 in profile:
				_append_distinct(result, point)
		_append_distinct(result, at)
	return result


func _collect_steps() -> void:
	for key: String in _used_edges:
		var ids: PackedStringArray = key.split(":")
		var first: Vector3 = _nodes[int(ids[0])]["point"]
		var second: Vector3 = _nodes[int(ids[1])]["point"]
		if absf(first.y - second.y) < 0.01:
			continue
		steps.append({"low": first if first.y < second.y else second, "high": second if first.y < second.y else first})


func _edge_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


static func _append_distinct(points: PackedVector3Array, point: Vector3) -> void:
	if points.is_empty() or not points[-1].is_equal_approx(point):
		points.append(point)
