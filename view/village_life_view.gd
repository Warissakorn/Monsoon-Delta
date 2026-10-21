class_name VillageLifeView
extends Node3D
## Presentation of committed work, never an economy or a second simulation.
## Command/production callers enqueue real events after their rules have run.
## Ordinary refreshes preserve jobs; Undo, load and reset explicitly clear them.

const Worker = preload("res://view/village_worker.gd")
const Routes = preload("res://view/route_graph.gd")
const MAX_ACTORS: int = 12
const MAX_JOBS: int = 24
const WALK_SPEED: float = 1.25
const WORK_SECONDS: float = 2.4
const STATIC_JOB_SECONDS: float = 4.8
const NO_COORD: Vector2i = Vector2i(2147483647, 2147483647)

var _state: GameState
var _graph: Routes
var _actors: Array[Dictionary] = []
var _jobs: Array[Dictionary] = []
var _homes: Array[Vector2i] = []
var _stores: Array[Vector2i] = []
var _reduced_motion: bool = false
var _paused: bool = false
var _clock: float = 0.0


func _init() -> void:
	set_process(false)


func set_state(state: GameState, graph: Routes) -> void:
	var routes_changed: bool = graph != _graph
	_state = state
	_graph = graph
	_homes.clear()
	_stores.clear()
	if state == null or graph == null:
		clear()
		return
	for tile: Tile in state.tiles:
		if not _graph.anchors.has(tile.coord):
			continue
		if tile.building in [C.Building.HOUSE, C.Building.STILT_HOUSE, C.Building.RAFT_HOUSE]:
			_homes.append(tile.coord)
		elif tile.building == C.Building.GRANARY:
			_stores.append(tile.coord)
	if _graph.anchors.has(_graph.hub_coord):
		_stores.append(_graph.hub_coord)
		if _homes.is_empty():
			_homes.append(_graph.hub_coord)
	var count: int = mini(MAX_ACTORS, maxi(0, state.population)) if not _homes.is_empty() else 0
	while _actors.size() > count:
		(_actors.pop_back()["node"] as Node3D).free()
	while _actors.size() < count:
		_create_actor(_actors.size())
	for actor: Dictionary in _actors:
		var job: Dictionary = actor["job"]
		if job.is_empty():
			_place_idle(actor)
		elif routes_changed:
			_reconcile_job(actor)
	_assign_jobs()
	_update_processing()


## Called only after CommandRules.apply succeeded. Its target remains available
## even when chopping/demolition has already removed the original map feature.
func show_command(id: String, coord: Vector2i) -> bool:
	var kind: String = "build"
	match id:
		"paddy": kind = "farm"
		"dig", "fill", "chop", "plant", "demolish": kind = id
		"toggle_gate": kind = "operate"
		"house", "stilt_house", "raft_house", "gate", "reservoir", "fish_trap", "granary", "waterwheel", "brace_house": kind = "build"
		_: return false
	return _enqueue(kind, coord, id == "chop", "command")


## Reports must be committed, not preview reports. Paddy growth means tending,
## whereas a positive fish entry is a real catch which can be carried home.
func show_report(report: TurnReport) -> void:
	if report == null:
		return
	for coord: Vector2i in report.paddy_gains:
		_enqueue("farm", coord, false, "production")
	for coord: Vector2i in report.fish_food_by_tile:
		if int(report.fish_food_by_tile[coord]) > 0:
			_enqueue("fish", coord, true, "production")


## The committed harvest caller supplies exact per-tile food from Harvest.
## There is no inferred harvest or duplicate resource award in this view.
func show_harvest(food_by_tile: Dictionary) -> void:
	for coord: Vector2i in food_by_tile:
		if int(food_by_tile[coord]) > 0:
			_enqueue("harvest", coord, true, "harvest")


