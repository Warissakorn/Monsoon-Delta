class_name BoardView
extends Node3D

## The scene is a view of GameState only; rebuilding never changes simulation data.
const BASE_Y: float = -1.7
const HEX_RADIUS: float = 0.96
const NO_COORD: Vector2i = Vector2i(2147483647, 2147483647)
const MARKER_FONT: Font = preload("res://assets/fonts/NotoSansThai.ttf")
const WATER_SHADER: Shader = preload("res://view/water_surface.gdshader")

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
var _reduced_motion: bool = false
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _water_materials: Dictionary = {}
var _colored_surfaces: Dictionary = {}
var _baked_materials: Dictionary = {}
var _target_coords: Array[Vector2i] = []
var _invalid_coord: Vector2i = NO_COORD
var _prediction: Dictionary = {}
var _route_view: RouteNetworkView
var _life_view: VillageLifeView
var _flow_view: FlowView
var _activity_paused: bool = false
var _actual_flow_report: TurnReport


func _ready() -> void:
	_ensure_nodes()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	for material: ShaderMaterial in _water_materials.values():
		material.set_shader_parameter("motion_scale", 0.0 if enabled or _activity_paused else 1.0)
	if _life_view != null:
		_life_view.set_reduced_motion(enabled)
		_flow_view.set_reduced_motion(enabled)


func set_state(next_state: GameState) -> void:
	if state != next_state:
		clear_activity()
	state = next_state
	_selected_coord = NO_COORD
	_hover_coord = NO_COORD
	_target_coords.clear()
	_invalid_coord = NO_COORD
	_prediction = {}
	_actual_flow_report = null
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
		_route_view.set_state(null)
		_life_view.set_state(null, null)
		_flow_view.set_state(null)
		_water_materials.clear()
		return
	# GL Compatibility has no instance shader uniforms. One cached material per
	# wet coordinate permits independent currents, bounded by the board size.
	for coord: Vector2i in _water_materials.keys():
		var tile: Tile = state.get_tile(coord)
		if tile == null or (tile.water < 0.05 and not tile.is_sea):
			_water_materials.erase(coord)
	for tile: Tile in state.tiles:
		_build_tile(tile)
	_batch_static_geometry()
	_update_markers()
	_refresh_targets()
	_refresh_preview()
	_route_view.set_state(state)
	_life_view.set_state(state, _route_view.graph)
	_flow_view.set_state(state)
	_flow_view.set_preview(_prediction, not _prediction.is_empty())
	_update_water_flow()


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
	_flow_view.set_preview(prediction, enabled)
	_update_water_flow()


func show_command_activity(id: String, coord: Vector2i) -> void:
	_ensure_nodes()
	_life_view.show_command(id, coord)


func show_turn_activity(report: TurnReport) -> void:
	_ensure_nodes()
	_life_view.show_report(report)


func show_harvest_activity(food_by_tile: Dictionary) -> void:
	_ensure_nodes()
	_life_view.show_harvest(food_by_tile)


func show_actual_flow(report: TurnReport) -> void:
	_ensure_nodes()
	_actual_flow_report = report
	_flow_view.show_report(report, state)
	if _flow_view.is_showing_actual():
		_clear_root(_preview_root)
	_update_water_flow()


func clear_activity() -> void:
	_actual_flow_report = null
	if _life_view != null:
		_life_view.clear()
		_flow_view.clear()
	_update_water_flow()


func finish_actual_flow() -> void:
	_actual_flow_report = null
	if _flow_view != null:
		_flow_view.clear()
		_flow_view.set_preview(_prediction, not _prediction.is_empty())
		_refresh_preview()
	_update_water_flow()


func set_activity_paused(paused: bool) -> void:
	_activity_paused = paused
	if _life_view != null:
		_life_view.set_paused(paused)
		_flow_view.set_paused(paused)
	for material: ShaderMaterial in _water_materials.values():
		material.set_shader_parameter("motion_scale", 0.0 if paused or _reduced_motion else 1.0)


func _on_actual_flow_finished() -> void:
	_actual_flow_report = null
	_refresh_preview()
	_update_water_flow()


