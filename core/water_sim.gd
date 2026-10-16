class_name WaterSim
extends RefCounted


# All movement in an iteration uses the same surface heights and is applied
# together. Float64 working buffers keep the conservation check independent of
# the Float32 snapshots used by the water animation.
static func simulate(s: GameState, inflow: float, record_snapshots: bool) -> Dictionary:
	var count: int = s.tiles.size()
	var elevation := PackedFloat64Array()
	var water := PackedFloat64Array()
	var closed := PackedByteArray()
	var sea := PackedByteArray()
	var neighbors := PackedInt32Array()
	var sources := PackedInt32Array()
	var wheels := PackedInt32Array()
	var tile_index: Dictionary = {}
	elevation.resize(count)
	water.resize(count)
	closed.resize(count)
	sea.resize(count)
	neighbors.resize(count * 6)
	neighbors.fill(-1)
	for i in count:
		var tile: Tile = s.tiles[i]
		tile_index[tile.coord] = i
		elevation[i] = float(tile.elevation)
		water[i] = tile.water
		closed[i] = int(tile.building == C.Building.GATE and not tile.gate_open)
		sea[i] = int(tile.is_sea)
		if tile.is_source:
			sources.append(i)
		if tile.building == C.Building.WATERWHEEL:
			wheels.append(i)
	for i in count:
		for direction in 6:
			var neighbor: Tile = s.neighbor_in_dir(s.tiles[i], direction)
			if neighbor != null:
				neighbors[i * 6 + direction] = int(tile_index[neighbor.coord])

	# W-03: waterwheels run once, in tile index order, before the first snapshot.
	var wheel_amount: float = float(s.mod("wheel_amount"))
	var wheel_moved: float = 0.0
	for wheel in wheels:
		var direction: int = s.tiles[wheel].wheel_dir
		if direction < 0 or direction >= 6:
			continue
		var source: int = neighbors[wheel * 6 + direction]
		if source < 0 or sea[source] == 1 or closed[source] == 1:
			continue
		var amount: float = minf(wheel_amount, water[source])
		water[source] -= amount
		water[wheel] += amount
		wheel_moved += amount

	var iterations: int = maxi(1, int(s.mod("water_iterations")))
	var flow: float = clampf(float(s.mod("flow_rate")), 0.05, 0.9)
	var sea_key: String = "sea_level_rain" if s.is_rain() else "sea_level_dry"
	var sea_level: float = float(s.mod(sea_key))
	var applied_inflow: float = inflow if not sources.is_empty() else 0.0
	var per_source: float = 0.0
	if not sources.is_empty():
		per_source = inflow / float(iterations) / float(sources.size())
	var to_sea: float = 0.0
	var from_sea: float = 0.0
	var snapshots: Array[PackedFloat32Array] = []
	if record_snapshots:
		snapshots.append(PackedFloat32Array(Array(water)))
	var surface := PackedFloat64Array()
	var delta := PackedFloat64Array()
	var lower_indices := PackedInt32Array()
	var lower_differences := PackedFloat64Array()
	surface.resize(count)
	delta.resize(count)
	lower_indices.resize(6)
	lower_differences.resize(6)

	for _iteration in iterations:
		for source in sources:
			water[source] += per_source
		for i in count:
			surface[i] = elevation[i] + water[i]
		delta.fill(0.0)
		for i in count:
			if water[i] <= C.EPS or closed[i] == 1:
				continue
			var lower_count: int = 0
			var total_difference: float = 0.0
			for direction in 6:
				var j: int = neighbors[i * 6 + direction]
				if j < 0 or closed[j] == 1:
					continue
				var difference: float = surface[i] - surface[j]
				if difference > C.EPS:
					lower_indices[lower_count] = j
					lower_differences[lower_count] = difference
					lower_count += 1
					total_difference += difference
			if lower_count == 0:
				continue
			var outflow: float = minf(water[i], total_difference / float(lower_count + 1) * flow)
			for lower in lower_count:
				var j: int = lower_indices[lower]
				var share: float = outflow * lower_differences[lower] / total_difference
				delta[i] -= share
				delta[j] += share
				if sea[i] == 0 and sea[j] == 1:
					to_sea += share
				elif sea[i] == 1 and sea[j] == 0:
					from_sea += share
		for i in count:
			var next_water: float = water[i] + delta[i]
			if next_water < 0.0:
				if next_water < -1e-4:
					push_error("WaterSim: negative water %f at tile %d" % [next_water, i])
				next_water = 0.0
			water[i] = sea_level if sea[i] == 1 else next_water
		if record_snapshots:
			snapshots.append(PackedFloat32Array(Array(water)))

	for i in count:
		s.tiles[i].water = water[i]
	return {
		"inflow": applied_inflow,
		"to_sea": to_sea,
		"from_sea": from_sea,
		"wheel_moved": wheel_moved,
		"snapshots": snapshots,
	}


static func absorb(s: GameState) -> float:
	var absorbed: float = 0.0
	for tile in s.tiles:
		if tile.is_sea:
			continue
		var capacity: float = 0.0
		if tile.feature == C.Feature.FOREST:
			capacity = float(s.mod("forest_absorb"))
		elif tile.feature == C.Feature.SAPLING:
			capacity = float(s.mod("sapling_absorb"))
		var amount: float = minf(tile.water, capacity)
		tile.water -= amount
		absorbed += amount
	return absorbed


static func evaporate(s: GameState) -> float:
	if s.is_rain():
		return 0.0
	var rate: float = float(s.mod("evaporation_dry")) * float(s.mod("evaporation_multiplier"))
	var evaporated: float = 0.0
	for tile in s.tiles:
		if tile.is_sea:
			continue
		var amount: float = minf(tile.water, rate)
		tile.water -= amount
		evaporated += amount
	return evaporated
