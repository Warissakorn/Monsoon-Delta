extends TestCase


func test_neighbor_direction_order() -> void:
	var expected: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	]
	assert_eq(Hex.neighbors(Vector2i.ZERO), expected, "axial direction order")
	var center := Vector2i(-2, 3)
	var actual: Array[Vector2i] = Hex.neighbors(center)
	for direction: int in range(6):
		assert_eq(actual[direction], center + expected[direction], "translated neighbor")


func test_radius_four_has_61_unique_coords_in_q_major_order() -> void:
	var coords: Array[Vector2i] = Hex.coords(4)
	assert_eq(coords.size(), 61)
	var seen: Dictionary = {}
	var previous := Vector2i(-5, -5)
	for coord: Vector2i in coords:
		assert_true(not seen.has(coord), "duplicate coordinate %s" % coord)
		seen[coord] = true
		assert_true(Hex.distance(Vector2i.ZERO, coord) <= 4, "coordinate outside radius")
		assert_true(coord.x > previous.x or (coord.x == previous.x and coord.y > previous.y), "q-major order")
		previous = coord
	assert_eq(Hex.coords(0).size(), 1)
	assert_eq(Hex.coords(1).size(), 7)


func test_distance_and_ring() -> void:
	assert_eq(Hex.distance(Vector2i.ZERO, Vector2i(2, -4)), 4)
	assert_eq(Hex.distance(Vector2i(2, -4), Vector2i.ZERO), 4)
	var center := Vector2i(3, -2)
	var ring: Array[Vector2i] = Hex.ring(center, 2)
	assert_eq(ring.size(), 12)
	var seen: Dictionary = {}
	for coord: Vector2i in ring:
		assert_eq(Hex.distance(center, coord), 2)
		assert_true(not seen.has(coord), "ring repeats a coordinate")
		seen[coord] = true
	assert_eq(Hex.ring(center, 0), [center])


func test_world_coordinate_roundtrip_and_height() -> void:
	for coord: Vector2i in Hex.coords(4):
		for elevation: int in [-3, 0, 4]:
			var world: Vector3 = Hex.to_world(coord, elevation)
			assert_eq(Hex.world_to_hex(world), coord, "roundtrip %s" % coord)
			assert_near(world.y, float(elevation) * C.HEIGHT_UNIT, 0.000001)
	assert_near(Hex.to_world(Vector2i(1, 0)).x, sqrt(3.0), 0.000001)
	assert_near(Hex.to_world(Vector2i(0, 1)).z, 1.5, 0.000001)
