class_name VillageScenePlan
extends RefCounted
## A disposable, read-only contract between simulation state and scenery.
## Positions are board-local. No references to mutable tiles enter the result.

const MAX_DOCKS: int = 6
const MAX_BOATS: int = 4
const MAX_ANIMALS: int = 10
const MAX_PLANTS: int = 24
const MAX_RIPPLES: int = 18


static func build(state: GameState, routes: RouteGraph) -> Dictionary:
	var result: Dictionary = {"props": [], "actors": [], "ripples": [], "sites": [], "clearance": [], "rain": false}
	if state == null:
		return result
	result["rain"] = state.is_rain()
	var tiles: Array[Tile] = []
	tiles.assign(state.tiles)
	tiles.sort_custom(func(a: Tile, b: Tile) -> bool: return a.q < b.q or (a.q == b.q and a.r < b.r))
	var homes: Array[Vector2i] = []
	for tile: Tile in tiles:
		if tile.building in [C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.RAFT_HOUSE, C.Building.HALL]:
			homes.append(tile.coord)
	var occupied: Array[Dictionary] = []
	var docks: int = 0
	var gauges: int = 0
	var boats: int = 0
	var plants: int = 0
	var chickens: int = 0
	var birds: int = 0
	var fish: int = 0
	var clothes: int = 0
	var cracks: int = 0
	var mats: int = 0
	var drips: int = 0
	var motes: int = 0
	var docked_water: Array[Vector2i] = []
	for tile: Tile in tiles:
		var center: Vector3 = Hex.to_world(tile.coord, tile.elevation)
		var dry: bool = tile.water < 0.05 and not tile.is_sea and not tile.is_river and not tile.is_source
		var role: String = role_of(tile)
		var nearby: bool = false
		for home: Vector2i in homes:
			if Hex.distance(tile.coord, home) <= 2:
				nearby = true
				break
		var stage: int = SettlementProgress.building_stage(state, tile)
		result["sites"].append({"coord": tile.coord, "role": role, "dry": dry, "water": tile.water, "stage": stage, "age": SettlementProgress.building_age(state, tile)})
		if not nearby:
			continue
		if dry and role in ["home", "hall", "store"]:
			_add(result, "courtyard", center + Vector3.UP * 0.009, tile.coord)
			var choices: Array = ["fence", "jar", "banana", "bamboo"] if role == "home" else ["noticeboard", "bench", "flowerbed", "signpost"]
			if role == "store":
				choices = ["wood_rack" if state.wood > 0 else "empty_rack", "workbench", "basket"]
			var installed: int = 0
			for index: int in range(10):
				var angle: float = TAU * float(index) / 10.0 + float(variant(tile.coord, 3)) * 0.22
				var at: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * 0.65
				var kind: String = choices[(installed + variant(tile.coord, 7)) % choices.size()]
				if kind in ["banana", "bamboo", "flowerbed"] and plants >= MAX_PLANTS:
					kind = "jar"
				var radius: float = 0.17 if kind in ["fence", "workbench", "bench", "noticeboard", "wood_rack", "empty_rack"] else 0.12
				if not slot_clear(at, radius, routes, occupied):
					continue
				var prop: Dictionary = _add(result, kind, at, tile.coord, -angle)
				prop["footprint"] = radius
				occupied.append({"position": at, "radius": radius})
				if kind == "wood_rack":
					prop["stock"] = mini(3, ceili(float(state.wood) / 4.0))
				if kind in ["banana", "bamboo", "flowerbed"]:
					plants += 1
				if birds < 3 and kind in ["fence", "noticeboard", "signpost"]:
					_actor(result, "bird", at + Vector3.UP * (0.25 if kind == "fence" else 0.45), tile.coord, float(birds))
					birds += 1
				installed += 1
				if installed >= (3 if stage >= 2 else 2):
					break
			if role == "hall":
				var has_board: bool = false
				for prop: Dictionary in result["props"]:
					if prop["kind"] == "noticeboard":
						has_board = true
				if not has_board:
					for neighbor: Tile in state.neighbors(tile):
						if neighbor.feature != C.Feature.NONE or neighbor.building != C.Building.NONE:
							continue
						var at: Vector3 = _free_slot(Hex.to_world(neighbor.coord, neighbor.elevation), routes, occupied, 0.17, 3)
						if at != Vector3.INF:
							_add(result, "noticeboard", at, neighbor.coord)
							break
			if role == "home" and clothes < 3 and stage >= 1:
				var at: Vector3 = _free_slot(center, routes, occupied, 0.18, variant(tile.coord, 5))
				if at == Vector3.INF:
					for neighbor: Tile in state.neighbors(tile):
						if neighbor.feature == C.Feature.NONE and neighbor.building == C.Building.NONE:
							at = _free_slot(Hex.to_world(neighbor.coord, neighbor.elevation), routes, occupied, 0.18, 0)
							if at != Vector3.INF:
								break
				if at != Vector3.INF:
					_add(result, "clothesline", at, tile.coord)
					_actor(result, "cloth", at + Vector3.UP * 0.28, tile.coord, float(clothes))
					clothes += 1
			if role == "home" and state.is_rain() and drips < 3:
				var offset: float = 0.41 if tile.building == C.Building.STILT_HOUSE else 0.0
				var at: Vector3 = center + Vector3(0.33, 0.44 + offset, 0.30).rotated(Vector3.UP, deg_to_rad(20.0))
				_actor(result, "drip", at, tile.coord, float(drips))
				drips += 1
			if chickens < 4:
				var at: Vector3 = _free_slot(center, routes, occupied, 0.09, variant(tile.coord, 1))
				if at != Vector3.INF:
					_actor(result, "chicken", at, tile.coord, float(chickens))
					chickens += 1
		if dry and tile.building == C.Building.NONE and tile.feature == C.Feature.NONE and plants < MAX_PLANTS and variant(tile.coord, 6) < 2:
			var at: Vector3 = _free_slot(center, routes, occupied, 0.16, variant(tile.coord, 9))
			if at != Vector3.INF:
				var kind: String = "banana" if variant(tile.coord, 4) % 2 == 0 else "bamboo"
				_add(result, kind, at, tile.coord, float(variant(tile.coord, 8)) * 0.5)
				plants += 1
			if state.is_rain():
				_add(result, "rain_soil", center + Vector3.UP * 0.012, tile.coord)
			elif cracks < 12:
				_add(result, "dry_cracks", center + Vector3.UP * 0.014, tile.coord, float(variant(tile.coord, 2)))
				cracks += 1
				if motes < 4:
					_actor(result, "mote", center + Vector3.UP * 0.10, tile.coord, float(motes))
					motes += 1
		# Empty drying mats never imply harvested rice. Bundles are shown only
		# by the committed-harvest activity layer, not the standing crop count.
		if dry and role == "farm" and mats < 4:
			for direction: int in range(6):
				var bank: Tile = state.neighbor_in_dir(tile, direction)
				if bank == null or bank.feature != C.Feature.NONE or bank.building != C.Building.NONE:
					continue
				var at: Vector3 = _free_slot(Hex.to_world(bank.coord, bank.elevation), routes, occupied, 0.19, direction)
				if at != Vector3.INF:
					_add(result, "drying_mat", at, bank.coord)
					mats += 1
					break
		if not dry or role in ["farm", "forest", "gate", "wheel", "reservoir"]:
			continue
		for direction: int in range(6):
			var water: Tile = state.neighbor_in_dir(tile, direction)
			if water == null or water.water < 0.15 or water.is_source:
				continue
			var normal: Vector3 = Hex.to_world(Hex.direction(direction)).normalized()
			var margin: Vector3 = center + normal * 0.62 + Vector3(-normal.z, 0.0, normal.x) * 0.36
			if plants < MAX_PLANTS and slot_clear(margin, 0.10, routes, occupied):
				_add(result, "reeds", margin, tile.coord, atan2(normal.x, normal.z))
				_add(result, "mud_margin", margin + Vector3.UP * 0.008, tile.coord, atan2(normal.x, normal.z))
				occupied.append({"position": margin, "radius": 0.10})
				plants += 1
			var water_center: Vector3 = Hex.to_world(water.coord, water.elevation)
			var surface: float = water_center.y + water.water * C.HEIGHT_UNIT + 0.015
			var landing: Vector3 = center + normal * 0.57
			var landing_radius: float = 0.22 if role == "store" else 0.17
			if docks >= MAX_DOCKS or water.coord in docked_water or surface > center.y + 0.12 or not slot_clear(landing, landing_radius, routes, occupied):
				continue
			var rotation: float = atan2(normal.x, normal.z)
			var deck: Vector3 = landing + Vector3.UP * 0.12
			var dock_kind: String = "cargo_dock" if role == "store" else ("fishing_dock" if water.building == C.Building.FISH_TRAP else "dock")
			_add(result, dock_kind, deck, tile.coord, rotation)
			occupied.append({"position": landing, "radius": landing_radius})
			for x: float in [-0.12, 0.12]:
				for z: float in [0.10, 0.64]:
					var position: Vector3 = deck + Vector3(x, 0.0, z).rotated(Vector3.UP, rotation)
					var floor_tile: Tile = state.get_tile(Hex.world_to_hex(position))
					var floor_y: float = float(floor_tile.elevation) * C.HEIGHT_UNIT if floor_tile != null else water_center.y
					var length: float = maxf(0.15, deck.y - floor_y + 0.08)
					_add(result, "post", position - Vector3.UP * length * 0.5, tile.coord, 0.0, Vector3(0.045, length, 0.045))
					if z > 0.5 and result["ripples"].size() < MAX_RIPPLES:
						result["ripples"].append({"position": Vector3(position.x, surface + 0.006, position.z), "coord": water.coord})
			if gauges < 2:
				var gauge: Vector3 = water_center - normal * 0.50 + Vector3(-normal.z, 0.0, normal.x) * 0.12
				_add(result, "gauge", gauge, water.coord, rotation, Vector3(1.0, maxf(1.0, water.water * C.HEIGHT_UNIT + 0.20), 1.0))
				_add(result, "water_mark", Vector3(gauge.x, surface, gauge.z), water.coord, rotation)
				gauges += 1
			if boats < MAX_BOATS:
				for side: float in [-1.0, 1.0]:
					var mooring: Vector3 = water_center - normal * 0.10 + Vector3(-normal.z, 0.0, normal.x) * 0.43 * side
					mooring.y = surface + 0.01
					if _boat_clear(state, mooring, rotation):
						_actor(result, "boat", mooring, water.coord, float(boats), rotation)
						boats += 1
						break
			if fish < 3 and water.building == C.Building.NONE:
				var at: Vector3 = water_center + normal * 0.18
				at.y = surface + 0.008
				_actor(result, "fish", at, water.coord, float(fish), rotation)
				fish += 1
			docked_water.append(water.coord)
			docks += 1
	result["clearance"] = occupied.duplicate(true)
	return result


