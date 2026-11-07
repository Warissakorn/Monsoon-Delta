extends TestCase


func _find(s: Dictionary, id: String, excluded: Array = []) -> int:
	for index: int in range(61):
		if index not in excluded and YearGame.check_order(s, id, index) == "":
			return index
	return -1


func _days(s: Dictionary, target: int) -> void:
	while int(s["day"]) < target and s["outcome"] == "running":
		YearGame.advance(s, mini(7, target - int(s["day"])))


func test_survival_strategy_reaches_day_365_using_real_food_work_and_water() -> void:
	for seed_value: int in [1, 42, 73]:
		var s: Dictionary = YearGame.new_game(seed_value, "rice" if seed_value == 73 else "none")
		while int(s["day"]) < 365 and s["outcome"] == "running":
			YearStrategy.plan(s)
			YearGame.advance(s, 7)
		print("YEAR replay seed=%d day=%d population=%d outcome=%s damage=%d" % [seed_value, s["day"], s["population"], s["outcome"], s["stats"]["damage"]])
		assert_eq(s["day"], 365)
		assert_eq(s["outcome"], "won")
		if seed_value == 73:
			assert_true(not YearGame.goal_met(s), "optional rice goal does not block surviving the year")
		assert_true(YearCheckpoint.valid(s))


func test_seeded_weather_and_preview_do_not_change_state() -> void:
	var s: Dictionary = YearGame.new_game(42)
	assert_eq(s["weather"], YearWeather.generate(42))
	var before: Dictionary = s.duplicate(true)
	var preview: Dictionary = YearGame.preview(s, 7)
	assert_eq(s, before)
	assert_eq(YearGame.advance(s, 7), preview["report"])
	assert_eq(s, preview["state"])


func test_full_year_save_float64_round_trip() -> void:
	var s: Dictionary = YearGame.new_game(42)
	YearGame.advance(s, 7)
	assert_true(YearCheckpoint.valid(s))
	var parser: JSON = JSON.new()
	assert_eq(parser.parse(JSON.stringify(YearCheckpoint.envelope(s), "", true, true)), OK)
	var decoded: Dictionary = YearCheckpoint.decode(parser.data)
	assert_eq(decoded["error"], "")
	assert_eq(decoded["state"], s)


func test_stock_reservations_shared_workers_and_repeat_are_real() -> void:
	var s: Dictionary = YearGame.new_game(42)
	var tile: int = _find(s, "build_sawmill")
	assert_true(tile >= 0)
	var wood: int = int(s["resources"]["wood"])
	assert_eq(YearGame.order(s, "build_sawmill", tile), "")
	assert_eq(s["resources"]["wood"], wood - 8)
	assert_eq(YearGame.order(s, "build_sawmill", tile), "year.error.occupied")
	_days(s, 8)
	assert_eq(s["structures"][tile], "sawmill")
	assert_eq(YearGame.order(s, "saw_planks", tile, 1, true), "")
	_days(s, 20)
	assert_eq(s["stats"]["planks"], 8)
	assert_true("production" in s["claimed"])
	assert_eq(YearGame.learn(s, "water1"), "")
	assert_true("water1" in s["research"])


func _feed(s: Dictionary) -> void:
	for count: int in range(2):
		var index: int = YearStrategy.target(s, "forage")
		assert_true(index >= 0)
		assert_eq(YearGame.order(s, "forage", index, 1, true), "")


func test_rice_can_be_planted_watered_harvested_and_unlock_rewards() -> void:
	var s: Dictionary = YearGame.new_game(42)
	_feed(s)
	var paddy: int = YearStrategy.target(s, "plant_paddy")
	assert_eq(YearGame.order(s, "plant_paddy", paddy), "")
	_days(s, 30)
	assert_eq(YearGame.learn(s, "agriculture1"), "")
	_days(s, 166)
	assert_true(int(s["crop_growth"][paddy]) >= 45)
	assert_eq(YearGame.order(s, "harvest", paddy), "")
	_days(s, 169)
	assert_true(int(s["stats"]["harvest"]) >= 60)
	assert_true("harvest" in s["claimed"])
	assert_true(int(s["crop_growth"][paddy]) < 45, "harvest resets accumulated crop once")
	assert_true(YearCheckpoint.valid(s))


func test_housing_and_food_support_births_at_the_population_review() -> void:
	var s: Dictionary = YearGame.new_game(42)
	_feed(s)
	assert_eq(YearGame.order(s, "build_house", YearStrategy.target(s, "build_house")), "")
	_days(s, 60)
	assert_eq(YearGame.housing(s), 8)
	assert_eq(s["population"], 7)
	assert_eq(s["stats"]["born"], 1)
	assert_true("shelter" in s["claimed"])


func test_without_food_work_the_village_can_lose_before_year_end() -> void:
	var s: Dictionary = YearGame.new_game(42)
	_days(s, 100)
	assert_eq(s["outcome"], "lost_population")
	assert_eq(s["population"], 0)
	assert_true(int(s["day"]) < 365)
	assert_true(YearCheckpoint.valid(s))


