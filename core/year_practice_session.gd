class_name YearPracticeSession
extends YearSession
## A real daily year with memory-only lesson progress. Never reads/writes checkpoints.
const STEPS: Array[String] = ["assign", "undo", "redo", "produce", "pause", "resume", "housing"]
var step: int = 0
var forage_tile: int = -1
var failed: bool = false
var initial_housing: int = 0


func begin() -> void:
	year = YearGame.new_campaign(42, "none", "food", "farmer", 0, true, true)
	step = 0
	forage_tile = -1
	failed = false
	initial_housing = YearGame.housing(year)
	daily_history.clear()
	visual_reports.clear()
	undo_plans.clear()
	redo_plans.clear()
	last_save_error = ""


func completed() -> bool:
	return step >= STEPS.size()


func target() -> int:
	if step >= 6:
		return YearPlanner.target(year, "build_house")
	return forage_tile if forage_tile >= 0 else YearPlanner.target(year, "forage")


func guided_job() -> Dictionary:
	for job: Dictionary in year.get("jobs", []):
		if int(job["tile"]) == forage_tile and job["id"] == "forage":
			return job.duplicate(true)
	return {}


func edit_year(action: String, id: String = "", tile: int = -1, batches: int = 1, repeat: bool = false, direction: int = 0, stop_at: int = 0, reserve: int = 0) -> String:
	if action == "cancel" and tile == forage_tile and step < 6:
		return "yearpractice.keep_work"
	var error: String = super.edit_year(action, id, tile, batches, repeat, direction, stop_at, reserve)
	if not error.is_empty():
		return error
	if step == 0 and action == "order" and id == "forage" and repeat:
		forage_tile = tile
		step = 1
	elif action == "pause" and tile == forage_tile:
		var job: Dictionary = guided_job()
		if step == 4 and not job.is_empty() and job["paused"]:
			step = 5
		elif step == 5 and not job.is_empty() and not job["paused"]:
			step = 6
	return ""


func undo_year() -> bool:
	var changed: bool = super.undo_year()
	if changed and step == 1 and guided_job().is_empty():
		step = 2
	return changed


func redo_year() -> bool:
	var changed: bool = super.redo_year()
	if changed and step == 2 and not guided_job().is_empty():
		step = 3
	return changed


func advance_year(days: int) -> Dictionary:
	if step < 3 or completed() or failed:
		return {"days": 0, "events": []}
	var result: Dictionary = super.advance_year(days)
	if step == 3:
		for visual: TurnReport in visual_reports:
			for job: Dictionary in visual.year_jobs_completed:
				if job["id"] == "forage" and int(job["tile"]) == forage_tile:
					step = 4
	if step == 6 and YearGame.housing(year) > initial_housing:
		step = STEPS.size()
	failed = year["outcome"] != "running" and not completed()
	return result


func start_year(_seed: int = 42, _goal: String = "none", _project: String = "") -> String:
	return "yearpractice.restart_only"


func start_campaign(_seed: int, _goal: String, _project: String, _leader: String = "farmer", _difficulty: int = 0, _classic: bool = false, _heritage: bool = false) -> String:
	return "yearpractice.restart_only"


func checkpoint_year() -> String:
	last_save_error = ""
	return ""


func load_year() -> String:
	return "msg.no_save"


func _read_year() -> Dictionary:
	return {"error": "msg.no_save", "state": {}}


# Block the inherited normal-game I/O routes too, even if called through GameSession.
func start(_cfg: Dictionary) -> String:
	return "yearpractice.restart_only"


func load_game() -> String:
	return "msg.no_save"


func checkpoint() -> String:
	return checkpoint_year()
