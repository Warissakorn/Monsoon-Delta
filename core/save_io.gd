class_name SaveIO
extends RefCounted
## Durable checkpoints for the implemented plains game. Validation happens
## before deserialization so malformed files never reach typed model loops.

const DEFAULT_PATH: String = "user://save.json"
const MAX_FILE_BYTES: int = 1024 * 1024
const MAX_JSON_INTEGER: int = 9007199254740991
# A checkpoint is normally about 20 KiB and uses 20 simulation iterations.
# Bound loaded work as well as file size, rather than trusting a modifier that
# could otherwise make opening a save allocate or simulate without a limit.
const MAX_WATER_ITERATIONS: int = 1000
const STATE_FIELDS: Array[String] = [
	"version", "seed", "map_type", "leader", "difficulty", "is_daily", "is_tutorial",
	"tiles", "year", "turn", "phase", "population", "food", "wood", "labor", "labor_max",
	"cards", "card_offer", "pending_event", "year_mods", "forecast_min", "forecast_max",
	"rain_inflows", "rng_seed", "rng_state", "stats", "outcome", "harvest_report", "final_score",
]
const RUN_FIELDS: Array[String] = ["run_mode", "village_goal", "goal_achieved_year"]
const TILE_FIELDS: Array[String] = [
	"q", "r", "elevation", "water", "feature", "building", "gate_open", "wheel_dir",
	"is_source", "is_sea", "is_river", "paddy_yield", "paddy_dead", "paddy_rain_turns", "start_house",
]
const STAT_COUNTS: Array[String] = [
	"houses_lost", "paddies_lost", "max_population", "food_produced", "reached_year",
]
const HARVEST_COUNTS: Array[String] = [
	"paddy_food", "eaten", "left_hunger", "left_housing", "born", "spoiled", "food_after", "population_after",
]


static func save(state: GameState, path: String = DEFAULT_PATH) -> String:
	if state == null or path.is_empty():
		return "msg.save_failed"
	# Debug/tutorial play must leave an existing normal run checkpoint alone.
	if state.is_tutorial:
		return ""
	if state.ruleset not in GameState.RULESETS:
		return "msg.save_unsupported"
	if state.phase == C.Phase.GAME_OVER:
		return delete_save(path)
	if not _can_serialize(state):
		return "msg.save_failed"
	var data: Dictionary = state.to_dict()
	if not _valid_state(data):
		return "msg.save_failed"
	var restored: GameState = GameState.from_dict(data)
	if not _safe_mods(restored):
		return "msg.save_failed"
	# Keep legacy runs on their original schema. Visual history needs version 3
	# so an older client cannot silently discard building ages or development.
	var envelope_version: int = 2
	if state.has_moisture():
		envelope_version = 5
	elif state.has_bracing():
		envelope_version = 4
	elif data.has("settlement_progress"):
		envelope_version = 3
	elif data["run_mode"] == "classic" and data["village_goal"] == "none":
		envelope_version = 1
		for field: String in RUN_FIELDS:
			data.erase(field)
	var envelope: Dictionary = {
		"format": "monsoon_save", "version": envelope_version, "state": data, "float64": _encode_float64(data),
	}
	var bytes: PackedByteArray = JSON.stringify(envelope, "", true, true).to_utf8_buffer()
	if bytes.size() > MAX_FILE_BYTES:
		return "msg.save_failed"
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "msg.save_failed"
	file.store_buffer(bytes)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return "msg.save_failed"
	# Never delete/move the good destination first. If replacement fails, the
	# previous checkpoint remains readable and the caller can report the error.
	var result: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)
	)
	if result != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return "msg.save_failed"
	return ""


