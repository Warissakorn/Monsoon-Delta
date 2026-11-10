extends TestCase
## New public-command replays plus isolated fixtures for branch and save edge cases.

const PATH: String = "user://tests-year-expansion.json"


func before_each() -> void:
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _round_trip(s: Dictionary) -> Dictionary:
	var parser: JSON = JSON.new()
	assert_eq(parser.parse(JSON.stringify(YearCheckpoint.envelope(s), "", true, true)), OK)
	var decoded: Dictionary = YearCheckpoint.decode(parser.data)
	assert_eq(decoded["error"], "")
	assert_eq(decoded["state"], s)
	return decoded["state"]


func _complete(s: Dictionary, id: String, batches: int = 1) -> int:
	var index: int = YearStrategy.target(s, id)
	assert_true(index >= 0, "available target for " + id)
	if index < 0:
		return -1
	assert_eq(YearGame.order(s, id, index, batches), "", id)
	for day: int in range(YearGame._job_days(s, id, index) * batches):
		YearGame.resolve_day(s)
	assert_true(YearCheckpoint.valid(s), "valid after " + id)
	return index


func _feed(s: Dictionary) -> void:
	for count: int in range(2):
		var index: int = YearStrategy.target(s, "forage")
		assert_true(index >= 0)
		if index >= 0:
			assert_eq(YearGame.order(s, "forage", index, 1, true), "")


func _fixture(s: Dictionary, index: int, structure: String, upgrade: String = "") -> void:
	# Focused unit fixture; the end-to-end replay below never uses this helper.
	s["structures"][index] = structure
	s["health"][index] = 100
	s["upgrades"][index] = upgrade
	s["board"]["tiles"][index]["building"] = "none" if structure in ["sawmill", "workshop", "camp"] else structure
	s["board"]["tiles"][index]["feature"] = "none"
	s["deposits"][index] = ""
	s["stock"][index] = 0


func test_expanded_map_is_seeded_and_every_start_has_reachable_materials() -> void:
	for seed_value: int in range(1, 33):
		var s: Dictionary = YearGame.new_expanded(seed_value)
		assert_eq(s["board"]["tiles"].size(), 127)
		assert_eq(s["structures"].size(), 127)
		assert_true(YearCheckpoint.valid(s), "seed %d" % seed_value)
		for id: String in ["forage", "gather_stone", "gather_clay", "gather_fiber", "build_camp"]:
			assert_true(YearStrategy.target(s, id) >= 0, "%s seed %d" % [id, seed_value])
	assert_eq(YearGame.new_expanded(42), YearGame.new_expanded(42))
	assert_true(YearGame.new_expanded(42) != YearGame.new_expanded(73))
	assert_true(YearGame.new_expanded(42, "none", "future").is_empty())


func test_crafting_chain_earns_rewards_and_spends_kits_on_a_harder_upgrade() -> void:
	var s: Dictionary = YearGame.new_expanded(42, "none", "craft")
	_feed(s)
	_complete(s, "gather_wood", 3)
	var sawmill: int = _complete(s, "build_sawmill")
	_complete(s, "build_kiln")
	_complete(s, "saw_planks", 4)
	_complete(s, "fire_bricks", 2)
	assert_eq(s["project_stage"], 1)
	assert_eq(YearExpansion.inputs(s, "build_workshop", -1)["wood"], 2)
	assert_eq(s["resources"]["fiber"], 4, "project reward supplies kit ingredients")
	var workshop: int = _complete(s, "build_workshop")
	_complete(s, "gather_wood", 3)
	_complete(s, "saw_planks", 2)
	_complete(s, "gather_fiber", 2)
	_complete(s, "assemble_kits", 4)
	assert_eq(s["project_stage"], 2)
	assert_eq(s["resources"]["kits"], 4)
	assert_eq(YearGame._job_days(s, "assemble_kits", workshop), int(YearGame.config(s)["jobs"]["assemble_kits"]["days"]) - 1 + (1 if YearExpansion.distance_to_work(s, workshop) >= 2 else 0))
	_complete(s, "gather_stone", 2)
	assert_eq(YearGame.order(s, "improve_sawmill_efficient", sawmill), "")
	for day: int in range(YearGame._job_days(s, "improve_sawmill_efficient", sawmill)):
		YearGame.resolve_day(s)
	assert_eq(s["upgrades"][sawmill], "sawmill_efficient")
	assert_eq(s["resources"]["kits"], 2)
	assert_eq(YearGame.check_order(s, "improve_sawmill_fast", sawmill), "exp.error.improved")
	assert_true(YearCheckpoint.valid(s))
	_round_trip(s)


