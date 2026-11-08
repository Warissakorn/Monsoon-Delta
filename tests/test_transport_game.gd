extends TestCase


func _model() -> Dictionary:
	var result: Dictionary = TransportGame.create(42)
	assert_true(not result.is_empty())
	assert_true(TransportCheckpoint.valid(result), "new pilot has a valid nested year and exact ledgers")
	return result


func test_authored_corridor_preserves_seeded_hall_and_housing() -> void:
	for seed_value: int in range(1, 65):
		var initial: Dictionary = YearGame.new_expanded(seed_value)
		var model: Dictionary = TransportGame.create(seed_value)
		assert_eq(model["year"]["structures"].count("hall"), 1, "seed %d keeps its hall" % seed_value)
		assert_eq(YearGame.housing(model["year"]), YearGame.housing(initial), "seed %d keeps its homes" % seed_value)
		assert_true(TransportCheckpoint.valid(model), "seed %d starts a checkpointable pilot" % seed_value)
		var loaded: Dictionary = TransportCheckpoint.decode(TransportCheckpoint.envelope(model))
		assert_eq(loaded["error"], "")
		assert_eq(loaded["state"], model)


func _days(model: Dictionary, count: int) -> void:
	for day: int in range(count):
		TransportGame.advance(model, 1)
		var ledger: Dictionary = TransportGame.ledger(model)
		assert_true(ledger["forest_exact"] and ledger["wood_exact"] and ledger["planks_exact"])
		assert_true(TransportCheckpoint.valid(model), "every intermediate day is checkpointable")


func test_new_pilot_has_both_routes_and_boat_never_crosses_dry_bank_to_bank() -> void:
	var model: Dictionary = _model()
	var sites: Dictionary = model["transport"]["sites"]
	assert_eq(TransportGame.route(model, sites["source"], sites["mill"], "land").size(), 3)
	assert_eq(TransportGame.route(model, sites["source"], sites["mill"], "boat").size(), 5)
	assert_eq(TransportGame.route(model, sites["mill"], sites["store"], "boat").size(), 3)
	model["transport"]["ports"]["mill"] = false
	assert_true(TransportGame.route(model, sites["source"], sites["mill"], "boat").is_empty())
	assert_true(not TransportGame.route(model, sites["source"], sites["mill"], "land").is_empty())


func test_full_cut_boat_saw_land_store_claim_cycle_conserves_every_unit() -> void:
	var model: Dictionary = _model()
	var global_before: int = int(model["year"]["resources"]["planks"])
	assert_eq(TransportGame.order_work(model, "cut", 2), "")
	_days(model, 2)
	assert_eq(model["transport"]["inventory"]["source"]["wood"], 2)
	assert_eq(TransportGame.dispatch(model, "wood", 2, "boat"), "")
	assert_eq(TransportGame.ledger(model)["wood_reserved"], 2)
	_days(model, 1)
	assert_eq(TransportGame.ledger(model)["wood_transit"], 2)
	assert_eq(model["transport"]["inventory"]["mill"]["wood"], 0)
	_days(model, 2)
	assert_eq(model["transport"]["inventory"]["mill"]["wood"], 2)
	assert_eq(TransportGame.order_work(model, "saw", 1), "")
	assert_eq(TransportGame.ledger(model)["processing"], 2)
	_days(model, 2)
	assert_eq(model["transport"]["inventory"]["mill"]["planks"], 1)
	assert_eq(model["year"]["resources"]["planks"], global_before, "production at the mill is not yet spendable in the village")
	assert_eq(TransportGame.dispatch(model, "planks", 1, "land"), "")
	_days(model, 2)
	assert_eq(model["transport"]["inventory"]["store"]["planks"], 1)
	assert_eq(TransportGame.edit(model, "claim", -1, "", 1), "")
	assert_eq(model["year"]["resources"]["planks"], global_before + 1)
	assert_eq(model["transport"]["claimed"], 1)
	assert_true(TransportCheckpoint.valid(model))
	var before: Dictionary = model.duplicate(true)
	assert_eq(TransportGame.edit(model, "claim", -1, "", 1), "transport.error.stock")
	assert_eq(model, before, "the same delivered plank cannot be claimed twice")


func test_capacity_and_stock_failures_are_atomic_and_reservations_prevent_double_spending() -> void:
	var model: Dictionary = _model()
	assert_eq(TransportGame.order_work(model, "cut", 2), "")
	_days(model, 4)
	var before: Dictionary = model.duplicate(true)
	assert_eq(TransportGame.dispatch(model, "wood", 4, "land"), "transport.error.capacity")
	assert_eq(model, before)
	assert_eq(TransportGame.dispatch(model, "wood", 3, "land"), "")
	before = model.duplicate(true)
	assert_eq(TransportGame.dispatch(model, "wood", 2, "boat"), "transport.error.stock")
	assert_eq(model, before)
	assert_eq(TransportGame.edit(model, "cancel", 2), "")
	assert_eq(model["transport"]["inventory"]["source"]["wood"], 4)
	assert_eq(model["transport"]["shipments"].size(), 0)


