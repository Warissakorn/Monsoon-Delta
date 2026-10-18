class_name DifficultyInfo
extends RefCounted
## Read-only presentation of the shipped cumulative difficulty modifiers.


static func label(level: int) -> String:
	return String(TranslationServer.translate("setup.difficulty_zero")) if level == 0 else String(TranslationServer.translate("setup.difficulty_level")) % level


static func description(level: int, leader: String = "farmer", run_mode: String = "classic") -> String:
	# Recompute derived values without generating a map, forecast or checkpoint.
	var state: GameState = GameState.new()
	state.difficulty = level
	state.leader = leader
	state.run_mode = run_mode
	state.recompute_mods()
	var scoring: Dictionary = DataDB.balance()["scoring"]
	var lines: PackedStringArray = PackedStringArray([
		String(TranslationServer.translate("setup.difficulty_score")) % (1.0 + level * float(scoring["difficulty_step"])),
		String(TranslationServer.translate("setup.difficulty_start")) % [roundi(float(state.mod("start_population"))), roundi(float(state.mod("start_food")))],
		String(TranslationServer.translate("setup.difficulty_rain")) % [float(state.mod("rain_inflow_multiplier")), float(state.mod("year5_inflow_multiplier"))],
		String(TranslationServer.translate("setup.difficulty_range")) % float(state.mod("forecast_range_multiplier")),
		String(TranslationServer.translate("setup.difficulty_homes")) % [roundi(float(state.mod("house_wood"))), roundi(float(state.mod("stilt_wood")))],
		String(TranslationServer.translate("setup.difficulty_survival")) % [float(state.mod("rot_fraction")) * 100.0, float(state.mod("forest_absorb"))],
	])
	if level == 6:
		lines.append(String(TranslationServer.translate("setup.difficulty_six")))
	return "\n".join(lines)
