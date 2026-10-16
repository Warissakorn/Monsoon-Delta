extends Node

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
	var scene := String(options.get("scene", "sandbox"))
	if scene != "sandbox":
		push_error("This M2 build supports --scene=sandbox only.")
		get_tree().quit(2)
		return
	var screen := preload("res://ui/sandbox_screen.gd").new()
	screen.initial_seed = SeedUtil.parse_seed_text(String(options.get("seed", str(DataDB.balance().sandbox.default_seed))))
	screen.language = String(options.get("lang", "th"))
	if screen.language not in ["th", "en"]:
		push_error("Supported languages: --lang=th or --lang=en")
		get_tree().quit(2)
		return
	add_child(screen)
	if options.has("screenshot"):
		for frame in range(30):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := String(options.screenshot)
		var result := get_viewport().get_texture().get_image().save_png(path)
		if result != OK:
			push_error("Screenshot failed: %s" % error_string(result))
		get_tree().quit(0 if result == OK else 1)