func set_reduced_motion(enabled: bool) -> void:
	if _reduced_motion == enabled:
		return
	_reduced_motion = enabled
	for actor: Dictionary in _actors:
		var job: Dictionary = actor["job"]
		if not job.is_empty():
			if String(job["source"]) == "ambient":
				_finish_job(actor)
				continue
			if enabled:
				_place_static_worker(actor)
			else:
				# Resume at work, rather than teleporting back to an old journey.
				actor["stage"] = "work"
				actor["stage_time"] = 0.0
				(actor["node"] as Node3D).position = _work_position(actor)
		_update_pose(actor)
	_update_processing()


func set_paused(enabled: bool) -> void:
	_paused = enabled
	_update_processing()


## Frees pooled actors immediately. Re-apply set_state after a reset if idle
## villagers should be recreated; no stale queued work survives this boundary.
func clear() -> void:
	_jobs.clear()
	for actor: Dictionary in _actors:
		(actor["node"] as Node3D).free()
	_actors.clear()
	_clock = 0.0
	set_process(false)


func actor_count() -> int:
	return _actors.size()


func queued_job_count() -> int:
	return _jobs.size()


func activity_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor: Dictionary in _actors:
		var job: Dictionary = actor["job"]
		if job.is_empty():
			continue
		result.append({
			"kind": job["kind"], "coord": job["coord"], "source": job["source"],
			"stage": actor["stage"], "position": (actor["node"] as Node3D).position,
			"carrying": bool(job["carry"]) and String(actor["stage"]) == "deliver",
		})
	return result


func _enqueue(kind: String, coord: Vector2i, carry: bool, source: String) -> bool:
	if _state == null or _graph == null or _actors.is_empty() or _state.get_tile(coord) == null:
		return false
	# Do not claim access to an island or a flooded workplace without a dry route.
	var home: Vector2i = _home_for(coord)
	if home == NO_COORD:
		return false
	while _jobs.size() >= MAX_JOBS:
		_jobs.pop_front()
	_jobs.append({"kind": kind, "coord": coord, "carry": carry, "source": source, "home": home})
	_assign_jobs()
	_update_processing()
	return true


func _create_actor(index: int) -> void:
	var worker: Node3D = Worker.new()
	worker.build(index)
	add_child(worker)
	worker.owner = self
	_actors.append({
		"node": worker, "index": index, "job": {}, "stage": "idle", "path": PackedVector3Array(),
		"length": 0.0, "distance": 0.0, "stage_time": 0.0, "total_time": 0.0,
		"idle_time": float(index) * -1.1, "home": NO_COORD, "store": NO_COORD,
	})


func _place_idle(actor: Dictionary) -> void:
	if _homes.is_empty():
		(actor["node"] as Node3D).hide()
		return
	var index: int = int(actor["index"])
	var home: Vector2i = _homes[index % _homes.size()]
	actor["home"] = home
	var position: Vector3 = _graph.anchors[home]["position"]
	# A small entrance-side spread keeps idle representatives readable.
	var along: float = floorf(float(index) / float(maxi(1, _homes.size())))
	var spread: Vector3 = position + Vector3((fmod(along, 3.0) - 1.0) * 0.075, 0.0, 0.0)
	if _graph.point_clear(spread):
		position = spread
	var worker: Node3D = actor["node"] as Node3D
	worker.position = position
	worker.rotation.y = 0.20 + float(index % 3) * 0.35
	worker.visible = index < mini(6, _actors.size())
	worker.set_task("idle", false)
	worker.pose(_clock + float(index), false, false, _reduced_motion)


func _home_for(coord: Vector2i) -> Vector2i:
	var best: Vector2i = NO_COORD
	var shortest: float = INF
	for home: Vector2i in _homes:
		var path: PackedVector3Array = _graph.path_between(home, coord)
		if path.is_empty():
			continue
		var length: float = Routes.path_length(path)
		if length < shortest:
			shortest = length
			best = home
	return best


func _storage_for(coord: Vector2i, home: Vector2i) -> Vector2i:
	for store: Vector2i in _stores:
		if not _graph.path_between(coord, store).is_empty() and not _graph.path_between(store, home).is_empty():
			return store
	return home