func _update_water_flow() -> void:
	if state == null:
		return
	var report: TurnReport = _actual_flow_report
	if report == null and _prediction.get("report") is TurnReport:
		report = _prediction["report"]
	var velocities: Dictionary = FlowView.tile_velocities(state, report) if report != null else {}
	for coord: Vector2i in _water_materials:
		var velocity: Vector2 = velocities.get(coord, Vector2.ZERO)
		var material: ShaderMaterial = _water_materials[coord]
		material.set_shader_parameter("flow_velocity", velocity)
		material.set_shader_parameter("flow_strength", clampf(velocity.length(), 0.0, 1.0))


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
	_route_view = RouteNetworkView.new()
	_route_view.name = "Routes"
	add_child(_route_view)
	_life_view = VillageLifeView.new()
	_life_view.name = "VillageLife"
	add_child(_life_view)
	_flow_view = FlowView.new()
	_flow_view.name = "Flow"
	_flow_view.actual_finished.connect(_on_actual_flow_finished)
	add_child(_flow_view)
	_life_view.set_reduced_motion(_reduced_motion)
	_flow_view.set_reduced_motion(_reduced_motion)
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
	_build_ground_details(cell, tile)
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
	if tile.building != C.Building.NONE:
		_build_settlement_details(cell, tile)
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
	# The tint remains quantized; each wet tile has its own directional current.
	var depth_bucket: int = mini(8, floori(tile.water / 3.5 * 8.0))
	var color: Color = _color("water_shallow").lerp(_color("water_deep"), float(depth_bucket) / 8.0)
	color.a = 0.73 + float(depth_bucket) * 0.012
	var top: ShaderMaterial
	if _water_materials.has(tile.coord):
		top = _water_materials[tile.coord] as ShaderMaterial
	else:
		top = ShaderMaterial.new()
		top.shader = WATER_SHADER
		_water_materials[tile.coord] = top
	top.set_shader_parameter("water_color", color)
	top.set_shader_parameter("motion_scale", 0.0 if _reduced_motion or _activity_paused else 1.0)
	water.set_surface_override_material(0, top)
	var side_color: Color = color.darkened(0.10)
	side_color.a = 0.43
	var side: StandardMaterial3D = _material(side_color)
	side.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	side.roughness = 0.3
	water.set_surface_override_material(1, side)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(water)
	# A pale, broken margin only appears where water meets a dry bank.
	for direction: int in range(6):
		var neighbor: Tile = state.neighbor_in_dir(tile, direction)
		if neighbor == null or neighbor.water >= 0.05 or neighbor.is_sea:
			continue
		var normal: Vector3 = Hex.to_world(Hex.direction(direction)).normalized()
		var tangent: Vector3 = Vector3(-normal.z, 0.0, normal.x)
		var shore: MeshInstance3D = _add_mesh(cell, _box_mesh(Vector3(0.48, 0.009, 0.022)), normal * 0.81 + Vector3.UP * (depth + 0.023), _color("water_shallow").lightened(0.35))
		shore.rotation.y = atan2(-tangent.z, tangent.x)
		shore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_ground_details(cell: Node3D, tile: Tile) -> void:
	if tile.is_sea:
		return
	var earth: Color = _color("earth")
	var strata: MeshInstance3D = _add_mesh(cell, MeshLib.hex_prism(0.962), Vector3(0.0, -0.19, 0.0), earth.lightened(0.12))
	strata.scale.y = 0.038
	if tile.is_river:
		return
	var edge_color: Color = _terrain_color(tile).darkened(0.09)
	_add_mesh(cell, MeshLib.hex_ring(0.952, 0.925), Vector3(0.0, 0.005, 0.0), edge_color)
	if tile.water >= 0.05 or tile.feature == C.Feature.PADDY:
		return
	var count: int = 2 if tile.feature == C.Feature.NONE and tile.building == C.Building.NONE else 1
	for index: int in range(count):
		var angle: float = _variation(tile, index + 3) * TAU
		var at: Vector3 = Vector3(cos(angle) * 0.69, 0.01, sin(angle) * 0.69)
		var tuft: MeshInstance3D = _add_mesh(cell, MeshLib.grass_tuft(), at, _terrain_color(tile).darkened(0.2))
		tuft.material_override = _material(_terrain_color(tile).darkened(0.2), false, true)
		tuft.rotation.y = angle
	if tile.feature == C.Feature.NONE and tile.building == C.Building.NONE and _variation(tile, 9) > 0.65:
		var pebble: MeshInstance3D = _add_mesh(cell, _sphere_mesh(0.085, 0.065), Vector3(-0.49, 0.035, 0.31), earth.lightened(0.27))
		pebble.rotation.y = _variation(tile, 7) * TAU