func test_camps_unlock_remote_work_and_broken_camps_block_it() -> void:
	var s: Dictionary = YearGame.new_expanded(42)
	var camp: int = -1
	for index: int in range(127):
		if YearExpansion.distance_to_work(s, index) in [4, 5] and YearGame.check_order(s, "build_camp", index).is_empty():
			camp = index
			break
	assert_true(camp >= 0)
	if camp < 0: return
	assert_eq(YearGame.check_order(s, "plant_forest", camp), "exp.error.camp")
	assert_eq(YearGame.order(s, "build_camp", camp), "")
	for day: int in range(YearGame._job_days(s, "build_camp", camp)):
		YearGame.resolve_day(s)
	assert_eq(s["structures"][camp], "camp")
	var remote: int = -1
	var base: Dictionary = s.duplicate(true)
	base["health"][camp] = 0
	for index: int in range(127):
		if YearExpansion.distance_to_work(base, index) > 3 and YearGame.check_order(s, "plant_forest", index).is_empty():
			remote = index
			break
	assert_true(remote >= 0)
	assert_eq(YearGame.order(s, "plant_forest", remote), "")
	s["health"][camp] = 0
	assert_eq(YearGame.job_status(s, s["jobs"][0]), "exp.job.camp")
	assert_eq(YearGame.check_order(s, "repair", camp), "", "camp can be repaired from its original 5-hex supply range")
	assert_true(YearCheckpoint.valid(s))


func test_limits_pause_work_release_people_and_preserve_refundable_inputs() -> void:
	var s: Dictionary = YearGame.new_expanded(42)
	var index: int = YearStrategy.target(s, "build_sawmill")
	_fixture(s, index, "sawmill")
	var wood: int = int(s["resources"]["wood"])
	assert_eq(YearGame.order(s, "saw_planks", index, 1, true, 0, 2, wood), "exp.error.reserve")
	assert_eq(s["resources"]["wood"], wood)
	assert_eq(YearGame.order(s, "saw_planks", index, 1, true, 0, 2, 0), "")
	for day: int in range(YearGame._job_days(s, "saw_planks", index) + 1):
		YearGame.resolve_day(s)
	assert_eq(s["resources"]["planks"], 2)
	assert_true(s["jobs"][0]["paused"])
	assert_eq(YearGame.workers(s), 0)
	assert_eq(s["resources"]["wood"], wood - 3)
	assert_eq(YearGame.edit_job(s, index, true), "")
	assert_eq(YearGame.order(s, "saw_planks", index, 1, true, 0, 0, wood - 7), "")
	for day: int in range(YearGame._job_days(s, "saw_planks", index) + 1):
		YearGame.resolve_day(s)
	assert_true(s["jobs"][0]["paused"])
	assert_eq(s["resources"]["wood"], wood - 6)
	assert_eq(YearGame.edit_job(s, index, true), "")
	# A discounted finite order refunds its own price, even after a project changes.
	s["project"] = "craft"
	s["project_stage"] = 1
	var site: int = YearStrategy.target(s, "build_workshop")
	s["resources"]["planks"] = 20
	s["resources"]["bricks"] = 20
	site = YearStrategy.target(s, "build_workshop")
	wood = int(s["resources"]["wood"])
	assert_eq(YearGame.order(s, "build_workshop", site), "")
	assert_eq(s["resources"]["wood"], wood - 2)
	s["project"] = "food"
	assert_eq(YearGame.edit_job(s, site, true), "")
	assert_eq(s["resources"]["wood"], wood)
	_round_trip(s)


