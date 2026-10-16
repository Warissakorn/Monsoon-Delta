class_name ThemeBuilder
extends RefCounted

static func palette() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/palette.json"))

static func box(color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func build() -> Theme:
	var p := palette()
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansThai.ttf")
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", Color(p.ink))
	theme.set_color("font_color", "Button", Color(p.ink))
	theme.set_color("font_hover_color", "Button", Color(p.accent))
	theme.set_color("font_pressed_color", "Button", Color(p.background))
	theme.set_color("font_disabled_color", "Button", Color(p.muted).darkened(0.35))
	theme.set_stylebox("normal", "Button", box(Color(p.panel_light), 10))
	theme.set_stylebox("hover", "Button", box(Color(p.panel_light).lightened(0.12), 10, Color(p.accent)))
	theme.set_stylebox("pressed", "Button", box(Color(p.accent), 10))
	theme.set_stylebox("focus", "Button", box(Color.TRANSPARENT, 10, Color(p.accent)))
	theme.set_stylebox("disabled", "Button", box(Color(p.panel), 10))
	theme.set_stylebox("panel", "PanelContainer", box(Color(p.panel, 0.96), 16, Color(p.panel_light)))
	theme.set_stylebox("normal", "LineEdit", box(Color(p.background), 8, Color(p.panel_light)))
	theme.set_stylebox("focus", "LineEdit", box(Color(p.background), 8, Color(p.accent)))
	theme.set_color("font_color", "LineEdit", Color(p.ink))
	theme.set_color("font_placeholder_color", "LineEdit", Color(p.muted))
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	return theme
