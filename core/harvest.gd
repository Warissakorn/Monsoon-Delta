class_name Harvest
extends RefCounted
## End-of-year food, housing and population accounting in T-13 order.

const Constants = preload("res://core/constants.gd")


static func do_harvest(s: GameState) -> void:
	s.population = maxi(0, s.population)
	s.food = maxi(0, s.food)
	var paddy_food: int = 0
	for tile: Tile in s.tiles:
		if tile.feature != Constants.Feature.PADDY or tile.paddy_dead:
			continue
		var produced: int = maxi(0, tile.paddy_yield)
		if produced >= 1:
			produced += roundi(float(s.mod("harvest_paddy_bonus")))
			if tile.paddy_rain_turns == Constants.TURNS_PER_YEAR - Constants.DRY_TURNS:
				produced += roundi(float(s.mod("jasmine_bonus")))
			if _is_riverside(s, tile):
				produced += roundi(float(s.mod("fertile_silt_bonus")))
		paddy_food += maxi(0, produced)
	s.food += paddy_food
	s.stats["food_produced"] = int(s.stats.get("food_produced", 0)) + paddy_food

	# Zero feeding cost means everyone eats for free; it never divides by zero.
	var food_per_person: int = maxi(0, roundi(float(s.mod("food_per_person"))))
	var need: int = s.population * food_per_person
	var eaten: int = mini(s.food, need)
	var left_hunger: int = 0
	if s.food >= need:
		s.food -= need
	else:
		left_hunger = mini(s.population, ceili(float(need - s.food) / float(food_per_person)))
		s.population = maxi(0, s.population - left_hunger)
		s.food = 0

	var housing: int = maxi(0, s.capacity())
	var left_housing: int = maxi(0, s.population - housing)
	s.population = mini(s.population, housing)
	var vacancies: int = housing - s.population
	var food_per_growth: int = maxi(0, roundi(float(s.mod("food_per_growth"))))
	# Zero growth cost allows free births up to housing capacity.
	var born: int = vacancies if food_per_growth == 0 else mini(vacancies, floori(float(s.food) / float(food_per_growth)))
	s.population += born
	s.food -= born * food_per_growth

	var spoiled: int = 0
	if not s.has_building(Constants.Building.GRANARY):
		spoiled = floori(float(s.food) * clampf(float(s.mod("rot_fraction")), 0.0, 1.0))
		s.food -= spoiled
	s.stats["max_population"] = maxi(int(s.stats.get("max_population", 0)), s.population)
	if s.population == 0:
		s.outcome = Constants.Outcome.LOSE_POPULATION
	elif s.year == Constants.YEARS:
		s.outcome = Constants.Outcome.WIN
	s.harvest_report = {
		"paddy_food": paddy_food,
		"eaten": eaten,
		"left_hunger": left_hunger,
		"left_housing": left_housing,
		"born": born,
		"spoiled": spoiled,
		"food_after": s.food,
		"population_after": s.population,
	}


static func _is_riverside(s: GameState, tile: Tile) -> bool:
	if tile.is_river:
		return true
	for neighbor: Tile in s.neighbors(tile):
		if neighbor.is_river:
			return true
	return false