func test_project_stage_rewards_are_once_only_and_keep_survival_optional() -> void:
	for project: String in ["food", "water", "craft"]:
		var s: Dictionary = YearGame.new_expanded(42, "rice", project)
		var site: int = YearStrategy.target(s, "build_house")
		if project == "food":
			_fixture(s, site, "granary")
		elif project == "water":
			_fixture(s, site, "reservoir")
			_fixture(s, YearStrategy.target(s, "build_gate"), "gate")
		else:
			_fixture(s, site, "workshop")
			_fixture(s, YearStrategy.target(s, "build_house"), "house", "house_room")
		s["day"] = 300
		s["resources"]["food"] = 80
		s["resources"]["bricks"] = 6
		s["stats"]["planks"] = 8
		s["stats"]["kits"] = 4
		s["stats"]["fed_days"] = 60
		for stage: int in range(1, 4):
			var events: Array = []
			YearExpansion.after_day(s, events)
			assert_eq(s["project_stage"], stage)
			assert_true("exp.event.project_" + project + str(stage) in events)
			assert_eq(YearExpansion.choose_project(s, "water"), "exp.error.project")
		var earned: Dictionary = s.duplicate(true)
		YearExpansion.after_day(s, [])
		assert_eq(s, earned)
		_round_trip(s)
	var optional: Dictionary = YearGame.new_expanded(42, "rice", "craft")
	optional["day"] = 364
	YearGame.resolve_day(optional)
	assert_eq(optional["outcome"], "won")
	assert_eq(optional["project_stage"], 0)


func test_branch_effects_are_local_and_choices_are_exclusive() -> void:
	var s: Dictionary = YearGame.new_expanded(42)
	var site: int = YearStrategy.target(s, "build_house")
	var capacity: int = YearGame.housing(s)
	_fixture(s, site, "house", "house_room")
	assert_eq(YearGame.housing(s), capacity + 3)
	_fixture(s, site, "granary", "granary_storage")
	assert_eq(YearGame.storage(s), int(YearGame.config(s)["base_storage"]) + 360)
	_fixture(s, site, "sawmill", "sawmill_efficient")
	assert_eq(YearExpansion.inputs(s, "saw_planks", site)["wood"], 2)
	var ordinary: int = YearGame._job_days(s, "saw_planks", site)
	s["upgrades"][site] = "sawmill_fast"
	assert_eq(YearGame._job_days(s, "saw_planks", site), ordinary - 1)
	assert_eq(YearExpansion.inputs(s, "saw_planks", site)["wood"], 3)
	assert_eq(YearGame.check_order(s, "improve_sawmill_efficient", site), "exp.error.improved")
	_round_trip(s)


func test_half_gate_changes_water_and_round_trips_exactly() -> void:
	var s: Dictionary = YearGame.new_expanded(42, "none", "water")
	var gate: int = YearStrategy.target(s, "build_gate")
	for index: int in range(127):
		if s["board"]["tiles"][index]["is_river"] and YearGame.check_order(s, "build_gate", index).is_empty():
			gate = index
			break
	_fixture(s, gate, "gate", "gate_control")
	s["board"]["tiles"][gate]["water"] = 2.0
	s["board"]["tiles"][gate]["gate_open"] = false
	assert_eq(YearGame.toggle_gate(s, gate), "")
	assert_true(s["gate_half"][gate])
	var preview: Dictionary = YearGame.preview(s)
	var full: Dictionary = s.duplicate(true)
	assert_eq(YearGame.toggle_gate(full, gate), "")
	assert_true(not full["gate_half"][gate])
	YearGame.resolve_day(full)
	YearGame.resolve_day(s)
	assert_eq(preview["state"], s)
	assert_true(full["board"]["tiles"] != s["board"]["tiles"], "half-open gate changes the physical result")
	var loaded: Dictionary = _round_trip(s)
	assert_eq(YearGame.resolve_day(loaded), YearGame.resolve_day(s))
	assert_eq(loaded, s)
	assert_eq(YearGame.toggle_gate(s, gate), "")
	assert_true(not s["gate_half"][gate])
	assert_eq(YearGame.toggle_gate(s, gate), "")
	assert_true(not s["board"]["tiles"][gate]["gate_open"])


