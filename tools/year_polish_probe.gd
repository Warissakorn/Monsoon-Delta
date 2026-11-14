extends "res://tools/year_heritage_probe.gd"
## Mouse/physical-key checks for the polished UI; all world state uses public replay.


func _choose(button: OptionButton, index: int) -> void:
	await _click(button)
	var popup: PopupMenu = button.get_popup()
	_check(popup.visible, "native option menu opens")
	if not popup.visible:
		return
	# Option menus include panel padding; proportional positions can hit the
	# bottom padding rather than the final item. These menus contain no separators.
	var item_height: float = popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size")) + popup.get_theme_constant("v_separation")
	var padding: float = maxf(0.0, (float(popup.size.y) - float(popup.item_count) * item_height) * 0.5)
	await _click_at(Vector2(popup.position) + Vector2(float(popup.size.x) * 0.5, padding + (float(index) + 0.5) * item_height))
	_check(button.selected == index, "native option selects the requested item")


func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Localization.setup(language)
	var wide: bool = "--wide" in OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 900) if wide else Vector2i(1280, 720)
	var session: YearSession = YearSession.new()
	session.save_path = output.path_join("village.json")
	_check(session.start_campaign(42, "forest", "water", "farmer", 0, true, true) == "", "isolated v5 year starts")
	for _job: int in range(2):
		YearGame.order(session.year, "forage", YearStrategy.target(session.year, "forage"), 1, true)
	YearGame.order(session.year, "build_sawmill", YearStrategy.target(session.year, "build_sawmill"))
	while int(session.year["day"]) < 90 and session.year["outcome"] == "running":
		session.advance_year(mini(7, 90 - int(session.year["day"])))
	_check(int(session.year["day"]) == 90 and YearCheckpoint.valid(session.year), "real daily replay reaches a valid ninety-day village")
	var screen: YearScreen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	(screen.board as YearBoard3D).set_reduced_motion(true)
	var before: Dictionary = session.year.duplicate(true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(session.save_path)
	await _click(screen._heritage_button)
	_check(not screen._heritage_goal.text.contains("0/0") and screen._heritage_goal.text.contains("250"), "goal card shows the earned medal and only useful requirements")
	_check(screen._heritage_goal.get_global_rect().position.y < screen._building_list.get_global_rect().position.y, "ambition is shown before the long building list")
	await _capture("year-polish-village-" + language)
	await _choose(screen._building_list.filter, 1)
	await _choose(screen._building_list.sort, 1)
	_check(screen._heritage_buildings.get_child_count() == 3, "native home filter removes workplaces from the list")
	_check(screen._building_list.sort.selected == 1, "native oldest-first sort is selected")
	await _key(KEY_1)
	await _key(KEY_Q)
	screen.board.zoom_by(1.2)
	await _click(screen._heritage_button)
	var camera: Dictionary = screen.board.view_draft()
	var selected: int = screen.selected
	var house: int = session.year["structures"].find("house")
	await _click(screen._heritage_buildings.get_node("BuildingAge_" + str(house)))
	var return_scroll: int = int(screen._village_context.get("scroll", -1))
	_check(screen.selected == house and screen._village_return.visible and screen.action_id() == "dig", "building inspection keeps the selected work tool and offers return")
	await _capture("year-polish-inspector-" + language)
	await _key(KEY_ESCAPE)
	await process_frame
	await process_frame
	_check(screen._tabs.current_tab == 7 and screen.board.view_draft() == camera and screen.selected == selected, "Escape restores village tab, camera and prior selection")
	_check(screen._building_list.draft() == {"filter": 1, "sort": 1} and (screen._tabs.get_child(7) as ScrollContainer).scroll_vertical == return_scroll, "return keeps the original filter, order and scroll position")
	await _capture("year-polish-buildings-" + language)
	await _choose(screen._building_list.filter, 4)
	_check(screen._building_list.empty_label.visible and screen._heritage_buildings.get_child_count() == 0, "an empty repair filter gives a clear empty state")
	await _click(screen._new_button)
	_check(screen._classic.visible and screen._classic.get_global_rect().end.y < float(screen._restart.size.y) - 80.0, "extra systems are visible in the initial new-year form without scrolling")
	await _capture("year-polish-setup-" + language)
	await _click(screen._restart.get_cancel_button())
	_check(session.year == before and FileAccess.get_file_as_bytes(session.save_path) == bytes and session.undo_plans.is_empty(), "navigation, filters and cancelled setup do not change gameplay, RNG, save or Undo")
	screen.free()

	session = YearSession.new()
	session.save_path = output.path_join("final.json")
	_check(session.start_campaign(42, "forest", "water", "farmer", 0, true, true) == "", "full-year replay starts")
	while int(session.year["day"]) < 364 and session.year["outcome"] == "running":
		YearProjectStrategy.plan(session.year)
		session.advance_year(mini(7, 364 - int(session.year["day"])))
	YearProjectStrategy.plan(session.year)
	session.checkpoint_year()
	screen = YearScreen.new()
	screen.session = session
	root.add_child(screen)
	await _click(screen._time_buttons[0])
	if screen._advance_confirmation.visible:
		await _click(screen._advance_confirmation.get_ok_button())
	_check(int(session.year["day"]) == 365 and session.year["outcome"] == "won" and screen._result_dialog.visible, "native final day opens the polished result card")
	await _capture("year-polish-result-" + language)
	var parts: Dictionary = YearHeritage.score_parts(session.year)
	_check(screen._result_total.text.contains(str(parts["total"])) and screen._result_values["goal"].text == "250", "result card shows the actual total and medal contribution")
	var numbers_fit: bool = true
	for label: Label in screen._result_values.values():
		var font: Font = label.get_theme_font("font")
		numbers_fit = numbers_fit and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x + 1.0
	_check(numbers_fit, "every score value fits without wrapping or clipping")
	_check(not screen._forecast.visible and screen._preview.disabled and screen.board.predicted.is_empty(), "completed year has no next-day forecast or ghost prediction")
	var dialog_rect: Rect2 = Rect2(Vector2(screen._result_dialog.position), Vector2(screen._result_dialog.size))
	_check(root.get_visible_rect().encloses(dialog_rect), "result window fits within the viewport")
	bytes = FileAccess.get_file_as_bytes(session.save_path)
	before = session.year.duplicate(true)
	await _click(screen._result_view_village)
	_check(not screen._result_dialog.visible and screen._tabs.current_tab == 7, "native result action opens village and medals")
	await _click(screen._result_button)
	await _click(screen._result_dialog.get_ok_button())
	_check(screen._tabs.current_tab == 0, "back-to-map action returns to the inspector")
	_check(session.year == before and FileAccess.get_file_as_bytes(session.save_path) == bytes, "reopening results and viewing the village do not save or resolve again")
	screen.free()
	var passed: bool = checks.all(func(check: Dictionary): return check["passed"])
	var file: FileAccess = FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"language": language, "resolution": [root.size.x, root.size.y], "checks": checks, "passed": passed}, "  "))
	file.close()
	print("YEAR POLISH NATIVE ", language, " ", root.size, ": ", "PASS" if passed else "FAIL", " ", checks.size(), " checks")
	quit(0 if passed else 1)
