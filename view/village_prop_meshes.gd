class_name VillagePropMeshes
extends RefCounted
## Small original low-poly assets, shared and vertex-colored for batching.

const WOOD: Color = Color("87664b")
const PALE: Color = Color("c5aa73")
const DARK: Color = Color("4c4935")
const GREEN: Color = Color("437357")
const LEAF: Color = Color("91a962")
const CLAY: Color = Color("b87552")
const PAPER: Color = Color("e3dcc0")
static var _cache: Dictionary = {}
static var _material: StandardMaterial3D


class Maker extends RefCounted:
	var surface: SurfaceTool = SurfaceTool.new()

	func _init() -> void:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
		# Godot's front faces use clockwise winding.
		var normal: Vector3 = (c - a).cross(b - a).normalized()
		surface.set_color(color)
		surface.set_normal(normal)
		for point: Vector3 in [a, b, c]:
			surface.add_vertex(point)

	func piece(mesh: Mesh, at: Vector3, color: Color, scale: Vector3 = Vector3.ONE, rotation: Vector3 = Vector3.ZERO) -> void:
		var transform: Transform3D = Transform3D(Basis.from_euler(rotation).scaled(scale), at)
		var points: PackedVector3Array = mesh.get_faces()
		for index: int in range(0, points.size(), 3):
			triangle(transform * points[index], transform * points[index + 1], transform * points[index + 2], color)

	func box(size: Vector3, at: Vector3, color: Color) -> void:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		piece(mesh, at, color)

	func cylinder(radius: float, height: float, at: Vector3, color: Color) -> void:
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius * 1.05
		mesh.height = height
		mesh.radial_segments = 7
		mesh.rings = 1
		piece(mesh, at, color)

	func sphere(size: Vector3, at: Vector3, color: Color) -> void:
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 7
		mesh.rings = 3
		piece(mesh, at, color, size)

	func beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(width, a.distance_to(b), width)
		var basis: Basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		var transform: Transform3D = Transform3D(basis, (a + b) * 0.5)
		var points: PackedVector3Array = mesh.get_faces()
		for index: int in range(0, points.size(), 3):
			triangle(transform * points[index], transform * points[index + 1], transform * points[index + 2], color)


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.93
	return _material