func test_recovery_rewards_are_late_and_cannot_be_claimed_twice() -> void:
	var s: Dictionary = YearGame.new_expanded(42, "none", "craft")
	s["stats"]["recovery_repairs"] = 3
	s["day"] = 299
	YearExpansion.after_day(s, [])
	assert_true(not s["recovery_claimed"])
	s["day"] = 300
	var wood: int = int(s["resources"]["wood"])
	YearExpansion.after_day(s, [])
	assert_true(s["recovery_claimed"])
	assert_eq(s["resources"]["wood"], wood + 4)
	var before: Dictionary = s.duplicate(true)
	YearExpansion.after_day(s, [])
	assert_eq(s, before)
	_round_trip(s)


func test_new_save_undo_redo_and_legacy_save_keep_distinct_rules() -> void:
	var session: YearSession = YearSession.new()
	session.save_path = PATH
	assert_eq(session.start_year(42, "none", "craft"), "")
	var initial: Dictionary = session.year.duplicate(true)
	assert_eq(session.edit_year("project", "water"), "")
	assert_true(session.undo_year())
	assert_eq(session.year, initial)
	assert_true(session.redo_year())
	assert_eq(session.year["project"], "water")
	var loaded: YearSession = YearSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_year(), "")
	assert_eq(loaded.year, session.year)
	assert_eq(YearCheckpoint.envelope(loaded.year)["version"], 2)
	assert_true(not SaveIO._valid_state(loaded.year["board"]), "normal saves still require 61 hexes")
	var legacy: Dictionary = YearGame.new_game(42)
	var legacy_loaded: Dictionary = _round_trip(legacy)
	assert_eq(YearCheckpoint.envelope(legacy)["version"], 1)
	assert_eq(legacy_loaded["structures"].size(), 61)
	for day: int in range(20):
		assert_eq(YearGame.resolve_day(legacy_loaded), YearGame.resolve_day(legacy))
		assert_eq(legacy_loaded, legacy)


func test_malformed_expansion_and_future_files_are_rejected_and_preserved() -> void:
	var s: Dictionary = YearGame.new_expanded(42)
	for change: Dictionary in [{"project": "future"}, {"project_stage": 4}, {"gate_half": []}, {"upgrades": []}, {"recovery_claimed": 1}, {"ruleset": "future"}]:
		var copy: Dictionary = s.duplicate(true)
		copy.merge(change, true)
		assert_true(not YearCheckpoint.valid(copy))
	var bad: Dictionary = s.duplicate(true)
	bad["upgrades"][0] = "gate_control"
	assert_true(not YearCheckpoint.valid(bad))
	var envelope: Dictionary = YearCheckpoint.envelope(s)
	envelope["version"] = 5
	var text: String = JSON.stringify(envelope)
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var session: YearSession = YearSession.new()
	session.save_path = PATH
	assert_eq(session.load_year(), "msg.save_unsupported")
	assert_eq(session.start_year(42, "none", "food"), "msg.save_unsupported")
	assert_eq(FileAccess.get_file_as_string(PATH), text)


func test_all_projects_reach_day_365_with_rewards_used_through_public_commands() -> void:
	for seed_value: int in [1, 42, 73]:
		for project: String in ["food", "water", "craft"]:
			var s: Dictionary = YearGame.new_expanded(seed_value, "none", project)
			while s["outcome"] == "running":
				YearProjectStrategy.plan(s)
				YearGame.advance(s, 7)
			print("EXPANDED seed=%d project=%s day=%d outcome=%s stage=%d kits=%d damage=%d" % [seed_value, project, s["day"], s["outcome"], s["project_stage"], s["stats"]["kits"], s["stats"]["damage"]])
			assert_eq(s["day"], 365)
			assert_eq(s["outcome"], "won")
			assert_eq(s["project_stage"], 3)
			assert_true(int(s["stats"]["kits"]) >= 4)
			assert_true("sawmill_efficient" in s["upgrades"])
			assert_true("camp" in s["structures"])
			assert_true(YearCheckpoint.valid(s))
			_round_trip(s)


