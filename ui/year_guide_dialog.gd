class_name YearGuideDialog
extends AcceptDialog
## Rules-aware help. Opening, switching chapters and reading never resolves a day.
signal practice_requested()
var _tabs: TabContainer
var _facts: Label
var _extra: Label
var _practice: Button


func _ready() -> void:
	title = tr("yearguide.title")
	exclusive = true
	ok_button_text = tr("action.close")
	_practice = add_button(tr("yearpractice.start"), true, "practice")
	custom_action.connect(func(_action: StringName): hide(); practice_requested.emit.call_deferred())
	var content: VBoxContainer = VBoxContainer.new()
	content.custom_minimum_size = Vector2(690, 520)
	add_child(content)
	_facts = Label.new()
	_facts.custom_minimum_size.x = 650
	_facts.max_lines_visible = 3
	_facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_facts)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_tabs)
	for topic: String in ["daily", "work", "water", "village", "controls"]:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		_tabs.add_child(scroll)
		_tabs.set_tab_title(_tabs.get_tab_count() - 1, tr("yearguide." + topic + ".title"))
		var label: Label = Label.new()
		label.text = tr("yearguide." + topic + ".body")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		scroll.add_child(label)
		if topic == "village":
			_extra = label


func open_for(year: Dictionary, in_practice: bool = false) -> void:
	_practice.visible = not in_practice
	if year.is_empty():
		_facts.text = tr("yearguide.before_start")
	else:
		_facts.text = tr("yearguide.current") % [int(year["day"]), YearGame.food_need(year), maxi(0, int(year["population"]) - YearGame.workers(year)), YearGame.housing(year), YearGame.storage(year)]
	_extra.text = tr("yearguide.village.body") + "\n\n" + tr("yearguide.projects_on" if YearGame.expanded(year) else "yearguide.projects_off") + "\n\n" + tr("yearguide.extra_on" if YearClassic.enabled(year) else "yearguide.extra_off")
	_extra.text += "\n\n" + tr("yearguide.heritage_on" if YearHeritage.enabled(year) else "yearguide.heritage_off")
	popup_centered(Vector2i(960, 650))
