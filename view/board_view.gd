class_name BoardView
extends Node3D

## The scene is a view of GameState only; rebuilding never changes simulation data.
const BASE_Y: float = -1.7
const HEX_RADIUS: float = 0.96
const NO_COORD: Vector2i = Vector2i(2147483647, 2147483647)
const MARKER_FONT: Font = preload("res://assets/fonts/NotoSansThai.ttf")

var palette: Dictionary = {}
var state: GameState
var _tiles_root: Node3D
var _labels_root: Node3D
var _targets_root: Node3D
var _preview_root: Node3D
var _selection: MeshInstance3D
var _hover: MeshInstance3D
var _selected_coord: Vector2i = NO_COORD
var _hover_coord: Vector2i = NO_COORD
var _labels_visible: bool = false
var _materials: Dictionary = {}
var _target_coords: Array[Vector2i] = []
var _invalid_coord: Vector2i = NO_COORD
var _prediction: Dictionary = {}


func _ready() -> void:
	_ensure_nodes()


func set_state(next_state: GameState) -> void:
	state = next_state
	_selected_coord = NO_COORD
	_hover_coord = NO_COORD
	_target_coords.clear()
	_invalid_coord = NO_COORD
	_prediction = {}
	refresh()


func refresh() -> void:
	_ensure_nodes()
	_clear_root(_tiles_root)
	_clear_root(_labels_root)
	if state == null:
		_selection.hide()
		_hover.hide()
		_clear_root(_targets_root)
		_clear_root(_preview_root)
		return
	for tile: Tile in state.tiles:
		_build_tile(tile)
	_update_markers()
	_refresh_targets()
	_refresh_preview()


## Targets and predictions survive refresh(), but set_state() clears them.
func set_targets(coords: Array[Vector2i], invalid_coord: Vector2i = NO_COORD) -> void:
	_target_coords.assign(coords)
	_invalid_coord = invalid_coord
	_ensure_nodes()
	_refresh_targets()


func clear_targets() -> void:
	set_targets([])


## Prediction state and report are read only; overlays never edit either state.
func set_preview(prediction: Dictionary, enabled: bool = true) -> void:
	_prediction = prediction if enabled else {}
	_ensure_nodes()
	_refresh_preview()


func select(coord: Vector2i) -> void:
	_selected_coord = coord
	_ensure_nodes()
	_update_markers()


func hover(coord: Vector2i) -> void:
	_hover_coord = coord
	_ensure_nodes()
	_update_markers()


func clear_hover() -> void:
	hover(NO_COORD)


func set_labels_visible(enabled: bool) -> void:
	_labels_visible = enabled
	_ensure_nodes()
	_labels_root.visible = enabled


func pick(view_camera: Camera3D, screen_pos: Vector2) -> Tile:
	if state == null or view_camera == null:
		return null
	var ray_origin: Vector3 = to_local(view_camera.project_ray_origin(screen_pos))
	var ray_direction: Vector3 = global_transform.basis.inverse() * view_camera.project_ray_normal(screen_pos)
	if absf(ray_direction.y) < 0.00001:
		return null
	var closest_distance: float = INF
	var closest: Tile = null
	for tile: Tile in state.tiles:
		var center: Vector3 = Hex.to_world(tile.coord, tile.elevation)
		var distance: float = (_surface_y(tile) - ray_origin.y) / ray_direction.y
		if distance < 0.0 or distance >= closest_distance:
			continue
		var intersection: Vector3 = ray_origin + ray_direction * distance - center
		var x: float = absf(intersection.x)
		var z: float = absf(intersection.z)
		var radius: float = 0.985 if tile.water >= 0.05 or tile.is_sea else HEX_RADIUS
		if x <= Hex.SQRT_3 * radius * 0.5 and z <= radius and x + Hex.SQRT_3 * z <= Hex.SQRT_3 * radius:
			closest_distance = distance
			closest = tile
	return closest


