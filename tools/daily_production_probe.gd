extends SceneTree
## Native fixture probe: real GUI mouse events, isolated paths, no gameplay edits.

class MenuBoot extends "res://ui/boot.gd":
	func _ready() -> void:
		pass

var _screen: DailyScreen
var _checks: Array[Dictionary] = []
var _out: String = "/tmp/monsoon-daily-probe"
var _language: String = "en"


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, name: String) -> void:
	_checks.append({"name": name, "passed": condition})
	if not condition:
		printerr("FAIL " + name)


func _frames(count: int = 3) -> void:
	for index: int in range(count):
		await process_frame


func _click(button: Button) -> void:
	await _frames()
	_check(button.is_visible_in_tree() and not button.disabled, "clickable: " + button.text)
	var position: Vector2 = button.get_global_rect().get_center() * Vector2(root.size) / root.get_visible_rect().size
	Input.warp_mouse(position)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await _frames(1)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(1)


func _order(id: String, batches: int = 1) -> void:
	var entry: Dictionary = _screen._orders[id]
	_screen._tabs.current_tab = int(entry["tab"])
	entry["amount"].value = batches
	await _frames()
	entry["scroll"].ensure_control_visible(entry["button"])
	await _frames()
	await _click(entry["button"])
	var found: bool = false
	for job: Dictionary in _screen.session.daily["jobs"]:
		if job["id"] == id:
			found = true
	_check(found, "order accepted: " + id)


func _advance() -> void:
	await create_timer(0.42).timeout
	await _click(_screen._advance_buttons[2])


func _shot(name: String) -> void:
	await _frames()
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, "screenshot: " + name)


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out = arg.trim_prefix("--out-dir=")
		if arg.begins_with("--lang="):
			_language = arg.trim_prefix("--lang=")
	if DisplayServer.get_name() == "headless":
		printerr("Use a native rendering display for this probe.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Localization.setup(_language)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var checkpoint: String = _out.path_join("normal.json")
	_check(SaveIO.save(GameFlow.new_game({"seed": 42}), checkpoint) == "", "normal fixture saved")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(checkpoint)
	var daily_path: String = _out.path_join("daily.json")
	if FileAccess.file_exists(daily_path):
		DirAccess.remove_absolute(daily_path)
	_screen = DailyScreen.new()
	_screen.session = DailySession.new()
	_screen.session.save_path = daily_path
	root.add_child(_screen)
	await _frames(10)
	await _shot("initial-" + _language)
	await _order("build_sawmill")
	await _order("build_kiln")
	await _order("gather_wood", 6)
	await _advance()
	_check(int(_screen.session.daily["day"]) == 2, "stop at sawmill completion")
	await _advance()
	_check(int(_screen.session.daily["day"]) == 3, "stop at kiln completion")
	await _order("saw_planks", 4)
	await _order("fire_bricks", 3)
	for index: int in range(3):
		await _advance()
	_check(int(_screen.session.daily["day"]) == 12, "crafting orders finish")
	_check(int(_screen.session.daily["knowledge"]) == 1, "first challenge grants knowledge")
	await _order("build_foundation")
	await _advance()
	_check(int(_screen.session.daily["knowledge"]) == 1, "foundation spends and earns next reward")
	await _order("build_barrier")
	await _advance()
	_check(int(_screen.session.daily["day"]) == 18, "barrier built before floods")
	await _shot("prepared-" + _language)
	var resumed: DailySession = DailySession.new()
	resumed.save_path = daily_path
	_check(resumed.load_prototype() == "", "prototype reload succeeds")
	_check(resumed.daily == _screen.session.daily, "prototype reload exact")
	await _advance()
	_check(int(_screen.session.daily["day"]) == 21, "stop at first flood warning")
	# A real second click within the guard cannot advance another day.
	await _click(_screen._advance_buttons[2])
	_check(int(_screen.session.daily["day"]) == 21, "burst input blocked")
	for index: int in range(5):
		await _advance()
	_check(_screen.session.daily["outcome"] == "won", "complete reward chain survives both floods")
	_check(FileAccess.get_file_as_bytes(checkpoint) == bytes, "normal checkpoint preserved")
	await _shot("complete-" + _language)
	_screen.free()
	var boot: MenuBoot = MenuBoot.new()
	boot._language = _language
	boot._save_path = checkpoint
	root.add_child(boot)
	boot._show_menu()
	await _frames()
	var menu: MainMenu = boot._screen as MainMenu
	var daily_button: Button = menu.find_child("DailyPrototype", true, false) as Button
	_check(daily_button != null, "daily entry exists in real menu")
	if daily_button != null:
		var ancestor: Node = daily_button.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				ancestor.ensure_control_visible(daily_button)
			ancestor = ancestor.get_parent()
		await _click(daily_button)
		_check(boot._screen is DailyScreen, "menu click opens daily scene")
	_check(FileAccess.get_file_as_bytes(checkpoint) == bytes, "menu transition preserves normal save")
	boot.free()
	var failed: int = 0
	for check: Dictionary in _checks:
		if not check["passed"]:
			failed += 1
	var report: FileAccess = FileAccess.open(_out.path_join("report-" + _language + ".json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"language": _language, "checks": _checks, "failed": failed}, "  "))
	report.close()
	print("Daily production native: %d checks, %d failed" % [_checks.size(), failed])
	quit(0 if failed == 0 else 1)
