class_name YearSession
extends GameSession
## Durable full-year run; normal and prototype checkpoints keep their own paths.

const YEAR_PATH: String = "user://year365.json"
var year: Dictionary = {}
var undo_plans: Array[Dictionary] = []
var redo_plans: Array[Dictionary] = []


func _init() -> void:
	save_path = YEAR_PATH


func start_year(seed_value: int = 42, goal: String = "none", project: String = "") -> String:
	var next: Dictionary = YearGame.new_game(seed_value, goal) if project.is_empty() else YearGame.new_expanded(seed_value, goal, project)
	if next.is_empty():
		return "msg.new_game_failed"
	year = next
	undo_plans.clear()
	redo_plans.clear()
	return checkpoint_year()


func edit_year(action: String, id: String = "", tile: int = -1, batches: int = 1, repeat: bool = false, direction: int = 0, stop_at: int = 0, reserve: int = 0) -> String:
	if year.is_empty():
		return "year.error.order"
	var copy: Dictionary = year.duplicate(true)
	var error: String = "year.error.order"
	match action:
		"order": error = YearGame.order(copy, id, tile, batches, repeat, direction, stop_at, reserve)
		"pause": error = YearGame.edit_job(copy, tile, false)
		"cancel": error = YearGame.edit_job(copy, tile, true)
		"learn": error = YearGame.learn(copy, id)
		"gate": error = YearGame.toggle_gate(copy, tile)
		"project": error = YearExpansion.choose_project(copy, id)
	if not error.is_empty():
		return error
	undo_plans.append(year.duplicate(true))
	if undo_plans.size() > 200:
		undo_plans.pop_front()
	redo_plans.clear()
	year = copy
	checkpoint_year()
	return ""


func undo_year() -> bool:
	if undo_plans.is_empty():
		return false
	redo_plans.append(year.duplicate(true))
	year = undo_plans.pop_back()
	checkpoint_year()
	return true


func redo_year() -> bool:
	if redo_plans.is_empty():
		return false
	undo_plans.append(year.duplicate(true))
	year = redo_plans.pop_back()
	checkpoint_year()
	return true


func advance_year(days: int) -> Dictionary:
	if year.is_empty():
		return {"days": 0, "events": []}
	var report: Dictionary = YearGame.advance(year, days)
	if int(report["days"]) > 0:
		undo_plans.clear()
		redo_plans.clear()
		checkpoint_year()
	return report


func load_year() -> String:
	if not FileAccess.file_exists(save_path):
		return "msg.no_save"
	var result: Dictionary = _read_year()
	if not String(result["error"]).is_empty():
		last_save_error = result["error"]
		return last_save_error
	year = result["state"]
	undo_plans.clear()
	redo_plans.clear()
	last_save_error = ""
	return ""


func checkpoint_year() -> String:
	var path: String = ProjectSettings.globalize_path(save_path).simplify_path()
	for protected: String in [SaveIO.DEFAULT_PATH, DailySession.DAILY_PATH]:
		if path == ProjectSettings.globalize_path(protected).simplify_path():
			last_save_error = "msg.save_failed"
			return last_save_error
	if not YearCheckpoint.valid(year):
		last_save_error = "msg.save_failed"
		return last_save_error
	if FileAccess.file_exists(save_path):
		var previous: Dictionary = _read_year()
		if not String(previous["error"]).is_empty():
			last_save_error = previous["error"]
			return last_save_error
	var temporary: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_save_error = "msg.save_failed"
		return last_save_error
	file.store_string(JSON.stringify(YearCheckpoint.envelope(year), "", true, true))
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
	if length > 1024 * 1024:
		return bad
	var bytes: PackedByteArray = file.get_buffer(length)
	if bytes.size() != length or not SaveIO._valid_utf8(bytes):
		return bad
	var parser: JSON = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return bad
	return YearCheckpoint.decode(parser.data)
