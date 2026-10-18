class_name MeshLib
extends RefCounted

## Pointy-top procedural pieces. The first vertex points toward -Z, matching
## Hex.to_world's axial spacing. Terrain surfaces can use separate materials.
static var _hex_cache: Dictionary = {}
static var _ring_cache: Dictionary = {}
static var _rice_cache: Dictionary = {}
static var _grass_mesh: ArrayMesh


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


## Entire fields share one mesh per growth stage rather than one node per leaf.
static func rice_field(stage: int) -> ArrayMesh:
	if _rice_cache.has(stage):
		return _rice_cache[stage] as ArrayMesh
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height: float = 0.13 if stage < 0 else 0.25 + float(mini(stage, 3)) * 0.045
	for row: int in range(3):
		for column: int in range(4):
			var base: Vector3 = Vector3((float(column) - 1.5) * 0.28, 0.025, float(row - 1) * 0.32)
			for blade: int in range(3):
				var angle: float = float(blade) * TAU / 3.0 + float(row + column) * 0.4
				var across: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.022
				var lean: Vector3 = Vector3(-sin(angle), 0.0, cos(angle)) * 0.09
				var tip: Vector3 = base + Vector3.UP * height + lean
				_triangle(surface, base - across, base + across, tip, Color(0.73, 0.82, 0.62), Color.WHITE)
				_triangle(surface, base + across, base - across, tip, Color(0.73, 0.82, 0.62), Color.WHITE)
			if stage > 0:
				var tip: Vector3 = base + Vector3.UP * (height - 0.015)
				_triangle(surface, tip, tip + Vector3(0.09, -0.035, 0.018), tip + Vector3(0.025, -0.085, 0.035), Color(1.0, 0.92, 0.56), Color(1.0, 0.92, 0.56))
				_triangle(surface, tip, tip + Vector3(-0.025, -0.085, -0.035), tip + Vector3(-0.09, -0.035, -0.018), Color(1.0, 0.92, 0.56), Color(1.0, 0.92, 0.56))
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	mesh.set_meta("thin_foliage", true)
	_rice_cache[stage] = mesh
	return mesh


static func grass_tuft() -> ArrayMesh:
	if _grass_mesh != null:
		return _grass_mesh
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade: int in range(5):
		var angle: float = TAU * float(blade) / 5.0
		var base: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.025
		var across: Vector3 = Vector3(-sin(angle), 0.0, cos(angle)) * 0.018
		var tip: Vector3 = base * 3.5 + Vector3.UP * (0.11 + float(blade % 3) * 0.035)
		_triangle(surface, base - across, base + across, tip, Color(0.72, 0.82, 0.61), Color.WHITE)
		_triangle(surface, base + across, base - across, tip, Color(0.72, 0.82, 0.61), Color.WHITE)
	surface.generate_normals()
	_grass_mesh = surface.commit()
	_grass_mesh.set_meta("thin_foliage", true)
	return _grass_mesh


static func _triangle(surface: SurfaceTool, first: Vector3, second: Vector3, third: Vector3, base_color: Color, tip_color: Color) -> void:
	surface.set_color(base_color)
	surface.add_vertex(first)
	surface.add_vertex(second)
	surface.set_color(tip_color)
	surface.add_vertex(third)
