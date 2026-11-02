class_name ResourceFeedback
extends Control
## Presentation-only deltas. HUD totals always show the committed state.
const KEYS: Array[String] = ResourceLedger.KEYS
const LIFETIME: float = 2.4
const TOKEN_LIFETIME: float = 0.65
const MAX_TOKENS: int = 15

var _chips: Dictionary = {}
var _entries: Array[Dictionary] = []
var _reduced_motion: bool = false
var last_changes: Dictionary = {}
var generation: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 80
	set_process(false)


static func capture(state: GameState) -> Dictionary:
	return ResourceLedger.capture(state)


static func difference(before: Dictionary, after: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in KEYS:
		var delta: int = int(after[key]) - int(before[key])
		if delta != 0:
			result[key] = {"before": int(before[key]), "after": int(after[key]), "delta": delta}
	return result


func bind_chips(chips: Dictionary) -> void:
	_chips = chips.duplicate()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_changes(before: Dictionary, after: Dictionary) -> void:
	clear()
	last_changes = difference(before, after)
	if last_changes.is_empty():
		return
	generation += 1
	var groups: Dictionary = {}
	for key: String in last_changes:
		var target: String = "people" if key == "housing" else key
		if not _chips.has(target):
			continue
		var color: Color = Color(ThemeBuilder.palette()["success" if int(last_changes[key]["delta"]) > 0 else "danger"])
		var marker: Control = Control.new()
		marker.name = "ResourceFX_" + key
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marker)
		var halo: Panel = null
		if not groups.has(target):
			halo = Panel.new()
			halo.name = "Halo"
			halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			halo.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(color, 0.13), 7, Color(color, 0.7)))
			marker.add_child(halo)
			groups[target] = true
		var badge: PanelContainer = PanelContainer.new()
		badge.name = "Delta"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style: StyleBoxFlat = ThemeBuilder.box(Color(ThemeBuilder.palette()["panel_inset"]), 7, color)
		style.content_margin_left = 7
		style.content_margin_right = 7
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", style)
		marker.add_child(badge)
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		badge.add_child(row)
		var icon: TextureRect = _icon(key, 19)
		row.add_child(icon)
		var label: Label = Label.new()
		label.name = "SignedDelta"
		label.text = "%+d" % int(last_changes[key]["delta"])
		label.add_theme_font_size_override("font_size", 21)
		label.add_theme_color_override("font_color", color)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		badge.tooltip_text = tr("resourcefx.change") % [tr("resourcefx.housing" if key == "housing" else "resource." + key), int(last_changes[key]["before"]), int(last_changes[key]["after"]), int(last_changes[key]["delta"])]
		var entry: Dictionary = {"key": key, "target": target, "root": marker, "halo": halo, "badge": badge, "color": color, "age": 0.0, "tokens": [], "base": Vector2.ZERO}
		if not _reduced_motion:
			for _index: int in range(3):
				var token: TextureRect = _icon(key, 13)
				token.name = "ResourceToken"
				marker.add_child(token)
				entry["tokens"].append(token)
		_entries.append(entry)
	_layout()
	_update_visuals()
	set_process(true)


func clear() -> void:
	for entry: Dictionary in _entries:
		(entry["root"] as Control).free()
	_entries.clear()
	last_changes.clear()
	set_process(false)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		for entry: Dictionary in _entries:
			_remove_tokens(entry)
	_layout()
	_update_visuals()


func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for index: int in range(_entries.size() - 1, -1, -1):
		var entry: Dictionary = _entries[index]
		entry["age"] = float(entry["age"]) + delta
		if float(entry["age"]) >= LIFETIME:
			(entry["root"] as Control).free()
			_entries.remove_at(index)
	if _entries.is_empty():
		last_changes.clear()
		set_process(false)
		return
	_layout()
	_update_visuals()


func _layout() -> void:
	var right_edges: Dictionary = {}
	for index: int in range(_entries.size() - 1, -1, -1):
		var entry: Dictionary = _entries[index]
		var label: Label = _chips[entry["target"]]
		var rect: Rect2 = (label.get_parent() as Control).get_global_rect()
		var marker: Control = entry["root"]
		marker.position = get_global_transform().affine_inverse() * rect.position
		marker.size = rect.size
		var badge: PanelContainer = entry["badge"]
		badge.size = badge.get_combined_minimum_size()
		badge.pivot_offset = badge.size * 0.5
		var right: float = float(right_edges.get(entry["target"], rect.size.x - 4.0))
		entry["base"] = Vector2(right - badge.size.x, (rect.size.y - badge.size.y) * 0.5)
		right_edges[entry["target"]] = right - badge.size.x - 6.0
		if entry["halo"] != null:
			var halo: Panel = entry["halo"]
			halo.position = Vector2(-4, -4)
			halo.size = rect.size + Vector2(8, 8)


func _update_visuals() -> void:
	for entry: Dictionary in _entries:
		var age: float = float(entry["age"])
		var badge: PanelContainer = entry["badge"]
		var opacity: float = 1.0 if _reduced_motion else 1.0 - smoothstep(LIFETIME - 0.5, LIFETIME, age)
		badge.position = entry["base"] if _reduced_motion else Vector2(entry["base"]) + Vector2(0, -6.0 * minf(age / 1.2, 1.0))
		badge.scale = Vector2.ONE if _reduced_motion else Vector2.ONE * (1.0 + 0.12 * sin(minf(age / 0.42, 1.0) * PI))
		badge.modulate.a = opacity
		if entry["halo"] != null:
			(entry["halo"] as Panel).modulate.a = 0.85 if _reduced_motion else opacity * (0.55 + 0.35 * sin(minf(age / 0.65, 1.0) * PI))
		if age >= TOKEN_LIFETIME:
			_remove_tokens(entry)
		elif not _reduced_motion:
			var progress: float = minf(age / TOKEN_LIFETIME, 1.0)
			var destination: Vector2 = Vector2(entry["base"]) + badge.size * 0.5 - Vector2(6.5, 6.5)
			for index: int in range(entry["tokens"].size()):
				var token: TextureRect = entry["tokens"][index]
				var offset: Vector2 = Vector2(float(index - 1) * 12.0, 18.0)
				var gain: bool = int(last_changes[entry["key"]]["delta"]) > 0
				var from: Vector2 = destination + offset if gain else destination
				var to: Vector2 = destination if gain else destination + offset
				token.position = from.lerp(to, progress) + Vector2(sin(progress * PI) * 5.0, -sin(progress * PI) * 7.0)
				token.modulate = Color(entry["color"], 1.0 - progress)


func _remove_tokens(entry: Dictionary) -> void:
	for token: TextureRect in entry["tokens"]:
		token.free()
	entry["tokens"].clear()


func _icon(key: String, width: int) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/icons/%s.svg" % ("house" if key == "housing" else key))
	icon.custom_minimum_size = Vector2(width, width)
	icon.size = Vector2(width, width)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