func _ensure_nodes() -> void:
	if palette.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/palette.json"))
		if parsed is Dictionary:
			palette = parsed
	if _tiles_root != null:
		return
	_tiles_root = Node3D.new()
	_tiles_root.name = "Tiles"
	add_child(_tiles_root)
	_labels_root = Node3D.new()
	_labels_root.name = "ElevationLabels"
	_labels_root.visible = _labels_visible
	add_child(_labels_root)
	_targets_root = Node3D.new()
	_targets_root.name = "Targets"
	add_child(_targets_root)
	_preview_root = Node3D.new()
	_preview_root.name = "Preview"
	add_child(_preview_root)
	_selection = MeshInstance3D.new()
	_selection.name = "SelectedHex"
	_selection.mesh = MeshLib.hex_ring(1.005, 0.935)
	_selection.material_override = _material(_color("accent"), true)
	_selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_selection)
	_selection.hide()
	_hover = MeshInstance3D.new()
	_hover.name = "HoveredHex"
	_hover.mesh = MeshLib.hex_ring(0.995, 0.972)
	_hover.material_override = _material(_color("highlight"), true)
	_hover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hover)
	_hover.hide()


func _build_tile(tile: Tile) -> void:
	var cell: Node3D = Node3D.new()
	cell.name = "Hex_%d_%d" % [tile.q, tile.r]
	cell.position = Hex.to_world(tile.coord, tile.elevation)
	_tiles_root.add_child(cell)
	var terrain: MeshInstance3D = MeshInstance3D.new()
	terrain.mesh = MeshLib.hex_prism(HEX_RADIUS)
	terrain.position.y = BASE_Y - cell.position.y
	terrain.scale.y = maxf(0.05, cell.position.y - BASE_Y)
	terrain.set_surface_override_material(0, _material(_terrain_color(tile)))
	terrain.set_surface_override_material(1, _material(_color("earth"), false, true))
	cell.add_child(terrain)
	if tile.water >= 0.05 or tile.is_sea:
		_build_water(cell, tile)
	if tile.feature == C.Feature.FOREST or tile.feature == C.Feature.SAPLING:
		_build_forest(cell, tile)
	elif tile.feature == C.Feature.PADDY:
		_build_paddy(cell, tile)
	if tile.building == C.Building.HALL:
		_build_hall(cell)
	elif tile.building == C.Building.HOUSE or tile.building == C.Building.STILT_HOUSE or tile.building == C.Building.RAFT_HOUSE:
		_build_house(cell, tile)
	elif tile.building == C.Building.GATE:
		_build_gate(cell, tile)
	elif tile.building == C.Building.GRANARY:
		_build_granary(cell)
	elif tile.building == C.Building.FISH_TRAP:
		_build_fish_trap(cell, tile)
	elif tile.building == C.Building.RESERVOIR:
		_build_reservoir(cell)
	elif tile.building == C.Building.WATERWHEEL:
		_build_waterwheel(cell, tile)
	if tile.is_source:
		_build_source(cell, tile)
	var label: Label3D = Label3D.new()
	label.text = "e%d · w%.1f" % [tile.elevation, tile.water]
	label.position = Hex.to_world(tile.coord)
	label.position.y = _surface_y(tile) + 1.05
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.009
	label.modulate = _color("ink")
	label.outline_modulate = _color("background")
	label.no_depth_test = true
	_labels_root.add_child(label)


func _build_water(cell: Node3D, tile: Tile) -> void:
	var depth: float = maxf(tile.water * C.HEIGHT_UNIT, 0.055)
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Water"
	water.mesh = MeshLib.hex_prism(0.985)
	water.position.y = 0.015
	water.scale.y = depth
	var color: Color = _color("water_shallow").lerp(_color("water_deep"), clampf(tile.water / 3.5, 0.0, 1.0))
	color.a = 0.58 + clampf(tile.water / 7.0, 0.0, 0.17)
	var top: StandardMaterial3D = _material(color)
	top.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	top.roughness = 0.22
	top.metallic = 0.10
	top.emission_enabled = true
	top.emission = Color(color.r * 0.13, color.g * 0.13, color.b * 0.13)
	water.set_surface_override_material(0, top)
	var side_color: Color = color.darkened(0.10)
	side_color.a = 0.43
	var side: StandardMaterial3D = _material(side_color)
	side.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	side.roughness = 0.3
	water.set_surface_override_material(1, side)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(water)


