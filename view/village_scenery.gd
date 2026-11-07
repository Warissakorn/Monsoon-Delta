class_name VillageScenery
extends Node3D
## Bounded presentation of the scene contract. No simulation timers or I/O.

var plan: Dictionary = {}
var rebuild_count: int = 0
var _signature: String = ""
var _clock: float = 0.0
var _paused: bool = false
var _reduced_motion: bool = false
var _detail: bool = true
var _groups: Dictionary = {}
var _static_root: Node3D
var _actor_root: Node3D
var _activity_root: Node3D
var _activity_left: float = 0.0
var _flow: Dictionary = {}


func _init() -> void:
	set_process(false)


func set_state(state: GameState, routes: RouteGraph) -> void:
	_ensure_roots()
	var next: Dictionary = VillageScenePlan.build(state, routes)
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(next))
	var signature: String = digest.finish().hex_encode()
	if signature == _signature:
		return
	_signature = signature
	plan = next
	rebuild_count += 1
	_clear_children(_static_root)
	_clear_children(_actor_root)
	_groups.clear()
	clear_activity()
	if state == null:
		_clock = 0.0
		_update_processing()
		return
	var builders: Dictionary = {}
	for item: Dictionary in plan["props"]:
		var kind: String = item["kind"]
		if kind == "wood_rack":
			kind += "_%d" % int(item["stock"])
		var category: String = "Ground" if kind in ["courtyard", "rain_soil", "mud_margin", "dry_cracks", "drying_mat", "water_mark"] else "Furniture"
		if not builders.has(category):
			var builder: SurfaceTool = SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builders[category] = builder
		var transform: Transform3D = Transform3D(Basis(Vector3.UP, float(item["rotation"])).scaled(item["scale"]), item["position"])
		(builders[category] as SurfaceTool).append_from(VillagePropMeshes.mesh(kind), 0, transform)
	for category: String in builders:
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Scenery_" + category
		instance.mesh = (builders[category] as SurfaceTool).commit()
		instance.material_override = VillagePropMeshes.material()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if category == "Furniture" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_static_root.add_child(instance)
	var entries: Dictionary = {}
	for item: Dictionary in plan["actors"]:
		var kind: String = item["kind"]
		if not entries.has(kind):
			entries[kind] = []
		entries[kind].append(item)
	for index: int in range(plan["ripples"].size()):
		var item: Dictionary = plan["ripples"][index].duplicate(true)
		item.merge({"phase": float(index) * 1.4, "rotation": 0.0})
		if not entries.has("ripple"):
			entries["ripple"] = []
		entries["ripple"].append(item)
	for kind: String in entries:
		var node: MultiMeshInstance3D = _multimesh(kind, entries[kind].size())
		node.name = kind.capitalize()
		_actor_root.add_child(node)
		_groups[kind] = {"node": node, "entries": entries[kind]}
	_apply_poses(0.0 if _reduced_motion else _clock)
	set_detail(_detail)
	_update_processing()


func set_detail(enabled: bool) -> void:
	_detail = enabled
	for kind: String in _groups:
		(_groups[kind]["node"] as MultiMeshInstance3D).visible = (enabled or kind == "boat") and (not _reduced_motion or kind not in ["drip", "mote"])


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	_apply_poses(0.0 if enabled else _clock)
	_update_processing()


func set_paused(enabled: bool) -> void:
	_paused = enabled
	_update_processing()


func set_flow(velocities: Dictionary) -> void:
	_flow = velocities.duplicate()
	_apply_poses(0.0 if _reduced_motion else _clock)


func show_report(report: TurnReport) -> void:
	if report == null:
		return
	var coords: Array[Vector2i] = []
	for coord: Vector2i in report.fish_food_by_tile:
		if int(report.fish_food_by_tile[coord]) > 0:
			coords.append(coord)
	if coords.is_empty():
		return
	_ensure_roots()
	clear_activity()
	for actor: Dictionary in plan.get("actors", []):
		if actor["kind"] == "boat" and actor["coord"] in coords:
			_add_activity("catch_basket", actor["position"] + Vector3.UP * 0.095)
	_activity_left = 2.4 if _activity_root.get_child_count() > 0 else 0.0
	_update_processing()


func show_harvest(food_by_tile: Dictionary) -> void:
	_ensure_roots()
	clear_activity()
	var total: int = 0
	for amount: int in food_by_tile.values():
		total += maxi(0, amount)
	if total == 0:
		return
	var shown: int = 0
	for item: Dictionary in plan.get("props", []):
		if item["kind"] == "drying_mat":
			_add_activity("rice_bundle", item["position"] + Vector3.UP * 0.012)
			shown += 1
			if shown >= mini(4, total):
				break
	_activity_left = 2.4 if shown > 0 else 0.0
	_update_processing()