static func mesh(kind: String) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var m: Maker = Maker.new()
	match kind:
		"courtyard":
			m.piece(MeshLib.hex_prism(0.78), Vector3.ZERO, Color("a6966e"), Vector3(1.0, 0.008, 1.0))
		"fence":
			for x: float in [-0.15, 0.0, 0.15]:
				m.cylinder(0.013, 0.26, Vector3(x, 0.13, 0.0), PALE)
			for y: float in [0.08, 0.20]:
				m.beam(Vector3(-0.18, y, 0.0), Vector3(0.18, y, 0.0), 0.018, WOOD)
				for x: float in [-0.15, 0.15]:
					m.box(Vector3(0.026, 0.028, 0.027), Vector3(x, y, 0.0), PALE.lightened(0.20))
		"jar":
			m.sphere(Vector3(0.17, 0.20, 0.17), Vector3(0.0, 0.10, 0.0), CLAY)
			m.cylinder(0.053, 0.012, Vector3(0.0, 0.186, 0.0), PALE)
			m.cylinder(0.044, 0.014, Vector3(0.0, 0.19, 0.0), DARK)
			m.box(Vector3(0.08, 0.012, 0.018), Vector3(0.045, 0.205, 0.015), WOOD)
		"bench", "workbench":
			var height: float = 0.19 if kind == "workbench" else 0.13
			m.box(Vector3(0.30, 0.025, 0.16), Vector3(0.0, height, 0.0), PALE)
			for x: float in [-0.12, 0.12]:
				for z: float in [-0.05, 0.05]:
					m.box(Vector3(0.022, height, 0.022), Vector3(x, height * 0.5, z), WOOD)
			if kind == "bench":
				m.box(Vector3(0.30, 0.065, 0.018), Vector3(0.0, 0.23, -0.065), WOOD)
			else:
				m.box(Vector3(0.14, 0.012, 0.014), Vector3(-0.01, 0.214, 0.02), DARK)
				m.box(Vector3(0.045, 0.027, 0.04), Vector3(0.06, 0.22, 0.02), WOOD)
		"noticeboard":
			for x: float in [-0.12, 0.12]:
				m.box(Vector3(0.022, 0.47, 0.022), Vector3(x, 0.235, 0.0), WOOD)
			m.box(Vector3(0.29, 0.20, 0.025), Vector3(0.0, 0.34, 0.0), WOOD)
			for x: float in [-0.065, 0.065]:
				m.box(Vector3(0.085, 0.12, 0.007), Vector3(x, 0.34, 0.018), PAPER)
				m.box(Vector3(0.05, 0.007, 0.008), Vector3(x, 0.36, 0.023), DARK)
			m.box(Vector3(0.35, 0.028, 0.10), Vector3(0.0, 0.47, 0.0), CLAY)
		"signpost":
			m.cylinder(0.015, 0.45, Vector3(0.0, 0.225, 0.0), WOOD)
			m.box(Vector3(0.22, 0.06, 0.025), Vector3(-0.03, 0.35, 0.0), PALE)
			m.box(Vector3(0.19, 0.055, 0.025), Vector3(0.035, 0.26, 0.0), PALE)
		"banana":
			m.cylinder(0.035, 0.34, Vector3(0.0, 0.17, 0.0), Color("9b9e64"))
			for index: int in range(5):
				var angle: float = index * TAU / 5.0 + (0.25 if index % 2 == 0 else -0.1)
				var outward: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
				var across: Vector3 = Vector3(-sin(angle), 0.0, cos(angle)) * 0.075
				var root: Vector3 = Vector3.UP * (0.33 + index * 0.018)
				var middle: Vector3 = outward * 0.17 + Vector3.UP * (0.48 + index * 0.008)
				var tip: Vector3 = outward * 0.36 + Vector3.UP * (0.27 + index * 0.018)
				for side: float in [-1.0, 1.0]:
					var edge: Vector3 = middle + across * side - Vector3.UP * 0.027
					m.triangle(root, edge, middle, LEAF.lightened(index * 0.025))
					m.triangle(middle, edge, tip, LEAF)
					m.triangle(middle, edge, root, GREEN)
					m.triangle(tip, edge, middle, GREEN)
		"bamboo":
			for index: int in range(3):
				var x: float = (index - 1) * 0.045
				var height: float = 0.47 + index * 0.09
				m.cylinder(0.015, height, Vector3(x, height * 0.5, 0.0), GREEN)
				for node: int in range(3):
					m.cylinder(0.018, 0.012, Vector3(x, 0.12 + node * 0.14, 0.0), LEAF)
				for side: float in [-1.0, 1.0]:
					m.triangle(Vector3(x, height * 0.8, 0.0), Vector3(x + side * 0.16, height + 0.02, 0.025), Vector3(x + side * 0.06, height * 0.78, 0.045), LEAF)
		"flowerbed":
			m.box(Vector3(0.24, 0.045, 0.19), Vector3(0.0, 0.023, 0.0), WOOD)
			m.box(Vector3(0.21, 0.01, 0.16), Vector3(0.0, 0.047, 0.0), DARK)
			for index: int in range(4):
				var at: Vector3 = Vector3(float(index % 2) * 0.10 - 0.05, 0.08, float(index / 2) * 0.08 - 0.04)
				m.sphere(Vector3(0.09, 0.09, 0.08), at, GREEN)
				m.sphere(Vector3(0.03, 0.025, 0.03), at + Vector3.UP * 0.05, PAPER if index % 2 == 0 else PALE)
		"reeds":
			for index: int in range(6):
				var angle: float = index * TAU / 6.0
				var at: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.055
				var height: float = 0.23 + float(index % 3) * 0.06
				m.cylinder(0.006, height, at + Vector3.UP * height * 0.5, LEAF)
				m.cylinder(0.012, 0.055, at + Vector3.UP * height, WOOD)
		"drying_mat":
			m.box(Vector3(0.32, 0.008, 0.22), Vector3(0.0, 0.006, 0.0), PALE)
			for index: int in range(6):
				m.box(Vector3(0.30, 0.003, 0.007), Vector3(0.0, 0.012, -0.09 + index * 0.035), WOOD.lightened(0.25))
		"rice_bundle":
			for index: int in range(3):
				m.cylinder(0.025, 0.16, Vector3((index - 1) * 0.035, 0.09, 0.0), PALE)
			m.box(Vector3(0.13, 0.018, 0.07), Vector3(0.0, 0.09, 0.0), WOOD)
		"mud_margin", "rain_soil":
			m.sphere(Vector3(0.36, 0.012, 0.20), Vector3.ZERO, Color("746e4c") if kind == "mud_margin" else Color("68705a"))
			for index: int in range(3):
				m.sphere(Vector3(0.035, 0.025, 0.03), Vector3((index - 1) * 0.08, 0.012, 0.05), Color("a2a080"))
		"dry_cracks":
			for index: int in range(3):
				var angle: float = index * TAU / 3.0
				var middle: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.08
				m.beam(Vector3.ZERO, middle, 0.005, Color("7b7954"))
				m.beam(middle, middle * 1.8 + Vector3(0.02, 0.0, -0.025), 0.004, Color("7b7954"))
		"dock", "cargo_dock", "fishing_dock":
			var width: float = 0.40 if kind == "cargo_dock" else 0.30
			for index: int in range(9):
				m.box(Vector3(width, 0.027, 0.075), Vector3(0.0, 0.0, 0.04 + index * 0.08), PALE.darkened(float(index % 3) * 0.045))
			for x: float in [-width * 0.39, width * 0.39]:
				m.box(Vector3(0.035, 0.06, 0.76), Vector3(x, -0.04, 0.36), WOOD)
			if kind == "fishing_dock":
				m.cylinder(0.045, 0.09, Vector3(-0.09, 0.06, 0.50), WOOD)
				m.beam(Vector3(0.11, 0.02, 0.10), Vector3(0.11, 0.36, 0.47), 0.012, DARK)
			elif kind == "cargo_dock":
				m.box(Vector3(0.13, 0.015, 0.12), Vector3(0.10, 0.03, 0.50), WOOD)
		"post":
			m.box(Vector3.ONE, Vector3.ZERO, WOOD)
		"gauge":
			m.box(Vector3(0.035, 1.0, 0.035), Vector3(0.0, 0.5, 0.0), WOOD)
			for index: int in range(5):
				m.box(Vector3(0.065, 0.012, 0.012), Vector3(0.015, 0.10 + index * 0.17, 0.023), PAPER if index % 2 == 0 else PALE)
		"water_mark":
			m.box(Vector3(0.09, 0.018, 0.055), Vector3.ZERO, Color("8ed1ce"))
		"clothesline":
			for x: float in [-0.16, 0.16]:
				m.cylinder(0.012, 0.39, Vector3(x, 0.195, 0.0), WOOD)
			m.beam(Vector3(-0.16, 0.35, 0.0), Vector3(0.16, 0.35, 0.0), 0.006, PALE)
		"cloth":
			for side: float in [-1.0, 1.0]:
				m.box(Vector3(0.10, 0.14, 0.006), Vector3(side * 0.075, 0.0, 0.0), Color("769d9d") if side < 0.0 else PAPER)
		"boat":
			_boat(m)
		"chicken":
			m.sphere(Vector3(0.08, 0.09, 0.11), Vector3(0.0, 0.075, 0.0), PAPER)
			m.sphere(Vector3(0.045, 0.05, 0.045), Vector3(0.0, 0.13, 0.04), PALE)
			m.box(Vector3(0.008, 0.019, 0.023), Vector3(0.0, 0.159, 0.04), Color("b75d47"))
			m.box(Vector3(0.02, 0.013, 0.027), Vector3(0.0, 0.13, 0.065), CLAY)
			for x: float in [-0.018, 0.018]:
				m.box(Vector3(0.007, 0.035, 0.008), Vector3(x, 0.023, 0.0), CLAY)
			m.triangle(Vector3(-0.025, 0.08, -0.03), Vector3(0.0, 0.14, -0.08), Vector3(0.025, 0.08, -0.03), WOOD)
		"bird":
			m.sphere(Vector3(0.05, 0.06, 0.08), Vector3(0.0, 0.035, 0.0), Color("647d7e"))
			m.sphere(Vector3(0.033, 0.035, 0.033), Vector3(0.0, 0.065, 0.026), DARK)
			m.box(Vector3(0.012, 0.009, 0.025), Vector3(0.0, 0.065, 0.048), PALE)
		"fish":
			m.sphere(Vector3(0.05, 0.007, 0.12), Vector3.ZERO, Color("2b6564"))
			m.triangle(Vector3(0.0, 0.0, -0.04), Vector3(-0.035, 0.0, -0.09), Vector3(0.035, 0.0, -0.09), Color("2b6564"))
		"ripple":
			var ring: TorusMesh = TorusMesh.new()
			ring.inner_radius = 0.075
			ring.outer_radius = 0.081
			ring.rings = 16
			ring.ring_segments = 3
			m.piece(ring, Vector3.ZERO, Color("a4d6c8"))
		"drip":
			m.box(Vector3(0.004, 0.035, 0.004), Vector3.ZERO, Color("adc9c8"))
		"mote":
			m.sphere(Vector3(0.013, 0.012, 0.013), Vector3.ZERO, Color("ccc29b"))
		_:
			if kind.begins_with("wood_rack_") or kind == "empty_rack":
				_rack(m, int(kind.trim_prefix("wood_rack_")) if kind != "empty_rack" else 0)
			elif kind in ["basket", "catch_basket"]:
				m.cylinder(0.065, 0.11, Vector3(0.0, 0.055, 0.0), PALE)
				m.cylinder(0.056, 0.005, Vector3(0.0, 0.113, 0.0), DARK)
				if kind == "catch_basket":
					m.sphere(Vector3(0.035, 0.025, 0.09), Vector3(0.0, 0.12, 0.0), Color("85afb3"))
			else:
				push_error("Unknown village prop: " + kind)
	var built: ArrayMesh = m.surface.commit()
	_cache[kind] = built
	return built


