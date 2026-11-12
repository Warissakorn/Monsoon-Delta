class_name YearLedger
extends RefCounted
## Actual daily receipts. Transient: never checkpointed or reconstructed from a later board.

static func snapshot(s: Dictionary) -> Dictionary:
	var result: Dictionary = s["resources"].duplicate(true)
	result.merge({"people": int(s["population"]), "labor": int(s["population"]) - YearGame.workers(s), "housing": YearGame.housing(s), "knowledge": int(s["knowledge"])})
	return result


static func record(report: TurnReport, s: Dictionary, before: Dictionary, cause: String, index: int = -1) -> void:
	if report == null:
		return
	var after: Dictionary = snapshot(s)
	var delta: Dictionary = {}
	for key: String in before:
		if int(after[key]) != int(before[key]):
			delta[key] = int(after[key]) - int(before[key])
	if not delta.is_empty():
		var entry: Dictionary = {"cause": cause, "tile": index, "delta": delta}
		if index >= 0:
			var tile: Dictionary = s["board"]["tiles"][index]
			entry["coord"] = Vector2i(int(tile["q"]), int(tile["r"]))
		report.year_ledger["causes"].append(entry)


static func fact(report: TurnReport, s: Dictionary, index: int, kind: String, before: Variant, after: Variant) -> void:
	if report == null:
		return
	var tile: Dictionary = s["board"]["tiles"][index]
	report.year_ledger["locations"].append({"tile": index, "coord": Vector2i(int(tile["q"]), int(tile["r"])), "kind": kind, "before": before, "after": after, "site": String(s["structures"][index]) if not String(s["structures"][index]).is_empty() else String(tile["feature"])})


static func begin(report: TurnReport, s: Dictionary) -> void:
	if report != null:
		report.year_ledger = {"from_day": int(s["day"]), "before": snapshot(s), "causes": [], "locations": []}


static func finish(report: TurnReport, s: Dictionary, events: Array) -> void:
	if report == null:
		return
	var entry: Dictionary = report.year_ledger
	entry.merge({"day": int(s["day"]), "after": snapshot(s), "events": events.duplicate(), "outcome": String(s["outcome"]), "delta": {}})
	for key: String in entry["before"]:
		entry["delta"][key] = int(entry["after"][key]) - int(entry["before"][key])