func _build_forest(cell: Node3D, tile: Tile) -> void:
	var offsets: Array[Vector2] = [Vector2(-0.29, 0.18), Vector2(0.29, 0.19), Vector2(0.0, -0.30)]
	var young: bool = tile.feature == C.Feature.SAPLING
	for index: int in range(3 if not young else 2):
		var offset: Vector2 = offsets[index]
		var tree: Node3D = Node3D.new()
		tree.position = Vector3(offset.x, 0.0, offset.y)
		cell.add_child(tree)
		var trunk: CylinderMesh = CylinderMesh.new()
		trunk.top_radius = 0.045
		trunk.bottom_radius = 0.06
		trunk.height = 0.32
		trunk.radial_segments = 6
		_add_mesh(tree, trunk, Vector3(0.0, 0.16, 0.0), _color("earth").darkened(0.13))
		var crown: CylinderMesh = CylinderMesh.new()
		crown.top_radius = 0.0
		crown.bottom_radius = 0.28 if not young else 0.19
		crown.height = 0.66 if not young else 0.4
		crown.radial_segments = 6
		var tint: Color = _color("forest").lightened(float(index) * 0.045)
		_add_mesh(tree, crown, Vector3(0.0, 0.60 if not young else 0.39, 0.0), tint)
		if not young:
			var lower: CylinderMesh = CylinderMesh.new()
			lower.top_radius = 0.0
			lower.bottom_radius = 0.32
			lower.height = 0.48
			lower.radial_segments = 6
			_add_mesh(tree, lower, Vector3(0.0, 0.43, 0.0), tint.darkened(0.05))


func _build_paddy(cell: Node3D, tile: Tile) -> void:
	var field: Node3D = Node3D.new()
	field.name = "Paddy"
	cell.add_child(field)
	var stalk_color: Color = _color("accent") if tile.paddy_yield > 0 else _color("forest").lightened(0.23)
	if tile.paddy_dead:
		stalk_color = _color("earth")
	for row: int in range(3):
		var z: float = float(row - 1) * 0.35
		_add_box(field, Vector3(1.05, 0.035, 0.22), Vector3(0.0, 0.018, z), _color("riverbed").darkened(0.14))
		for column: int in range(3):
			var x: float = float(column - 1) * 0.35
			var height: float = 0.11 if tile.paddy_dead else 0.23 + minf(float(tile.paddy_yield), 3.0) * 0.035
			_add_box(field, Vector3(0.035, height, 0.035), Vector3(x, height * 0.5, z), stalk_color)
			var leaf: MeshInstance3D = _add_mesh(field, _box_mesh(Vector3(0.18, 0.025, 0.045)), Vector3(x, height * 0.73, z), stalk_color)
			leaf.rotation_degrees.z = -18.0 if column % 2 == 0 else 18.0


func _build_gate(cell: Node3D, tile: Tile) -> void:
	var gate: Node3D = Node3D.new()
	gate.name = "Gate"
	cell.add_child(gate)
	for x: float in [-0.53, 0.53]:
		_add_box(gate, Vector3(0.14, 0.91, 0.22), Vector3(x, 0.455, 0.0), _color("earth").lightened(0.16))
	_add_box(gate, Vector3(1.22, 0.12, 0.22), Vector3(0.0, 0.89, 0.0), _color("accent"))
	var panel: Node3D = Node3D.new()
	panel.name = "GatePanel"
	panel.position.y = 0.55 if tile.gate_open else 0.03
	gate.add_child(panel)
	for row: int in range(3):
		_add_box(panel, Vector3(0.92, 0.13, 0.14), Vector3(0.0, 0.07 + float(row) * 0.15, 0.0), _color("roof").darkened(0.12))
	for x: float in [-0.31, 0.31]:
		_add_box(panel, Vector3(0.055, 0.44, 0.035), Vector3(x, 0.22, 0.09), _color("accent"))


