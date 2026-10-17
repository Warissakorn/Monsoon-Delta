extends TestCase
## Scenario files are validated before any run can change effective modifiers.


func test_json_errors_return_no_partial_results() -> void:
	for source: String in ["", "{", "{\"version\":1,\"scenarios\":[}", "null", "[]"]:
		var before: Dictionary = DataDB.balance().duplicate(true)
		_assert_failure(BalanceScenarios.parse_text(source), "JSON %s" % source)
		assert_eq(DataDB.balance(), before, "invalid JSON must preserve shared balance")


func test_document_requires_supported_version_and_exact_root_keys() -> void:
	for data: Variant in [null, [], true, 1, "text", {}]:
		_rejected(data, "document must be a versioned object")
	for version: Variant in [null, true, "1", 0, 2, 1.5]:
		_rejected({"version": version, "scenarios": [_entry()]}, "unsupported version")
	_rejected({"scenarios": [_entry()]}, "missing version")
	_rejected({"version": 1}, "missing scenarios")
	_rejected({"version": 1, "scenarios": [_entry()], "mods": {}}, "unknown root key")
	var scenarios: Array = _success(BalanceScenarios.validate(_document()), "minimal document")
	assert_eq(scenarios, [{"id": "baseline", "mods": {}}])


func test_scenarios_requires_nonempty_array_and_exact_entries() -> void:
	for value: Variant in [null, {}, "baseline", 1, []]:
		_rejected({"version": 1, "scenarios": value}, "scenarios array")
	for entry: Variant in [
		null, true, "baseline", [],
		{}, {"id": "baseline"}, {"mods": {}},
		{"id": "baseline", "mods": {}, "seed": 42},
		{"id": 1, "mods": {}},
	]:
		_rejected({"version": 1, "scenarios": [entry]}, "scenario entry")
	for mods: Variant in [null, true, 1, [], "flow_rate"]:
		_rejected(_document(mods), "mods must be an object")


func test_ids_are_filename_safe_unique_and_keep_input_order() -> void:
	for id: String in [
		"", ".", "..", "../escape", "folder/name", "folder\\name", "/absolute",
		"C:drive", "-leading", "_leading", "two words", "tab\tid", "line\n",
		"con", "PrN", "AUX", "nul", "COM1", "com9", "Lpt1", "lpt9",
		"ไทย", "a".repeat(65),
	]:
		_rejected({"version": 1, "scenarios": [_entry(id)]}, "unsafe id %s" % id)
	_rejected({
		"version": 1, "scenarios": [_entry("same"), _entry("same")],
	}, "duplicate id")
	_rejected({
		"version": 1, "scenarios": [_entry("Trial"), _entry("trial")],
	}, "ids must be unique on case-insensitive filesystems")
	var ids: Array[String] = ["Z_last", "a-2", "7", "a".repeat(64)]
	var entries: Array[Dictionary] = []
	for id: String in ids:
		entries.append(_entry(id))
	var scenarios: Array = _success(
		BalanceScenarios.validate({"version": 1, "scenarios": entries}), "safe ids"
	)
	assert_eq(scenarios.size(), ids.size())
	for index: int in range(mini(scenarios.size(), ids.size())):
		assert_eq(scenarios[index]["id"], ids[index], "preserve scenario order")


func test_modifiers_reject_unknown_keys_and_nonnumeric_values() -> void:
	_mod_rejected("flow_rates", 0.5)
	for value: Variant in [null, true, false, "0.5", [], {}]:
		_mod_rejected("flow_rate", value)
	_rejected(_document({1: 0.5}), "modifier keys must be strings")
	var data: Dictionary = {
		"version": 1,
		"scenarios": [_entry("valid"), _entry("invalid", {"made_up": 1})],
	}
	_rejected(data, "later invalid scenarios must discard earlier normalized entries")


func test_nonfinite_and_excessive_values_are_rejected() -> void:
	for value: float in [NAN, INF, -INF, 1000001.0, -1000001.0]:
		_mod_rejected("sea_level_rain", value)
	_mod_rejected("water_iterations", 1000001)


