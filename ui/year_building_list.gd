class_name YearBuildingList
extends PanelContainer
## Read-only filters and ordering for the village's real buildings, including ruins.

signal inspected(index: int)
const FILTERS: Array[String] = ["all", "homes", "work", "water", "damaged"]
const SORTS: Array[String] = ["location", "age", "condition"]
var rows: VBoxContainer
var filter: OptionButton
var sort: OptionButton
var count_label: Label
var empty_label: Label
var _year: Dictionary = {}


func _ready() -> void:
	theme_type_variation = "CardPanel"
	var content: VBoxContainer = VBoxContainer.new()
	add_child(content)
	var title: Label = Label.new()
	title.text = tr("yearpolish.buildings")
	title.theme_type_variation = "Heading"
	content.add_child(title)
	var controls: HBoxContainer = HBoxContainer.new()
	content.add_child(controls)
	filter = OptionButton.new()
	filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in FILTERS:
		filter.add_item(tr("yearpolish.filter." + id))
	filter.tooltip_text = tr("yearpolish.filter_help")
	controls.add_child(filter)
	sort = OptionButton.new()
	sort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in SORTS:
		sort.add_item(tr("yearpolish.sort." + id))
	sort.tooltip_text = tr("yearpolish.sort_help")
	controls.add_child(sort)
	filter.item_selected.connect(func(_index: int): refresh(_year))
	sort.item_selected.connect(func(_index: int): refresh(_year))
	count_label = Label.new()
	count_label.theme_type_variation = "Caption"
	content.add_child(count_label)
	rows = VBoxContainer.new()
	content.add_child(rows)
	empty_label = Label.new()
	empty_label.text = tr("yearpolish.empty_buildings")
	empty_label.theme_type_variation = "Caption"
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(empty_label)


func refresh(year: Dictionary) -> void:
	_year = year
	visible = YearHeritage.enabled(year)
	if not visible:
		return
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var indices: Array[int] = []
	var total: int = 0
	for index: int in range(year["structures"].size()):
		var kind: String = year["structures"][index]
		if kind.is_empty():
			continue
		total += 1
		var matches: bool = true
		match FILTERS[filter.selected]:
			"homes": matches = kind in ["house", "stilt_house", "raft_house"]
			"work": matches = kind in ["hall", "sawmill", "kiln", "workshop", "camp", "granary"]
			"water": matches = kind in ["gate", "reservoir", "waterwheel", "fish_trap"]
			"damaged": matches = int(year["health"][index]) < 100
		if matches:
			indices.append(index)
	indices.sort_custom(func(a: int, b: int) -> bool:
		if SORTS[sort.selected] == "condition" and year["health"][a] != year["health"][b]:
			return int(year["health"][a]) < int(year["health"][b])
		if SORTS[sort.selected] == "age":
			if (int(year["health"][a]) == 0) != (int(year["health"][b]) == 0):
				return int(year["health"][a]) > 0
			if YearHeritage.age(year, a) != YearHeritage.age(year, b):
				return YearHeritage.age(year, a) > YearHeritage.age(year, b)
		return a < b
	)
	var palette: Dictionary = ThemeBuilder.palette()
	for index: int in indices:
		var tile: Dictionary = year["board"]["tiles"][index]
		var record: Dictionary = YearHeritage.building(year, index)
		var button: Button = Button.new()
		button.name = "BuildingAge_" + str(index)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = tr("year.site." + String(year["structures"][index])) + " (%d,%d) · %d/100\n" % [int(tile["q"]), int(tile["r"]), int(year["health"][index])]
		button.text += tr("yearpolish.ruin") if record.is_empty() else tr("yearheritage.building") % [int(record["built_day"]), YearHeritage.age(year, index), tr("settlement.stage." + str(record["stage"]))]
		if int(year["health"][index]) < 100:
			button.add_theme_color_override("font_color", Color(palette["danger"]))
		button.tooltip_text = tr("yearpolish.inspect_building")
		button.pressed.connect(func(): inspected.emit(index))
		rows.add_child(button)
	count_label.text = tr("yearpolish.building_count") % [indices.size(), total]
	empty_label.visible = indices.is_empty()


func draft() -> Dictionary:
	return {"filter": filter.selected, "sort": sort.selected}


func restore_draft(value: Dictionary) -> void:
	filter.select(clampi(int(value.get("filter", 0)), 0, FILTERS.size() - 1))
	sort.select(clampi(int(value.get("sort", 0)), 0, SORTS.size() - 1))
	refresh(_year)
