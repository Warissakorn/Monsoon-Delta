extends TestCase

const PATH: String = "user://tests-transport365.json"


func before_each() -> void:
	for path: String in [PATH, PATH + ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _session() -> TransportSession:
	var session: TransportSession = TransportSession.new()
	session.save_path = PATH
	assert_eq(session.start_year(42), "")
	return session


func _days(session: TransportSession, count: int) -> void:
	for index: int in range(count):
		session.advance_year(1)
		assert_eq(session.last_save_error, "")


func _wood(session: TransportSession, batches: int = 3) -> void:
	assert_eq(session.edit_transport("work", "cut", batches), "")
	_days(session, batches * 2)


func test_loaded_checkpoint_and_future_water_rng_and_results_are_exact() -> void:
	var session: TransportSession = _session()
	_wood(session)
	assert_eq(session.edit_transport("dispatch", "wood", 3), "")
	_days(session, 2)
	assert_true(session.transport["shipments"][0]["loaded"])
	var loaded: TransportSession = TransportSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_year(), "")
	assert_eq(loaded.model(), session.model(), "nested board float64, weather and RNG round trip exactly")
	for index: int in range(8):
		assert_eq(loaded.advance_year(1), session.advance_year(1))
		assert_eq(loaded.model(), session.model())
	assert_eq(session.transport["inventory"]["mill"]["wood"], 3)


func test_undo_redo_restores_both_models_and_day_boundary_clears_history() -> void:
	var session: TransportSession = _session()
	var before: Dictionary = session.model().duplicate(true)
	assert_eq(session.edit_transport("work", "cut", 2), "")
	var planned: Dictionary = session.model().duplicate(true)
	assert_true(session.undo_year())
	assert_eq(session.model(), before)
	assert_true(session.redo_year())
	assert_eq(session.model(), planned)
	assert_eq(session.edit_year("order", "forage", YearStrategy.target(session.year, "forage")), "")
	assert_true(session.undo_year())
	assert_eq(session.model(), planned)
	_days(session, 1)
	assert_true(not session.undo_year())
	assert_true(not session.redo_year())


func test_shared_labor_rejects_normal_orders_and_transport_resume_atomically() -> void:
	var session: TransportSession = _session()
	_wood(session)
	for index: int in range(6):
		assert_eq(session.edit_transport("dispatch", "wood", 1), "")
	var before: Dictionary = session.model().duplicate(true)
	var target: int = YearStrategy.target(session.year, "forage")
	assert_eq(session.edit_year("order", "forage", target), "year.error.workers")
	assert_eq(session.model(), before)
	assert_eq(session.edit_transport("pause", "", 1, "land", 2), "")
	assert_eq(session.edit_year("order", "forage", target), "")
	before = session.model().duplicate(true)
	assert_eq(session.edit_transport("pause", "", 1, "land", 2), "year.error.workers")
	assert_eq(session.model(), before)
	assert_eq(session.edit_year("order", "cut_wood", int(session.transport["sites"]["source"])), "transport.error.dedicated")
	assert_eq(session.model(), before)


func test_write_failure_preserves_bytes_and_retry_never_repeats_reservation() -> void:
	var session: TransportSession = _session()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	assert_eq(session.edit_transport("work", "cut", 2), "")
	var planned: Dictionary = session.model().duplicate(true)
	assert_eq(session.last_save_error, "msg.save_failed")
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	assert_eq(session.checkpoint_year(), "")
	assert_eq(session.model(), planned)
	var loaded: TransportSession = TransportSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_year(), "")
	assert_eq(loaded.model(), planned)


func test_foreign_future_and_corrupt_files_survive_load_restart_and_retry() -> void:
	var session: TransportSession = _session()
	var initial: Dictionary = session.model().duplicate(true)
	var texts: Array[String] = [
		'{"format":"monsoon_transport","version":99,"ruleset":"future"}',
		JSON.stringify(YearCheckpoint.envelope(session.year), "", true, true),
		'{broken',
	]
	for text: String in texts:
		var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		assert_true(not session.load_year().is_empty())
		assert_true(not session.start_year(73).is_empty())
		assert_true(not session.checkpoint_year().is_empty())
		assert_eq(FileAccess.get_file_as_string(PATH), text)
		assert_eq(session.model(), initial)