func test_integer_modifiers_require_whole_values_and_normalize_json_numbers() -> void:
	for key: String in [
		"water_iterations", "start_food", "house_wood", "harvest_paddy_bonus",
		"home_capacity", "reveal_all_inflow",
	]:
		_mod_rejected(key, 1.5)
	var result: Dictionary = BalanceScenarios.parse_text(
		"{\"version\":1,\"scenarios\":[{\"id\":\"counts\",\"mods\":"
		+ "{\"water_iterations\":21.0,\"start_food\":9,\"harvest_paddy_bonus\":-2.0}}]}"
	)
	var scenarios: Array = _success(result, "JSON whole numbers")
	if scenarios.size() != 1:
		return
	var mods: Dictionary = scenarios[0]["mods"]
	assert_eq(mods, {"water_iterations": 21, "start_food": 9, "harvest_paddy_bonus": -2})
	assert_eq(typeof(mods["water_iterations"]), TYPE_INT)
	assert_eq(typeof(mods["harvest_paddy_bonus"]), TYPE_INT)


func test_modifier_ranges_reject_invalid_probabilities_flags_and_counts() -> void:
	for key: String in ["reveal_all_inflow", "unlock_waterwheel", "unlock_raft_house"]:
		for value: int in [-1, 2]:
			_mod_rejected(key, value)
	for key: String in ["rot_fraction", "demolish_refund_fraction", "event_chance"]:
		for value: float in [-0.01, 1.01]:
			_mod_rejected(key, value)
	for value: float in [0.049, 0.901]:
		_mod_rejected("flow_rate", value)
	for value: int in [0, 1001]:
		_mod_rejected("water_iterations", value)
	for key: String in [
		"food_per_person", "food_per_growth", "home_capacity", "start_population",
		"card_offer_count", "dig_amount", "fill_amount", "reservoir_depth",
	]:
		_mod_rejected(key, 0)
	for key: String in ["start_food", "start_wood", "house_wood", "dry_inflow", "sea_level_dry", "sea_level_rain"]:
		_mod_rejected(key, -1)
	for flow: float in [0.05, 0.9]:
		var scenarios: Array = _success(
			BalanceScenarios.validate(_document({
				"flow_rate": flow, "rot_fraction": 0.0, "event_chance": 1.0,
				"demolish_refund_fraction": 1.0, "water_iterations": 1000,
				"reveal_all_inflow": 1, "unlock_waterwheel": 0,
			})), "inclusive range boundaries"
		)
		assert_eq(scenarios.size(), 1)


func test_fractional_and_signed_overrides_are_preserved() -> void:
	var source: Dictionary = _document({
		"harvest_paddy_bonus": -2, "sea_level_dry": 0.375,
		"rain_turn_labor": -1, "year_start_food": -3,
		"rain_inflow_multiplier": 1.125, "fish_trap_multiplier": 1.5,
		"dry_paddy_water_use": 0.125, "flow_rate": 0.625,
	})
	var before: Dictionary = source.duplicate(true)
	var balance_before: Dictionary = DataDB.balance().duplicate(true)
	var scenarios: Array = _success(BalanceScenarios.validate(source), "signed and fractional mods")
	assert_eq(source, before, "validation preserves source values")
	assert_eq(DataDB.balance(), balance_before, "validation preserves default balance")
	if scenarios.size() != 1:
		return
	var mods: Dictionary = scenarios[0]["mods"]
	assert_eq(mods["harvest_paddy_bonus"], -2)
	assert_eq(mods["rain_turn_labor"], -1)
	assert_eq(mods["year_start_food"], -3)
	assert_near(float(mods["sea_level_dry"]), 0.375, 0.000001)
	assert_near(float(mods["rain_inflow_multiplier"]), 1.125, 0.000001)
	assert_near(float(mods["fish_trap_multiplier"]), 1.5, 0.000001)
	assert_near(float(mods["dry_paddy_water_use"]), 0.125, 0.000001)
	assert_near(float(mods["flow_rate"]), 0.625, 0.000001)