static func load_game(path: String = DEFAULT_PATH) -> Dictionary:
	if path.is_empty():
		return _result(null, "msg.save_failed")
	if not FileAccess.file_exists(path):
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			return _result(null, "msg.save_failed")
		return _result(null, "")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _result(null, "msg.save_failed")
	var length: int = file.get_length()
	if length > MAX_FILE_BYTES:
		file.close()
		return _corrupt(path)
	var bytes: PackedByteArray = file.get_buffer(length)
	var read_error: Error = file.get_error()
	file.close()
	if bytes.size() != length or read_error not in [OK, ERR_FILE_EOF]:
		return _result(null, "msg.save_failed")
	# get_string_from_utf8 logs engine errors for invalid byte sequences; check
	# them explicitly so a corrupt user file produces only the localized result.
	if not _valid_utf8(bytes):
		return _corrupt(path)
	var parser: JSON = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return _corrupt(path)
	var envelope: Variant = parser.data
	if not envelope is Dictionary:
		return _corrupt(path)
	if not envelope.get("format") is String or envelope["format"] != "monsoon_save" or not _integer(envelope.get("version"), 1):
		return _corrupt(path)
	# A future build's save is unsupported, not corrupt. Preserve it for that
	# build instead of deleting progress we cannot interpret.
	if int(envelope["version"]) > 5:
		return _result(null, "msg.save_unsupported")
	if not envelope.get("state") is Dictionary:
		return _corrupt(path)
	var data: Dictionary = envelope["state"]
	if data.get("ruleset") is String and data["ruleset"] not in GameState.RULESETS:
		return _result(null, "msg.save_unsupported")
	if not _valid_state(data):
		return _corrupt(path)
	var envelope_version: int = int(envelope["version"])
	if envelope_version == 5:
		if data.get("ruleset") not in ["moisture_v1", "bracing_moisture_v1"] or not _has_fields(data, RUN_FIELDS):
			return _corrupt(path)
	elif envelope_version == 4:
		if data.get("ruleset") != "bracing_v1" or not _has_fields(data, RUN_FIELDS):
			return _corrupt(path)
	elif data.has("ruleset"):
		return _corrupt(path)
	if envelope_version == 3:
		if not _has_fields(data, RUN_FIELDS) or not data.has("settlement_progress"):
			return _corrupt(path)
	elif envelope_version not in [4, 5] and data.has("settlement_progress"):
		return _corrupt(path)
	if envelope_version == 2:
		if not _has_fields(data, RUN_FIELDS):
			return _corrupt(path)
	elif envelope_version == 1 and (data.get("run_mode", "classic") != "classic" or data.get("village_goal", "none") != "none"):
		return _corrupt(path)
	# Godot's decimal JSON reader can differ by a few ULPs even when stringify
	# uses full precision. All versions therefore require this exact IEEE-754
	# companion; its hex encodes eight little-endian bytes, never object data.
	if not _restore_float64(envelope["state"], envelope.get("float64")) or not _valid_state(envelope["state"]):
		return _corrupt(path)
	var state: GameState = GameState.from_dict(envelope["state"])
	if not _safe_mods(state):
		return _corrupt(path)
	# from_dict rebuilds index/mods and starts with an empty UndoStack. Do not
	# call begin_turn/start_year/harvest here: loading must not apply effects twice.
	return _result(state, "")


static func has_save(path: String = DEFAULT_PATH) -> bool:
	# A non-mutating presence check; load_game owns validation and error reporting.
	return FileAccess.file_exists(path)


static func delete_save(path: String = DEFAULT_PATH) -> String:
	if path.is_empty():
		return "msg.save_failed"
	if not FileAccess.file_exists(path):
		return "msg.save_failed" if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)) else ""
	var result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return "" if result == OK else "msg.save_failed"


static func _result(state: GameState, error: String) -> Dictionary:
	return {"state": state, "error": error}


static func _corrupt(path: String) -> Dictionary:
	# Failure to remove an unreadable/corrupt file does not hide the diagnosis.
	delete_save(path)
	return _result(null, "msg.save_corrupt")