func test_protected_normal_daily_and_year_paths_are_never_overwritten() -> void:
	for path: String in [SaveIO.DEFAULT_PATH, DailySession.DAILY_PATH, YearSession.YEAR_PATH]:
		var exists: bool = FileAccess.file_exists(path)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path) if exists else PackedByteArray()
		var session: TransportSession = TransportSession.new()
		session.save_path = path
		assert_true(not session.start_year().is_empty())
		assert_eq(FileAccess.file_exists(path), exists)
		if exists:
			assert_eq(FileAccess.get_file_as_bytes(path), bytes)


func test_validator_rejects_malformed_cargo_ids_counts_corridors_and_extra_fields() -> void:
	var session: TransportSession = _session()
	_wood(session)
	assert_eq(session.edit_transport("dispatch", "wood", 3), "")
	var valid: Dictionary = session.model().duplicate(true)
	for change: Dictionary in [{"amount": 4}, {"amount": -1}, {"current": 126}, {"loaded": 1}, {"returning": true}, {"capacity": NAN}, {"id": 999}, {"speed": 0}, {"extra": 1}]:
		var model: Dictionary = valid.duplicate(true)
		model["transport"]["shipments"][0].merge(change, true)
		assert_true(not TransportCheckpoint.valid(model), str(change))
	for change: Dictionary in [{"gathered": 7}, {"produced": 1}, {"claimed": 1}, {"initial_stock": 31}, {"land": []}, {"ports": {}}, {"inventory": null}]:
		var model: Dictionary = valid.duplicate(true)
		model["transport"].merge(change, true)
		assert_true(not TransportCheckpoint.valid(model), str(change))
	var model: Dictionary = valid.duplicate(true)
	model["transport"]["shipments"].append(model["transport"]["shipments"][0].duplicate(true))
	assert_true(not TransportCheckpoint.valid(model))
	for value: Variant in [null, [], 1, {"format": [], "ruleset": {}}]:
		assert_eq(TransportCheckpoint.decode(value)["error"], "msg.save_corrupt")


func test_blocked_returning_cargo_can_reload_and_refunds_once_at_real_origin() -> void:
	var session: TransportSession = _session()
	_wood(session)
	assert_eq(session.edit_transport("dispatch", "wood", 3), "")
	_days(session, 2)
	assert_eq(session.edit_transport("cancel", "", 1, "land", 2), "")
	var at: int = int(session.transport["shipments"][0]["current"])
	session.year["board"]["tiles"][at]["water"] = 1.0 # Explicit flood fixture.
	assert_eq(session.checkpoint_year(), "")
	var loaded: TransportSession = TransportSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_year(), "")
	assert_eq(loaded.model(), session.model())
	assert_eq(TransportGame.shipment_status(loaded.model(), loaded.transport["shipments"][0]), "transport.status.blocked")
	loaded.year["board"]["tiles"][at]["water"] = 0.0
	_days(loaded, 1)
	assert_eq(loaded.transport["inventory"]["source"]["wood"], 6)
	_days(loaded, 1)
	assert_eq(loaded.transport["inventory"]["source"]["wood"], 6)


func test_ui_reads_preview_and_route_selection_leave_state_rng_and_file_unchanged() -> void:
	Localization.setup("th")
	var session: TransportSession = _session()
	var before: Dictionary = session.model().duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var screen: TransportScreen = TransportScreen.new()
	screen.session = session
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen._preview.button_pressed = true
	for index: int in range(3):
		screen.transport_panel._mode.select(index % 2)
		screen.transport_panel._mode.item_selected.emit(index % 2)
		screen._refresh()
	assert_eq(session.model(), before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen.transport_panel._buttons["cut"].pressed.emit()
	assert_eq(session.transport["work"].size(), 1)
	assert_true(session.undo_year())
	assert_eq(session.model(), before)
	screen.free()
	Localization.setup("en")
