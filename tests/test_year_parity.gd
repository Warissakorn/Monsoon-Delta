extends TestCase

const PATH: String = "user://test-year-parity.json"


func before_each() -> void:
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Localization.setup("en")


func _year() -> Dictionary:
	return YearGame.new_campaign(42, "forest", "water", "farmer", 0, true)


func _land(s: Dictionary) -> int:
	var best: int = -1
	for index: int in range(s["structures"].size()):
		if YearGame.target_matches(s, "build_house", index) and (best < 0 or YearExpansion.distance_to_work(s, index) < YearExpansion.distance_to_work(s, best)):
			best = index
	return best


func _paddy(s: Dictionary, index: int) -> void:
	s["board"]["tiles"][index]["feature"] = "paddy"
	s["crop_growth"][index] = 60
	s["soil_moisture"][index] = 2


func _screen(s: Dictionary) -> YearScreen:
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.save_path = PATH
	screen.session.year = s
	assert_eq(screen.session.checkpoint_year(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


func _ledger_balances(entry: Dictionary) -> void:
	for key: String in entry["before"]:
		var total: int = 0
		for cause: Dictionary in entry["causes"]:
			total += int(cause["delta"].get(key, 0))
		assert_eq(int(entry["before"][key]) + total, int(entry["after"][key]), "causal receipts balance " + key)


func test_v4_is_opt_in_and_legacy_configs_and_envelopes_are_unchanged() -> void:
	var versions: Array[Dictionary] = [YearGame.new_game(), YearGame.new_expanded(), YearGame.new_campaign(42, "none", "food"), _year()]
	for index: int in range(versions.size()):
		var s: Dictionary = versions[index]
		assert_true(YearCheckpoint.valid(s))
		assert_eq(YearCheckpoint.envelope(s)["version"], index + 1)
		assert_eq(YearGame.config(s)["jobs"].has("build_raft"), index == 3)
		assert_eq(s.has("soil_moisture"), index == 3)
		assert_eq(YearCheckpoint.decode(YearCheckpoint.envelope(s))["state"], s)
	assert_eq(YearGame.config(versions[2])["jobs"]["build_house"], YearGame.config(versions[3])["jobs"]["build_house"])


func test_v4_strict_arrays_and_rule_version_pairing_reject_corruption() -> void:
	var good: Dictionary = _year()
	for field: String in YearClassic.FIELDS:
		var broken: Dictionary = good.duplicate(true)
		broken.erase(field)
		assert_true(not YearCheckpoint.valid(broken))
		broken = good.duplicate(true)
		broken[field].pop_back()
		assert_true(not YearCheckpoint.valid(broken))
	var index: int = _land(good)
	for choice: Array in [["soil_moisture", 3], ["soil_moisture", 1], ["brace_days", 1], ["irrigation_policy", "first"], ["irrigation_policy", "unknown"]]:
		var broken: Dictionary = good.duplicate(true)
		broken[choice[0]][index] = choice[1]
		assert_true(not YearCheckpoint.valid(broken))
	var envelope: Dictionary = YearCheckpoint.envelope(good)
	envelope["version"] = 3
	assert_eq(YearCheckpoint.decode(envelope)["error"], "msg.save_corrupt")
	envelope["version"] = 7
	assert_eq(YearCheckpoint.decode(envelope)["error"], "msg.save_unsupported")


func test_clear_removes_paddy_crop_moisture_and_priority_through_a_real_job() -> void:
	var s: Dictionary = _year()
	var index: int = _land(s)
	_paddy(s, index)
	s["irrigation_policy"][index] = "first"
	assert_eq(YearGame.order(s, "clear_land", index), "")
	for _step: int in range(4):
		YearGame.advance(s, 1)
	assert_eq(s["board"]["tiles"][index]["feature"], "none")
	assert_eq(s["crop_growth"][index], 0)
	assert_eq(s["soil_moisture"][index], 0)
	assert_eq(s["irrigation_policy"][index], "normal")
	assert_true(YearCheckpoint.valid(s))
	s["board"]["tiles"][index]["feature"] = "sapling"
	s["sapling_ready"][index] = 100
	assert_eq(YearGame.order(s, "clear_land", index), "")
	for _step: int in range(4):
		YearGame.advance(s, 1)
	assert_eq(s["sapling_ready"][index], 0)
	assert_eq(s["board"]["tiles"][index]["feature"], "none")


func test_raft_and_fish_trap_use_real_construction_costs_and_no_passive_labor() -> void:
	var s: Dictionary = _year()
	var index: int = _land(s)
	for key: String in YearGame.resources(s):
		s["resources"][key] = 50
	s["board"]["tiles"][index]["water"] = 0.3
	var before_housing: int = YearGame.housing(s)
	assert_eq(YearGame.order(s, "build_raft", index), "")
	assert_eq(s["resources"]["planks"], 47)
	assert_eq(s["resources"]["fiber"], 48)
	for _day: int in range(8):
		YearGame._work(s, [])
	assert_eq(s["structures"][index], "raft_house")
	assert_eq(YearGame.housing(s), before_housing + 2)
	assert_eq(YearGame.workers(s), 0)
	var trap: int = _land(s)
	s["board"]["tiles"][trap]["water"] = 0.3
	assert_eq(YearGame.order(s, "build_fish_trap", trap), "")
	for _day: int in range(5):
		YearGame._work(s, [])
	assert_eq(s["resources"]["wood"], 47)
	assert_eq(s["structures"][trap], "fish_trap")
	assert_eq(YearGame.workers(s), 0)
	var board: GameState = YearGame.board_of(s)
	board.tiles[trap].water = 0.3
	var food: int = int(s["resources"]["food"])
	var report: TurnReport = TurnReport.new()
	YearLedger.begin(report, s)
	YearClassic.crops_and_fish(s, board, "dry", [], report)
	assert_eq(s["resources"]["food"], food + 1)
	assert_eq(report.fish_food_by_tile[board.tiles[trap].coord], 1)
	board.tiles[trap].water = 1.2
	YearClassic.crops_and_fish(s, board, "dry", [], report)
	assert_eq(s["resources"]["food"], food + 1, "high water suspends the catch")
	for tile: Dictionary in s["board"]["tiles"]:
		tile["water"] = 10.0
	YearGame.advance(s, 1)
	assert_eq(s["health"][index], 100, "raft survives actual flood resolution")
	assert_true(YearCheckpoint.valid(s))


func test_brace_is_one_day_only_costs_wood_and_changes_actual_flood_damage() -> void:
	var s: Dictionary = _year()
	var house: int = s["structures"].find("house")
	for tile: Dictionary in s["board"]["tiles"]:
		tile["elevation"] = 0
		tile["water"] = 0.75
	var unbraced: Dictionary = YearGame.preview(s)["state"]
	assert_eq(YearGame.order(s, "brace_house", house), "")
	var wood: int = int(s["resources"]["wood"])
	var predicted: Dictionary = YearGame.preview(s)["state"]
	YearGame.advance(s, 1)
	assert_eq(s, predicted)
	assert_eq(s["brace_days"][house], 0)
	assert_eq(s["resources"]["wood"], wood)
	assert_true(int(s["health"][house]) > int(unbraced["health"][house]))
	assert_true(YearCheckpoint.valid(s))


func test_moisture_supports_two_dry_days_then_stops_growth_and_flood_clears_it() -> void:
	var s: Dictionary = _year()
	var index: int = _land(s)
	_paddy(s, index)
	var board: GameState = YearGame.board_of(s)
	board.tiles[index].water = 0.0
	for expected: int in [1, 0, 0]:
		YearClassic.crops_and_fish(s, board, "dry", [], null)
		assert_eq(s["soil_moisture"][index], expected)
	assert_eq(s["crop_growth"][index], 62)
	YearClassic.crops_and_fish(s, board, "early_rain", [], null)
	assert_eq(s["soil_moisture"][index], 2)
	board.tiles[index].water = 1.1
	for _day: int in range(5):
		YearClassic.crops_and_fish(s, board, "flood", [], null)
	assert_eq(s["soil_moisture"][index], 0)
	assert_eq(s["crop_growth"][index], 0)


func test_priority_allocates_scarce_reservoir_water_once_and_skip_keeps_moisture() -> void:
	var s: Dictionary = _year()
	var board: GameState = YearGame.board_of(s)
	var center: int = int(board.index[Vector2i.ZERO])
	var fields: Array[int] = []
	for coord: Vector2i in Hex.neighbors(Vector2i.ZERO):
		var index: int = int(board.index[coord])
		fields.append(index)
		board.tiles[index].feature = C.Feature.PADDY
		board.tiles[index].water = 0.0
		s["soil_moisture"][index] = 0
	fields.sort()
	s["structures"][center] = "reservoir"
	s["health"][center] = 100
	board.tiles[center].water = 0.04
	s["irrigation_policy"][fields.back()] = "first"
	s["irrigation_policy"][fields[0]] = "skip"
	s["soil_moisture"][fields[0]] = 1
	var report: TurnReport = TurnReport.new()
	YearLedger.begin(report, s)
	YearClassic.crops_and_fish(s, board, "dry", [], report)
	assert_eq(report.irrigation_results.size(), 1)
	assert_eq(report.irrigation_results[0]["coord"], board.tiles[fields.back()].coord)
	assert_true(is_equal_approx(board.tiles[center].water, 0.02))
	assert_eq(s["soil_moisture"][fields.back()], 2)
	assert_eq(s["soil_moisture"][fields[0]], 0)
	assert_eq(s["crop_growth"][fields[0]], 1)


func test_irrigation_policy_is_undoable_and_round_trips_without_changing_other_saves() -> void:
	var s: Dictionary = _year()
	var index: int = _land(s)
	_paddy(s, index)
	var screen: YearScreen = _screen(s)
	var before: Dictionary = s.duplicate(true)
	assert_eq(screen.session.edit_year("irrigation", "first", index), "")
	assert_eq(screen.session.year["irrigation_policy"][index], "first")
	assert_eq(screen.session.load_year(), "")
	assert_eq(screen.session.year["irrigation_policy"][index], "first")
	assert_eq(screen.session.edit_year("irrigation", "skip", index), "")
	assert_true(screen.session.undo_year())
	assert_eq(screen.session.year["irrigation_policy"][index], "first")
	assert_true(screen.session.redo_year())
	assert_eq(screen.session.year["irrigation_policy"][index], "skip")
	assert_eq(before["irrigation_policy"][index], "normal")
	screen.free()


func test_daily_receipts_balance_all_resources_and_visual_recording_never_changes_rules() -> void:
	for s: Dictionary in [YearGame.new_game(), YearGame.new_expanded(), YearGame.new_campaign(42, "none", "food"), _year()]:
		YearStrategy.plan(s)
		var actual: Dictionary = s.duplicate(true)
		var reports: Array[TurnReport] = []
		for _day: int in range(20):
			YearGame.advance(s, 1, reports)
			YearGame.advance(actual, 1)
		assert_eq(s, actual)
		for report: TurnReport in reports:
			_ledger_balances(report.year_ledger)
			assert_true(not report.to_dict().has("year_ledger"))
			assert_true(not YearCheckpoint.envelope(s)["state"].has("year_ledger"))


func test_restart_form_uses_loaded_campaign_profile_and_preserves_it_on_cancel() -> void:
	var s: Dictionary = YearGame.new_campaign(73, "rice", "craft", "fisher", 5, true)
	var screen: YearScreen = _screen(s)
	assert_eq(screen._seed.text, "73")
	assert_eq(screen._goal.selected, 3)
	assert_eq(screen._project.selected, 2)
	assert_eq(MainMenu.LEADERS[screen._leader.selected], "fisher")
	assert_eq(int(screen._difficulty.value), 5)
	assert_true(screen._classic.button_pressed)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen.show_new_year()
	screen._restart.hide()
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_eq(screen.session.year, s)
	screen.free()


func test_nonfatal_impact_confirmation_and_inspection_are_read_only() -> void:
	var s: Dictionary = _year()
	for tile: Dictionary in s["board"]["tiles"]:
		tile["water"] = 10.0
	var screen: YearScreen = _screen(s)
	var before: Dictionary = s.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen._request_advance(7)
	assert_true(screen._advance_confirmation.visible)
	assert_true(screen._advance_text.text.contains("predicted impacts"))
	assert_true(screen._impact_button.visible)
	screen._advance_confirmation.custom_action.emit("inspect")
	assert_eq(screen.selected, screen._impact_tile)
	assert_eq(screen.session.year, before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_true(screen.session.undo_plans.is_empty())
	screen.free()


func test_try_order_compares_real_daily_resolution_and_never_mutates_its_input() -> void:
	var s: Dictionary = _year()
	var index: int = YearStrategy.target(s, "forage")
	var before: Dictionary = s.duplicate(true)
	var result: Dictionary = YearOrderPreview.describe(s, "forage", index, 1, true)
	assert_eq(result["error"], "")
	var actual: Dictionary = s.duplicate(true)
	assert_eq(YearGame.order(actual, "forage", index, 1, true), "")
	for _day: int in range(7):
		YearGame.resolve_day(actual)
	assert_eq(result["planned"], actual)
	assert_eq(s, before)
	assert_eq(YearOrderPreview.describe(s, "bad_order", index)["error"], "year.error.order")


func test_try_order_cancel_commit_once_undo_and_stale_guard() -> void:
	var screen: YearScreen = _screen(_year())
	screen._select_action("forage")
	screen.select_tile(YearStrategy.target(screen.session.year, "forage"))
	var before: Dictionary = screen.session.year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen._try_order()
	assert_true(screen._order_confirmation.visible)
	assert_eq(screen.session.year, before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_true(screen.session.undo_plans.is_empty())
	screen._order_confirmation.hide()
	screen._commit_tried_order()
	assert_eq(screen.session.year["jobs"].size(), 1)
	screen._commit_tried_order()
	assert_eq(screen.session.year["jobs"].size(), 1)
	assert_true(screen.session.undo_year())
	assert_eq(screen.session.year, before)
	screen._try_order()
	screen._order_confirmation.hide()
	assert_eq(screen.session.edit_year("order", "forage", screen.selected), "")
	var changed: Dictionary = screen.session.year.duplicate(true)
	screen._commit_tried_order()
	assert_eq(screen.session.year, changed)
	screen.free()


func test_history_retains_original_coordinates_and_return_restores_camera_and_tool() -> void:
	var s: Dictionary = _year()
	var index: int = _land(s)
	_paddy(s, index)
	assert_eq(YearGame.order(s, "harvest", index), "")
	var screen: YearScreen = _screen(s)
	screen.session.advance_year(7)
	screen._refresh()
	var history: Array[Dictionary] = screen.session.daily_history.duplicate(true)
	var found: bool = false
	for entry: Dictionary in history:
		for fact: Dictionary in entry["locations"]:
			if fact["kind"] == "year.action.harvest":
				found = true
				screen._select_action("dig")
				var camera: Dictionary = screen.board.view_draft()
				var selected: int = screen.selected
				screen._inspect_history(index, fact["coord"])
				assert_true(screen._history_return.visible)
				assert_eq(screen.action_id(), "dig")
				screen._return_history()
				assert_eq(screen.board.view_draft(), camera)
				assert_eq(screen.selected, selected)
				assert_eq(screen._tabs.current_tab, 5)
	assert_true(found)
	assert_true(not screen._history.text.contains("daily.resource."))
	assert_true(screen._history.text.contains("Housing capacity"))
	assert_eq(screen.session.edit_year("order", "clear_land", index), "")
	screen.session.advance_year(7)
	assert_eq(screen.session.daily_history.slice(0, history.size()), history)
	screen.free()


func test_v4_survives_full_year_and_continues_exactly_after_flood_checkpoint() -> void:
	var s: Dictionary = _year()
	while int(s["day"]) < 242 and s["outcome"] == "running":
		YearProjectStrategy.plan(s)
		YearGame.advance(s, mini(7, 242 - int(s["day"])))
	assert_eq(s["day"], 242)
	var parser: JSON = JSON.new()
	assert_eq(parser.parse(JSON.stringify(YearCheckpoint.envelope(s), "", true, true)), OK)
	var loaded: Dictionary = YearCheckpoint.decode(parser.data)["state"]
	assert_eq(s, loaded)
	while s["outcome"] == "running":
		YearProjectStrategy.plan(s)
		YearProjectStrategy.plan(loaded)
		assert_eq(YearGame.advance(s, 7), YearGame.advance(loaded, 7))
		assert_eq(s, loaded)
	assert_eq(s["day"], 365)
	assert_eq(s["outcome"], "won")
	assert_true(YearCheckpoint.valid(s))


func test_physical_tools_preview_pan_and_right_cancel_leave_the_plan_untouched() -> void:
	var screen: YearScreen = _screen(_year())
	var before: Dictionary = screen.session.year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var camera: Dictionary = screen.board.view_draft()
	for code: Key in [KEY_6, KEY_R, KEY_D, KEY_TAB, KEY_F3]:
		var event: InputEventKey = InputEventKey.new()
		event.pressed = true
		event.physical_keycode = code
		screen._unhandled_key_input(event)
	assert_eq(screen.action_id(), "brace_house")
	assert_true(not screen._preview.button_pressed)
	assert_eq(screen._tabs.current_tab, 5)
	assert_true(screen.board.view_draft() != camera)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	screen.board._gui_input(click)
	assert_eq(screen.action_id(), "")
	assert_true(screen._order_button.disabled)
	assert_eq(screen.session.year, before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen.free()