static func _can_serialize(state: GameState) -> bool:
	# to_dict reports unknown enums and recursively canonicalizes dictionaries.
	# Reject those unsafe inputs before calling it, without engine error output.
	if state.rng == null or state.phase not in [C.Phase.PLANNING, C.Phase.HARVEST]:
		return false
	if state.ruleset not in GameState.RULESETS:
		return false
	if state.outcome not in C.Outcome.values():
		return false
	for tile: Tile in state.tiles:
		if tile == null or tile.feature not in C.Feature.values() or tile.building not in C.Building.values():
			return false
		if tile.brace_turns < 0 or tile.brace_turns > 1:
			return false
		if tile.brace_turns != 0 and (not state.has_bracing() or state.phase != C.Phase.PLANNING or tile.building not in [C.Building.HOUSE, C.Building.STILT_HOUSE]):
			return false
		if tile.soil_moisture < 0 or tile.soil_moisture > 2:
			return false
		if tile.soil_moisture != 0 and (not state.has_moisture() or tile.feature != C.Feature.PADDY or tile.paddy_dead):
			return false
	return _valid_stats(state.stats, state.target_years()) and _valid_report(state.harvest_report, state.phase == C.Phase.HARVEST) and _valid_modifiers(state.year_mods)


static func _valid_state(data: Dictionary) -> bool:
	if not _has_fields(data, STATE_FIELDS) or not _integer(data["version"], 1, 1):
		return false
	var ruleset: Variant = data.get("ruleset", "legacy")
	if data.has("ruleset") and (not ruleset is String or ruleset not in GameState.RULESETS or ruleset == "legacy" or not _has_fields(data, RUN_FIELDS)):
		return false
	var bracing: bool = ruleset in ["bracing_v1", "bracing_moisture_v1"]
	var moisture: bool = ruleset in ["moisture_v1", "bracing_moisture_v1"]
	if not _valid_run_fields(data):
		return false
	var target_years: int = int(DataDB.balance()["run_modes"][data.get("run_mode", "classic")]["years"])
	for key: String in ["seed", "rng_seed", "rng_state"]:
		if not _decimal_int64(data[key]):
			return false
	if not data["map_type"] is String or data["map_type"] != "plains" or not data["leader"] is String:
		return false
	if not DataDB.balance()["leaders"].has(data["leader"]):
		return false
	if not _integer(data["difficulty"], 0, 10) or not _integer(data["year"], 1, target_years) or not _integer(data["turn"], 1, C.TURNS_PER_YEAR):
		return false
	for key: String in ["is_daily", "is_tutorial"]:
		if typeof(data[key]) != TYPE_BOOL:
			return false
	if data["is_tutorial"] or data["phase"] not in ["planning", "harvest"]:
		return false
	if data["outcome"] not in ["none", "win", "lose_population"]:
		return false
	if data["phase"] == "planning" and data["outcome"] != "none":
		return false
	if data["phase"] == "harvest" and int(data["turn"]) != C.TURNS_PER_YEAR:
		return false
	for key: String in ["population", "food", "wood", "labor", "labor_max", "final_score"]:
		if not _integer(data[key], 0):
			return false
	if data["labor"] > data["labor_max"]:
		return false
	# The implemented rules cannot resolve card/event payloads from later builds.
	for key: String in ["cards", "card_offer"]:
		if not data[key] is Array or not data[key].is_empty():
			return false
	if not data["pending_event"] is String or not data["pending_event"].is_empty():
		return false
	if not data["year_mods"] is Array or not _valid_modifiers(data["year_mods"]):
		return false
	if not _number(data["forecast_min"], 0.0) or not _number(data["forecast_max"], 0.0) or data["forecast_min"] > data["forecast_max"]:
		return false
	if not data["rain_inflows"] is Array or data["rain_inflows"].size() != C.TURNS_PER_YEAR - C.DRY_TURNS:
		return false
	for inflow: Variant in data["rain_inflows"]:
		if not _number(inflow, 0.0):
			return false
	if not data["stats"] is Dictionary or not _valid_stats(data["stats"], target_years):
		return false
	if data["stats"]["max_population"] < data["population"]:
		return false
	if data["stats"]["reached_year"] != data["year"] or data["final_score"] != 0:
		return false
	if not data["harvest_report"] is Dictionary or not _valid_report(data["harvest_report"], data["phase"] == "harvest"):
		return false
	if data["phase"] == "harvest":
		if data["harvest_report"]["food_after"] != data["food"] or data["harvest_report"]["population_after"] != data["population"]:
			return false
		if data["outcome"] == "win" and (int(data["year"]) != target_years or data["population"] == 0):
			return false
		if data["outcome"] == "lose_population" and data["population"] != 0:
			return false
		if data["outcome"] == "none" and (int(data["year"]) == target_years or data["population"] == 0):
			return false
	var coords: Array[Vector2i] = Hex.coords()
	if not data["tiles"] is Array or data["tiles"].size() != coords.size():
		return false
	for index: int in range(coords.size()):
		if not data["tiles"][index] is Dictionary or not _valid_tile(data["tiles"][index], coords[index]):
			return false
		var tile: Dictionary = data["tiles"][index]
		if bracing:
			if not tile.has("brace_turns") or not _integer(tile["brace_turns"], 0, 1):
				return false
			if tile["brace_turns"] != 0 and (data["phase"] != "planning" or tile["building"] not in ["house", "stilt_house"]):
				return false
		elif tile.has("brace_turns"):
			return false
		if moisture:
			if not tile.has("soil_moisture") or not _integer(tile["soil_moisture"], 0, 2):
				return false
			if tile["soil_moisture"] != 0 and (tile["feature"] != "paddy" or tile["paddy_dead"]):
				return false
		elif tile.has("soil_moisture"):
			return false
	return not data.has("settlement_progress") or _valid_settlement_progress(data)