static func _rack(m: Maker, stock: int) -> void:
	for x: float in [-0.12, 0.12]:
		m.box(Vector3(0.025, 0.18, 0.15), Vector3(x, 0.09, 0.0), WOOD)
	for index: int in range(stock):
		var at: Vector3 = Vector3(0.0, 0.04 + index * 0.045, 0.0)
		var log_piece: CylinderMesh = CylinderMesh.new()
		log_piece.top_radius = 0.025
		log_piece.bottom_radius = 0.025
		log_piece.height = 0.28
		log_piece.radial_segments = 6
		log_piece.rings = 1
		m.piece(log_piece, at, PALE, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))


static func _boat(m: Maker) -> void:
	var outline: Array[Vector2] = [Vector2(0.0, -0.42), Vector2(0.10, -0.30), Vector2(0.15, -0.16), Vector2(0.15, 0.17), Vector2(0.08, 0.33), Vector2(0.0, 0.40), Vector2(-0.08, 0.33), Vector2(-0.15, 0.17), Vector2(-0.15, -0.16), Vector2(-0.10, -0.30)]
	for index: int in range(outline.size()):
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[(index + 1) % outline.size()]
		var top_a: Vector3 = Vector3(a.x, 0.085, a.y)
		var top_b: Vector3 = Vector3(b.x, 0.085, b.y)
		var low_a: Vector3 = Vector3(a.x * 0.70, 0.015, a.y * 0.85)
		var low_b: Vector3 = Vector3(b.x * 0.70, 0.015, b.y * 0.85)
		m.triangle(top_a, low_a, top_b, WOOD)
		m.triangle(top_b, low_a, low_b, WOOD)
		m.triangle(top_b, low_a, top_a, PALE)
		m.triangle(low_b, low_a, top_b, PALE)
		m.triangle(Vector3(0.0, 0.016, 0.0), low_a, low_b, WOOD)
		m.beam(top_a, top_b, 0.015, PALE)
	for z: float in [-0.16, 0.17]:
		m.box(Vector3(0.24, 0.018, 0.055), Vector3(0.0, 0.07, z), PALE)
	m.beam(Vector3(-0.09, 0.10, -0.19), Vector3(0.10, 0.10, 0.19), 0.013, WOOD)
	m.box(Vector3(0.045, 0.009, 0.09), Vector3(0.10, 0.10, 0.20), PALE)
