class_name UndoStack
extends RefCounted
## Turn-local snapshots. History never becomes part of a game save or preview.

const MAX_SIZE: int = 200

var _entries: Array[Dictionary] = []


func push(snapshot: Dictionary) -> void:
	_entries.append(snapshot.duplicate(true))
	if _entries.size() > MAX_SIZE:
		_entries.pop_front()


func pop() -> Dictionary:
	if _entries.is_empty():
		return {}
	return _entries.pop_back()


func clear() -> void:
	_entries.clear()


func size() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty()


func snapshots() -> Array[Dictionary]:
	return _entries.duplicate(true)