func _variation(tile: Tile, salt: int) -> float:
	# Coordinate hashing is decorative only: it never consumes the run's RNG.
	return float(posmod(tile.q * 73856093 + tile.r * 19349663 + salt * 83492791, 997)) / 997.0


func _batch_static_geometry() -> void:
	# Tiny porch rails and leaves otherwise each submit their own draw call,
	# including every shadow cascade. Bake opaque pieces into three board-local
	# meshes, keeping named structure containers and transparent water intact.
	for key: String in _colored_surfaces.keys():
		if (_colored_surfaces[key]["source"] as WeakRef).get_ref() == null:
			_colored_surfaces.erase(key)
	var instances: Array[MeshInstance3D] = []
	_collect_meshes(_tiles_root, instances)
	var batches: Dictionary = {}
	for instance: MeshInstance3D in instances:
		if not _can_batch(instance):
			continue
		var transform: Transform3D = _board_transform(instance)
		for surface_index: int in range(instance.mesh.get_surface_count()):
			var material: StandardMaterial3D = instance.get_active_material(surface_index) as StandardMaterial3D
			var category: String = _batch_category(instance, transform, material)
			if not batches.has(category):
				var builder: SurfaceTool = SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[category] = builder
			var builder: SurfaceTool = batches[category] as SurfaceTool
			builder.append_from(_colored_surface(instance.mesh, surface_index, material), 0, transform)
		instance.get_parent().remove_child(instance)
		instance.free()
	for category: String in batches:
		var builder: SurfaceTool = batches[category] as SurfaceTool
		var batch: MeshInstance3D = MeshInstance3D.new()
		batch.name = "Baked_" + category
		batch.mesh = builder.commit()
		batch.material_override = _baked_material(category)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if category == "Solids" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tiles_root.add_child(batch)


func _collect_meshes(root: Node3D, instances: Array[MeshInstance3D]) -> void:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			instances.append(child as MeshInstance3D)
		elif child is Node3D:
			_collect_meshes(child as Node3D, instances)


func _can_batch(instance: MeshInstance3D) -> bool:
	if instance.mesh == null:
		return false
	for surface_index: int in range(instance.mesh.get_surface_count()):
		var material: Material = instance.get_active_material(surface_index)
		if not material is StandardMaterial3D:
			return false
		var standard: StandardMaterial3D = material as StandardMaterial3D
		if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or standard.albedo_texture != null:
			return false
	return true


func _board_transform(instance: MeshInstance3D) -> Transform3D:
	# Tests also build views outside SceneTree, so avoid global_transform getters.
	var transform: Transform3D = instance.transform
	var parent: Node = instance.get_parent()
	while parent != self and parent is Node3D:
		transform = (parent as Node3D).transform * transform
		parent = parent.get_parent()
	return transform


func _batch_category(instance: MeshInstance3D, transform: Transform3D, material: StandardMaterial3D) -> String:
	if material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return "Markers"
	var size: Vector3 = instance.mesh.get_aabb().size * transform.basis.get_scale().abs()
	if instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or minf(size.x, minf(size.y, size.z)) < 0.09 or instance.mesh.get_meta("thin_foliage", false):
		return "Details"
	return "Solids"