func test_forest_depletion_and_replanting_rebuild_a_real_resource_site() -> void:
	var s: Dictionary = YearGame.new_game(42)
	_feed(s)
	var forest: int = YearStrategy.target(s, "gather_wood")
	assert_eq(YearGame.order(s, "gather_wood", forest, 10), "")
	_days(s, 30)
	assert_eq(s["stock"][forest], 0)
	assert_eq(s["board"]["tiles"][forest]["feature"], "none")
	assert_eq(YearGame.order(s, "plant_forest", forest), "")
	_days(s, 65)
	assert_eq(s["board"]["tiles"][forest]["feature"], "forest")
	assert_eq(s["stock"][forest], 30)
	assert_true(YearCheckpoint.valid(s))


func test_pause_cancel_and_repeat_wait_for_inputs_without_double_spending() -> void:
	var s: Dictionary = YearGame.new_game(42)
	var sawmill: int = YearStrategy.target(s, "build_sawmill")
	YearGame.order(s, "build_sawmill", sawmill)
	_days(s, 8)
	var wood: int = int(s["resources"]["wood"])
	YearGame.order(s, "saw_planks", sawmill, 3)
	YearGame.advance(s, 1)
	YearGame.edit_job(s, sawmill, false)
	var progress: int = int(s["jobs"][0]["progress"])
	YearGame.advance(s, 1)
	assert_eq(s["jobs"][0]["progress"], progress)
	YearGame.edit_job(s, sawmill, true)
	assert_eq(s["resources"]["wood"], wood - 3)
	assert_eq(s["resources"]["planks"], 0)


func test_research_requires_earned_knowledge_and_previous_tiers() -> void:
	var s: Dictionary = YearGame.new_game(42)
	var before: Dictionary = s.duplicate(true)
	assert_eq(YearGame.learn(s, "water2"), "year.error.knowledge")
	assert_eq(s, before)
	assert_eq(YearGame.check_order(s, "build_wheel", YearStrategy.target(s, "build_house")), "year.error.research")
	_feed(s)
	_days(s, 30)
	assert_eq(YearGame.learn(s, "water1"), "")
	assert_eq(YearGame.learn(s, "water1"), "year.error.research")
	assert_eq(s["knowledge"], 0)
	assert_true(YearCheckpoint.valid(s))


func test_next_day_flood_damage_is_predicted_exactly_and_does_not_mutate() -> void:
	var s: Dictionary = YearGame.new_game(42)
	_feed(s)
	var observed: bool = false
	while int(s["day"]) < 300 and s["outcome"] == "running":
		var snapshot: Dictionary = s.duplicate(true)
		var next: Dictionary = YearGame.preview(s)
		assert_eq(s, snapshot)
		var report: Dictionary = YearGame.advance(s, 1)
		assert_eq(report, next["report"])
		if "year.event.damage" in report["events"]:
			observed = true
			assert_eq(s, next["state"])
			break
	assert_true(observed, "physical water eventually damages an unprotected village")


func test_invalid_orders_are_atomic_and_terminal_days_cannot_advance() -> void:
	var s: Dictionary = YearGame.new_game(42)
	var before: Dictionary = s.duplicate(true)
	for request: Array in [["unknown", 0], ["build_house", -1], ["build_house", 100]]:
		assert_true(not YearGame.order(s, request[0], int(request[1])).is_empty())
		assert_eq(s, before)
	for days: int in [0, -1, 366]:
		assert_eq(YearGame.advance(s, days)["days"], 0)
		assert_eq(s, before)
	_days(s, 100)
	before = s.duplicate(true)
	assert_eq(YearGame.advance(s, 7)["days"], 0)
	assert_eq(YearGame.order(s, "forage", 0), "year.error.finished")
	assert_eq(s, before)


func test_gate_changes_actual_water_flow() -> void:
	var s: Dictionary = YearGame.new_game(42)
	_feed(s)
	var gate: int = _find(s, "build_gate")
	for index: int in range(61):
		if s["board"]["tiles"][index]["is_river"] and YearGame.check_order(s, "build_gate", index).is_empty():
			gate = index
			break
	assert_eq(YearGame.order(s, "build_gate", gate), "")
	_days(s, 6)
	var closed: Dictionary = s.duplicate(true)
	assert_eq(YearGame.toggle_gate(closed, gate), "")
	YearGame.advance(s, 7)
	YearGame.advance(closed, 7)
	assert_true(s["board"]["tiles"] != closed["board"]["tiles"])


func test_broken_waterwheel_is_inert_until_repaired() -> void:
	var broken: Dictionary = YearGame.new_game(42)
	var index: int = _find(broken, "build_house")
	broken["structures"][index] = "waterwheel"
	broken["health"][index] = 0
	broken["board"]["tiles"][index]["building"] = "waterwheel"
	broken["board"]["tiles"][index]["wheel_dir"] = 0
	var reference: Dictionary = broken.duplicate(true)
	reference["structures"][index] = ""
	reference["board"]["tiles"][index]["building"] = "none"
	YearGame.advance(broken, 1)
	YearGame.advance(reference, 1)
	for tile: int in range(61):
		assert_eq(broken["board"]["tiles"][tile]["water"], reference["board"]["tiles"][tile]["water"])
	assert_true(YearCheckpoint.valid(broken))