static func _valid_settlement_progress(data: Dictionary) -> bool:
	var progress: Variant = data.get("settlement_progress")
	var fields: Array[String] = ["version", "condition", "evaluated_year", "candidate", "candidate_years", "buildings"]
	if not progress is Dictionary or progress.size() != fields.size() or not _has_fields(progress, fields):
		return false
	if not _integer(progress["version"], 1, 1):
		return false
	for field: String in ["condition", "candidate"]:
		if not progress[field] is String or progress[field] not in SettlementProgress.CONDITION_IDS:
			return false
	if not _integer(progress["evaluated_year"], 0, int(data["year"])) or not _integer(progress["candidate_years"], 0, 1):
		return false
	if progress["candidate_years"] == 0 and progress["candidate"] != progress["condition"]:
		return false
	if progress["candidate_years"] == 1 and progress["candidate"] == progress["condition"]:
		return false
	if not progress["buildings"] is Dictionary or progress["buildings"].size() > data["tiles"].size():
		return false
	var count: int = 0
	for tile: Dictionary in data["tiles"]:
		if tile["building"] == "none":
			continue
		count += 1
		var key: String = "%d,%d" % [int(tile["q"]), int(tile["r"])]
		var record: Variant = progress["buildings"].get(key)
		var record_fields: Array[String] = ["building", "built_year", "built_turn", "stage"]
		if not record is Dictionary or record.size() != record_fields.size() or not _has_fields(record, record_fields):
			return false
		if not record["building"] is String or record["building"] != tile["building"]:
			return false
		if not _integer(record["built_year"], 1, int(data["year"])) or not _integer(record["built_turn"], 1, C.TURNS_PER_YEAR):
			return false
		if record["built_year"] == data["year"] and record["built_turn"] > data["turn"]:
			return false
		if not _integer(record["stage"], 0, mini(2, int(data["year"]) - int(record["built_year"]))):
			return false
	return count == progress["buildings"].size()


static func _valid_run_fields(data: Dictionary) -> bool:
	var present: int = 0
	for field: String in RUN_FIELDS:
		if data.has(field):
			present += 1
	# Version 1 saves predate this triplet; migrate only an entirely absent set.
	if present == 0:
		return true
	if present != RUN_FIELDS.size():
		return false
	if not data["run_mode"] is String or data["run_mode"] not in ["classic", "long"] or not DataDB.balance()["run_modes"].has(data["run_mode"]):
		return false
	if not data["village_goal"] is String or data["village_goal"] not in ["none", "growth", "forest", "rice"] or not DataDB.balance()["village_goals"].has(data["village_goal"]):
		return false
	if not _integer(data["goal_achieved_year"], 0) or not _integer(data["year"], 1):
		return false
	if data["goal_achieved_year"] > data["year"]:
		return false
	return data["village_goal"] != "none" or data["goal_achieved_year"] == 0


