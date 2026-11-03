class_name DailySession
extends GameSession
## GameSession specialization: prototype I/O stays outside deterministic rules.
## Normal GameState and SaveIO v1-v6 are deliberately not used by this fixture.

const DAILY_PATH: String = "user://daily-production-prototype.json"
var daily: Dictionary = {}
var _undo_daily: Array[Dictionary] = []
var _redo_daily: Array[Dictionary] = []


func _init() -> void:
	save_path = DAILY_PATH


func start_prototype() -> String:
	daily = DailyProduction.new_state()
	_undo_daily.clear()
	_redo_daily.clear()
	return checkpoint_daily()


func load_prototype() -> String:
	if not FileAccess.file_exists(save_path):
		return "msg.no_save"
	var result: Dictionary = _read_daily()
	if not String(result["error"]).is_empty():
		last_save_error = result["error"]
		return last_save_error
	daily = result["state"]
	_undo_daily.clear()
	_redo_daily.clear()
	last_save_error = ""
	return ""


func edit(action: String, id: String, batches: int = 1) -> String:
	if daily.is_empty():
		return "daily.error.order"
	var copy: Dictionary = daily.duplicate(true)
	var error: String = "daily.error.order"
	match action:
		"order": error = DailyProduction.order(copy, id, batches)
		"pause": error = DailyProduction.pause_job(copy, id)
		"cancel": error = DailyProduction.cancel_job(copy, id)
	if not error.is_empty():
		return error
	_undo_daily.append(daily.duplicate(true))
	if _undo_daily.size() > 200:
		_undo_daily.pop_front()
	_redo_daily.clear()
	daily = copy
	checkpoint_daily()
	return ""


func undo_daily() -> bool:
	if _undo_daily.is_empty():
		return false
	_redo_daily.append(daily.duplicate(true))
	daily = _undo_daily.pop_back()
	checkpoint_daily()
	return true


func redo_daily() -> bool:
	if _redo_daily.is_empty():
		return false
	_undo_daily.append(daily.duplicate(true))
	daily = _redo_daily.pop_back()
	checkpoint_daily()
	return true


func advance_days(days: int) -> Dictionary:
	if daily.is_empty():
		return {"days": 0, "events": []}
	var report: Dictionary = DailyProduction.advance(daily, days)
	if int(report["days"]) > 0:
		_undo_daily.clear()
		_redo_daily.clear()
		checkpoint_daily()
	return report


func checkpoint_daily() -> String:
	# No caller may point this specialization at the player's normal checkpoint.
	if ProjectSettings.globalize_path(save_path).simplify_path() == ProjectSettings.globalize_path(SaveIO.DEFAULT_PATH).simplify_path() or daily.is_empty():
		last_save_error = "msg.save_failed"
		return last_save_error
	var checked: Dictionary = DailyCheckpoint.decode(DailyCheckpoint.envelope(daily))
	if not String(checked["error"]).is_empty():
		last_save_error = checked["error"]
		return last_save_error
	# Preserve corrupt/unsupported files even when a restart is requested.
	if FileAccess.file_exists(save_path):
		var previous: Dictionary = _read_daily()
		if not String(previous["error"]).is_empty():
			last_save_error = previous["error"]
			return last_save_error
	var temporary: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_save_error = "msg.save_failed"
		return last_save_error
	file.store_string(JSON.stringify(DailyCheckpoint.envelope(daily)))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(save_path))
	last_save_error = "" if error == OK else "msg.save_failed"
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return last_save_error


func _read_daily() -> Dictionary:
	var bad: Dictionary = {"error": "msg.save_corrupt", "state": {}}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {"error": "msg.save_failed", "state": {}}
	if file.get_length() > 65536:
		return bad
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	if not SaveIO._valid_utf8(bytes):
		return bad
	var parser: JSON = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return bad
	return DailyCheckpoint.decode(parser.data)