func _build_granary(cell: Node3D) -> void:
	var granary: Node3D = Node3D.new()
	granary.name = "Granary"
	granary.rotation_degrees.y = 20.0
	cell.add_child(granary)
	for x: float in [-0.32, 0.32]:
		for z: float in [-0.25, 0.25]:
			_add_box(granary, Vector3(0.09, 0.29, 0.09), Vector3(x, 0.145, z), _color("earth"))
	_add_box(granary, Vector3(0.83, 0.10, 0.70), Vector3(0.0, 0.29, 0.0), _color("earth").lightened(0.12))
	_add_box(granary, Vector3(0.69, 0.46, 0.58), Vector3(0.0, 0.56, 0.0), _color("accent").darkened(0.10))
	for height: float in [0.40, 0.56, 0.72]:
		_add_box(granary, Vector3(0.71, 0.035, 0.60), Vector3(0.0, height, 0.0), _color("earth"))
	_add_roof(granary, Vector3(0.95, 0.34, 0.79), Vector3(0.0, 0.94, 0.0), _color("roof"))


func _build_fish_trap(cell: Node3D, tile: Tile) -> void:
	var trap: Node3D = Node3D.new()
	trap.name = "FishTrap"
	cell.add_child(trap)
	for height: float in [0.07, 0.37]:
		var hoop: TorusMesh = TorusMesh.new()
		hoop.inner_radius = 0.23
		hoop.outer_radius = 0.27
		hoop.rings = 12
		hoop.ring_segments = 4
		_add_mesh(trap, hoop, Vector3(0.0, height, 0.0), _color("accent"))
	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0
		_add_box(trap, Vector3(0.035, 0.32, 0.035), Vector3(cos(angle) * 0.25, 0.22, sin(angle) * 0.25), _color("earth"))
	var buoy_height: float = maxf(0.45, tile.water * C.HEIGHT_UNIT + 0.16)
	_add_box(trap, Vector3(0.045, buoy_height, 0.045), Vector3(0.40, buoy_height * 0.5, 0.0), _color("earth"))
	var buoy: SphereMesh = SphereMesh.new()
	buoy.radius = 0.11
	buoy.height = 0.22
	buoy.radial_segments = 8
	buoy.rings = 4
	_add_mesh(trap, buoy, Vector3(0.40, buoy_height, 0.0), _color("accent"))


func _build_reservoir(cell: Node3D) -> void:
	var reservoir: Node3D = Node3D.new()
	reservoir.name = "Reservoir"
	cell.add_child(reservoir)
	_add_mesh(reservoir, MeshLib.hex_ring(0.88, 0.72), Vector3(0.0, 0.07, 0.0), _color("earth").lightened(0.21))
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0 + PI / 6.0
		var block: MeshInstance3D = _add_mesh(reservoir, _box_mesh(Vector3(0.47, 0.14, 0.17)), Vector3(cos(angle) * 0.76, 0.07, sin(angle) * 0.76), _color("earth").lightened(0.21))
		block.rotation.y = -angle + PI / 2.0