func test_closed_dock_holds_reservation_and_reopens_without_duplicate_loading() -> void:
	var model: Dictionary = _model()
	assert_eq(TransportGame.order_work(model, "cut", 1), "")
	_days(model, 2)
	assert_eq(TransportGame.edit(model, "port", -1, "source"), "")
	assert_eq(TransportGame.dispatch(model, "wood", 2, "boat"), "")
	_days(model, 2)
	var job: Dictionary = model["transport"]["shipments"][0]
	assert_true(not job["loaded"])
	assert_eq(TransportGame.ledger(model)["wood_reserved"], 2)
	assert_eq(TransportGame.edit(model, "port", -1, "source"), "")
	_days(model, 3)
	assert_eq(model["transport"]["inventory"]["mill"]["wood"], 2)
	assert_eq(model["transport"]["shipments"].size(), 0)


func test_return_request_keeps_loaded_cargo_at_its_real_position_until_route_is_safe() -> void:
	var model: Dictionary = _model()
	assert_eq(TransportGame.order_work(model, "cut", 2), "")
	_days(model, 4)
	assert_eq(TransportGame.dispatch(model, "wood", 3, "land"), "")
	_days(model, 2)
	var job: Dictionary = model["transport"]["shipments"][0]
	var at: int = int(job["current"])
	assert_true(at != int(model["transport"]["sites"]["source"]))
	assert_eq(TransportGame.edit(model, "cancel", int(job["id"])), "")
	model["year"]["board"]["tiles"][at]["water"] = 1.0
	assert_eq(TransportGame.shipment_status(model, job), "transport.status.blocked")
	assert_eq(TransportGame.ledger(model)["wood_transit"], 3)
	assert_eq(model["transport"]["inventory"]["source"]["wood"], 1)
	_days(model, 1)
	assert_eq(job["current"], at)
	model["year"]["board"]["tiles"][at]["water"] = 0.0
	_days(model, 1)
	assert_eq(model["transport"]["shipments"].size(), 0)
	assert_eq(model["transport"]["inventory"]["source"]["wood"], 4)


func test_cancelling_partial_production_returns_only_the_remaining_reserved_material() -> void:
	var model: Dictionary = _model()
	assert_eq(TransportGame.order_work(model, "cut", 3), "")
	_days(model, 3)
	assert_eq(TransportGame.edit(model, "cancel", 1), "")
	assert_eq(model["year"]["stock"][model["transport"]["sites"]["source"]], 28)
	assert_eq(model["transport"]["gathered"], 2)
	assert_true(TransportCheckpoint.valid(model))


func test_preview_matches_committed_days_without_mutating_model_or_rng() -> void:
	var model: Dictionary = _model()
	assert_eq(TransportGame.order_work(model, "cut", 1), "")
	var before: Dictionary = model.duplicate(true)
	var preview: Dictionary = TransportGame.preview(model, 7)
	assert_eq(model, before)
	var report: Dictionary = TransportGame.advance(model, 7)
	assert_eq(model, preview["state"])
	assert_eq(report, preview["report"])


func test_real_water_and_terrain_changes_block_routes_and_restore_them() -> void:
	var model: Dictionary = _model()
	var t: Dictionary = model["transport"]
	var source: int = int(t["sites"]["source"])
	var mill: int = int(t["sites"]["mill"])
	var channel: int = int(t["water"][1])
	model["year"]["board"]["tiles"][channel]["water"] = 0.0
	assert_true(TransportGame.route(model, source, mill, "boat").is_empty())
	model["year"]["board"]["tiles"][t["land"][1]]["elevation"] = 0
	assert_true(TransportGame.route(model, source, mill, "land").is_empty())


func test_finite_source_exhaustion_survives_save_and_cannot_generate_extra_wood() -> void:
	var model: Dictionary = _model()
	assert_eq(TransportGame.order_work(model, "cut", 15), "")
	_days(model, 30)
	assert_eq(model["transport"]["gathered"], 30)
	assert_eq(model["year"]["board"]["tiles"][model["transport"]["sites"]["source"]]["feature"], "none")
	assert_eq(TransportGame.order_work(model, "cut", 1), "transport.error.stock")
	assert_true(TransportCheckpoint.valid(model))


func test_population_loss_pauses_excess_transport_work_without_losing_reservations() -> void:
	var model: Dictionary = _model()
	assert_eq(TransportGame.order_work(model, "cut", 3), "")
	_days(model, 6)
	for index: int in range(6):
		assert_eq(TransportGame.dispatch(model, "wood", 1, "land"), "")
	model["year"]["resources"]["food"] = 0 # Hunger fixture, not a player command.
	model["year"]["starvation"] = 2
	_days(model, 1)
	assert_eq(model["year"]["population"], 5)
	assert_eq(TransportGame.workers(model), 5)
	assert_eq(TransportGame.ledger(model)["wood_transit"], 6)
	assert_true(TransportCheckpoint.valid(model))


func test_partial_saw_cancellation_refunds_only_unprocessed_wood() -> void:
	var model: Dictionary = _model()
	assert_eq(TransportGame.order_work(model, "cut", 3), "")
	_days(model, 6)
	assert_eq(TransportGame.dispatch(model, "wood", 6, "boat"), "")
	_days(model, 3)
	assert_eq(TransportGame.order_work(model, "saw", 3), "")
	_days(model, 3)
	assert_eq(TransportGame.edit(model, "cancel", 3), "")
	assert_eq(model["transport"]["inventory"]["mill"]["wood"], 4)
	assert_eq(model["transport"]["inventory"]["mill"]["planks"], 1)
	assert_true(TransportCheckpoint.valid(model))
