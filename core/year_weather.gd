class_name YearWeather
extends RefCounted
## A seeded, integer schedule is generated once. Reading a forecast uses no RNG.


static func generate(seed_value: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SeedUtil.derive_seed(seed_value, 365)
	var settings: Dictionary = DataDB.balance()["year_game"]["weather"]
	var result: Array = []
	for day: int in range(1, 366):
		var bounds: Array = settings[DailyProduction.season(day)]
		var amount: int = rng.randi_range(int(bounds[0]), int(bounds[1]))
		for storm: Dictionary in settings["storms"]:
			if day >= int(storm["start"]) and day <= int(storm["end"]):
				var middle: float = (float(storm["start"]) + float(storm["end"])) * 0.5
				var radius: float = (float(storm["end"]) - float(storm["start"])) * 0.5 + 1.0
				amount += roundi(float(storm["peak"]) * (1.0 - absf(float(day) - middle) / radius))
		result.append(amount)
	return result


static func inflow(s: Dictionary, index: int) -> float:
	return float(s["weather"][index]) / 1000.0 * (1.0 + float(s.get("difficulty", 0)) * float(DataDB.balance()["year_campaign"]["inflow_per_difficulty"]))


static func forecast(s: Dictionary) -> Array:
	var horizon: int = 14 if "water3" in s["research"] else 7
	var result: Array = []
	for index: int in range(int(s["day"]), mini(365, int(s["day"]) + horizon)):
		result.append({"day": index + 1, "inflow": inflow(s, index)})
	return result