func _assign_jobs() -> void:
	for actor: Dictionary in _actors:
		if _jobs.is_empty():
			return
		var current: Dictionary = actor["job"]
		if not current.is_empty() and String(current["source"]) != "ambient":
			continue
		if not current.is_empty():
			_finish_job(actor)
		while not _jobs.is_empty():
			var job: Dictionary = _jobs.pop_front()
			if _start_job(actor, job):
				break


func _start_job(actor: Dictionary, job: Dictionary) -> bool:
	var home: Vector2i = actor["home"]
	if home == NO_COORD or not _homes.has(home) or _graph.path_between(home, job["coord"]).is_empty():
		home = _home_for(job["coord"])
	if home == NO_COORD:
		return false
	actor["home"] = home
	actor["store"] = job["coord"] if String(job["source"]) == "ambient" else _storage_for(job["coord"], home)
	actor["job"] = job
	actor["total_time"] = 0.0
	actor["idle_time"] = 0.0
	var worker: Node3D = actor["node"] as Node3D
	worker.show()
	if not _set_stage(actor, "outbound"):
		_finish_job(actor)
		return false
	if _reduced_motion:
		_place_static_worker(actor)
	return true


func _set_stage(actor: Dictionary, stage: String, fraction: float = 0.0) -> bool:
	var job: Dictionary = actor["job"]
	var path: PackedVector3Array = PackedVector3Array()
	match stage:
		"outbound": path = _graph.path_between(actor["home"], job["coord"])
		"deliver": path = _graph.path_between(job["coord"], actor["store"])
		"return": path = _graph.path_between(actor["store"], actor["home"])
		"work":
			actor["stage"] = stage
			actor["stage_time"] = 0.0
			(actor["node"] as Node3D).position = _work_position(actor)
			_face_work(actor)
			_update_pose(actor)
			return true
	if path.is_empty():
		return false
	actor["stage"] = stage
	actor["path"] = path
	actor["length"] = Routes.path_length(path)
	actor["distance"] = clampf(fraction, 0.0, 1.0) * float(actor["length"])
	actor["stage_time"] = 0.0
	_sample_actor(actor)
	_update_pose(actor)
	return true


func _work_position(actor: Dictionary) -> Vector3:
	var job: Dictionary = actor["job"]
	var path: PackedVector3Array = _graph.path_between(actor["home"], job["coord"])
	return path[path.size() - 1] if not path.is_empty() else (actor["node"] as Node3D).position


func _place_static_worker(actor: Dictionary) -> void:
	(actor["node"] as Node3D).position = _work_position(actor)
	_face_work(actor)
	actor["stage"] = "work"
	actor["stage_time"] = 0.0
	_update_pose(actor)


func _reconcile_job(actor: Dictionary) -> void:
	var job: Dictionary = actor["job"]
	if _home_for(job["coord"]) == NO_COORD or not _homes.has(actor["home"]):
		_finish_job(actor)
		return
	actor["store"] = _storage_for(job["coord"], actor["home"])
	var stage: String = String(actor["stage"])
	if stage == "work":
		(actor["node"] as Node3D).position = _work_position(actor)
		_face_work(actor)
		return
	var fraction: float = float(actor["distance"]) / maxf(0.001, float(actor["length"]))
	if not _set_stage(actor, stage, fraction):
		_finish_job(actor)


func _finish_job(actor: Dictionary) -> void:
	actor["job"] = {}
	actor["stage"] = "idle"
	actor["idle_time"] = 0.0
	actor["path"] = PackedVector3Array()
	_place_idle(actor)


func _process(delta: float) -> void:
	if _paused or not is_finite(delta) or delta <= 0.0:
		return
	_clock += delta
	for actor: Dictionary in _actors:
		if (actor["job"] as Dictionary).is_empty():
			actor["idle_time"] = float(actor["idle_time"]) + delta
			_maybe_visit_hall(actor)
		else:
			_tick_job(actor, delta)
		_update_pose(actor)
	_assign_jobs()
	_update_processing()


