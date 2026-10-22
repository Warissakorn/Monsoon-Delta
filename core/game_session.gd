class_name GameSession
extends RefCounted
## A playable run and its durable checkpoint. GameFlow stays persistence-free
## so simulations, the sandbox and previews cannot overwrite a player's run.

var state: GameState
var save_path: String = SaveIO.DEFAULT_PATH
var last_save_error: String = ""
var last_harvest_food_by_tile: Dictionary = {}
var _turn_history: Array[Dictionary] = []


func start(cfg: Dictionary) -> String:
	var next: GameState = GameFlow.new_game(cfg)
	if next == null:
		return "msg.new_game_failed"
	state = next
	_turn_history.clear()
	last_harvest_food_by_tile.clear()
	checkpoint()
	return ""


func load_game() -> String:
	var result: Dictionary = SaveIO.load_game(save_path)
	var error: String = result["error"]
	if not error.is_empty():
		last_save_error = error
		return error
	if result["state"] == null:
		return "msg.no_save"
	state = result["state"]
	_turn_history.clear()
	last_harvest_food_by_tile.clear()
	last_save_error = ""
	return ""


func apply(cmd: Command) -> String:
	if state == null:
		return "err.phase"
	if cmd == null:
		return "err.unknown"
	var error: String = GameFlow.apply_command(state, cmd)
	if error.is_empty():
		checkpoint()
	return error


func undo() -> bool:
	if state == null or state.phase != C.Phase.PLANNING or state.undo.is_empty():
		return false
	# Undo returns a replacement model. Keep the remaining live history stacks;
	# saving intentionally serializes neither its snapshots nor its identity.
	state = GameFlow.undo(state)
	checkpoint()
	return true


func redo() -> bool:
	if state == null or state.phase != C.Phase.PLANNING or state.redo.is_empty():
		return false
	state = GameFlow.redo(state)
	checkpoint()
	return true


func advance_turn() -> TurnReport:
	last_harvest_food_by_tile.clear()
	if state == null:
		return null
	var year: int = state.year
	var turn: int = state.turn
	var season: int = state.season()
	var report: TurnReport = GameFlow.end_turn(state)
	if report != null:
		if state.phase == C.Phase.HARVEST:
			last_harvest_food_by_tile = Harvest.paddy_food_by_tile(state)
		# Reports describe the turn just resolved, while state may already show
		# the next turn. Keep only player-facing results, without water snapshots.
		var results: Dictionary = {
			"inflow": report.inflow,
			"destroyed": report.destroyed,
			"paddies_died": report.paddies_died,
			"paddy_gains": report.paddy_gains,
			"fish_food": report.fish_food,
			"hall_wet": report.hall_wet,
			"dry_paddy_water_used": report.dry_paddy_water_used,
		}
		if not report.brace_results.is_empty():
			results["brace_results"] = report.brace_results.duplicate(true)
		if not report.moisture_changes.is_empty():
			results["moisture_changes"] = report.moisture_changes.duplicate(true)
		_turn_history.append({
			"year": year,
			"turn": turn,
			"season": season,
			"report": results.duplicate(true),
			"harvest": state.harvest_report.duplicate(true) if state.phase == C.Phase.HARVEST else {},
			# Harvest can decide a win or population loss after TurnReport ends.
			"outcome": state.outcome,
		})
		while _turn_history.size() > state.target_years() * C.TURNS_PER_YEAR:
			_turn_history.pop_front()
		checkpoint()
	return report


func turn_history() -> Array[Dictionary]:
	# Runtime history belongs to this session, outside the durable GameState.
	# Callers may inspect or format a result without changing recorded facts.
	return _turn_history.duplicate(true)


func continue_year() -> bool:
	if state == null or state.phase != C.Phase.HARVEST:
		return false
	GameFlow.continue_after_harvest(state)
	checkpoint()
	return true


func checkpoint() -> String:
	# SaveIO rejects null too, but keep an empty session away from persistence.
	last_save_error = "msg.save_failed" if state == null else SaveIO.save(state, save_path)
	return last_save_error
