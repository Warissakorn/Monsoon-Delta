class_name RiverSchoolSession
extends GameSession
## Turn-local lesson metadata follows successful commands and the same bounded
## Undo/Redo history as GameState, without changing normal saves or snapshots.

var _targets: Array[Vector2i] = []
var _pending_removals: Array[Vector2i] = []
var _undo_removals: Array[Array] = []
var _redo_removals: Array[Array] = []


func _init(targets: Array[Vector2i] = []) -> void:
	_targets = targets.duplicate()


func target_removals() -> Array[Vector2i]:
	return _pending_removals.duplicate()


func apply(cmd: Command) -> String:
	var before: Array[Vector2i] = _pending_removals.duplicate()
	var removed: bool = cmd != null and cmd.id == "demolish" and cmd.coord in _targets
	var error: String = super.apply(cmd)
	if not error.is_empty() or _targets.is_empty():
		return error
	_undo_removals.append(before)
	if _undo_removals.size() > UndoStack.MAX_SIZE:
		_undo_removals.pop_front()
	_redo_removals.clear()
	if removed and cmd.coord not in _pending_removals:
		_pending_removals.append(cmd.coord)
	return error


func undo() -> bool:
	if not super.undo():
		return false
	if not _targets.is_empty():
		_redo_removals.append(_pending_removals.duplicate())
		if _redo_removals.size() > UndoStack.MAX_SIZE:
			_redo_removals.pop_front()
		_pending_removals.assign(_undo_removals.pop_back())
	return true


func redo() -> bool:
	if not super.redo():
		return false
	if not _targets.is_empty():
		_undo_removals.append(_pending_removals.duplicate())
		if _undo_removals.size() > UndoStack.MAX_SIZE:
			_undo_removals.pop_front()
		_pending_removals.assign(_redo_removals.pop_back())
	return true


func advance_turn() -> TurnReport:
	var report: TurnReport = super.advance_turn()
	if report != null:
		_pending_removals.clear()
		_undo_removals.clear()
		_redo_removals.clear()
	return report
