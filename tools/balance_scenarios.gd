class_name BalanceScenarios
extends RefCounted
## Validated, absolute modifier overrides for balance experiments.
## Water overrides also affect MapGen's rejection sampling, so the same seed
## can produce different boards between scenarios. Sea levels remain nonnegative
## because they are copied to Tile.water. IDs must also be portable file stems.

const MAX_ABS_MOD: float = 1000000.0
const FRACTIONAL_MODS: Array[String] = [
	"flow_rate", "sea_level_dry", "sea_level_rain", "dry_inflow",
	"forest_absorb", "sapling_absorb", "evaporation_dry",
	"evaporation_multiplier", "wheel_amount", "rain_inflow_multiplier",
	"year5_inflow_multiplier", "forecast_range_multiplier", "storm_last_turn_add",
	"demolish_refund_fraction", "fish_trap_multiplier",
	"dry_paddy_reservoir_min", "dry_paddy_water_use", "rot_fraction", "event_chance",
]
const SIGNED_MODS: Array[String] = [
	"harvest_paddy_bonus", "jasmine_bonus",
	"fertile_silt_bonus", "home_capacity_bonus", "season_first_turn_labor",
	"rain_turn_labor", "year_start_food", "year_start_wood",
]
const POSITIVE_MODS: Array[String] = [
	"food_per_person", "food_per_growth", "home_capacity", "start_population",
	"card_offer_count", "dig_amount", "fill_amount", "reservoir_depth",
	"water_iterations",
]
const FRACTION_MODS: Array[String] = [
	"rot_fraction", "demolish_refund_fraction", "event_chance",
]
const FLAG_MODS: Array[String] = [
	"reveal_all_inflow", "unlock_waterwheel", "unlock_raft_house",
]

const RESERVED_IDS: Array[String] = [
	"con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5",
	"com6", "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4",
	"lpt5", "lpt6", "lpt7", "lpt8", "lpt9",
]


static func load_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Cannot read scenario file '%s': %s" % [
			path, error_string(FileAccess.get_open_error()),
		])
	var result: Dictionary = parse_text(file.get_as_text())
	if not String(result["error"]).is_empty():
		result["error"] = "Scenario file '%s': %s" % [path, result["error"]]
	return result


static func parse_text(source: String) -> Dictionary:
	var parser: JSON = JSON.new()
	if parser.parse(source) != OK:
		return _failure("Invalid scenario JSON at line %d: %s" % [
			parser.get_error_line(), parser.get_error_message(),
		])
	return validate(parser.data)


static func validate(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return _failure("Scenario root must be an object.")
	var root: Dictionary = data as Dictionary
	for key in root:
		if key not in ["version", "scenarios"]:
			return _failure("Unknown scenario root key '%s'." % str(key))
	if not root.has("version") or not _is_number(root["version"]) or root["version"] != 1:
		return _failure("Scenario version must be 1.")
	if not root.has("scenarios") or not root["scenarios"] is Array:
		return _failure("Scenario root must contain a scenarios array.")
	var entries: Array = root["scenarios"] as Array
	if entries.is_empty():
		return _failure("Scenario array must not be empty.")
	var defaults: Dictionary = DataDB.balance().get("mods_default", {}) as Dictionary
	if defaults.is_empty():
		return _failure("Balance defaults contain no modifier keys.")
	var id_pattern: RegEx = RegEx.new()
	id_pattern.compile("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}\\z")
	var seen: Dictionary = {}
	var scenarios: Array[Dictionary] = []
	for index in entries.size():
		if not entries[index] is Dictionary:
			return _failure("Scenario %d must be an object." % (index + 1))
		var entry: Dictionary = entries[index] as Dictionary
		var context: String = "Scenario %d" % (index + 1)
		if entry.get("id") is String:
			context = "Scenario '%s'" % entry["id"]
		for key in entry:
			if key not in ["id", "mods"]:
				return _failure("%s: unknown key '%s'." % [context, str(key)])
		if not entry.get("id") is String or id_pattern.search(entry["id"]) == null:
			return _failure("%s: id must match [a-zA-Z0-9][a-zA-Z0-9_-]{0,63}." % context)
		var id: String = entry["id"]
		var folded_id: String = id.to_lower()
		if folded_id in RESERVED_IDS:
			return _failure("%s: id is a reserved filename." % context)
		if seen.has(folded_id):
			return _failure("%s: duplicate id (case-insensitive)." % context)
		if not entry.get("mods") is Dictionary:
			return _failure("%s: mods must be an object." % context)
		var mods: Dictionary = {}
		for key in entry["mods"]:
			if not key is String:
				return _failure("%s: modifier keys must be strings." % context)
			var value: Variant = entry["mods"][key]
			var error: String = _validate_mod(key, value, defaults)
			if not error.is_empty():
				return _failure("%s, modifier '%s': %s" % [context, key, error])
			mods[key] = float(value) if key in FRACTIONAL_MODS else int(value)
		seen[folded_id] = true
		scenarios.append({"id": id, "mods": mods})
	return {"error": "", "scenarios": scenarios}


static func _validate_mod(key: String, value: Variant, defaults: Dictionary) -> String:
	if not defaults.has(key):
		return "unknown modifier."
	if not _is_number(value):
		return "must be a number (booleans and strings are not accepted)."
	var number: float = float(value)
	if not is_finite(number):
		return "must be finite."
	if absf(number) > MAX_ABS_MOD:
		return "absolute value must not exceed 1000000."
	if key not in FRACTIONAL_MODS and number != floorf(number):
		return "must be an integer."
	if key in FLAG_MODS and number != 0.0 and number != 1.0:
		return "must be 0 or 1."
	if key == "flow_rate" and (number < 0.05 or number > 0.9):
		return "must be between 0.05 and 0.9."
	if key in FRACTION_MODS and (number < 0.0 or number > 1.0):
		return "must be between 0 and 1."
	if key in POSITIVE_MODS and number < 1.0:
		return "must be at least 1."
	if key == "water_iterations" and number > 1000.0:
		return "must not exceed 1000."
	if key not in SIGNED_MODS and number < 0.0:
		return "must not be negative."
	return ""


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _failure(message: String) -> Dictionary:
	var scenarios: Array[Dictionary] = []
	return {"error": message, "scenarios": scenarios}
