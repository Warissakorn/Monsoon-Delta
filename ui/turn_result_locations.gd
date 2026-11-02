class_name TurnResultLocations
extends RefCounted
## Locations come from committed reports, never from the current board/forecast.


static func collect(entry: Dictionary) -> Array[Dictionary]:
	var locations: Dictionary = {}
	var report: Dictionary = entry["report"]
	for item: Dictionary in report["destroyed"]:
		var building: String = _tr("building." + C.enum_name(C.Building, int(item["building"])))
		_add(locations, item["coord"], _tr("feedback.destroyed") % building)
	for coord: Vector2i in report["paddies_died"]:
		_add(locations, coord, _tr("feedback.rice_lost"))
	for coord: Vector2i in report["paddy_gains"]:
		_add(locations, coord, _tr("feedback.rice_gain"))
		_add(locations, coord, _tr("history.yield_note"))
	for coord: Vector2i in report.get("fish_food_by_tile", {}):
		_add(locations, coord, _tr("history.map_fish") % int(report["fish_food_by_tile"][coord]))
	var result: Array[Dictionary] = []
	for coord: Vector2i in locations:
		result.append({"coord": coord, "lines": locations[coord]})
	return result


static func _add(locations: Dictionary, coord: Vector2i, text: String) -> void:
	if not locations.has(coord):
		locations[coord] = PackedStringArray()
	var lines: PackedStringArray = locations[coord]
	lines.append(text)
	locations[coord] = lines


static func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))
