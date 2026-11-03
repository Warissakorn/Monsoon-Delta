extends TestCase


func _to_day(s: Dictionary, day: int) -> void:
	while int(s["day"]) < day and s["outcome"] == "running":
		DailyProduction.advance(s, 1)


func _prepared() -> Dictionary:
	# An executable reference strategy using only actual orders and daily resolve.
	var s: Dictionary = DailyProduction.new_state()
	assert_eq(DailyProduction.order(s, "build_sawmill"), "")
	assert_eq(DailyProduction.order(s, "build_kiln"), "")
	assert_eq(DailyProduction.order(s, "gather_wood", 6), "")
	_to_day(s, 3)
	assert_eq(DailyProduction.order(s, "saw_planks", 4), "")
	assert_eq(DailyProduction.order(s, "fire_bricks", 3), "")
	_to_day(s, 12)
	assert_eq(DailyProduction.order(s, "build_foundation"), "")
	_to_day(s, 15)
	assert_eq(DailyProduction.order(s, "build_barrier"), "")
	_to_day(s, 18)
	return s


func test_reference_strategy_crafts_earns_and_spends_rewards_to_win() -> void:
	var s: Dictionary = _prepared()
	assert_true(s["buildings"]["foundation"] and s["buildings"]["barrier"])
	assert_eq(s["knowledge"], 0)
	_to_day(s, 30)
	assert_eq(s["outcome"], "won")
	assert_eq(s["knowledge"], 1, "first flood grants one final reward")
	assert_eq(s["claimed"], ["planks", "foundation", "flood"])
	assert_eq(s["resources"]["food"], 0, "initial food lasts exactly 30 days")
	assert_eq(DailyCheckpoint.decode(DailyCheckpoint.envelope(s))["error"], "")


func test_calendar_boundaries_support_all_365_days() -> void:
	for day: int in [1, 120]:
		assert_eq(DailyProduction.season(day), "dry")
	for day: int in [121, 180]:
		assert_eq(DailyProduction.season(day), "early_rain")
	for day: int in [181, 300]:
		assert_eq(DailyProduction.season(day), "flood")
	for day: int in [301, 365]:
		assert_eq(DailyProduction.season(day), "receding")


func test_materials_are_reserved_once_for_the_whole_order() -> void:
	var s: Dictionary = DailyProduction.new_state()
	DailyProduction.order(s, "build_sawmill")
	_to_day(s, 2)
	var before: int = int(s["resources"]["wood"])
	assert_eq(DailyProduction.order(s, "saw_planks", 3), "")
	assert_eq(s["resources"]["wood"], before - 6)
	_to_day(s, 8)
	assert_eq(s["resources"]["wood"], before - 6)
	assert_eq(s["resources"]["planks"], 3)


func test_insufficient_resources_and_duplicate_orders_are_atomic() -> void:
	var s: Dictionary = DailyProduction.new_state()
	var snapshot: Dictionary = s.duplicate(true)
	assert_eq(DailyProduction.order(s, "saw_planks"), "daily.error.building")
	assert_eq(s, snapshot)
	assert_eq(DailyProduction.order(s, "build_foundation"), "daily.error.knowledge")
	assert_eq(s, snapshot)
	DailyProduction.order(s, "build_sawmill")
	snapshot = s.duplicate(true)
	assert_eq(DailyProduction.order(s, "build_sawmill"), "daily.error.queued")
	assert_eq(s, snapshot)
	_to_day(s, 2)
	snapshot = s.duplicate(true)
	assert_eq(DailyProduction.order(s, "saw_planks", 20), "daily.error.materials")
	assert_eq(s, snapshot)


func test_workers_are_shared_and_pausing_frees_capacity() -> void:
	var s: Dictionary = DailyProduction.new_state()
	for id: String in ["build_sawmill", "build_kiln", "gather_wood", "gather_food"]:
		assert_eq(DailyProduction.order(s, id), "")
	assert_eq(DailyProduction.workers_used(s), 6)
	assert_eq(DailyProduction.order(s, "gather_stone"), "daily.error.workers")
	assert_eq(DailyProduction.pause_job(s, "build_sawmill"), "")
	assert_eq(DailyProduction.order(s, "gather_stone", 20), "")
	assert_eq(DailyProduction.pause_job(s, "build_sawmill"), "daily.error.workers")
	DailyProduction.advance(s, 1)
	assert_eq(s["jobs"][0]["progress"], 0, "paused jobs retain progress and reservations")