func _colored_surface(mesh: Mesh, surface_index: int, material: StandardMaterial3D) -> ArrayMesh:
	var key: String = "%d:%d:%d" % [mesh.get_instance_id(), surface_index, material.get_instance_id()]
	if _colored_surfaces.has(key):
		return _colored_surfaces[key]["mesh"] as ArrayMesh
	var source: Array = mesh.surface_get_arrays(surface_index)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(vertices.size())
	# Keep the StandardMaterial color values: an extra linear conversion here
	# darkens vertex-colored geometry in the project's Compatibility renderer.
	var tint: Color = material.albedo_color
	var original_colors: PackedColorArray = PackedColorArray()
	if material.vertex_color_use_as_albedo and source[Mesh.ARRAY_COLOR] != null:
		original_colors = source[Mesh.ARRAY_COLOR]
	for index: int in range(vertices.size()):
		var color: Color = tint
		if index < original_colors.size():
			var original: Color = original_colors[index]
			color *= original.srgb_to_linear() if material.vertex_color_is_srgb else original
		colors[index] = color
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = source[Mesh.ARRAY_NORMAL]
	arrays[Mesh.ARRAY_COLOR] = colors
	var indices: PackedInt32Array = PackedInt32Array()
	if source[Mesh.ARRAY_INDEX] != null:
		indices = source[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		# append_from retains explicit indices from later primitive meshes. Give
		# unindexed procedural surfaces indices too, or their faces disappear.
		indices.resize(vertices.size())
		for index: int in range(vertices.size()):
			indices[index] = index
	arrays[Mesh.ARRAY_INDEX] = indices
	var painted: ArrayMesh = ArrayMesh.new()
	painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_colored_surfaces[key] = {"mesh": painted, "source": weakref(mesh)}
	return painted


func _baked_material(category: String) -> StandardMaterial3D:
	if not _baked_materials.has(category):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.88
		if category == "Markers":
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_baked_materials[category] = material
	return _baked_materials[category] as StandardMaterial3D


func _build_forest(cell: Node3D, tile: Tile) -> void:
	var offsets: Array[Vector2] = [Vector2(-0.30, 0.17), Vector2(0.29, 0.23), Vector2(0.01, -0.32)]
	var young: bool = tile.feature == C.Feature.SAPLING
	for index: int in range(2 if young else 3):
		var offset: Vector2 = offsets[index]
		var tree: Node3D = Node3D.new()
		tree.position = Vector3(offset.x, 0.0, offset.y)
		tree.rotation.y = _variation(tile, index) * TAU
		var scale_variation: float = 0.9 + _variation(tile, index + 2) * 0.22
		tree.scale = Vector3.ONE * scale_variation * (0.63 if young else 1.0)
		cell.add_child(tree)
		var wood: Color = _color("earth").lerp(_color("roof"), 0.3).darkened(0.12)
		_add_mesh(tree, _cylinder_mesh(0.035, 0.065, 0.58), Vector3(0.0, 0.29, 0.0), wood)
		var branch: MeshInstance3D = _add_mesh(tree, _cylinder_mesh(0.023, 0.034, 0.28), Vector3(0.08, 0.46, 0.0), wood)
		branch.rotation_degrees.z = -38.0
		var tint: Color = _color("forest").lightened(float(index) * 0.055 + _variation(tile, index + 5) * 0.06)
		# Broad, faceted leaf masses make a lowland canopy instead of a conifer.
		_add_mesh(tree, _sphere_mesh(0.31, 0.46), Vector3(-0.10, 0.64, 0.03), tint.darkened(0.06))
		_add_mesh(tree, _sphere_mesh(0.29, 0.43), Vector3(0.16, 0.72, 0.015), tint)
		_add_mesh(tree, _sphere_mesh(0.28, 0.40), Vector3(-0.015, 0.88, -0.035), tint.lightened(0.08))


func _build_paddy(cell: Node3D, tile: Tile) -> void:
	var field: Node3D = Node3D.new()
	field.name = "Paddy"
	cell.add_child(field)
	var stalk_color: Color = _color("forest").lerp(_color("accent"), 0.72 if tile.paddy_yield > 0 else 0.26)
	if tile.paddy_dead:
		stalk_color = _color("earth").lightened(0.24)
	var mud: Color = _color("riverbed").lerp(_color("earth"), 0.55)
	_add_box(field, Vector3(1.20, 0.022, 1.05), Vector3(0.0, 0.012, 0.0), mud)
	for x: float in [-0.64, 0.64]:
		_add_box(field, Vector3(0.07, 0.055, 1.16), Vector3(x, 0.028, 0.0), _color("earth").lightened(0.17))
	for z: float in [-0.56, 0.56]:
		_add_box(field, Vector3(1.28, 0.055, 0.065), Vector3(0.0, 0.028, z), _color("earth").lightened(0.17))
	for row: int in range(3):
		_add_box(field, Vector3(1.15, 0.026, 0.22), Vector3(0.0, 0.032, float(row - 1) * 0.32), mud.lightened(0.10))
	var rice: MeshInstance3D = _add_mesh(field, MeshLib.rice_field(-1 if tile.paddy_dead else mini(tile.paddy_yield, 3)), Vector3.ZERO, stalk_color)
	rice.material_override = _material(stalk_color, false, true)


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
	village.name = "House"
	village.rotation_degrees.y = 20.0
	cell.add_child(village)
	var offset: float = 0.0
	var timber: Color = _color("earth").lerp(_color("roof"), 0.25)
	if tile.building == C.Building.STILT_HOUSE:
		offset = 0.41
		for x: float in [-0.27, 0.27]:
			for z: float in [-0.23, 0.23]:
				_add_mesh(village, _cylinder_mesh(0.032, 0.044, offset + 0.04), Vector3(x, offset * 0.5, z), timber)
		var brace: MeshInstance3D = _add_mesh(village, _box_mesh(Vector3(0.58, 0.035, 0.035)), Vector3(0.0, 0.21, 0.24), timber.lightened(0.18))
		brace.rotation_degrees.z = 28.0
	elif tile.building == C.Building.RAFT_HOUSE:
		offset = maxf(0.0, tile.water * C.HEIGHT_UNIT) + 0.13
		for z: float in [-0.34, -0.17, 0.0, 0.17, 0.34]:
			var log_piece: MeshInstance3D = _add_mesh(village, _cylinder_mesh(0.072, 0.072, 0.91), Vector3(0.0, offset - 0.055, z), timber.lightened(0.17))
			log_piece.rotation_degrees.z = 90.0
	_add_box(village, Vector3(0.76, 0.065, 0.73), Vector3(0.0, offset + 0.03, 0.025), timber.lightened(0.17))
	_add_box(village, Vector3(0.62, 0.43, 0.52), Vector3(0.0, 0.27 + offset, -0.035), _color("house"))
	for y: float in [0.16, 0.29, 0.42]:
		_add_box(village, Vector3(0.63, 0.012, 0.018), Vector3(0.0, offset + y, 0.234), _color("house").darkened(0.15))
	_add_box(village, Vector3(0.15, 0.28, 0.025), Vector3(0.03, 0.21 + offset, 0.24), timber.darkened(0.17))
	_add_box(village, Vector3(0.017, 0.027, 0.024), Vector3(0.076, 0.22 + offset, 0.258), _color("accent"))
	_add_window(village, Vector3(-0.19, offset + 0.32, 0.245), 0.14, 0.16)
	_add_window(village, Vector3(0.318, offset + 0.32, -0.045), 0.18, 0.16, true)
	_add_roof(village, Vector3(0.82, 0.34, 0.74), Vector3(0.0, 0.61 + offset, -0.035), _color("roof").lightened(_variation(tile, 5) * 0.055))
	for x: float in [-0.32, 0.32]:
		_add_box(village, Vector3(0.035, 0.32, 0.035), Vector3(x, offset + 0.22, 0.35), timber)
	_add_box(village, Vector3(0.68, 0.035, 0.04), Vector3(0.0, offset + 0.38, 0.35), timber)
	if tile.building == C.Building.RAFT_HOUSE:
		_add_box(village, Vector3(0.035, 0.41, 0.035), Vector3(0.42, offset + 0.14, -0.32), timber)
	elif tile.building == C.Building.STILT_HOUSE:
		for step: int in range(3):
			_add_box(village, Vector3(0.25, 0.075, 0.14), Vector3(0.03, 0.07 + float(step) * 0.115, 0.71 - float(step) * 0.13), timber.lightened(0.12))
	else:
		_add_box(village, Vector3(0.28, 0.045, 0.14), Vector3(0.03, 0.025, 0.46), timber.lightened(0.22))
		_build_path(village, 0.0, 0.61, 2)


func _build_settlement_details(cell: Node3D, tile: Tile) -> void:
	if not SettlementProgress.enabled(state):
		return
	var stage: int = SettlementProgress.building_stage(state, tile)
	var age: int = SettlementProgress.building_age(state, tile)
	var condition: int = SettlementProgress.condition(state)
	var details: Node3D = Node3D.new()
	details.name = "SettlementDetails"
	details.rotation_degrees.y = 20.0
	details.set_meta("stage", stage)
	details.set_meta("age", age)
	details.set_meta("condition", condition)
	cell.add_child(details)
	var timber: Color = _color("earth").lerp(_color("roof"), 0.25)
	if tile.building in [C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.RAFT_HOUSE]:
		var offset: float = 0.41 if tile.building == C.Building.STILT_HOUSE else 0.0
		if tile.building == C.Building.RAFT_HOUSE:
			offset = maxf(0.0, tile.water * C.HEIGHT_UNIT) + 0.13
		if condition == 0 and age > 0:
			# Maintenance patches signal lean years without implying hit points.
			for side: float in [-1.0, 1.0]:
				var patch: MeshInstance3D = _add_mesh(details, _box_mesh(Vector3(0.13, 0.018, 0.14)), Vector3(side * 0.22, offset + 0.59, 0.13), timber.lightened(0.2))
				patch.rotation_degrees.z = -side * 22.0
		if stage >= 1:
			_add_mesh(details, _cylinder_mesh(0.070, 0.053, 0.10), Vector3(-0.27, offset + 0.10, 0.38), _color("roof").lightened(0.15))
			_add_mesh(details, _sphere_mesh(0.085, 0.11), Vector3(-0.27, offset + 0.19, 0.38), _color("forest").lightened(0.18))
			_add_box(details, Vector3(0.12, 0.095, 0.13), Vector3(0.25, offset + 0.11, 0.39), _color("accent").darkened(0.2))
		if stage >= 2:
			_add_roof(details, Vector3(0.50, 0.12, 0.23), Vector3(0.0, offset + 0.50, 0.36), _color("roof").lightened(0.10))
			var lamp: MeshInstance3D = _add_mesh(details, _sphere_mesh(0.045, 0.095), Vector3(0.26, offset + 0.36, 0.31), _color("highlight"), true)
			lamp.name = "PorchLantern"
	elif tile.building == C.Building.GRANARY:
		# Sack count follows actual communal reserves, not fabricated income.
		var sacks: int = mini(5, state.food / maxi(1, state.population))
		for index: int in range(sacks):
			_add_mesh(details, _sphere_mesh(0.10, 0.16), Vector3(-0.36 + float(index % 3) * 0.15, 0.09 + float(index / 3) * 0.11, 0.43), _color("accent").lightened(0.10))
	elif tile.building == C.Building.HALL and stage >= 1:
		for side: float in [-1.0, 1.0]:
			_add_mesh(details, _cylinder_mesh(0.075, 0.055, 0.13), Vector3(side * 0.47, 0.10, 0.34), _color("roof"))
			_add_mesh(details, _sphere_mesh(0.11, 0.16), Vector3(side * 0.47, 0.23, 0.34), _color("forest").lightened(0.13))
		if stage >= 2:
			_add_box(details, Vector3(0.34, 0.08, 0.018), Vector3(0.0, 0.64, 0.32), _color("highlight"))


func _build_hall(cell: Node3D) -> void:
	var hall: Node3D = Node3D.new()
	hall.name = "Hall"
	hall.rotation_degrees.y = 20.0
	cell.add_child(hall)
	var timber: Color = _color("earth").lerp(_color("roof"), 0.3)
	_add_box(hall, Vector3(1.03, 0.12, 0.90), Vector3(0.0, 0.06, 0.0), _color("house").darkened(0.17))
	_add_box(hall, Vector3(0.93, 0.035, 0.81), Vector3(0.0, 0.135, 0.0), _color("house").lightened(0.08))
	_add_box(hall, Vector3(0.73, 0.46, 0.63), Vector3(0.0, 0.38, -0.025), _color("house"))
	_add_box(hall, Vector3(0.23, 0.35, 0.025), Vector3(0.0, 0.33, 0.302), timber.darkened(0.12))
	_add_box(hall, Vector3(0.012, 0.32, 0.03), Vector3(0.0, 0.33, 0.32), _color("accent"))
	for x: float in [-0.39, 0.39]:
		_add_box(hall, Vector3(0.06, 0.52, 0.06), Vector3(x, 0.39, 0.35), timber)
		_add_box(hall, Vector3(0.085, 0.05, 0.085), Vector3(x, 0.18, 0.35), _color("accent"))
	_add_window(hall, Vector3(-0.24, 0.42, 0.302), 0.14, 0.18)
	_add_window(hall, Vector3(0.24, 0.42, 0.302), 0.14, 0.18)
	_add_window(hall, Vector3(0.373, 0.43, -0.06), 0.22, 0.18, true)
	_add_roof(hall, Vector3(1.12, 0.34, 0.99), Vector3(0.0, 0.75, -0.025), _color("roof").darkened(0.08))
	_add_roof(hall, Vector3(0.78, 0.30, 0.72), Vector3(0.0, 0.99, -0.025), _color("roof"))
	for z: float in [-0.39, 0.34]:
		var finial: MeshInstance3D = _add_mesh(hall, _box_mesh(Vector3(0.04, 0.20, 0.045)), Vector3(0.0, 1.18, z), _color("accent"))
		finial.rotation_degrees.x = -22.0 if z < 0.0 else 22.0
	for step: int in range(2):
		_add_box(hall, Vector3(0.40 + float(step) * 0.13, 0.055, 0.16), Vector3(0.0, 0.075 - float(step) * 0.035, 0.50 + float(step) * 0.14), _color("house").darkened(0.1))
	_add_box(hall, Vector3(0.027, 0.84, 0.027), Vector3(-0.65, 0.42, 0.11), timber)
	_add_box(hall, Vector3(0.19, 0.24, 0.015), Vector3(-0.55, 0.68, 0.11), _color("accent"))


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
	var key: String = "roof:" + str(size)
	if not _meshes.has(key):
		var roof: PrismMesh = PrismMesh.new()
		roof.size = size
		_meshes[key] = roof
	var prism: PrismMesh = _meshes[key] as PrismMesh
	_add_mesh(parent, prism, at, color)
	# Raised terracotta courses and a timber fascia catch the low sun.
	for course: int in range(-2, 3):
		var x: float = float(course) * size.x * 0.16
		var y: float = at.y + size.y * (0.5 - absf(x) / size.x * 2.0) + 0.008
		_add_box(parent, Vector3(0.020, 0.015, size.z + 0.016), Vector3(at.x + x, y, at.z), color.lightened(0.14))
	_add_box(parent, Vector3(0.045, 0.035, size.z + 0.065), at + Vector3.UP * (size.y * 0.5 + 0.015), _color("accent").lerp(color, 0.68))
	for z: float in [-size.z * 0.5, size.z * 0.5]:
		_add_box(parent, Vector3(size.x + 0.02, 0.035, 0.035), at + Vector3(0.0, -size.y * 0.5, z), _color("earth").darkened(0.08))


func _add_window(parent: Node3D, at: Vector3, width: float, height: float, side: bool = false) -> void:
	var window: Node3D = Node3D.new()
	window.position = at
	window.rotation.y = PI * 0.5 if side else 0.0
	parent.add_child(window)
	_add_box(window, Vector3(width + 0.035, height + 0.035, 0.023), Vector3.ZERO, _color("earth").lightened(0.18))
	_add_box(window, Vector3(width, height, 0.026), Vector3(0.0, 0.0, 0.009), _color("sea").darkened(0.35))
	_add_box(window, Vector3(0.016, height, 0.031), Vector3(0.0, 0.0, 0.015), _color("house"))
	_add_box(window, Vector3(width, 0.018, 0.031), Vector3(0.0, -height * 0.10, 0.015), _color("house"))


func _build_path(parent: Node3D, x: float, z: float, count: int) -> void:
	for index: int in range(count):
		_add_box(parent, Vector3(0.19, 0.018, 0.11), Vector3(x + float(index % 2) * 0.035, 0.012, z + float(index) * 0.14), _color("house").darkened(0.13))


func _add_box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	_add_mesh(parent, _box_mesh(size), at, color)


func _box_mesh(size: Vector3) -> BoxMesh:
	var key: String = "box:" + str(size)
	if not _meshes.has(key):
		var box: BoxMesh = BoxMesh.new()
		box.size = size
		_meshes[key] = box
	return _meshes[key] as BoxMesh


func _sphere_mesh(radius: float, height: float) -> SphereMesh:
	var key: String = "sphere:%.3f:%.3f" % [radius, height]
	if not _meshes.has(key):
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = radius
		sphere.height = height
		sphere.radial_segments = 8
		sphere.rings = 4
		_meshes[key] = sphere
	return _meshes[key] as SphereMesh


func _cylinder_mesh(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var key: String = "cylinder:%.3f:%.3f:%.3f" % [top_radius, bottom_radius, height]
	if not _meshes.has(key):
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = top_radius
		cylinder.bottom_radius = bottom_radius
		cylinder.height = height
		cylinder.radial_segments = 7
		_meshes[key] = cylinder
	return _meshes[key] as CylinderMesh


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
	if _flow_view != null and _flow_view.is_showing_actual():
		return
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
		_preview_label("", entry["coord"], Color("#ef8c76"), "Destroyed", "broken_house")
	if report.outcome == C.Outcome.LOSE_HALL:
		for tile: Tile in state.tiles:
			if tile.building == C.Building.HALL:
				_preview_label("", tile.coord, Color("#ef8c76"), "HallRisk", "hall")
	for coord: Vector2i in report.paddies_died:
		_preview_label("", coord, Color("#ef8c76"), "PaddyDied", "dead_rice")
	for coord: Vector2i in report.paddy_gains:
		_preview_label("+1", coord, _color("highlight"), "PaddyGain", "paddy")
	var fish: Dictionary = preview_fish_food_by_tile(predicted, report)
	for coord: Vector2i in fish:
		_preview_label("+%d" % int(fish[coord]), coord, _color("water_shallow"), "FishFood", "fish")


static func preview_fish_food_by_tile(predicted: GameState, report: TurnReport) -> Dictionary:
	if not report.fish_food_by_tile.is_empty():
		return report.fish_food_by_tile.duplicate()
	var result: Dictionary = {}
	if report.outcome == C.Outcome.LOSE_HALL or report.fish_food <= 0:
		return result
	var productive_traps: Array[Vector2i] = []
	for index: int in range(predicted.tiles.size()):
		var tile: Tile = predicted.tiles[index]
		var level: int = report.levels_after[index] if index < report.levels_after.size() else predicted.level_of(tile)
		if tile.building == C.Building.FISH_TRAP and level >= 1:
			productive_traps.append(tile.coord)
	if productive_traps.is_empty():
		return result
	# Every productive trap has the same yield. Read the resolved total rather
	# than evaluating modifiers here, so even the model's caches stay untouched.
	var fish_food: int = roundi(float(report.fish_food) / float(productive_traps.size()))
	for coord: Vector2i in productive_traps:
		result[coord] = fish_food
	return result


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


func _preview_label(text: String, coord: Vector2i, color: Color, prefix: String, icon: String = "warning") -> void:
	var tile: Tile = state.get_tile(coord)
	if tile == null:
		return
	var predicted: GameState = _prediction["state"]
	var after: Tile = predicted.get_tile(coord)
	var label: Label3D = Label3D.new()
	label.name = "%s_%d_%d" % [prefix, coord.x, coord.y]
	label.text = text
	label.font = MARKER_FONT
	label.font_size = 36
	label.pixel_size = 0.012
	label.position = Hex.to_world(coord)
	label.position.y = maxf(_surface_y(tile), _surface_y(after) if after != null else _surface_y(tile)) + 0.95
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_modulate = _color("background")
	label.outline_size = 9
	label.no_depth_test = true
	label.set_meta("icon", icon)
	var plate: Sprite3D = Sprite3D.new()
	plate.name = "Backplate"
	plate.texture = preload("res://assets/icons/marker_plate.svg")
	plate.pixel_size = 0.019 if text.is_empty() else 0.015
	plate.position = Vector3(0.0 if text.is_empty() else -0.36, 0.06, 0.0)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.no_depth_test = true
	plate.render_priority = 1
	label.add_child(plate)
	var pictogram: Sprite3D = Sprite3D.new()
	pictogram.name = "Icon"
	pictogram.texture = load("res://assets/icons/%s.svg" % icon)
	pictogram.pixel_size = 0.026 if text.is_empty() else 0.019
	pictogram.position = plate.position
	pictogram.modulate = color
	pictogram.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pictogram.no_depth_test = true
	pictogram.shaded = false
	pictogram.render_priority = 2
	label.add_child(pictogram)
	if prefix == "HallRisk":
		var warning: Sprite3D = Sprite3D.new()
		warning.name = "Warning"
		warning.texture = load("res://assets/icons/warning.svg")
		warning.pixel_size = 0.019
		warning.position = Vector3(0.37, 0.34, 0.0)
		warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		warning.no_depth_test = true
		warning.render_priority = 3
		label.add_child(warning)
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
