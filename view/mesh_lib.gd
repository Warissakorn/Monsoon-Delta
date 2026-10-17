class_name MeshLib
extends RefCounted

## Pointy-top procedural pieces. The first vertex points toward -Z, matching
## Hex.to_world's axial spacing. Terrain surfaces can use separate materials.
static var _hex_cache: Dictionary = {}
static var _ring_cache: Dictionary = {}


static func hex_prism(radius: float = 0.96) -> ArrayMesh:
	var key: String = "%.4f" % radius
	if _hex_cache.has(key):
		return _hex_cache[key] as ArrayMesh
	var corners: PackedVector3Array = _corners(radius)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	for index: int in range(6):
		surface.add_vertex(Vector3.UP)
		surface.add_vertex(corners[index] + Vector3.UP)
		surface.add_vertex(corners[(index + 1) % 6] + Vector3.UP)
	var mesh: ArrayMesh = surface.commit()
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(6):
		var first: Vector3 = corners[index]
		var second: Vector3 = corners[(index + 1) % 6]
		surface.set_normal(((first + second) * 0.5).normalized())
		surface.set_color(Color.WHITE)
		surface.add_vertex(second + Vector3.UP)
		surface.add_vertex(first + Vector3.UP)
		surface.set_color(Color(0.56, 0.59, 0.60))
		surface.add_vertex(first)
		surface.set_color(Color.WHITE)
		surface.add_vertex(second + Vector3.UP)
		surface.set_color(Color(0.56, 0.59, 0.60))
		surface.add_vertex(first)
		surface.add_vertex(second)
	surface.commit(mesh)
	_hex_cache[key] = mesh
	return mesh


static func hex_ring(outer_radius: float = 0.99, inner_radius: float = 0.93) -> ArrayMesh:
	var key: String = "%.4f:%.4f" % [outer_radius, inner_radius]
	if _ring_cache.has(key):
		return _ring_cache[key] as ArrayMesh
	var outer: PackedVector3Array = _corners(outer_radius)
	var inner: PackedVector3Array = _corners(inner_radius)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	for index: int in range(6):
		var next: int = (index + 1) % 6
		surface.add_vertex(outer[index])
		surface.add_vertex(outer[next])
		surface.add_vertex(inner[index])
		surface.add_vertex(outer[next])
		surface.add_vertex(inner[next])
		surface.add_vertex(inner[index])
	var mesh: ArrayMesh = surface.commit()
	_ring_cache[key] = mesh
	return mesh


static func _corners(radius: float) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for index: int in range(6):
		var angle: float = deg_to_rad(60.0 * float(index) - 90.0)
		result.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return result