static func role_of(tile: Tile) -> String:
	match tile.building:
		C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.RAFT_HOUSE: return "home"
		C.Building.HALL: return "hall"
		C.Building.GRANARY: return "store"
		C.Building.FISH_TRAP: return "fish"
		C.Building.GATE: return "gate"
		C.Building.WATERWHEEL: return "wheel"
		C.Building.RESERVOIR: return "reservoir"
	if tile.feature == C.Feature.PADDY:
		return "farm"
	if tile.feature in [C.Feature.FOREST, C.Feature.SAPLING]:
		return "forest"
	return "water" if tile.water >= 0.05 or tile.is_sea or tile.is_river else "ground"


static func variant(coord: Vector2i, salt: int) -> int:
	return posmod(coord.x * 73856093 + coord.y * 19349663 + salt * 83492791, 4)


static func slot_clear(at: Vector3, radius: float, routes: RouteGraph, occupied: Array[Dictionary]) -> bool:
	if routes == null or not routes.point_clear(at, radius):
		return false
	for item: Dictionary in occupied:
		if at.distance_to(item["position"]) < radius + float(item["radius"]) + 0.025:
			return false
	for anchor: Dictionary in routes.anchors.values():
		if at.distance_to(anchor["position"]) < radius + 0.12:
			return false
	for route: Dictionary in routes.routes:
		var points: PackedVector3Array = route["points"]
		for index: int in range(1, points.size()):
			var nearest: Vector3 = Geometry3D.get_closest_point_to_segment(at, points[index - 1], points[index])
			if Vector2(at.x - nearest.x, at.z - nearest.z).length() < radius + RouteGraph.HALF_WIDTH + 0.025:
				return false
	return true