func _build_waterwheel(cell: Node3D, tile: Tile) -> void:
	var mill: Node3D = Node3D.new()
	mill.name = "Waterwheel"
	var direction: Vector3 = Hex.to_world(Hex.direction(tile.wheel_dir)).normalized()
	mill.rotation.y = atan2(-direction.z, direction.x)
	cell.add_child(mill)
	for x: float in [-0.23, 0.23]:
		_add_box(mill, Vector3(0.08, 0.59, 0.13), Vector3(x, 0.295, 0.0), _color("earth"))
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 0.32
	rim.outer_radius = 0.39
	rim.rings = 16
	rim.ring_segments = 6
	var ring: MeshInstance3D = _add_mesh(mill, rim, Vector3(0.0, 0.58, 0.0), _color("roof"))
	ring.rotation_degrees.z = 90.0
	var axle: CylinderMesh = CylinderMesh.new()
	axle.top_radius = 0.065
	axle.bottom_radius = 0.065
	axle.height = 0.66
	axle.radial_segments = 8
	var hub: MeshInstance3D = _add_mesh(mill, axle, Vector3(0.0, 0.58, 0.0), _color("accent"))
	hub.rotation_degrees.z = 90.0
	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0
		var paddle: MeshInstance3D = _add_mesh(mill, _box_mesh(Vector3(0.37, 0.10, 0.16)), Vector3(0.0, 0.58 + sin(angle) * 0.35, cos(angle) * 0.35), _color("accent"))
		paddle.rotation.x = -angle
	_add_box(mill, Vector3(0.35, 0.04, 0.065), Vector3(0.45, 0.075, 0.0), _color("highlight"))
	var arrow: CylinderMesh = CylinderMesh.new()
	arrow.top_radius = 0.0
	arrow.bottom_radius = 0.13
	arrow.height = 0.23
	arrow.radial_segments = 3
	var tip: MeshInstance3D = _add_mesh(mill, arrow, Vector3(0.70, 0.075, 0.0), _color("highlight"))
	tip.rotation_degrees.z = -90.0


func _build_house(cell: Node3D, tile: Tile) -> void:
	var village: Node3D = Node3D.new()
	village.rotation_degrees.y = 20.0
	cell.add_child(village)
	var offset: float = 0.0
	if tile.building == C.Building.STILT_HOUSE:
		offset = 0.35
		for x: float in [-0.24, 0.24]:
			for z: float in [-0.19, 0.19]:
				_add_box(village, Vector3(0.06, 0.38, 0.06), Vector3(x, 0.19, z), _color("earth"))
	elif tile.building == C.Building.RAFT_HOUSE:
		offset = maxf(0.0, tile.water * C.HEIGHT_UNIT) + 0.08
		_add_box(village, Vector3(0.82, 0.10, 0.69), Vector3(0.0, offset - 0.05, 0.0), _color("earth"))
	_add_box(village, Vector3(0.59, 0.40, 0.49), Vector3(0.0, 0.20 + offset, 0.0), _color("house"))
	_add_box(village, Vector3(0.13, 0.23, 0.016), Vector3(0.0, 0.125 + offset, 0.252), _color("earth").darkened(0.2))
	_add_box(village, Vector3(0.11, 0.11, 0.018), Vector3(-0.18, 0.26 + offset, 0.252), _color("sea"))
	_add_roof(village, Vector3(0.73, 0.31, 0.65), Vector3(0.0, 0.505 + offset, 0.0), _color("roof"))


func _build_hall(cell: Node3D) -> void:
	var hall: Node3D = Node3D.new()
	hall.rotation_degrees.y = 20.0
	cell.add_child(hall)
	_add_box(hall, Vector3(0.95, 0.12, 0.85), Vector3(0.0, 0.06, 0.0), _color("earth").lightened(0.15))
	_add_box(hall, Vector3(0.75, 0.48, 0.65), Vector3(0.0, 0.36, 0.0), _color("house"))
	_add_box(hall, Vector3(0.21, 0.32, 0.018), Vector3(0.0, 0.28, 0.334), _color("earth").darkened(0.17))
	for x: float in [-0.31, 0.31]:
		_add_box(hall, Vector3(0.055, 0.5, 0.055), Vector3(x, 0.36, 0.335), _color("accent"))
	_add_roof(hall, Vector3(1.0, 0.35, 0.88), Vector3(0.0, 0.70, 0.0), _color("roof").darkened(0.10))
	_add_roof(hall, Vector3(0.70, 0.30, 0.60), Vector3(0.0, 0.91, 0.0), _color("roof"))
	_add_box(hall, Vector3(0.72, 0.035, 0.045), Vector3(0.0, 1.065, 0.0), _color("accent"))