func test_mid_flood_expanded_save_replays_every_following_day_exactly() -> void:
	var session: YearSession = YearSession.new()
	session.save_path = PATH
	assert_eq(session.start_year(42, "none", "water"), "")
	while int(session.year["day"]) < 242 and session.year["outcome"] == "running":
		YearProjectStrategy.plan(session.year)
		session.advance_year(mini(7, 242 - int(session.year["day"])))
	assert_eq(session.year["day"], 242)
	var gate: int = session.year["structures"].find("gate")
	assert_eq(session.year["upgrades"][gate], "gate_control")
	if session.year["board"]["tiles"][gate]["gate_open"]:
		assert_eq(session.edit_year("gate", "", gate), "")
	assert_eq(session.edit_year("gate", "", gate), "")
	assert_true(session.year["gate_half"][gate])
	var loaded: YearSession = YearSession.new()
	loaded.save_path = PATH
	assert_eq(loaded.load_year(), "")
	assert_eq(loaded.year, session.year)
	var checkpoint_bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var screen: YearScreen = YearScreen.new()
	screen.session = loaded
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen._refresh()
	assert_eq(FileAccess.get_file_as_bytes(PATH), checkpoint_bytes, "UI reads must not checkpoint")
	screen.free()
	while session.year["outcome"] == "running":
		YearProjectStrategy.plan(session.year)
		YearProjectStrategy.plan(loaded.year)
		assert_eq(loaded.advance_year(1), session.advance_year(1))
		assert_eq(loaded.year, session.year)
		assert_eq(loaded.last_save_error, "")
	assert_eq(loaded.year["outcome"], "won")


func test_deeper_reservoir_and_branch_protection_change_physical_outcomes() -> void:
	var s: Dictionary = YearGame.new_expanded(42)
	var site: int = YearStrategy.target(s, "build_reservoir")
	_fixture(s, site, "reservoir")
	s["resources"]["bricks"] = 8
	var elevation: int = int(s["board"]["tiles"][site]["elevation"])
	assert_eq(YearGame.order(s, "improve_reservoir_deep", site), "")
	for day: int in range(YearGame._job_days(s, "improve_reservoir_deep", site)):
		YearGame.resolve_day(s)
	assert_eq(s["board"]["tiles"][site]["elevation"], maxi(-3, elevation - 1))
	assert_eq(YearGame.check_order(s, "improve_reservoir_reach", site), "exp.error.improved")
	# A surrounded low home has persistent water, isolating the tolerance branch.
	s = YearGame.new_expanded(42)
	site = s["structures"].find("house")
	var home: Dictionary = s["board"]["tiles"][site]
	var coord: Vector2i = Vector2i(int(home["q"]), int(home["r"]))
	for tile: Dictionary in s["board"]["tiles"]:
		tile["water"] = 0.0
		if Hex.distance(coord, Vector2i(int(tile["q"]), int(tile["r"]))) == 1:
			tile["elevation"] = 4
	s["board"]["tiles"][site]["elevation"] = 0
	s["board"]["tiles"][site]["water"] = 0.75
	var protected: Dictionary = s.duplicate(true)
	protected["upgrades"][site] = "house_safe"
	YearGame.resolve_day(s)
	YearGame.resolve_day(protected)
	assert_true(int(s["health"][site]) < int(protected["health"][site]), "home branch reduces actual flood damage")
	assert_eq(s["board"], protected["board"])
	assert_true(YearCheckpoint.valid(protected))


func test_expanded_screen_displays_actual_recipe_and_passes_production_limits() -> void:
	Localization.setup("th")
	var session: YearSession = YearSession.new()
	session.save_path = PATH
	assert_eq(session.start_year(42, "none", "food"), "")
	var screen: YearScreen = YearScreen.new()
	screen.session = session
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	var index: int = YearStrategy.target(session.year, "forage")
	screen.select_tile(index)
	screen._stop_at.value = 80
	screen._repeat.button_pressed = true
	screen._order()
	assert_eq(session.year["jobs"][0]["stop_at"], 80)
	screen._advance(1)
	assert_true(session.year["jobs"][0]["paused"])
	assert_eq(YearGame.workers(session.year), 0)
	assert_true(screen._project_text.text.contains("ขณะนี้"))
	assert_true(not screen._project_text.text.contains("exp.progress"))
	screen._group.select(2)
	screen._populate_actions()
	var has_workshop: bool = false
	var has_branch: bool = false
	for item: int in range(screen._action.item_count):
		has_workshop = has_workshop or screen._action.get_item_metadata(item) == "build_workshop"
		has_branch = has_branch or screen._action.get_item_metadata(item) == "improve_gate_control"
	assert_true(has_workshop and has_branch)
	screen.free()
	Localization.setup("en")