static func _valid_tile(data: Dictionary, coord: Vector2i) -> bool:
	if not _has_fields(data, TILE_FIELDS):
		return false
	if not _integer(data["q"], coord.x, coord.x) or not _integer(data["r"], coord.y, coord.y):
		return false
	if not _integer(data["elevation"], -3, 4) or not _number(data["water"], 0.0):
		return false
	if not _enum_name(data["feature"], C.Feature) or not _enum_name(data["building"], C.Building):
		return false
	if data["building"] != "none" and data["feature"] != "none":
		return false
	for key: String in ["gate_open", "is_source", "is_sea", "is_river", "paddy_dead", "start_house"]:
		if typeof(data[key]) != TYPE_BOOL:
			return false
	if not _integer(data["wheel_dir"], -1, 5) or (data["building"] == "waterwheel" and data["wheel_dir"] < 0):
		return false
	for key: String in ["paddy_yield", "paddy_rain_turns"]:
		if not _integer(data[key], 0):
			return false
	return true


static func _valid_stats(data: Dictionary, target_years: int = C.YEARS) -> bool:
	if data.size() != STAT_COUNTS.size() + 1 or not _has_fields(data, STAT_COUNTS) or typeof(data.get("hall_ever_wet")) != TYPE_BOOL:
		return false
	for key: String in STAT_COUNTS:
		if not _integer(data[key], 1 if key == "reached_year" else 0, target_years if key == "reached_year" else MAX_JSON_INTEGER):
			return false
	return true


static func _valid_report(data: Dictionary, required: bool) -> bool:
	if data.is_empty():
		return not required
	if data.size() != HARVEST_COUNTS.size() or not _has_fields(data, HARVEST_COUNTS):
		return false
	for key: String in HARVEST_COUNTS:
		if not _integer(data[key], 0):
			return false
	return true


static func _valid_modifiers(data: Array) -> bool:
	var defaults: Dictionary = DataDB.balance()["mods_default"]
	for entry: Variant in data:
		if not entry is Dictionary or entry.size() != 3:
			return false
		if not entry.get("key") is String or not defaults.has(entry["key"]):
			return false
		if entry.get("op") not in ["add", "mul", "set"] or not _number(entry.get("value"), -float(MAX_JSON_INTEGER)):
			return false
	return true


static func _safe_mods(state: GameState) -> bool:
	for value: Variant in state.mods.values():
		if not _number(value, -float(MAX_JSON_INTEGER)):
			return false
	for key: String in [
		"sea_level_dry", "sea_level_rain", "wheel_amount", "dry_inflow", "forest_absorb",
		"sapling_absorb", "evaporation_dry", "evaporation_multiplier", "fish_trap_yield", "fish_trap_multiplier",
	]:
		if float(state.mods[key]) < 0.0:
			return false
	# Command prices are returned as Vector2i; their rounded positive values
	# must fit signed 32-bit components rather than wrapping into negative costs.
	for definition: Dictionary in CommandRules.DEFS.values():
		var labor_key: String = String(definition.get("labor", ""))
		var price_keys: Array[String] = []
		if labor_key in ["dig_labor", "fill_labor"]:
			price_keys.append(labor_key + "_dry")
			price_keys.append(labor_key + "_rain")
		elif not labor_key.is_empty():
			price_keys.append(labor_key)
		var wood_key: String = String(definition.get("wood", ""))
		if not wood_key.is_empty():
			price_keys.append(wood_key)
		for key: String in price_keys:
			if roundi(float(state.mods[key])) > 2147483647:
				return false
	var fish_food: float = roundf(float(state.mods["fish_trap_yield"])) * float(state.mods["fish_trap_multiplier"])
	if not _number(fish_food, 0.0):
		return false
	var iterations: Variant = state.mods.get("water_iterations")
	return _integer(iterations, 1, MAX_WATER_ITERATIONS)


static func _encode_float64(data: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"forecast_min": _float_hex(float(data["forecast_min"])),
		"forecast_max": _float_hex(float(data["forecast_max"])),
		"rain_inflows": [], "tile_water": [], "year_mod_values": [],
	}
	for value: Variant in data["rain_inflows"]:
		result["rain_inflows"].append(_float_hex(float(value)))
	for tile: Dictionary in data["tiles"]:
		result["tile_water"].append(_float_hex(float(tile["water"])))
	for modifier: Dictionary in data["year_mods"]:
		result["year_mod_values"].append(_float_hex(float(modifier["value"])))
	return result


