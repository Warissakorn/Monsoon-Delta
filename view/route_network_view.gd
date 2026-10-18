class_name RouteNetworkView
extends Node3D
## Cached, purely decorative roads. Game commands never pay a road cost.

const Graph = preload("res://view/route_graph.gd")

var graph: RouteGraph
var rebuild_count: int = 0
var _signature: String = "!unbuilt"
var _roads: MeshInstance3D
var _stairs: MeshInstance3D


func set_state(state: GameState) -> void:
	var next_signature: String = Graph.topology_signature(state)
	if next_signature == _signature:
		return
	_signature = next_signature
	graph = Graph.build(state)
	rebuild_count += 1
	_rebuild()


func _rebuild() -> void:
	if _roads == null:
		_roads = MeshInstance3D.new()
		_roads.name = "RoadRibbons"
		_roads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_roads)
		_stairs = MeshInstance3D.new()
		_stairs.name = "TerrainSteps"
		add_child(_stairs)
		var road_material: StandardMaterial3D = StandardMaterial3D.new()
		road_material.vertex_color_use_as_albedo = true
		road_material.roughness = 1.0
		road_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_roads.material_override = road_material
		_stairs.material_override = road_material
	_roads.mesh = null
	_stairs.mesh = null
	if graph.routes.is_empty():
		return
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var road: Color = Color("b99d71")
	var wear: Color = Color("cbb185")
	var joints: Dictionary = {}
	for route: Dictionary in graph.routes:
		var points: PackedVector3Array = route["points"]
		_ribbon(surface, points, Graph.HALF_WIDTH, road)
		# A narrow worn centre makes paths read against both sand and grass.
		_ribbon(surface, points, Graph.HALF_WIDTH * 0.42, wear, 0.001)
		for point: Vector3 in points:
			var key: String = "%.4f:%.4f:%.4f" % [point.x, point.y, point.z]
			if not joints.has(key):
				_disk(surface, point, Graph.HALF_WIDTH, road)
				joints[key] = true
	_roads.mesh = surface.commit()
	if not graph.steps.is_empty():
		var stair_surface: SurfaceTool = SurfaceTool.new()
		stair_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for step: Dictionary in graph.steps:
			_stair(stair_surface, step["low"], step["high"])
		_stairs.mesh = stair_surface.commit()


func _ribbon(surface: SurfaceTool, points: PackedVector3Array, half: float, color: Color, lift: float = 0.0) -> void:
	for index: int in range(1, points.size()):
		var first: Vector3 = points[index - 1] + Vector3.UP * lift
		var second: Vector3 = points[index] + Vector3.UP * lift
		var direction: Vector3 = second - first
		var sideways: Vector3 = Vector3(-direction.z, 0.0, direction.x).normalized() * half
		if sideways.length_squared() < 0.000001:
			continue
		_triangle(surface, first - sideways, first + sideways, second + sideways, color)
		_triangle(surface, first - sideways, second + sideways, second - sideways, color)


func _disk(surface: SurfaceTool, point: Vector3, radius: float, color: Color) -> void:
	# Round caps also fill T-junctions without cracks or protruding mitres.
	for index: int in range(12):
		var first_angle: float = float(index) * TAU / 12.0
		var next_angle: float = float(index + 1) * TAU / 12.0
		var first: Vector3 = point + Vector3(cos(first_angle), 0.0, sin(first_angle)) * radius
		var second: Vector3 = point + Vector3(cos(next_angle), 0.0, sin(next_angle)) * radius
		_triangle(surface, point, first, second, color)


func _stair(surface: SurfaceTool, low: Vector3, high: Vector3) -> void:
	# Solid timber treads visibly support every one-level terrain crossing.
	# Higher cliffs have no graph connection and cannot receive stairs.
	var full_run: Vector3 = Vector3(high.x - low.x, 0.0, high.z - low.z)
	var run: Vector3 = full_run * 0.5
	var side: Vector3 = Vector3(-run.z, 0.0, run.x).normalized() * Graph.HALF_WIDTH
	var count: int = maxi(2, ceili((high.y - low.y) / 0.1))
	for index: int in range(count + 1):
		var begin: Vector3 = low + run * float(index) / float(count)
		var end: Vector3 = low + run * float(index + 1) / float(count) if index < count else low + full_run
		var height: float = low.y + (high.y - low.y) * float(mini(index + 1, count)) / float(count) - 0.002
		var first: Vector3 = Vector3(begin.x, height, begin.z)
		var second: Vector3 = Vector3(end.x, height, end.z)
		var floor_first: Vector3 = Vector3(begin.x, low.y - 0.035, begin.z)
		var floor_second: Vector3 = Vector3(end.x, low.y - 0.035, end.z)
		var wood: Color = Color("92784f").lightened(float(index % 2) * 0.08)
		_triangle(surface, first - side, first + side, second + side, wood)
		_triangle(surface, first - side, second + side, second - side, wood)
		_triangle(surface, floor_first - side, first - side, second - side, wood.darkened(0.18))
		_triangle(surface, floor_first - side, second - side, floor_second - side, wood.darkened(0.18))
		_triangle(surface, floor_first + side, second + side, first + side, wood.darkened(0.18))
		_triangle(surface, floor_first + side, floor_second + side, second + side, wood.darkened(0.18))
		_triangle(surface, floor_first - side, first + side, first - side, wood.darkened(0.12))
		_triangle(surface, floor_first - side, floor_first + side, first + side, wood.darkened(0.12))


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	if normal.y < 0.0:
		normal = -normal
	surface.set_normal(normal)
	surface.set_color(color)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
