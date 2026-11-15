extends TestCase

const PATH: String = "user://test-year-polish.json"


class YearBoot extends "res://ui/boot.gd":
	func _ready() -> void:
		pass


func before_each() -> void:
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Localization.setup("en")


func _year(goal: String = "forest") -> Dictionary:
	return YearGame.new_campaign(42, goal, "water", "farmer", 0, true, true)


func _screen(s: Dictionary) -> YearScreen:
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.year = s
	screen.session.save_path = PATH
	assert_eq(screen.session.checkpoint_year(), "")
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	return screen


func test_goals_only_show_relevant_requirements_and_original_medal_receipts() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		for goal: String in ["forest", "rice", "growth", "none"]:
			var s: Dictionary = _year(goal)
			YearGame.advance(s, 1)
			var screen: YearScreen = _screen(s)
			var before: Dictionary = s.duplicate(true)
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
			assert_true(not screen._heritage_goal.text.contains("0/0"))
			if goal != "none":
				assert_true(screen._heritage_goal.text.contains(tr("yearpolish.metric.population")))
				assert_eq(screen._heritage_goal.text.contains(tr("yearpolish.metric.forests")), goal == "forest")
				assert_eq(screen._heritage_goal.text.contains(tr("yearpolish.metric.harvest")), goal == "rice")
			if int(s["goal_medal"]["day"]) > 0:
				assert_true(screen._heritage_goal.text.contains(tr("yearpolish.awarded_with")))
			assert_eq(screen.session.year, before)
			assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
			screen.free()


