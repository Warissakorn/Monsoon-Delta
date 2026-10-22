extends Node

var _screen: Node
var _session: GameSession
var _initial_seed: int = 42
var _initial_difficulty: int = 0
var _initial_ruleset: String = "legacy"
var _language: String = "en"
var _save_path: String = SaveIO.DEFAULT_PATH


func _ready() -> void:
	var options: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg == "--ruleset":
			_reject_ruleset("")
			return
		if arg == "--difficulty":
			_reject_difficulty("")
			return
		if arg.begins_with("--") and "=" in arg:
			var parts := arg.substr(2).split("=", true, 1)
			if parts[0] == "ruleset":
				if parts[1] not in ["legacy", "bracing_v1"]:
					_reject_ruleset(parts[1])
					return
				_initial_ruleset = parts[1]
			if parts[0] == "difficulty":
				var difficulty: int = _parse_difficulty(parts[1])
				if difficulty < 0:
					_reject_difficulty(parts[1])
					return
				_initial_difficulty = difficulty
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
	_initial_seed = SeedUtil.parse_seed_text(String(options.get("seed", str(int(DataDB.balance().sandbox.default_seed)))))
	_save_path = String(options.get("save-path", SaveIO.DEFAULT_PATH))
	get_tree().auto_accept_quit = false
	match scene:
		"menu": _show_menu()
		"game": _start_game({"seed": _initial_seed, "difficulty": _initial_difficulty, "ruleset": _initial_ruleset, "run_mode": String(options.get("run-mode", "classic")), "village_goal": String(options.get("goal", "none"))})
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


static func _parse_difficulty(value: String) -> int:
	# Check decimal syntax and bounds before converting: int() alone truncates
	# malformed text and can overflow on a very long command-line value.
	if value.is_empty():
		return -1
	for position: int in range(value.length()):
		var character: int = value.unicode_at(position)
		if character < 48 or character > 57:
			return -1
	var digits: String = value.lstrip("0")
	if digits.is_empty():
		return 0
	if digits.length() > 2 or (digits.length() == 2 and digits != "10"):
		return -1
	return int(digits)


func _reject_ruleset(value: String) -> void:
	printerr("Invalid --ruleset=%s. Use --ruleset=legacy or --ruleset=bracing_v1." % value)
	get_tree().quit(2)


func _reject_difficulty(value: String) -> void:
	printerr("Invalid --difficulty=%s. Use --difficulty=N with an integer from 0 to 10." % value)
	get_tree().quit(2)


func _replace_screen(next: Node) -> void:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = next
	add_child(next)


func _show_menu(error: String = "") -> void:
	var menu := MainMenu.new()
	menu.initial_seed = _initial_seed
	menu.initial_difficulty = _initial_difficulty
	menu.initial_ruleset = _initial_ruleset
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
	var new_run: Dictionary = config.duplicate(true)
	new_run["living_village"] = true
	var error: String = next.start(new_run)
	if not error.is_empty():
		_show_menu(error)
		return
	_session = next
	_initial_seed = _session.state.seed
	_initial_difficulty = _session.state.difficulty
	_initial_ruleset = _session.state.ruleset
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
	_initial_difficulty = _session.state.difficulty
	_initial_ruleset = _session.state.ruleset
	_show_game()


func _show_sandbox() -> void:
	var sandbox := preload("res://ui/sandbox_screen.gd").new()
	sandbox.initial_seed = _initial_seed
	sandbox.language = _language
	sandbox.menu_requested.connect(_show_menu)
	_replace_screen(sandbox)


func _change_language(language: String) -> void:
	if _screen is MainMenu:
		_initial_ruleset = "bracing_v1" if _screen._bracing_toggle.button_pressed else "legacy"
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
