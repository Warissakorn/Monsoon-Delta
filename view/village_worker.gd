class_name VillageWorker
extends Node3D
## Small pooled presentation actors. Geometry and materials are shared by every
## villager; a job only switches tools and poses, never creates new scene nodes.

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

var _body: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _tools: Dictionary = {}
var _loads: Dictionary = {}
var _task: String = "idle"
var _carrying: bool = false


func build(index: int) -> void:
	name = "Villager_%02d" % index
	var shirts: Array[Color] = [Color("#d27e50"), Color("#6c9a9c"), Color("#f1d28b"), Color("#a6b482")]
	var skin: Color = Color("#bd8762") if index % 2 == 0 else Color("#d9a77c")
	var shirt: Color = shirts[index % shirts.size()]
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_piece(_body, "torso", _cylinder(0.058, 0.073, 0.15), Vector3(0.0, 0.205, 0.0), shirt)
	_piece(_body, "sash", _cylinder(0.074, 0.074, 0.025), Vector3(0.0, 0.143, 0.0), Color("#665548"))
	_piece(_body, "head", _sphere(0.062), Vector3(0.0, 0.325, 0.0), skin)
	_piece(_body, "hair", _sphere(0.063), Vector3(0.0, 0.347, -0.009), Color("#463d34"), Vector3(1.0, 0.58, 0.97))
	_piece(_body, "hat_brim", _cylinder(0.113, 0.113, 0.014), Vector3(0.0, 0.366, 0.0), Color("#d8b777"))
	_piece(_body, "hat", _cylinder(0.0, 0.097, 0.071), Vector3(0.0, 0.405, 0.0), Color("#e6c98c"))
	for side: float in [-1.0, 1.0]:
		_piece(_body, "eye", _sphere(0.008), Vector3(side * 0.022, 0.329, 0.056), Color("#493d34"))
	_left_arm = _limb("LeftArm", Vector3(-0.083, 0.257, 0.0), skin, 0.116)
	_right_arm = _limb("RightArm", Vector3(0.083, 0.257, 0.0), skin, 0.116)
	_left_leg = _limb("LeftLeg", Vector3(-0.032, 0.137, 0.0), Color("#4b6066"), 0.12)
	_right_leg = _limb("RightLeg", Vector3(0.032, 0.137, 0.0), Color("#4b6066"), 0.12)
	_make_tools()
	_make_loads()
	set_task("idle", false)
	pose(0.0, false, false, true)


func set_task(kind: String, carrying: bool) -> void:
	_task = kind
	_carrying = carrying
	for key: String in _tools:
		(_tools[key] as Node3D).visible = key == _tool_for(kind)
	for key: String in _loads:
		(_loads[key] as Node3D).visible = carrying and key == _load_for(kind)


func pose(time: float, walking: bool, working: bool, reduced_motion: bool) -> void:
	var stride: float = sin(time * 10.0) * 0.55 if walking and not reduced_motion else 0.0
	_left_leg.rotation.x = stride
	_right_leg.rotation.x = -stride
	_left_arm.rotation.x = -stride * 0.7
	_right_arm.rotation.x = stride * 0.5
	_body.position.y = absf(sin(time * 10.0)) * 0.010 if walking and not reduced_motion else 0.0
	_body.rotation = Vector3.ZERO
	if working:
		var stroke: float = 0.0 if reduced_motion else sin(time * 4.8)
		match _task:
			"farm", "harvest", "dig", "fill", "plant":
				_body.rotation.x = -0.12 - stroke * 0.07
				_right_arm.rotation.x = -0.55 + stroke * 0.45
				_left_arm.rotation.x = -0.35 + stroke * 0.25
			"chop", "build", "demolish", "operate":
				_right_arm.rotation.x = -0.75 + stroke * 0.75
				_left_arm.rotation.x = -0.20
			"fish":
				_right_arm.rotation.x = -0.40 + stroke * 0.05
				_left_arm.rotation.x = -0.35
	elif not walking and not reduced_motion:
		_body.rotation.z = sin(time * 0.65) * 0.018
	if _carrying:
		_left_arm.rotation.x = -0.5


func _limb(label: String, at: Vector3, color: Color, length: float) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = label
	pivot.position = at
	_body.add_child(pivot)
	_piece(pivot, "limb", _cylinder(0.019, 0.023, length), Vector3(0.0, -length * 0.5, 0.0), color)
	return pivot