func test_filters_include_ruins_and_condition_sort_makes_damaged_buildings_easy_to_find() -> void:
	var s: Dictionary = _year()
	var homes: Array[int] = []
	for index: int in range(s["structures"].size()):
		if s["structures"][index] == "house":
			homes.append(index)
	s["health"][homes[0]] = 40
	s["health"][homes[1]] = 0
	YearHeritage.reconcile(s)
	var screen: YearScreen = _screen(s)
	var before: Dictionary = s.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var list: YearBuildingList = screen._building_list
	assert_eq(list.rows.get_child_count(), 4)
	list.filter.select(4)
	list.sort.select(2)
	list.refresh(s)
	assert_eq(list.rows.get_child_count(), 2)
	assert_eq(String(list.rows.get_child(0).name), "BuildingAge_" + str(homes[1]))
	assert_true((list.rows.get_child(0) as Button).text.contains(tr("yearpolish.ruin")))
	assert_eq(String(list.rows.get_child(1).name), "BuildingAge_" + str(homes[0]))
	list.filter.select(3)
	list.refresh(s)
	assert_eq(list.rows.get_child_count(), 0)
	assert_true(list.empty_label.visible)
	list.filter.select(1)
	list.refresh(s)
	assert_eq(list.rows.get_child_count(), 3)
	assert_true(not list.empty_label.visible)
	assert_eq(screen.session.year, before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_true(screen.session.undo_plans.is_empty())
	screen.free()


func test_oldest_sort_and_escape_restore_the_original_camera_selection_and_tool() -> void:
	var s: Dictionary = _year()
	s["day"] = 10
	YearHeritage.after_day(s, [])
	var homes: Array[int] = []
	for index: int in range(s["structures"].size()):
		if s["structures"][index] == "house":
			homes.append(index)
	s["settlement_progress"]["buildings"][YearHeritage.key(s, homes[0])]["built_day"] = 9
	var screen: YearScreen = _screen(s)
	screen._tabs.current_tab = 7
	screen._select_action("dig")
	screen._tabs.current_tab = 7
	screen._building_list.filter.select(1)
	screen._building_list.sort.select(1)
	screen._building_list.refresh(s)
	assert_eq(String(screen._heritage_buildings.get_child(2).name), "BuildingAge_" + str(homes[0]))
	var selected: int = screen.selected
	var camera: Dictionary = screen.board.view_draft()
	var before: Dictionary = s.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	screen._heritage_buildings.get_node("BuildingAge_" + str(homes[0])).pressed.emit()
	assert_eq(screen.selected, homes[0])
	assert_true(screen._village_return.visible)
	assert_eq(screen.action_id(), "dig")
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_ESCAPE
	screen._unhandled_key_input(event)
	assert_eq(screen._tabs.current_tab, 7)
	assert_eq(screen.selected, selected)
	assert_eq(screen.board.view_draft(), camera)
	assert_eq(screen._building_list.draft(), {"filter": 1, "sort": 1})
	assert_true(not screen._village_return.visible)
	assert_true(not screen._settings.visible)
	assert_eq(screen.session.year, before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	screen.free()


func test_language_change_keeps_building_filter_and_pending_return_context() -> void:
	var preferences: Dictionary = GamePreferences.read()
	var boot: YearBoot = YearBoot.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(boot)
	var screen: YearScreen = YearScreen.new()
	screen.session = YearSession.new()
	screen.session.save_path = PATH
	assert_eq(screen.session.start_campaign(42, "forest", "water", "farmer", 0, true, true), "")
	boot._language = "en"
	boot._replace_screen(screen)
	screen._building_list.filter.select(1)
	screen._building_list.sort.select(2)
	screen._building_list.refresh(screen.session.year)
	screen._heritage_help.button_pressed = true
	screen._inspect_village(screen.session.year["structures"].find("house"))
	var draft: Dictionary = screen.ui_draft()
	var camera: Dictionary = screen.board.view_draft()
	var before: Dictionary = screen.session.year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	boot._change_year_language()
	screen = boot._screen as YearScreen
	assert_eq(screen.ui_draft(), draft)
	assert_eq(screen.board.view_draft(), camera)
	assert_true(screen._village_return.visible)
	assert_true(screen._heritage_explanation.visible)
	screen._return_village()
	assert_eq(screen._tabs.current_tab, 7)
	assert_eq(screen._building_list.draft(), {"filter": 1, "sort": 2})
	assert_eq(screen.session.year, before)
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	boot.free()
	assert_eq(GamePreferences.write(preferences), "")


func test_result_card_uses_the_actual_score_and_view_village_does_not_write_the_save() -> void:
	for language: String in ["en", "th"]:
		Localization.setup(language)
		var s: Dictionary = _year()
		YearGame.advance(s, 1)
		s["population"] = 1
		s["resources"]["food"] = 0
		s["starvation"] = 2
		YearGame.advance(s, 1)
		var screen: YearScreen = _screen(s)
		var before: Dictionary = s.duplicate(true)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var parts: Dictionary = YearHeritage.score_parts(s)
		screen._show_year_result()
		assert_true(screen._result_dialog.visible)
		assert_eq(screen._result_outcome.text, tr("year.outcome.lost_population"))
		assert_true(screen._result_total.text.contains(str(parts["total"])))
		for id: String in ["people", "food", "challenges", "project", "goal", "base"]:
			assert_eq(screen._result_values[id].text, str(parts[id]))
		assert_eq(screen._result_values["goal"].text, "250")
		screen._result_dialog.custom_action.emit("village")
		assert_true(not screen._result_dialog.visible)
		assert_eq(screen._tabs.current_tab, 7)
		assert_eq(screen.session.year, before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		screen.free()


func test_finished_year_hides_next_day_forecasts_and_predictions_for_old_and_new_saves() -> void:
	for s: Dictionary in [YearGame.new_game(), YearGame.new_campaign(42, "none", "water"), _year()]:
		s["population"] = 1
		s["resources"]["food"] = 0
		s["starvation"] = 2
		YearGame.advance(s, 1)
		var screen: YearScreen = _screen(s)
		assert_true(screen._preview.disabled)
		assert_true(not screen._forecast.visible)
		assert_true(not screen._planning_assumption.visible)
		assert_true(screen.board.predicted.is_empty())
		assert_eq(screen._food_plan.text, tr("yearpolish.finished_plan"))
		var before: Dictionary = screen.session.year.duplicate(true)
		screen._request_advance(1)
		assert_eq(screen.session.year, before)
		screen.free()


func test_switching_between_history_and_village_inspection_has_only_one_return_target() -> void:
	var screen: YearScreen = _screen(_year())
	var house: int = screen.session.year["structures"].find("house")
	var coord: Vector2i = YearGame.board_of(screen.session.year).tiles[house].coord
	screen._inspect_village(house)
	screen._inspect_history(house, coord)
	assert_true(screen._village_context.is_empty())
	assert_true(not screen._village_return.visible)
	assert_true(screen._history_return.visible)
	screen._inspect_village(house)
	assert_true(screen._history_view.is_empty())
	assert_true(not screen._history_return.visible)
	assert_true(screen._village_return.visible)
	var before: Dictionary = screen.session.year.duplicate(true)
	screen._return_village()
	assert_eq(screen.session.year, before)
	screen.free()


func test_old_year_versions_hide_heritage_controls_and_keep_their_checkpoint_unchanged() -> void:
	for year: Dictionary in [YearGame.new_game(), YearGame.new_expanded(), YearGame.new_campaign(42, "none", "water"), YearGame.new_campaign(42, "none", "water", "farmer", 0, true)]:
		var screen: YearScreen = _screen(year)
		var before: Dictionary = year.duplicate(true)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		assert_true(not screen._building_list.visible)
		assert_true(not screen._heritage_panel.visible)
		screen._tabs.current_tab = 7
		screen._refresh()
		assert_eq(screen.session.year, before)
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
		screen.free()
