class_name TransportSession
extends YearSession
## One owner for the combined model, isolated I/O and planning history.

const TRANSPORT_PATH: String = "user://transport365.json"
var transport: Dictionary = {}


func _init() -> void:
	save_path = TRANSPORT_PATH


func model() -> Dictionary:
	return {"year": year, "transport": transport}


func _replace(next: Dictionary) -> void:
	year = next["year"]
	transport = next["transport"]


func start_year(seed_value: int = 42, goal: String = "none", project: String = "food") -> String:
	if FileAccess.file_exists(save_path):
		var old: Dictionary = _read_year()
		if not String(old["error"]).is_empty():
			last_save_error = old["error"]
			return last_save_error
	var next: Dictionary = TransportGame.create(seed_value, goal, "food" if project.is_empty() else project)
	if next.is_empty() or not TransportCheckpoint.valid(next):
		return "msg.new_game_failed"
	_replace(next)
	undo_plans.clear()
	redo_plans.clear()
	return checkpoint_year()


func _commit(next: Dictionary) -> void:
	undo_plans.append(model().duplicate(true))
	if undo_plans.size() > 200:
		undo_plans.pop_front()
	redo_plans.clear()
	_replace(next)
	checkpoint_year()


func edit_transport(action: String, kind: String = "", amount: int = 1, mode: String = "land", id: int = -1) -> String:
	if year.is_empty():
		return "transport.error.order"
	var next: Dictionary = model().duplicate(true)
	var error: String
	match action:
		"work": error = TransportGame.order_work(next, kind, amount)
		"dispatch": error = TransportGame.dispatch(next, kind, amount, mode)
		_: error = TransportGame.edit(next, action, id, kind, amount)
	if not error.is_empty():
		return error
	_commit(next)
	return ""


func edit_year(action: String, id: String = "", tile: int = -1, batches: int = 1, repeat: bool = false, direction: int = 0, stop_at: int = 0, reserve: int = 0) -> String:
	if year.is_empty():
		return "year.error.order"
	if action == "order":
		var checked: String = check_year_order(id, tile, batches, repeat, direction, stop_at, reserve)
		if not checked.is_empty():
			return checked
	var next: Dictionary = model().duplicate(true)
	var error: String = "year.error.order"
	match action:
		"order": error = YearGame.order(next["year"], id, tile, batches, repeat, direction, stop_at, reserve)
		"pause": error = YearGame.edit_job(next["year"], tile, false)
		"cancel": error = YearGame.edit_job(next["year"], tile, true)
		"learn": error = YearGame.learn(next["year"], id)
		"gate": error = YearGame.toggle_gate(next["year"], tile)
		"project": error = YearExpansion.choose_project(next["year"], id)
	if not error.is_empty():
		return error
	if TransportGame.free_workers(next) < 0:
		return "year.error.workers"
	_commit(next)
	return ""


func check_year_order(id: String, tile: int, batches: int = 1, repeat: bool = false, direction: int = 0, stop_at: int = 0, reserve: int = 0) -> String:
	if year.is_empty():
		return "year.error.order"
	if TransportGame.protected_order(model(), id, tile):
		return "transport.error.dedicated"
	for job: Dictionary in transport["work"]:
		if tile == int(transport["sites"]["source" if job["kind"] == "cut" else "mill"]):
			return "year.error.occupied"
	var error: String = YearGame.check_order(year, id, tile, batches, repeat, direction, stop_at, reserve)
	if error.is_empty() and free_workers_for_order(id) < 0:
		return "year.error.workers"
	return error


func free_workers_for_order(id: String) -> int:
	return TransportGame.free_workers(model()) - int(YearGame.config(year)["jobs"][id]["workers"])


func undo_year() -> bool:
	if undo_plans.is_empty():
		return false
	redo_plans.append(model().duplicate(true))
	_replace(undo_plans.pop_back())
	checkpoint_year()
	return true


func redo_year() -> bool:
	if redo_plans.is_empty():
		return false
	undo_plans.append(model().duplicate(true))
	_replace(redo_plans.pop_back())
	checkpoint_year()
	return true


func advance_year(days: int) -> Dictionary:
	if year.is_empty():
		return {"days": 0, "events": []}
	var report: Dictionary = TransportGame.advance(model(), days)
	if int(report["days"]) > 0:
		undo_plans.clear()
		redo_plans.clear()
		checkpoint_year()
	return report


func load_year() -> String:
	if not FileAccess.file_exists(save_path):
		return "msg.no_save"
	var result: Dictionary = _read_year()
	last_save_error = result["error"]
	if not last_save_error.is_empty():
		return last_save_error
	_replace(result["state"])
	undo_plans.clear()
	redo_plans.clear()
	return ""


func checkpoint_year() -> String:
	var path: String = ProjectSettings.globalize_path(save_path).simplify_path()
	for protected: String in [SaveIO.DEFAULT_PATH, DailySession.DAILY_PATH, YearSession.YEAR_PATH]:
		if path == ProjectSettings.globalize_path(protected).simplify_path():
			last_save_error = "msg.save_failed"
			return last_save_error
	if not TransportCheckpoint.valid(model()):
		last_save_error = "msg.save_failed"
		return last_save_error
	if FileAccess.file_exists(save_path):
		var old: Dictionary = _read_year()
		if not String(old["error"]).is_empty():
			last_save_error = old["error"]
			return last_save_error
	var temporary: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_save_error = "msg.save_failed"
		return last_save_error
	file.store_string(JSON.stringify(TransportCheckpoint.envelope(model()), "", true, true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), path)
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	last_save_error = "" if error == OK else "msg.save_failed"
	return last_save_error


func _read_year() -> Dictionary:
	var bad: Dictionary = {"error": "msg.save_corrupt", "state": {}}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {"error": "msg.save_failed", "state": {}}
	var length: int = file.get_length()
	if length > 2 * 1024 * 1024:
		return bad
	var bytes: PackedByteArray = file.get_buffer(length)
	if bytes.size() != length or not SaveIO._valid_utf8(bytes):
		return bad
	var parser: JSON = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return bad
	return TransportCheckpoint.decode(parser.data)
