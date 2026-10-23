extends TestCase
## Practice selection is independent of the player's normal Continue checkpoint.

const PATH: String = "user://tests/river_school_menu/checkpoint.json"
const SETTINGS: String = "user://tests/river_school_menu/settings.json"
const IDS: Array[String] = ["river_school_01", "river_school_03"]


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	SaveIO.delete_save(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	Localization.setup("en")


func _menu(language: String = "en") -> MainMenu:
	Localization.setup(language)
	var menu: MainMenu = MainMenu.new()
	menu.save_path = PATH
	menu.language = language
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	return menu


func _translated(key: String) -> String:
	return String(TranslationServer.translate(key))


func _labels(node: Node) -> String:
	var result: PackedStringArray = []
	for child: Node in node.get_children():
		if child is Label:
			result.append(child.text)
		result.append(_labels(child))
	return "\n".join(result)


func test_school_page_is_explicit_localized_and_focuses_the_first_available_lesson() -> void:
	for language: String in ["en", "th"]:
		var menu: MainMenu = _menu(language)
		assert_true(menu._school_button.is_visible_in_tree())
		assert_eq(menu._school_button.text, _translated("school.title"))
		assert_true(not menu._school.visible)
		menu._school_button.pressed.emit()
		assert_true(menu._school.is_visible_in_tree())
		assert_true(not menu._home.visible and not menu._setup.visible and not menu._credits.visible)
		var first: Button = menu._school.find_child("Lesson_river_school_01", true, false) as Button
		assert_true(first != null)
		assert_eq(menu.get_viewport().gui_get_focus_owner(), first)
		var labels: String = _labels(menu._school)
		assert_true(labels.contains(_translated("school.no_checkpoint")))
		for id: String in IDS:
			assert_true(labels.contains(_translated("school." + id + ".name")))
			assert_true(labels.contains(_translated("school." + id + ".goal")))
			assert_true(labels.contains(_translated("school." + id + ".prepared")))
		assert_true(not FileAccess.file_exists(PATH))
		menu.free()


func test_lesson_buttons_emit_only_the_selected_id_without_overwrite_confirmation() -> void:
	var player: GameState = GameFlow.new_game({"seed": 71, "ruleset": "bracing_moisture_v1"})
	assert_eq(SaveIO.save(player, PATH), "")
	var before: Dictionary = player.to_dict()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var balance: Dictionary = DataDB.balance().duplicate(true)
	var menu: MainMenu = _menu()
	var lessons: Array[String] = []
	var starts: Array[Dictionary] = []
	menu.lesson_requested.connect(func(id: String): lessons.append(id))
	menu.start_requested.connect(func(config: Dictionary): starts.append(config))
	menu.show_school()
	for id: String in IDS:
		var button: Button = menu._school.find_child("Lesson_" + id, true, false) as Button
		assert_true(button != null)
		if button == null:
			continue
		button.pressed.emit()
		assert_eq(lessons[-1], id)
		assert_true(not menu._overwrite_dialog.visible, "practice never requests replacement of a normal run")
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_eq(lessons, IDS)
	assert_true(starts.is_empty())
	assert_eq(player.to_dict(), before, "lesson selection cannot change the run or its RNG")
	assert_eq(DataDB.balance(), balance)
	menu.free()


func test_back_and_setup_navigation_keep_normal_continue_available_and_exact() -> void:
	assert_eq(SaveIO.save(GameFlow.new_game({"seed": 72}), PATH), "")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var menu: MainMenu = _menu()
	var continued: Array[bool] = []
	menu.continue_requested.connect(func(): continued.append(true))
	for destination: Control in [menu._school, menu._home, menu._setup, menu._school, menu._credits, menu._home]:
		menu._show_page(destination)
		for page: Control in [menu._home, menu._school, menu._setup, menu._credits]:
			assert_eq(page.visible, page == destination, "only the requested page remains visible")
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	assert_true(menu._continue_button.is_visible_in_tree())
	menu._continue_button.pressed.emit()
	assert_eq(continued, [true])
	assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	menu.free()


func test_enter_activation_cannot_also_resolve_the_new_lessons_first_turn() -> void:
	var menu: MainMenu = _menu()
	var screens: Array[RiverSchoolScreen] = []
	var expected: Array[Dictionary] = []
	menu.lesson_requested.connect(func(id: String):
		var lesson: RiverSchoolRun = RiverSchoolRun.new()
		assert_true(lesson.start(id))
		expected.append(lesson.session.state.to_dict())
		var root: Window = (Engine.get_main_loop() as SceneTree).root
		root.remove_child(menu)
		menu.queue_free()
		var screen: RiverSchoolScreen = RiverSchoolScreen.new()
		screen.lesson = lesson
		screen.preferences_path = SETTINGS
		root.add_child(screen)
		screen.set_process(false)
		screens.append(screen)
	)
	menu.show_school()
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)
	assert_eq(screens.size(), 1, "the focused lesson button receives the real activation event")
	if not screens.is_empty():
		assert_eq(screens[0].session.state.to_dict(), expected[0])
		assert_eq(screens[0].lesson.turns_resolved, 0)
		assert_eq(screens[0].session.state.turn, 1)
		assert_true(not FileAccess.file_exists(PATH))
		screens[0].free()
	else:
		menu.free()