func test_normalized_results_do_not_alias_input_other_entries_or_balance() -> void:
	var shared: Dictionary = {"harvest_paddy_bonus": -1.0, "flow_rate": 0.625}
	var source: Dictionary = {
		"version": 1, "scenarios": [_entry("first", shared), _entry("second", shared)],
	}
	var before: Dictionary = source.duplicate(true)
	var balance_before: Dictionary = DataDB.balance().duplicate(true)
	var scenarios: Array = _success(BalanceScenarios.validate(source), "independent results")
	if scenarios.size() != 2:
		return
	scenarios[0]["mods"]["flow_rate"] = 0.125
	scenarios[0]["id"] = "changed"
	scenarios.append(_entry("third"))
	assert_near(float(scenarios[1]["mods"]["flow_rate"]), 0.625, 0.000001)
	assert_eq(source, before, "mutating normalized entries must preserve nested source dictionaries")
	assert_eq(DataDB.balance(), balance_before, "normalized entries must not expose DataDB")
	source["scenarios"][0]["mods"]["flow_rate"] = 0.375
	assert_near(float(scenarios[1]["mods"]["flow_rate"]), 0.625, 0.000001)
	var again: Array = _success(BalanceScenarios.validate(before), "a second validation")
	if again.size() == 2:
		assert_near(float(again[0]["mods"]["flow_rate"]), 0.625, 0.000001)


func test_load_file_reports_missing_malformed_and_valid_files() -> void:
	var path: String = "user://test_balance_scenarios_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec(),
	]
	assert_true(not FileAccess.file_exists(path), "fixture must use an unused isolated path")
	if FileAccess.file_exists(path):
		return
	var before: Dictionary = DataDB.balance().duplicate(true)
	_assert_failure(BalanceScenarios.load_file(path), "missing file")
	assert_eq(DataDB.balance(), before, "missing file preserves DataDB")
	if not _write_fixture(path, "{malformed"):
		return
	_assert_failure(BalanceScenarios.load_file(path), "malformed file")
	assert_eq(DataDB.balance(), before, "malformed file preserves DataDB")
	if not _write_fixture(path, JSON.stringify(_document({"start_food": 8}))):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var scenarios: Array = _success(BalanceScenarios.load_file(path), "valid file")
	assert_eq(scenarios, [{"id": "baseline", "mods": {"start_food": 8}}])
	assert_eq(DataDB.balance(), before, "loading scenarios preserves DataDB")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "remove fixture")


func _document(mods: Variant = {}) -> Dictionary:
	return {"version": 1, "scenarios": [_entry("baseline", mods)]}


func _entry(id: String = "baseline", mods: Variant = {}) -> Dictionary:
	return {"id": id, "mods": mods}


func _rejected(data: Variant, message: String) -> Dictionary:
	var before: Dictionary = DataDB.balance().duplicate(true)
	var result: Dictionary = BalanceScenarios.validate(data)
	_assert_failure(result, message)
	assert_eq(DataDB.balance(), before, message + ": shared balance must remain unchanged")
	return result


func _mod_rejected(key: String, value: Variant) -> void:
	var result: Dictionary = _rejected(_document({key: value}), "invalid modifier " + key)
	var error: String = str(result.get("error", ""))
	assert_true(error.contains("baseline"), "modifier error must identify its scenario")
	assert_true(error.contains(key), "modifier error must identify its key")


func _assert_failure(result: Dictionary, message: String) -> void:
	var error: Variant = result.get("error")
	assert_true(error is String, message + ": error must be a string")
	if error is String:
		assert_true(not error.is_empty(), message + ": expected an error")
	var scenarios: Variant = result.get("scenarios")
	assert_true(scenarios is Array, message + ": scenarios must be an array")
	if scenarios is Array:
		assert_eq(scenarios.size(), 0, message + ": failure must return no scenarios")


func _success(result: Dictionary, message: String) -> Array:
	assert_eq(result.get("error"), "", message)
	var scenarios: Variant = result.get("scenarios")
	assert_true(scenarios is Array, message + ": scenarios must be an array")
	return scenarios if scenarios is Array else []


func _write_fixture(path: String, contents: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "create isolated scenario fixture")
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return true