func test_cancel_refunds_only_unstarted_batches() -> void:
	var s: Dictionary = DailyProduction.new_state()
	DailyProduction.order(s, "build_sawmill")
	_to_day(s, 2)
	var wood: int = int(s["resources"]["wood"])
	DailyProduction.order(s, "saw_planks", 3)
	DailyProduction.advance(s, 1)
	assert_eq(DailyProduction.cancel_job(s, "saw_planks"), "")
	assert_eq(s["resources"]["wood"], wood - 2)
	assert_eq(s["resources"]["planks"], 0)
	DailyProduction.order(s, "saw_planks", 2)
	DailyProduction.cancel_job(s, "saw_planks")
	assert_eq(s["resources"]["wood"], wood - 2, "unstarted order refunds all inputs")


func test_rewards_are_granted_once_even_after_more_production() -> void:
	var s: Dictionary = DailyProduction.new_state()
	DailyProduction.order(s, "build_sawmill")
	_to_day(s, 2)
	DailyProduction.order(s, "saw_planks", 5)
	_to_day(s, 12)
	assert_eq(s["planks_produced"], 5)
	assert_eq(s["knowledge"], 1)
	assert_eq(s["claimed"], ["planks"])


func test_cancelling_a_started_project_returns_progression_knowledge() -> void:
	var s: Dictionary = DailyProduction.new_state()
	DailyProduction.order(s, "build_sawmill")
	DailyProduction.order(s, "build_kiln")
	_to_day(s, 3)
	DailyProduction.order(s, "saw_planks", 2)
	DailyProduction.order(s, "fire_bricks", 2)
	_to_day(s, 9)
	assert_eq(DailyProduction.order(s, "build_foundation"), "")
	DailyProduction.advance(s, 1)
	assert_eq(s["knowledge"], 0)
	DailyProduction.cancel_job(s, "build_foundation")
	assert_eq(s["knowledge"], 1, "cancel does not lock out progression")


func test_batch_advance_stops_at_completion_and_matches_single_days() -> void:
	var s: Dictionary = DailyProduction.new_state()
	DailyProduction.order(s, "build_sawmill")
	var copy: Dictionary = s.duplicate(true)
	var report: Dictionary = DailyProduction.advance(s, 7)
	assert_eq(report["days"], 2)
	assert_true("daily.event.complete_build_sawmill" in report["events"])
	DailyProduction.advance(copy, 1)
	DailyProduction.advance(copy, 1)
	assert_eq(s, copy)


func test_advance_stops_before_the_announced_flood_day() -> void:
	var s: Dictionary = DailyProduction.new_state()
	var report: Dictionary = DailyProduction.advance(s, 365)
	assert_eq(s["day"], 21)
	assert_eq(report["events"], ["daily.event.warning_foundation"])
	assert_eq(s["outcome"], "running")
	DailyProduction.advance(s, 365)
	assert_eq(s["day"], 24)
	assert_eq(s["outcome"], "lost_flood")


func test_second_flood_requires_using_the_new_reward() -> void:
	var s: Dictionary = _prepared()
	# Remove only the second protection to exercise the authored second gate.
	s["buildings"]["barrier"] = false
	_to_day(s, 30)
	assert_eq(s["outcome"], "lost_flood")
	assert_true("flood" in s["claimed"], "first flood was survived")


func test_preview_never_changes_resources_progress_or_rewards() -> void:
	var s: Dictionary = DailyProduction.new_state()
	DailyProduction.order(s, "build_sawmill")
	DailyProduction.advance(s, 1)
	var snapshot: Dictionary = s.duplicate(true)
	var preview: Dictionary = DailyProduction.preview(s, 7)
	assert_eq(s, snapshot)
	var report: Dictionary = DailyProduction.advance(s, 7)
	assert_eq(s, preview["state"])
	assert_eq(report, preview["report"])


func test_food_work_is_resolved_before_daily_consumption() -> void:
	var s: Dictionary = DailyProduction.new_state()
	s["resources"]["food"] = 0
	DailyProduction.order(s, "gather_food", 2)
	DailyProduction.advance(s, 1)
	assert_eq(s["resources"]["food"], 1)
	assert_eq(s["outcome"], "running")
	DailyProduction.cancel_job(s, "gather_food")
	DailyProduction.advance(s, 1)
	assert_eq(s["outcome"], "running", "the last daily portion is enough")
	DailyProduction.advance(s, 1)
	assert_eq(s["outcome"], "lost_food")


func test_invalid_time_and_terminal_state_cannot_advance_or_mutate() -> void:
	var s: Dictionary = DailyProduction.new_state()
	var copy: Dictionary = s.duplicate(true)
	for days: int in [-1, 0, 366]:
		assert_eq(DailyProduction.advance(s, days)["days"], 0)
		assert_eq(s, copy)
	_to_day(s, 24)
	copy = s.duplicate(true)
	assert_eq(DailyProduction.advance(s, 7)["days"], 0)
	assert_eq(DailyProduction.order(s, "gather_food"), "daily.error.finished")
	assert_eq(s, copy)
