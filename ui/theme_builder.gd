class_name ThemeBuilder
extends RefCounted
## Shared lagoon surfaces, rice-paper typography and restrained brass accents.

static func palette() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/palette.json"))


static func box(color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.corner_detail = 12
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func _panel(color: Color, border: Color, raised: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(color, 14, border)
	if raised:
		style.shadow_color = Color("#030c10", 0.32)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0, 5)
	return style


static func _focus(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(Color.TRANSPARENT, 9, color)
	style.draw_center = false
	style.set_border_width_all(2)
	style.set_expand_margin_all(3)
	return style


static func _button_colors(theme: Theme, type_name: String, normal: Color, active: Color, disabled: Color) -> void:
	for key: String in ["font_color", "icon_normal_color"]:
		theme.set_color(key, type_name, normal)
	for key: String in ["font_hover_color", "font_focus_color", "icon_hover_color", "icon_focus_color"]:
		theme.set_color(key, type_name, active)
	for key: String in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		theme.set_color(key, type_name, active)
	for key: String in ["font_disabled_color", "icon_disabled_color"]:
		theme.set_color(key, type_name, disabled)


static func _buttons(theme: Theme, p: Dictionary) -> void:
	var normal: StyleBoxFlat = box(Color(p.panel_light), 8, Color(p.border))
	var hover: StyleBoxFlat = box(Color(p.panel_raised).lightened(0.06), 8, Color(p.border_strong))
	var pressed: StyleBoxFlat = box(Color(p.accent_soft), 8, Color(p.accent))
	var disabled: StyleBoxFlat = box(Color(p.panel_inset), 8, Color(p.border, 0.65))
	for type_name: String in ["Button", "OptionButton"]:
		theme.set_font_size("font_size", type_name, 20)
		_button_colors(theme, type_name, Color(p.ink), Color(p.paper), Color(p.disabled))
		theme.set_stylebox("normal", type_name, normal)
		theme.set_stylebox("hover", type_name, hover)
		theme.set_stylebox("pressed", type_name, pressed)
		theme.set_stylebox("hover_pressed", type_name, pressed)
		theme.set_stylebox("disabled", type_name, disabled)
		theme.set_stylebox("focus", type_name, _focus(Color(p.accent)))
		theme.set_constant("h_separation", type_name, 10)
	theme.set_color("font_pressed_color", "Button", Color(p.accent_hover))
	theme.set_color("font_hover_pressed_color", "Button", Color(p.accent_hover))
	theme.set_constant("arrow_margin", "OptionButton", 16)
	theme.set_constant("modulate_arrow", "OptionButton", 1)
	theme.set_type_variation("CommandButton", "Button")
	for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var compact: StyleBoxFlat = theme.get_stylebox(state_name, "Button").duplicate() as StyleBoxFlat
		compact.content_margin_left = 10
		compact.content_margin_right = 10
		compact.content_margin_top = 8
		compact.content_margin_bottom = 8
		theme.set_stylebox(state_name, "CommandButton", compact)
	theme.set_constant("h_separation", "CommandButton", 6)

	theme.set_type_variation("PrimaryButton", "Button")
	_button_colors(theme, "PrimaryButton", Color(p.ink_dark), Color(p.ink_dark), Color(p.disabled))
	theme.set_stylebox("normal", "PrimaryButton", box(Color(p.accent), 8, Color(p.accent_hover, 0.6)))
	theme.set_stylebox("hover", "PrimaryButton", box(Color(p.accent_hover), 8, Color(p.paper, 0.6)))
	var primary_pressed: StyleBoxFlat = box(Color(p.accent).darkened(0.12), 8, Color(p.accent))
	theme.set_stylebox("pressed", "PrimaryButton", primary_pressed)
	theme.set_stylebox("hover_pressed", "PrimaryButton", primary_pressed)
	theme.set_stylebox("focus", "PrimaryButton", _focus(Color(p.paper)))

	theme.set_type_variation("QuietButton", "Button")
	theme.set_stylebox("normal", "QuietButton", box(Color(p.panel_inset, 0.35), 8, Color(p.border, 0.6)))
	theme.set_stylebox("hover", "QuietButton", box(Color(p.panel_light), 8, Color(p.border_strong)))
	_button_colors(theme, "QuietButton", Color(p.ink), Color(p.paper), Color(p.disabled))

	theme.set_type_variation("DangerButton", "Button")
	_button_colors(theme, "DangerButton", Color(p.danger), Color(p.paper), Color(p.disabled))
	theme.set_stylebox("normal", "DangerButton", box(Color(p.danger, 0.08), 8, Color(p.danger, 0.35)))
	theme.set_stylebox("hover", "DangerButton", box(Color(p.danger, 0.16), 8, Color(p.danger, 0.7)))
	var danger_pressed: StyleBoxFlat = box(Color(p.danger, 0.25), 8, Color(p.danger))
	theme.set_stylebox("pressed", "DangerButton", danger_pressed)
	theme.set_stylebox("hover_pressed", "DangerButton", danger_pressed)


static func _inputs(theme: Theme, p: Dictionary) -> void:
	for type_name: String in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", type_name, box(Color(p.panel_inset), 8, Color(p.border)))
		theme.set_stylebox("focus", type_name, _focus(Color(p.accent)))
		theme.set_stylebox("read_only", type_name, box(Color(p.panel), 8, Color(p.border, 0.7)))
		theme.set_color("font_color", type_name, Color(p.ink))
		theme.set_color("font_placeholder_color", type_name, Color(p.disabled))
		theme.set_color("font_uneditable_color", type_name, Color(p.muted))
		theme.set_color("caret_color", type_name, Color(p.accent_hover))
		theme.set_color("selection_color", type_name, Color(p.accent, 0.32))
		theme.set_color("font_selected_color", type_name, Color(p.paper))
	for type_name: String in ["CheckBox", "CheckButton"]:
		_button_colors(theme, type_name, Color(p.ink), Color(p.accent_hover), Color(p.disabled))


static func _popups(theme: Theme, p: Dictionary) -> void:
	theme.set_stylebox("panel", "PopupMenu", _panel(Color(p.panel_raised), Color(p.border_strong), true))
	theme.set_stylebox("panel", "PopupPanel", _panel(Color(p.panel_raised), Color(p.border_strong), true))
	var hover: StyleBoxFlat = box(Color(p.accent_soft), 6, Color(p.accent, 0.4))
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8
	theme.set_stylebox("hover", "PopupMenu", hover)
	theme.set_color("font_color", "PopupMenu", Color(p.ink))
	theme.set_color("font_hover_color", "PopupMenu", Color(p.accent_hover))
	theme.set_color("font_disabled_color", "PopupMenu", Color(p.disabled))
	theme.set_color("font_accelerator_color", "PopupMenu", Color(p.muted))
	theme.set_color("font_separator_color", "PopupMenu", Color(p.muted))
	theme.set_font_size("font_size", "PopupMenu", 20)
	theme.set_constant("v_separation", "PopupMenu", 12)
	theme.set_constant("h_separation", "PopupMenu", 14)
	var separator := StyleBoxLine.new()
	separator.color = Color(p.border)
	separator.thickness = 1
	theme.set_stylebox("separator", "PopupMenu", separator)
	theme.set_stylebox("labeled_separator_left", "PopupMenu", separator)
	theme.set_stylebox("labeled_separator_right", "PopupMenu", separator)
	theme.set_stylebox("panel", "TooltipPanel", _panel(Color(p.panel_inset), Color(p.border_strong), true))
	theme.set_color("font_color", "TooltipLabel", Color(p.paper))
	theme.set_font_size("font_size", "TooltipLabel", 18)


static func _scrollbars(theme: Theme, p: Dictionary) -> void:
	var track: StyleBoxFlat = box(Color(p.background, 0.65), 5)
	track.set_content_margin_all(5)
	var grabber: StyleBoxFlat = box(Color(p.border_strong), 5)
	grabber.set_content_margin_all(5)
	var highlight: StyleBoxFlat = box(Color(p.muted), 5)
	highlight.set_content_margin_all(5)
	var pressed: StyleBoxFlat = box(Color(p.accent), 5)
	pressed.set_content_margin_all(5)
	var transparent_image: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	transparent_image.fill(Color.TRANSPARENT)
	var empty_icon: ImageTexture = ImageTexture.create_from_image(transparent_image)
	for type_name: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type_name, track)
		theme.set_stylebox("scroll_focus", type_name, _focus(Color(p.accent)))
		theme.set_stylebox("grabber", type_name, grabber)
		theme.set_stylebox("grabber_highlight", type_name, highlight)
		theme.set_stylebox("grabber_pressed", type_name, pressed)
		for icon_name: String in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			theme.set_icon(icon_name, type_name, empty_icon)


static func build() -> Theme:
	var p: Dictionary = palette()
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansThai.ttf")
	theme.default_font_size = 20
	theme.set_constant("line_spacing", "Label", 4)
	theme.set_color("font_color", "Label", Color(p.ink))
	for type_name: String in ["Title", "Heading", "Caption", "Kicker", "Metric"]:
		theme.set_type_variation(type_name, "Label")
	theme.set_font_size("font_size", "Title", 52)
	theme.set_font_size("font_size", "Heading", 28)
	theme.set_font_size("font_size", "Caption", 17)
	theme.set_font_size("font_size", "Kicker", 15)
	theme.set_font_size("font_size", "Metric", 30)
	theme.set_color("font_color", "Title", Color(p.paper))
	theme.set_color("font_color", "Caption", Color(p.muted))
	theme.set_color("font_color", "Kicker", Color(p.accent))
	theme.set_color("font_color", "Metric", Color(p.paper))
	theme.set_stylebox("panel", "PanelContainer", _panel(Color(p.panel, 0.97), Color(p.border)))
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _panel(Color(p.panel_raised, 0.98), Color(p.border_strong, 0.8), true))
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", box(Color(p.panel_inset, 0.85), 10, Color(p.border, 0.8)))
	_buttons(theme, p)
	_inputs(theme, p)
	_popups(theme, p)
	_scrollbars(theme, p)
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	return theme