func _make_tools() -> void:
	var timber: Color = Color("#8d6749")
	var iron: Color = Color("#a9bcc2")
	for kind: String in ["hoe", "axe", "hammer", "rod", "sprout"]:
		var tool: Node3D = Node3D.new()
		tool.name = kind.capitalize()
		tool.position = Vector3(0.0, -0.095, 0.025)
		_right_arm.add_child(tool)
		_tools[kind] = tool
		if kind == "sprout":
			_piece(tool, "stem", _cylinder(0.007, 0.009, 0.14), Vector3(0.0, 0.04, 0.0), Color("#7f945b"))
			_piece(tool, "leaves", _sphere(0.039), Vector3(0.0, 0.095, 0.0), Color("#acc574"), Vector3(1.4, 0.6, 0.85))
			continue
		var length: float = 0.41 if kind == "rod" else 0.23
		var handle_y: float = 0.17 if kind == "rod" else -0.035
		_piece(tool, "handle", _cylinder(0.008, 0.010, length), Vector3(0.0, handle_y, 0.0), timber)
		match kind:
			"hoe":
				_piece(tool, "blade", _box(Vector3(0.075, 0.018, 0.065)), Vector3(0.0, -0.15, 0.025), iron)
			"axe":
				_piece(tool, "blade", _box(Vector3(0.105, 0.052, 0.026)), Vector3(0.025, -0.125, 0.0), iron)
			"hammer":
				_piece(tool, "head", _box(Vector3(0.094, 0.048, 0.046)), Vector3(0.0, -0.13, 0.0), iron)
			"rod":
				tool.rotation.x = 0.80
				var line_tip: Node3D = Node3D.new()
				line_tip.position.y = 0.375
				line_tip.rotation.x = -0.80
				tool.add_child(line_tip)
				_piece(line_tip, "line", _cylinder(0.002, 0.002, 0.22), Vector3(0.0, -0.11, 0.0), Color("#d4dfcd"))


func _make_loads() -> void:
	for kind: String in ["basket", "fish", "rice", "wood"]:
		var load: Node3D = Node3D.new()
		load.name = "Load_" + kind
		load.position = Vector3(0.0, 0.205, -0.095)
		_body.add_child(load)
		_loads[kind] = load
		if kind == "wood":
			for side: float in [-1.0, 1.0]:
				var log_piece: MeshInstance3D = _piece(load, "log", _cylinder(0.027, 0.031, 0.20), Vector3(side * 0.027, 0.01, 0.0), Color("#a47b51"))
				log_piece.rotation.x = PI * 0.5
		else:
			_piece(load, "basket", _cylinder(0.073, 0.050, 0.105), Vector3.ZERO, Color("#b99459"))
			_piece(load, "rim", _cylinder(0.078, 0.078, 0.016), Vector3(0.0, 0.053, 0.0), Color("#dcc48c"))
			if kind == "fish":
				_piece(load, "catch", _sphere(0.041), Vector3(0.0, 0.065, 0.0), Color("#9ac8cc"), Vector3(0.65, 0.7, 1.6))
			elif kind == "rice":
				for side: float in [-1.0, 1.0]:
					_piece(load, "grain", _cylinder(0.014, 0.019, 0.13), Vector3(side * 0.024, 0.09, 0.0), Color("#e8c66e"))


static func _tool_for(kind: String) -> String:
	match kind:
		"farm", "harvest", "dig", "fill": return "hoe"
		"chop": return "axe"
		"build", "demolish", "operate": return "hammer"
		"fish": return "rod"
		"plant": return "sprout"
	return ""


static func _load_for(kind: String) -> String:
	match kind:
		"chop": return "wood"
		"fish": return "fish"
		"harvest": return "rice"
	return "basket"


static func _piece(parent: Node3D, label: String, mesh: Mesh, at: Vector3, color: Color, size: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var piece: MeshInstance3D = MeshInstance3D.new()
	piece.name = label
	piece.mesh = mesh
	piece.position = at
	piece.scale = size
	var key: String = color.to_html()
	if not _materials.has(key):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		_materials[key] = material
	piece.material_override = _materials[key] as Material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece)
	return piece


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var key: String = "c:%.3f:%.3f:%.3f" % [top, bottom, height]
	if not _meshes.has(key):
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = top
		mesh.bottom_radius = bottom
		mesh.height = height
		mesh.radial_segments = 7
		mesh.rings = 1
		_meshes[key] = mesh
	return _meshes[key] as CylinderMesh


static func _sphere(radius: float) -> SphereMesh:
	var key: String = "s:%.3f" % radius
	if not _meshes.has(key):
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 8
		mesh.rings = 3
		_meshes[key] = mesh
	return _meshes[key] as SphereMesh


static func _box(size: Vector3) -> BoxMesh:
	var key: String = "b:" + str(size)
	if not _meshes.has(key):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _meshes[key] as BoxMesh