func _build_source(cell: Node3D, tile: Tile) -> void:
	var base: float = _surface_y(tile) - cell.position.y
	var marker: CylinderMesh = CylinderMesh.new()
	marker.top_radius = 0.04
	marker.bottom_radius = 0.04
	marker.height = 0.68
	marker.radial_segments = 8
	_add_mesh(cell, marker, Vector3(0.0, base + 0.34, 0.0), _color("highlight"))
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.18
	ring.outer_radius = 0.23
	ring.rings = 16
	ring.ring_segments = 6
	var instance: MeshInstance3D = _add_mesh(cell, ring, Vector3(0.0, base + 0.74, 0.0), _color("water_shallow"), true)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	sphere.radial_segments = 8
	sphere.rings = 4
	_add_mesh(cell, sphere, Vector3(0.0, base + 0.74, 0.0), _color("highlight"), true)


func _add_roof(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var prism: PrismMesh = PrismMesh.new()
	prism.size = size
	_add_mesh(parent, prism, at, color)


func _add_box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	_add_mesh(parent, _box_mesh(size), at, color)


func _box_mesh(size: Vector3) -> BoxMesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	return box


func _add_mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(color, unshaded)
	parent.add_child(instance)
	return instance


func _material(color: Color, unshaded: bool = false, vertex_color: bool = false) -> StandardMaterial3D:
	var key: String = "%s:%s:%s" % [color.to_html(), unshaded, vertex_color]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	material.vertex_color_use_as_albedo = vertex_color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = material
	return material


func _terrain_color(tile: Tile) -> Color:
	if tile.is_sea:
		return _color("sea")
	if tile.is_river:
		return _color("riverbed")
	var height_mix: float = clampf(float(tile.elevation) / 4.0, 0.0, 1.0)
	var color: Color = _color("terrain_low").lerp(_color("terrain_high"), height_mix)
	var variation: float = float(posmod(tile.q * 13 + tile.r * 7, 5) - 2) * 0.012
	return color.lightened(variation) if variation >= 0.0 else color.darkened(-variation)


func _surface_y(tile: Tile) -> float:
	var terrain_y: float = float(tile.elevation) * C.HEIGHT_UNIT
	if tile.water >= 0.05 or tile.is_sea:
		return terrain_y + maxf(tile.water * C.HEIGHT_UNIT, 0.055) + 0.015
	return terrain_y


func _clear_root(root: Node3D) -> void:
	for child: Node in root.get_children():
		root.remove_child(child)
		child.queue_free()


func _refresh_targets() -> void:
	_clear_root(_targets_root)
	if state == null:
		return
	var seen: Dictionary = {}
	for coord: Vector2i in _target_coords:
		if state.get_tile(coord) == null or seen.has(coord):
			continue
		seen[coord] = true
		var ring: MeshInstance3D = _add_mesh(_targets_root, MeshLib.hex_ring(0.965, 0.915), Vector3.ZERO, _color("water_shallow").lightened(0.18), true)
		ring.name = "Target_%d_%d" % [coord.x, coord.y]
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_position_marker(ring, coord, 0.075)
	if state.get_tile(_invalid_coord) != null:
		var invalid: MeshInstance3D = _add_mesh(_targets_root, MeshLib.hex_ring(0.97, 0.89), Vector3.ZERO, Color("#ef8c76"), true)
		invalid.name = "InvalidTarget"
		invalid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_position_marker(invalid, _invalid_coord, 0.09)


func _refresh_preview() -> void:
	_clear_root(_preview_root)
	if state == null or not _prediction.get("state") is GameState or not _prediction.get("report") is TurnReport:
		return
	var predicted: GameState = _prediction["state"]
	var report: TurnReport = _prediction["report"]
	for tile: Tile in state.tiles:
		var after: Tile = predicted.get_tile(tile.coord)
		if after == null:
			continue
		var delta: float = after.water - tile.water
		if absf(delta) > 0.05:
			_build_ghost_water(after, delta)
	for entry: Dictionary in report.destroyed:
		_preview_label("!", entry["coord"], Color("#ef8c76"), "Destroyed")
	for coord: Vector2i in report.paddies_died:
		_preview_label("x", coord, Color("#ef8c76"), "PaddyDied")
	for coord: Vector2i in report.paddy_gains:
		_preview_label("+1", coord, _color("highlight"), "PaddyGain")
	if report.fish_food <= 0:
		return
	var productive_traps: Array[Vector2i] = []
	for index: int in range(predicted.tiles.size()):
		var tile: Tile = predicted.tiles[index]
		var level: int = report.levels_after[index] if index < report.levels_after.size() else predicted.level_of(tile)
		if tile.building == C.Building.FISH_TRAP and level >= 1:
			productive_traps.append(tile.coord)
	if productive_traps.is_empty():
		return
	# Every productive trap has the same yield. Read the resolved total rather
	# than evaluating modifiers here, so even the model's caches stay untouched.
	var fish_food: int = roundi(float(report.fish_food) / float(productive_traps.size()))
	for coord: Vector2i in productive_traps:
		_preview_label("+%d" % fish_food, coord, _color("water_shallow"), "FishFood")


func _build_ghost_water(tile: Tile, delta: float) -> void:
	var ghost: Node3D = Node3D.new()
	ghost.name = "GhostWater_%d_%d" % [tile.q, tile.r]
	ghost.position = Hex.to_world(tile.coord, tile.elevation)
	_preview_root.add_child(ghost)
	var tint: Color = _color("water_shallow") if delta > 0.0 else _color("accent")
	tint.a = 0.30
	var surface: MeshInstance3D = _add_mesh(ghost, MeshLib.hex_prism(0.98), Vector3(0.0, maxf(0.0, tile.water * C.HEIGHT_UNIT) + 0.035, 0.0), tint, true)
	surface.name = "PredictedSurface"
	surface.scale.y = 0.025
	var material: StandardMaterial3D = surface.material_override.duplicate() as StandardMaterial3D
	material.no_depth_test = true
	material.render_priority = 1
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tint.a = 0.85
	var rim: MeshInstance3D = _add_mesh(ghost, MeshLib.hex_ring(0.985, 0.955), surface.position + Vector3(0.0, 0.03, 0.0), tint, true)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _preview_label(text: String, coord: Vector2i, color: Color, prefix: String) -> void:
	var tile: Tile = state.get_tile(coord)
	if tile == null:
		return
	var predicted: GameState = _prediction["state"]
	var after: Tile = predicted.get_tile(coord)
	var label: Label3D = Label3D.new()
	label.name = "%s_%d_%d" % [prefix, coord.x, coord.y]
	label.text = text
	label.font = MARKER_FONT
	label.font_size = 52
	label.pixel_size = 0.012
	label.position = Hex.to_world(coord)
	label.position.y = maxf(_surface_y(tile), _surface_y(after) if after != null else _surface_y(tile)) + 0.95
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_modulate = _color("background")
	label.outline_size = 9
	label.no_depth_test = true
	_preview_root.add_child(label)


func _update_markers() -> void:
	if state == null:
		_selection.hide()
		_hover.hide()
		return
	_position_marker(_selection, _selected_coord, 0.045)
	_position_marker(_hover, _hover_coord, 0.06)
	_hover.visible = _hover.visible and _hover_coord != _selected_coord


func _position_marker(marker: MeshInstance3D, coord: Vector2i, offset: float) -> void:
	var tile: Tile = state.get_tile(coord)
	marker.visible = tile != null
	if tile != null:
		marker.position = Hex.to_world(coord)
		marker.position.y = _surface_y(tile) + offset


func _color(key: String) -> Color:
	return Color(String(palette.get(key, "#ffffff")))
