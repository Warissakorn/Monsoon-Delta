extends TestCase

const SandboxScreen = preload("res://ui/sandbox_screen.gd")


func _new_screen() -> SandboxScreen:
	var screen := SandboxScreen.new()
	screen.language = "en"
	screen.initial_seed = 42
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.set_process(false)
	return screen


func _space_press() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = true
	return event


func _reset_button(screen: SandboxScreen) -> Button:
	for node: Node in screen.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == "Reset seed":
			return button
	return null


func test_reset_button_releases_seed_focus_and_restores_space_shortcut() -> void:
	var screen: SandboxScreen = _new_screen()
	screen._step_water()
	assert_eq(screen.rain_steps, 1, "fixture starts after one simulation")
	screen.seed_input.grab_focus()
	assert_true(screen.seed_input.has_focus(), "seed field must hold keyboard focus")
	var reset: Button = _reset_button(screen)
	assert_true(reset != null, "Reset seed button is available")
	if reset != null:
		reset.pressed.emit()
		assert_eq(screen.rain_steps, 0, "the real button callback resets the map")
		assert_true(not screen.seed_input.has_focus(), "button click ends seed editing")
		screen._unhandled_input(_space_press())
		assert_eq(screen.rain_steps, 1, "Space simulates rain after resetting")
	screen.free()


func test_space_while_editing_seed_keeps_simulation_unchanged() -> void:
	var screen: SandboxScreen = _new_screen()
	screen.seed_input.grab_focus()
	assert_true(screen.seed_input.has_focus(), "seed field must hold keyboard focus")
	var before: Dictionary = screen.state.to_dict()
	screen._unhandled_input(_space_press())
	assert_eq(screen.rain_steps, 0, "typing Space must not simulate rain")
	assert_eq(screen.state.to_dict(), before, "seed editing leaves the game state untouched")
	assert_true(screen.seed_input.has_focus(), "keyboard input continues seed editing")
	screen.free()


func test_click_outside_board_releases_seed_focus_without_editing_terrain() -> void:
	var screen: SandboxScreen = _new_screen()
	screen.seed_input.grab_focus()
	assert_true(screen.seed_input.has_focus(), "seed field must hold keyboard focus")
	var before: Dictionary = screen.state.to_dict()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(-100, -100)
	click.global_position = click.position
	assert_eq(screen.board.pick(screen.camera_rig.get_camera(), click.position), null, "fixture click misses the board")
	screen._unhandled_input(click)
	assert_true(not screen.seed_input.has_focus(), "clicking outside the seed field ends editing")
	assert_eq(screen.state.to_dict(), before, "an off-board click cannot edit terrain or water")
	assert_eq(screen.rain_steps, 0)
	screen.free()