func clear_activity() -> void:
	_activity_left = 0.0
	if _activity_root != null:
		_clear_children(_activity_root)
	_update_processing()


func _add_activity(kind: String, at: Vector3) -> void:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = kind.capitalize()
	node.mesh = VillagePropMeshes.mesh(kind)
	node.material_override = VillagePropMeshes.material()
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_activity_root.add_child(node)


func _process(delta: float) -> void:
	if _paused:
		return
	if not _reduced_motion:
		_clock += delta
		_apply_poses(_clock)
	if _activity_left > 0.0:
		_activity_left = maxf(0.0, _activity_left - delta)
		if _activity_left == 0.0:
			clear_activity()


func _apply_poses(time: float) -> void:
	for kind: String in _groups:
		var node: MultiMeshInstance3D = _groups[kind]["node"]
		var entries: Array = _groups[kind]["entries"]
		var poses: Array[Transform3D] = []
		for index: int in range(entries.size()):
			var item: Dictionary = entries[index]
			var phase: float = float(item["phase"])
			var moving: float = 0.0 if _reduced_motion else 1.0
			var at: Vector3 = item["position"]
			var angles: Vector3 = Vector3(0.0, float(item["rotation"]), 0.0)
			var scale: Vector3 = Vector3.ONE
			match kind:
				"boat":
					at.y += sin(time * 1.1 + phase) * 0.006 * moving
					angles.z = sin(time * 0.8 + phase) * 0.012 * moving
				"chicken":
					# A small orbit stays inside the tested clear placement disk.
					at += Vector3(sin(time * 0.6 + phase), 0.0, cos(time * 0.6 + phase)) * 0.023 * moving
					angles.y = sin(time * 0.4 + phase) * 0.8
					angles.x = maxf(0.0, sin(time * 1.5 + phase)) * 0.13 * moving
				"bird":
					angles.y = sin(time * 0.5 + phase) * 0.9
					at.y += maxf(0.0, sin(time * 0.9 + phase)) * 0.01 * moving
				"fish":
					at += Vector3(sin(time * 0.5 + phase), 0.0, cos(time * 0.5 + phase)) * 0.055 * moving
					angles.y += sin(time * 0.5 + phase) * 0.6
				"cloth":
					angles.x = sin(time * 1.3 + phase) * 0.06 * moving
				"drip":
					at.y -= fmod(time * 0.75 + phase, 0.35) * moving
				"mote":
					at += Vector3(sin(time * 0.3 + phase) * 0.07, sin(time * 0.4 + phase) * 0.04, cos(time * 0.3 + phase) * 0.05) * moving
				"ripple":
					var velocity: Vector2 = _flow.get(item["coord"], Vector2.ZERO)
					var pulse: float = 0.9 + fmod(time * 0.7 + phase, 1.0) * 0.7 if not _reduced_motion else 1.1
					scale = Vector3(pulse, 0.20, pulse)
					at += Vector3(velocity.x, 0.0, velocity.y).limit_length(1.0) * 0.018 * moving
			var pose: Transform3D = Transform3D(Basis.from_euler(angles).scaled(scale), at)
			node.multimesh.set_instance_transform(index, pose)
			poses.append(pose)
		_groups[kind]["poses"] = poses
		if kind in ["drip", "mote"]:
			node.visible = _detail and not _reduced_motion


func snapshot() -> Dictionary:
	var actors: Array[Dictionary] = []
	for kind: String in _groups:
		for pose: Transform3D in _groups[kind].get("poses", []):
			actors.append({"kind": kind, "transform": pose})
	return {"actors": actors, "activity": _activity_root.get_child_count() if _activity_root != null else 0, "clock": _clock, "props": plan.get("props", []).size(), "rebuilds": rebuild_count}


func _multimesh(kind: String, count: int) -> MultiMeshInstance3D:
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = VillagePropMeshes.mesh(kind)
	multi.instance_count = count
	node.multimesh = multi
	node.material_override = VillagePropMeshes.material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _ensure_roots() -> void:
	if _static_root != null:
		return
	_static_root = Node3D.new()
	_static_root.name = "Static"
	add_child(_static_root)
	_actor_root = Node3D.new()
	_actor_root.name = "Ambience"
	add_child(_actor_root)
	_activity_root = Node3D.new()
	_activity_root.name = "CommittedActivity"
	add_child(_activity_root)


func _update_processing() -> void:
	set_process(not _paused and ((not _reduced_motion and not _groups.is_empty()) or _activity_left > 0.0))


func _clear_children(node: Node3D) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.free()
