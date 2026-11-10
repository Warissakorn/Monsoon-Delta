class_name YearVillageView
extends BoardView
## Same terrain, architecture, water and scenery as classic, with year workplaces.

var year: Dictionary = {}
var year_predicted: Dictionary = {}


func _build_tile(tile: Tile) -> void:
	var index: int = int(state.index[tile.coord])
	var kind: String = year["structures"][index]
	var workplace: bool = kind in ["sawmill", "kiln", "workshop", "camp"]
	var original: int = tile.building
	if workplace:
		tile.building = C.Building.NONE
	super._build_tile(tile)
	tile.building = original
	var cell: Node3D = _tiles_root.get_child(_tiles_root.get_child_count() - 1)
	if workplace and int(year["health"][index]) > 0:
		_workplace(cell, kind)
	elif not kind.is_empty() and int(year["health"][index]) == 0:
		for offset: float in [-0.4, 0.0, 0.4]:
			_add_mesh(cell, _box_mesh(Vector3(0.2, 0.12, 0.45)), Vector3(offset, 0.06, 0.0), _color("house").darkened(0.3))
	var deposit: String = year["deposits"][index]
	if not deposit.is_empty():
		for offset: float in [-0.35, 0.05, 0.4]:
			var rock: MeshInstance3D = _add_mesh(cell, _box_mesh(Vector3(0.32, 0.26, 0.3)), Vector3(offset, 0.13, offset * 0.4), Color("b57650") if deposit == "clay" else (Color("b9ba8f") if deposit == "fiber" else Color("8d9c9d")))
			rock.rotation.y = offset
	if workplace or not deposit.is_empty() or (not kind.is_empty() and int(year["health"][index]) < 100):
		var label: Label3D = Label3D.new()
		label.font = MARKER_FONT
		label.text = tr("year.site." + (kind if not kind.is_empty() else deposit))
		if not kind.is_empty():
			label.text += " · %d/100" % int(year["health"][index])
		else:
			label.text += " · %d" % int(year["stock"][index])
		label.position = Hex.to_world(tile.coord)
		label.position.y = _surface_y(tile) + 1.7
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 28
		label.pixel_size = 0.012
		label.outline_size = 6
		label.no_depth_test = true
		_labels_root.add_child(label)


func _workplace(cell: Node3D, kind: String) -> void:
	var wood: Color = _color("house").darkened(0.3)
	_add_mesh(cell, _box_mesh(Vector3(1.05, 0.13, 0.85)), Vector3(0, 0.12, 0), wood)
	if kind == "kiln":
		_add_mesh(cell, _box_mesh(Vector3(0.9, 0.6, 0.72)), Vector3(0, 0.48, 0), Color("ad7152"))
		_add_mesh(cell, _box_mesh(Vector3(0.24, 0.75, 0.25)), Vector3(0.3, 1.0, 0.15), Color("8b5a49"))
		_add_mesh(cell, _box_mesh(Vector3(0.32, 0.26, 0.04)), Vector3(0, 0.38, 0.38), Color("362c2a"))
	else:
		for x: float in [-0.45, 0.45]:
			for z: float in [-0.32, 0.32]:
				_add_mesh(cell, _box_mesh(Vector3(0.07, 0.8, 0.07)), Vector3(x, 0.55, z), wood)
		for side: float in [-1.0, 1.0]:
			var roof: MeshInstance3D = _add_mesh(cell, _box_mesh(Vector3(1.25, 0.09, 0.57)), Vector3(0, 1.02, side * 0.23), Color("b79d65") if kind == "camp" else Color("688b85"))
			roof.rotation.x = side * -0.35
		_add_mesh(cell, _box_mesh(Vector3(0.7, 0.12, 0.4)), Vector3(0, 0.48, 0), wood)
		if kind == "sawmill":
			for z: float in [-0.12, 0.08, 0.28]:
				_add_mesh(cell, _box_mesh(Vector3(0.75, 0.1, 0.1)), Vector3(0, 0.6, z), Color("d8bb85"))
		elif kind == "workshop":
			_add_mesh(cell, _box_mesh(Vector3(0.16, 0.2, 0.24)), Vector3(0.15, 0.65, 0), Color("7b8b91"))
		else:
			_add_mesh(cell, _box_mesh(Vector3(0.28, 0.3, 0.28)), Vector3(0.2, 0.3, -0.1), Color("ceb279"))


func _refresh_preview() -> void:
	super._refresh_preview()
	if state == null or year_predicted.is_empty() or _flow_view.is_showing_actual():
		return
	for index: int in range(state.tiles.size()):
		var delta: int = int(year_predicted["health"][index]) - int(year["health"][index])
		if delta < 0:
			var ring: MeshInstance3D = _add_mesh(_preview_root, MeshLib.hex_ring(1.02, 0.9), Vector3.ZERO, Color("ef8c76"), true)
			ring.name = "YearDamage_%d" % index
			_position_marker(ring, state.tiles[index].coord, 0.1)
