class_name BoardView
extends Node3D

## The scene is a view of GameState only; rebuilding never changes simulation data.
const BASE_Y: float = -1.7
const HEX_RADIUS: float = 0.96
const NO_COORD: Vector2i = Vector2i(2147483647, 2147483647)

var palette: Dictionary = {}
var state: GameState
var _tiles_root: Node3D
var _labels_root: Node3D
var _selection: MeshInstance3D
var _hover: MeshInstance3D
var _selected_coord: Vector2i = NO_COORD
var _hover_coord: Vector2i = NO_COORD
var _labels_visible: bool = false
var _materials: Dictionary = {}


func _ready() -> void:
	_ensure_nodes()


func set_state(next_state: GameState) -> void:
	state = next_state
	_selected_coord = NO_COORD
	_hover_coord = NO_COORD
	refresh()


func refresh() -> void:
	_ensure_nodes()
	for child: Node in _tiles_root.get_children():
		_tiles_root.remove_child(child)
		child.queue_free()
	for child: Node in _labels_root.get_children():
		_labels_root.remove_child(child)
		child.queue_free()
	if state == null:
		_selection.hide()
		_hover.hide()
		return
	for tile: Tile in state.tiles:
		_build_tile(tile)
	_update_markers()


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
	if tile.building == C.Building.HALL:
		_build_hall(cell)
	elif tile.building == C.Building.HOUSE or tile.building == C.Building.STILT_HOUSE or tile.building == C.Building.RAFT_HOUSE:
		_build_house(cell, tile)
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
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	_add_mesh(parent, box, at, color)


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
