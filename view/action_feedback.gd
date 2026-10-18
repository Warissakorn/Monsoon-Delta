class_name ActionFeedback
extends Node3D
## Transient, presentation-only responses. No timers or tweens outlive this node.

signal emptied

const FONT: Font = preload("res://assets/fonts/NotoSansThai.ttf")
const MAX_MARKERS: int = 12
const LIFETIME: float = 1.2
const BURST_LIFETIME: float = 0.42
const LABEL_ORIGIN: Vector3 = Vector3(0.0, 0.95, 0.0)
const OUTLINE: Color = Color(0.025, 0.07, 0.08, 0.95)

static var _ring_mesh: ArrayMesh
static var _burst_mesh: SphereMesh

var _reduced_motion: bool = false
var _markers: Array[Dictionary] = []


func _init() -> void:
	set_process(false)


func show_marker(at: Vector3, text: String, color: Color, kind: String = "success") -> void:
	while _markers.size() >= MAX_MARKERS:
		_remove_marker(0)
	var marker: Node3D = Node3D.new()
	marker.name = "ActionMarker"
	marker.position = at
	add_child(marker)
	marker.owner = self
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	if _ring_mesh == null:
		_ring_mesh = MeshLib.hex_ring(0.84, 0.805)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = _ring_mesh
	ring.material_override = material
	ring.position.y = 0.025
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(ring)
	ring.owner = marker
	var label: Label3D = Label3D.new()
	label.name = "Label"
	label.text = text
	label.font = FONT
	label.font_size = 48
	label.pixel_size = 0.010
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = 500.0
	label.position = LABEL_ORIGIN
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_modulate = OUTLINE
	label.outline_size = 6
	label.no_depth_test = true
	label.render_priority = 4
	marker.add_child(label)
	label.owner = marker
	var entry: Dictionary = {
		"node": marker, "ring": ring, "label": label, "burst": null,
		"material": material, "color": color, "kind": kind, "age": 0.0,
	}
	if not _reduced_motion:
		entry["burst"] = _make_burst(marker, material)
	_markers.append(entry)
	_update_marker(entry)
	set_process(true)


func clear() -> void:
	var had_markers: bool = not _markers.is_empty()
	for index: int in range(_markers.size() - 1, -1, -1):
		_remove_marker(index)
	set_process(false)
	if had_markers:
		emptied.emit()


func set_reduced_motion(enabled: bool) -> void:
	if _reduced_motion == enabled:
		return
	_reduced_motion = enabled
	for entry: Dictionary in _markers:
		if enabled:
			_remove_burst(entry)
		elif float(entry["age"]) < BURST_LIFETIME:
			entry["burst"] = _make_burst(entry["node"], entry["material"])
		_update_marker(entry)


func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var had_markers: bool = not _markers.is_empty()
	for index: int in range(_markers.size() - 1, -1, -1):
		var entry: Dictionary = _markers[index]
		entry["age"] = float(entry["age"]) + delta
		if float(entry["age"]) >= LIFETIME:
			_remove_marker(index)
		else:
			_update_marker(entry)
	set_process(not _markers.is_empty())
	if had_markers and _markers.is_empty():
		emptied.emit()


func _update_marker(entry: Dictionary) -> void:
	var age: float = float(entry["age"])
	var label: Label3D = entry["label"] as Label3D
	var ring: MeshInstance3D = entry["ring"] as MeshInstance3D
	var material: StandardMaterial3D = entry["material"] as StandardMaterial3D
	var color: Color = entry["color"]
	if _reduced_motion:
		label.position = LABEL_ORIGIN
		label.modulate = color
		label.outline_modulate = OUTLINE
		ring.scale = Vector3.ONE
		material.albedo_color = color
		return
	var opacity: float = 1.0 - smoothstep(0.70, LIFETIME, age)
	var rise: float = 0.23 if entry["kind"] == "error" else 0.43
	label.position = LABEL_ORIGIN + Vector3.UP * (rise * age / LIFETIME)
	label.modulate = Color(color, color.a * opacity)
	label.outline_modulate = Color(OUTLINE, OUTLINE.a * opacity)
	var pulse: float = sin(minf(age / 0.48, 1.0) * PI * 0.5)
	ring.scale = Vector3.ONE * (0.9 + pulse * 0.17)
	material.albedo_color = Color(color, color.a * opacity * 0.84)
	if age >= BURST_LIFETIME:
		_remove_burst(entry)
	elif entry["burst"] != null:
		var burst: MultiMeshInstance3D = entry["burst"] as MultiMeshInstance3D
		var progress: float = age / BURST_LIFETIME
		for index: int in range(3):
			var angle: float = TAU * float(index) / 3.0 + 0.3
			var radius: float = 0.10 + progress * 0.36
			var at: Vector3 = Vector3(cos(angle) * radius, 0.09 + sin(progress * PI) * 0.25, sin(angle) * radius)
			var basis: Basis = Basis(Vector3.UP, angle + progress).scaled(Vector3.ONE * (1.0 - progress * 0.55))
			burst.multimesh.set_instance_transform(index, Transform3D(basis, at))


func _make_burst(marker: Node3D, material: Material) -> MultiMeshInstance3D:
	if _burst_mesh == null:
		_burst_mesh = SphereMesh.new()
		_burst_mesh.radius = 0.033
		_burst_mesh.height = 0.075
		_burst_mesh.radial_segments = 4
		_burst_mesh.rings = 2
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _burst_mesh
	multimesh.instance_count = 3
	var burst: MultiMeshInstance3D = MultiMeshInstance3D.new()
	burst.name = "Burst"
	burst.multimesh = multimesh
	burst.material_override = material
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(burst)
	burst.owner = marker
	return burst


func _remove_burst(entry: Dictionary) -> void:
	if entry["burst"] != null:
		(entry["burst"] as MultiMeshInstance3D).free()
		entry["burst"] = null


func _remove_marker(index: int) -> void:
	var entry: Dictionary = _markers[index]
	(entry["node"] as Node3D).free()
	_markers.remove_at(index)
