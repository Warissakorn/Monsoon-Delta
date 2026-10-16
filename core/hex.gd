class_name Hex
extends RefCounted

## Provisional H-02/H-03 conventions until the missing hex-map spec is supplied.
## Axial coordinates use pointy-top hexes and stable q-major tile indexing.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const SQRT_3: float = 1.7320508075688772


static func direction(dir: int) -> Vector2i:
	return DIRECTIONS[posmod(dir, DIRECTIONS.size())]


static func neighbor(coord: Vector2i, dir: int) -> Vector2i:
	return coord + direction(dir)


static func neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in DIRECTIONS:
		result.append(coord + offset)
	return result


static func distance(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return maxi(maxi(absi(delta.x), absi(delta.y)), absi(delta.x + delta.y))


static func coords(radius: int = C.MAP_RADIUS) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q: int in range(-radius, radius + 1):
		var r_min: int = maxi(-radius, -q - radius)
		var r_max: int = mini(radius, -q + radius)
		for r: int in range(r_min, r_max + 1):
			result.append(Vector2i(q, r))
	return result


static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if radius < 0:
		return result
	if radius == 0:
		result.append(center)
		return result
	var cursor: Vector2i = center + direction(4) * radius
	for dir: int in range(DIRECTIONS.size()):
		for step: int in range(radius):
			result.append(cursor)
			cursor += direction(dir)
	return result


static func to_world(coord: Vector2i, elevation: int = 0) -> Vector3:
	return Vector3(
		SQRT_3 * (float(coord.x) + float(coord.y) / 2.0),
		float(elevation) * C.HEIGHT_UNIT,
		1.5 * float(coord.y)
	)


static func world_to_hex(world: Vector3) -> Vector2i:
	var q_float: float = SQRT_3 / 3.0 * world.x - world.z / 3.0
	var r_float: float = 2.0 / 3.0 * world.z
	var y_float: float = -q_float - r_float
	var q: int = roundi(q_float)
	var r: int = roundi(r_float)
	var y: int = roundi(y_float)
	var q_error: float = absf(float(q) - q_float)
	var r_error: float = absf(float(r) - r_float)
	var y_error: float = absf(float(y) - y_float)
	if q_error > y_error and q_error > r_error:
		q = -y - r
	elif y_error <= r_error:
		r = -q - y
	return Vector2i(q, r)
