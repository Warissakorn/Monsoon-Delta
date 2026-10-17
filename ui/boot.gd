extends Node

var _screen: Node
var _session: GameSession
var _initial_seed: int = 42
var _language: String = "en"
var _save_path: String = SaveIO.DEFAULT_PATH


func _ready() -> void:
	var options: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var parts := arg.substr(2).split("=", true, 1)
			options[parts[0]] = parts[1]
	if options.has("screenshot") and DisplayServer.get_name() == "headless":
		push_error("Screenshots require a rendering display. Use a normal window or a virtual display.")
		get_tree().quit(2)
		return
	var scene := String(options.get("scene", "menu"))
	if scene not in ["menu", "game", "sandbox"]:
		push_error("Supported scenes: --scene=menu, --scene=game or --scene=sandbox.")
		get_tree().quit(2)
		return
	_language = String(options.get("lang", GamePreferences.read()["language"]))
	if _language not in ["th", "en"]:
		push_error("Supported languages: --lang=th or --lang=en")
		get_tree().quit(2)
		return
	Localization.setup(_language)
	get_window().min_size = Vector2i(1280, 720)
	_initial_seed = SeedUtil.parse_seed_text(String(options.get("seed", str(DataDB.balance().sandbox.default_seed))))
	_save_path = String(options.get("save-path", SaveIO.DEFAULT_PATH))
	get_tree().auto_accept_quit = false
	match scene:
		"menu": _show_menu()
		"game": _start_game({"seed": _initial_seed, "run_mode": String(options.get("run-mode", "classic")), "village_goal": String(options.get("goal", "none"))})
		"sandbox": _show_sandbox()
	if options.has("screenshot"):
		for frame in range(30):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := String(options.screenshot)
		var result := get_viewport().get_texture().get_image().save_png(path)
		if result != OK:
			push_error("Screenshot failed: %s" % error_string(result))
		get_tree().quit(0 if result == OK else 1)


func _replace_screen(next: Node) -> void:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = next
	add_child(next)


func _show_menu(error: String = "") -> void:
	var menu := MainMenu.new()
	menu.initial_seed = _initial_seed
	menu.language = _language
	menu.save_path = _save_path
	menu.start_requested.connect(_start_game)
	menu.continue_requested.connect(_continue_game)
	menu.sandbox_requested.connect(_show_sandbox)
	menu.language_changed.connect(_change_language)
	menu.quit_requested.connect(func(): get_tree().quit())
	_replace_screen(menu)
	if not error.is_empty():
		menu.show_error(error)


func _start_game(config: Dictionary) -> void:
	var next := GameSession.new()
	next.save_path = _save_path
	var error: String = next.start(config)
	if not error.is_empty():
		_show_menu(error)
		return
	_session = next
	_initial_seed = _session.state.seed
	_show_game()


func _show_game() -> void:
	var game := GameScreen.new()
	game.session = _session
	game.menu_requested.connect(_show_menu)
	game.restart_requested.connect(_start_game)
	_replace_screen(game)


func _continue_game() -> void:
	var next := GameSession.new()
	next.save_path = _save_path
	var error: String = next.load_game()
	if not error.is_empty():
		_show_menu(error)
		return
	_session = next
	_initial_seed = _session.state.seed
	_show_game()


func _show_sandbox() -> void:
	var sandbox := preload("res://ui/sandbox_screen.gd").new()
	sandbox.initial_seed = _initial_seed
	sandbox.language = _language
	sandbox.menu_requested.connect(_show_menu)
	_replace_screen(sandbox)


func _change_language(language: String) -> void:
	_language = language
	Localization.change_language(language)
	var error: String = GamePreferences.write({"language": language})
	_show_menu(error)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _screen is GameScreen and _session != null:
			_screen.request_quit()
		else:
			get_tree().quit()