static func _float_hex(value: float) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()


static func _restore_float64(data: Dictionary, bits: Variant) -> bool:
	if not bits is Dictionary or bits.size() != 5:
		return false
	for key: String in ["forecast_min", "forecast_max"]:
		var exact: Variant = _decode_float64(bits.get(key), data[key])
		if exact == null:
			return false
		data[key] = exact
	for pair: Array in [
		["rain_inflows", data["rain_inflows"].size()],
		["tile_water", data["tiles"].size()], ["year_mod_values", data["year_mods"].size()],
	]:
		if not bits.get(pair[0]) is Array or bits[pair[0]].size() != pair[1]:
			return false
	for index: int in range(data["rain_inflows"].size()):
		var exact: Variant = _decode_float64(bits["rain_inflows"][index], data["rain_inflows"][index])
		if exact == null:
			return false
		data["rain_inflows"][index] = exact
	for index: int in range(data["tiles"].size()):
		var exact: Variant = _decode_float64(bits["tile_water"][index], data["tiles"][index]["water"])
		if exact == null:
			return false
		data["tiles"][index]["water"] = exact
	for index: int in range(data["year_mods"].size()):
		var exact: Variant = _decode_float64(bits["year_mod_values"][index], data["year_mods"][index]["value"])
		if exact == null:
			return false
		data["year_mods"][index]["value"] = exact
	return true


static func _decode_float64(bits: Variant, numeric: Variant) -> Variant:
	if not bits is String or bits.length() != 16:
		return null
	for index: int in range(bits.length()):
		var code: int = bits.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return null
	var exact: float = bits.hex_decode().decode_double(0)
	if not is_finite(exact):
		return null
	# Permit decimal-reader roundoff, reject contradictory numeric/bit payloads.
	if absf(float(numeric) - exact) > maxf(absf(exact) * 1e-14, 1e-16):
		return null
	return exact


static func _has_fields(data: Dictionary, fields: Array[String]) -> bool:
	for field: String in fields:
		if not data.has(field):
			return false
	return true


static func _number(value: Variant, minimum: float) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number: float = float(value)
	return is_finite(number) and number >= minimum and number <= float(MAX_JSON_INTEGER)


static func _integer(value: Variant, minimum: int, maximum: int = MAX_JSON_INTEGER) -> bool:
	if not _number(value, float(minimum)):
		return false
	var number: float = float(value)
	return number <= float(maximum) and number == floorf(number)


static func _enum_name(value: Variant, enumeration: Dictionary) -> bool:
	if not value is String or value != value.to_lower():
		return false
	return enumeration.has(value.to_upper())


static func _decimal_int64(value: Variant) -> bool:
	if not value is String or value.is_empty():
		return false
	var negative: bool = value.begins_with("-")
	var digits: String = value.substr(1) if negative else value
	if digits.is_empty() or digits.length() > 19:
		return false
	for index: int in range(digits.length()):
		var code: int = digits.unicode_at(index)
		if code < 48 or code > 57:
			return false
	var limit: String = "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() == 19 and digits > limit:
		return false
	return str(value.to_int()) == value


static func _valid_utf8(bytes: PackedByteArray) -> bool:
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first <= 0x7f:
			index += 1
			continue
		var length: int = 0
		var second_min: int = 0x80
		var second_max: int = 0xbf
		if first >= 0xc2 and first <= 0xdf:
			length = 2
		elif first >= 0xe0 and first <= 0xef:
			length = 3
			if first == 0xe0:
				second_min = 0xa0
			elif first == 0xed:
				second_max = 0x9f
		elif first >= 0xf0 and first <= 0xf4:
			length = 4
			if first == 0xf0:
				second_min = 0x90
			elif first == 0xf4:
				second_max = 0x8f
		else:
			return false
		if index + length > bytes.size() or bytes[index + 1] < second_min or bytes[index + 1] > second_max:
			return false
		for offset: int in range(2, length):
			if bytes[index + offset] < 0x80 or bytes[index + offset] > 0xbf:
				return false
		index += length
	return true