func _tick_job(actor: Dictionary, delta: float) -> void:
	actor["total_time"] = float(actor["total_time"]) + delta
	if _reduced_motion:
		if float(actor["total_time"]) >= STATIC_JOB_SECONDS:
			_finish_job(actor)
		return
	var remaining: float = delta
	# At most outbound/work/delivery/return transitions, including zero-length
	# paths at a shared entrance. Large frame deltas cannot create a busy loop.
	for _step: int in range(5):
		if (actor["job"] as Dictionary).is_empty():
			break
		var stage: String = String(actor["stage"])
		var available: float
		if stage == "work":
			available = maxf(0.0, WORK_SECONDS - float(actor["stage_time"]))
			actor["stage_time"] = float(actor["stage_time"]) + minf(remaining, available)
		else:
			available = maxf(0.0, (float(actor["length"]) - float(actor["distance"])) / WALK_SPEED)
			actor["distance"] = minf(float(actor["length"]), float(actor["distance"]) + minf(remaining, available) * WALK_SPEED)
			_sample_actor(actor)
		if remaining < available:
			break
		remaining -= available
		var next: String = {"outbound": "work", "work": "deliver", "deliver": "return"}.get(stage, "")
		if next.is_empty() or not _set_stage(actor, next):
			_finish_job(actor)
			break


func _sample_actor(actor: Dictionary) -> void:
	var sampled: Dictionary = Routes.sample_path(actor["path"], float(actor["distance"]))
	var worker: Node3D = actor["node"] as Node3D
	worker.position = sampled["position"]
	var tangent: Vector3 = sampled["tangent"]
	if Vector2(tangent.x, tangent.z).length_squared() > 0.00001:
		worker.rotation.y = atan2(tangent.x, tangent.z)


func _face_work(actor: Dictionary) -> void:
	var job: Dictionary = actor["job"]
	var tile: Tile = _state.get_tile(job["coord"])
	if tile == null:
		return
	var worker: Node3D = actor["node"] as Node3D
	var toward: Vector3 = Hex.to_world(tile.coord, tile.elevation) - worker.position
	if Vector2(toward.x, toward.z).length_squared() > 0.01:
		worker.rotation.y = atan2(toward.x, toward.z)


func _maybe_visit_hall(actor: Dictionary) -> void:
	if _reduced_motion or _graph == null or int(actor["index"]) >= mini(4, _actors.size()):
		return
	if float(actor["idle_time"]) < 4.0 + float(int(actor["index"]) % 4) * 1.2:
		return
	var home: Vector2i = actor["home"]
	var hall: Vector2i = _graph.hub_coord
	if home == hall or not _graph.anchors.has(hall):
		return
	var visitors: int = 0
	for other: Dictionary in _actors:
		var job: Dictionary = other["job"]
		if not job.is_empty() and String(job["source"]) == "ambient":
			visitors += 1
	if visitors >= 2 or _graph.path_between(home, hall).is_empty():
		return
	_start_job(actor, {"kind": "visit", "coord": hall, "carry": false, "source": "ambient", "home": home})


func _update_pose(actor: Dictionary) -> void:
	var job: Dictionary = actor["job"]
	var stage: String = String(actor["stage"])
	var worker: Node3D = actor["node"] as Node3D
	worker.set_task(String(job.get("kind", "idle")), bool(job.get("carry", false)) and stage == "deliver")
	worker.pose(_clock + float(actor["index"]) * 0.41, stage in ["outbound", "deliver", "return"], stage == "work", _reduced_motion)


func _update_processing() -> void:
	var active: bool = false
	if _reduced_motion:
		for actor: Dictionary in _actors:
			if not (actor["job"] as Dictionary).is_empty():
				active = true
				break
	set_process(not _paused and not _actors.is_empty() and (not _reduced_motion or active or not _jobs.is_empty()))