static func _free_slot(center: Vector3, routes: RouteGraph, occupied: Array[Dictionary], radius: float, salt: int) -> Vector3:
	for index: int in range(12):
		var angle: float = TAU * float(index + salt) / 12.0
		var at: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * 0.63
		if slot_clear(at, radius, routes, occupied):
			occupied.append({"position": at, "radius": radius})
			return at
	return Vector3.INF


static func _boat_clear(state: GameState, at: Vector3, rotation: float) -> bool:
	for point: Vector3 in [Vector3.ZERO, Vector3(0.0, 0.0, -0.43), Vector3(0.0, 0.0, 0.42), Vector3(-0.16, 0.0, -0.18), Vector3(0.16, 0.0, 0.18)]:
		var sample: Vector3 = at + point.rotated(Vector3.UP, rotation)
		var tile: Tile = state.get_tile(Hex.world_to_hex(sample))
		if tile == null or tile.water < 0.15 or tile.is_source:
			return false
		var surface: float = float(tile.elevation) * C.HEIGHT_UNIT + tile.water * C.HEIGHT_UNIT + 0.025
		if absf(surface - at.y) > 0.04:
			return false
		if tile.building != C.Building.NONE and sample.distance_to(Hex.to_world(tile.coord, tile.elevation) + Vector3.UP * (tile.water * C.HEIGHT_UNIT + 0.025)) < 0.32:
			return false
	return true


static func _add(plan: Dictionary, kind: String, at: Vector3, coord: Vector2i, rotation: float = 0.0, scale: Vector3 = Vector3.ONE) -> Dictionary:
	var item: Dictionary = {"kind": kind, "position": at, "coord": coord, "rotation": rotation, "scale": scale}
	plan["props"].append(item)
	return item


static func _actor(plan: Dictionary, kind: String, at: Vector3, coord: Vector2i, phase: float, rotation: float = 0.0) -> void:
	plan["actors"].append({"kind": kind, "position": at, "coord": coord, "phase": phase * 1.7, "rotation": rotation})
