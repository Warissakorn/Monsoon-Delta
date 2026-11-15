class_name YearScreen
extends Control

signal menu_requested()
signal language_requested()
var initial_setup: bool = false
var _leave_confirmation: ConfirmationDialog
var _quit_after_confirm: bool = false
var _settings: AcceptDialog
var _advance_confirmation: ConfirmationDialog
var _pending_days: int = 1
var _history: Label
var _history_choice: OptionButton
var _history_rows: VBoxContainer
var _history_day: int = -1
var _history_return: Button
var _history_view: Dictionary = {}
var _history_selected: int = -1
var _classic: CheckBox
var _irrigation: OptionButton
var _try_button: Button
var _order_confirmation: ConfirmationDialog
var _order_snapshot: Dictionary = {}
var _pending_order: Dictionary = {}
var _impact_button: Button
var _impact_tile: int = -1
var _review_impacts: Array[Dictionary] = []
var _leader: OptionButton
var _difficulty: SpinBox
var _heritage_button: Button
var _heritage_panel: VBoxContainer
var _heritage_state: Label
var _heritage_goal: Label
var _heritage_buildings: VBoxContainer
var _result_button: Button
var _result_dialog: AcceptDialog
var _food_plan: Label
var _campaign_years: OptionButton
var _trial_horizon: OptionButton
var _area_button: Button
var _area_dialog: AcceptDialog
var _area_panel: YearAreaDevelopmentPanel
var _risk_choice: OptionButton
var _advance_text: Label
var _area_scroll: ScrollContainer
var _order_text: Label
var session: YearSession
var initial_seed: int = 42
var initial_difficulty: int = 0
var initial_goal: String = "none"
var initial_project: String = "food"
var board: YearBoard
var selected: int = -1
var _plan: Dictionary = {}
var _advice_text: Label
var _advice_button: Button
var _advice_card: PanelContainer
var _planning_assumption: Label
var _planning_rows: VBoxContainer
var _queue_list: VBoxContainer
var _queue_filter: OptionButton
var _queue_summary: Label
var _resource_chips: Dictionary = {}
var _resource_feedback: ResourceFeedback
var _progress: ProgressBar
var _status: Label
var _resources: Label
var _forecast: Label
var _inspection: Label
var _recipe: Label
var _reason: Label
var _messages: Label
var _summary: Label
var _notice: Label
var _latest_notice: String = ""
var _tabs: TabContainer
var _group: OptionButton
var _action: OptionButton
var _batches: SpinBox
var _repeat: CheckBox
var _direction: OptionButton
var _order_button: Button
var _gate_button: Button
var _queue: VBoxContainer
var _research: Dictionary = {}
var _challenges: Label
var _preview: CheckBox
var _time_buttons: Array[Button] = []
var _undo: Button
var _redo: Button
var _restart: ConfirmationDialog
var _new_button: Button
var _seed: LineEdit
var _goal: OptionButton
var _project: OptionButton
var _village_project: OptionButton
var _project_button: Button
var _project_text: Label
var _policy: HBoxContainer
var _stop_at: SpinBox
var _reserve: SpinBox
var _last_advance: int = -1000
var _log: Array[String] = []
var _predicted: Dictionary = {}

const GROUPS: Array[String] = ["food", "materials", "build", "land"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ThemeBuilder.build()
	if session == null:
		session = YearSession.new()
	if session.year.is_empty():
		var error: String = session.load_year()
		if error == "msg.no_save" and not initial_setup:
			if session is TransportSession:
				error = session.start_year(initial_seed, initial_goal, initial_project)
			else:
				error = session.start_campaign(initial_seed, initial_goal, initial_project, "farmer", initial_difficulty)
		if not error.is_empty() and error != "msg.no_save":
			_log.append(tr(error))
	var background: ColorRect = ColorRect.new()
	background.color = Color("#0b2128")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	margin.add_child(root)
	var nav: HBoxContainer = HBoxContainer.new()
	root.add_child(nav)
	nav.add_child(_button("menu.back", _request_menu))
	nav.add_child(_button("menu.settings", func(): _settings.popup_centered(Vector2i(600, 260))))
	_new_button = _button("year.new", func(): _restart.popup_centered(Vector2i(650, 650)))
	nav.add_child(_new_button)
	_heritage_button = _button("yearheritage.open", func(): _tabs.current_tab = 7)
	_heritage_button.hide()
	nav.add_child(_heritage_button)
	nav.add_child(_button("daily.retry_save", func(): session.checkpoint_year(); _refresh()))
	var title: Label = _label(tr(_title_key()), "Heading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(title)
	_status = _label("")
	root.add_child(_status)
	_resources = _label("")
	root.add_child(_resources)
	_resources.hide()
	var chips: HFlowContainer = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 18)
	root.add_child(chips)
	for key: String in ["people", "labor", "food", "wood", "stone", "clay", "planks", "bricks", "fiber", "kits"]:
		var chip: HBoxContainer = HBoxContainer.new()
		chips.add_child(chip)
		var icon_key: String = key
		var icon: TextureRect = TextureRect.new()
		icon.texture = load("res://assets/icons/" + icon_key + ".svg")
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip.add_child(icon)
		var value: Label = _label("")
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		chip.add_child(value)
		_resource_chips[key] = value
	_resource_feedback = ResourceFeedback.new()
	_resource_feedback.keys.assign(["people", "labor", "housing", "food", "wood", "stone", "clay", "planks", "bricks", "fiber", "kits"])
	add_child(_resource_feedback)
	_resource_feedback.bind_chips(_resource_chips)
	_progress = ProgressBar.new()
	_progress.max_value = 365
	_progress.custom_minimum_size.y = 8
	_progress.show_percentage = false
	root.add_child(_progress)
	var time: HBoxContainer = HBoxContainer.new()
	root.add_child(time)
	for days: int in [1, 7, 365]:
		var button: Button = _button("daily.next_event" if days == 365 else ("daily.day" if days == 1 else "daily.week"), _request_advance.bind(days))
		time.add_child(button)
		_time_buttons.append(button)
	_undo = _button("daily.undo", _undo_plan)
	time.add_child(_undo)
	_redo = _button("daily.redo", _redo_plan)
	time.add_child(_redo)
	_preview = CheckBox.new()
	_preview.text = tr("year.preview")
	_preview.set_pressed_no_signal(true)
	_preview.toggled.connect(func(_enabled: bool): _refresh_selection())
	time.add_child(_preview)
	_forecast = _label("", "Caption")
	root.add_child(_forecast)
	_notice = _label("", "Caption")
	_notice.max_lines_visible = 2
	root.add_child(_notice)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	var map_column: VBoxContainer = VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_column.size_flags_stretch_ratio = 1.3
	columns.add_child(map_column)
	_advice_card = PanelContainer.new()
	_advice_card.theme_type_variation = "CardPanel"
	var advice: VBoxContainer = VBoxContainer.new()
	_advice_card.add_child(advice)
	advice.add_child(_label(tr("yearplan.advisor"), "Caption"))
	_advice_text = _label("")
	_advice_text.max_lines_visible = 2
	advice.add_child(_advice_text)
	_advice_button = _button("yearplan.prepare", _act_on_advice)
	advice.add_child(_advice_button)
	board = _make_board()
	board.custom_minimum_size = Vector2(500, 320)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.tile_selected.connect(select_tile)
	board.cancel_requested.connect(_cancel_tool)
	map_column.add_child(board)
	var map_tools: HBoxContainer = HBoxContainer.new()
	map_column.add_child(map_tools)
	map_tools.add_child(_button("exp.zoom_out", func(): board.zoom_by(0.8)))
	map_tools.add_child(_button("exp.zoom_in", func(): board.zoom_by(1.25)))
	map_tools.add_child(_button("exp.map_fit", func(): board.fit_map()))
	map_tools.add_child(_button("exp.map_focus", func(): board.focus_selected()))
	if board is YearBoard3D:
		map_tools.add_child(_button("year3d.rotate_left", func(): (board as YearBoard3D).rotate_view(-1)))
		map_tools.add_child(_button("year3d.rotate_right", func(): (board as YearBoard3D).rotate_view(1)))
		map_tools.add_child(_button("year3d.levels", func(): (board as YearBoard3D).toggle_labels()))
	map_column.add_child(_label(tr("year3d.help" if board is YearBoard3D else "exp.map_help"), "Caption"))
	_summary = _label("", "Caption")
	map_column.add_child(_summary)
	var tabs: TabContainer = TabContainer.new()
	_tabs = tabs
	tabs.custom_minimum_size.x = 460 if get_viewport_rect().size.x < 1500 else 650
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side_column: VBoxContainer = VBoxContainer.new()
	side_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(side_column)
	side_column.add_child(_advice_card)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_column.add_child(tabs)
	var actions: VBoxContainer = _tab(tabs, "year.actions")
	_inspection = _label("")
	actions.add_child(_inspection)
	_area_button = _button("yeararea.open", open_area_development)
	_area_button.visible = not session is TransportSession
	actions.add_child(_area_button)
	_group = OptionButton.new()
	for group: String in GROUPS:
		_group.add_item(tr("year.group." + group))
	actions.add_child(_group)
	_group.item_selected.connect(func(_index: int): _populate_actions())
	_action = OptionButton.new()
	actions.add_child(_action)
	_action.item_selected.connect(func(_index: int): _refresh_selection())
	_recipe = _label("", "Caption")
	actions.add_child(_recipe)
	var quantity: HBoxContainer = HBoxContainer.new()
	actions.add_child(quantity)
	_batches = SpinBox.new()
	_batches.min_value = 1
	_batches.max_value = 100
	_batches.value = 1
	_batches.custom_minimum_size.x = 130
	quantity.add_child(_batches)
	_repeat = CheckBox.new()
	_repeat.text = tr("year.repeat")
	quantity.add_child(_repeat)
	_repeat.toggled.connect(func(enabled: bool):
		if enabled:
			_batches.value = 1
		_batches.editable = not enabled
		_refresh_selection()
	)
	_batches.value_changed.connect(func(_value: float): _refresh_selection())
	_policy = HBoxContainer.new()
	actions.add_child(_policy)
	_policy.add_child(_label(tr("exp.stop_at"), "Caption"))
	_stop_at = SpinBox.new()
	_stop_at.max_value = 100000
	_stop_at.tooltip_text = tr("exp.policy_help")
	_policy.add_child(_stop_at)
	_policy.add_child(_label(tr("exp.reserve"), "Caption"))
	_reserve = SpinBox.new()
	_reserve.max_value = 100000
	_reserve.tooltip_text = tr("exp.policy_help")
	_policy.add_child(_reserve)
	_stop_at.value_changed.connect(func(_value: float): _refresh_selection())
	_reserve.value_changed.connect(func(_value: float): _refresh_selection())
	_direction = OptionButton.new()
	for direction: String in ["e", "ne", "nw", "w", "sw", "se"]:
		_direction.add_item(tr("year.direction." + direction))
	actions.add_child(_direction)
	_direction.item_selected.connect(func(_index: int): _refresh_selection())
	_order_button = _button("year.order", _order)
	actions.add_child(_order_button)
	_try_button = _button("yeararea.preview", _try_order)
	_trial_horizon = OptionButton.new()
	_trial_horizon.add_item(tr("yearreview.seven"))
	_trial_horizon.add_item(tr("yearreview.until_complete"))
	_trial_horizon.visible = not session is TransportSession
	actions.add_child(_trial_horizon)
	actions.add_child(_try_button)
	_history_return = _button("yearplus.return_history", _return_history)
	_history_return.hide()
	actions.add_child(_history_return)
	_irrigation = OptionButton.new()
	for choice: String in Irrigation.POLICIES:
		_irrigation.add_item(tr("yearplus.policy." + choice))
	_irrigation.item_selected.connect(func(index: int): _edit("irrigation", Irrigation.POLICIES[index]))
	actions.add_child(_irrigation)
	_gate_button = _button("year.gate", func(): _edit("gate"))
	actions.add_child(_gate_button)
	_reason = _label("", "Caption")
	actions.add_child(_reason)
	actions.add_child(_label(tr("year.order_help"), "Caption"))
	_queue = _tab(tabs, "year.work")
	_queue_summary = _label("", "Caption")
	_queue.add_child(_queue_summary)
	_queue_filter = OptionButton.new()
	for kind: String in ["all", "working", "blocked", "paused"]:
		_queue_filter.add_item(tr("yearplan.filter." + kind))
	_queue_filter.item_selected.connect(func(_index: int): _refresh_queue())
	_queue.add_child(_queue_filter)
	_queue_list = VBoxContainer.new()
	_queue.add_child(_queue_list)
	var learning: VBoxContainer = _tab(tabs, "year.research")
	learning.add_child(_label(tr("year.research_help"), "Caption"))
	for id: String in YearGame.config()["research"]:
		var button: Button = _button("year.research." + id, _learn.bind(id))
		button.tooltip_text = tr("year.research." + id + "_desc")
		learning.add_child(button)
		learning.add_child(_label(tr("year.research." + id + "_desc"), "Caption"))
		_research[id] = button
	var challenges: VBoxContainer = _tab(tabs, "year.challenges")
	_challenges = _label("")
	challenges.add_child(_challenges)
	var planning: VBoxContainer = _tab(tabs, "year.food_plan")
	_food_plan = _label("")
	planning.add_child(_food_plan)
	_planning_assumption = _label(tr("yearplan.assumption"), "Caption")
	planning.add_child(_planning_assumption)
	_planning_rows = VBoxContainer.new()
	planning.add_child(_planning_rows)
	var history: VBoxContainer = _tab(tabs, "year.history")
	_history_choice = OptionButton.new()
	_history_choice.item_selected.connect(func(index: int):
		_history_day = int(_history_choice.get_item_metadata(index))
		_refresh_history()
	)
	history.add_child(_history_choice)
	_history = _label("")
	history.add_child(_history)
	history.add_child(_label(tr("yearplus.history_note"), "Caption"))
	_history_rows = VBoxContainer.new()
	history.add_child(_history_rows)
	var reports: VBoxContainer = _tab(tabs, "year.report")
	_messages = _label("")
	reports.add_child(_messages)
	var village: VBoxContainer = _tab(tabs, "exp.village")
	village.add_child(_label(tr("exp.prologue"), "Caption"))
	_heritage_panel = VBoxContainer.new()
	_heritage_panel.hide()
	village.add_child(_heritage_panel)
	_heritage_state = _label("")
	_heritage_panel.add_child(_heritage_state)
	_heritage_panel.add_child(_label(tr("yearheritage.explanation"), "Caption"))
	_heritage_goal = _label("")
	_heritage_panel.add_child(_heritage_goal)
	_result_button = _button("yearheritage.result", _show_year_result)
	_heritage_panel.add_child(_result_button)
	_heritage_buildings = VBoxContainer.new()
	_heritage_panel.add_child(_heritage_buildings)
	_village_project = OptionButton.new()
	for project: String in ["food", "water", "craft"]:
		_village_project.add_item(tr("exp.project." + project))
	village.add_child(_village_project)
	_project_button = _button("exp.choose_project", func(): _edit("project", ["food", "water", "craft"][_village_project.selected]))
	village.add_child(_project_button)
	_project_text = _label("")
	village.add_child(_project_text)
	_restart = ConfirmationDialog.new()
	_restart.title = tr("year.new")
	_restart.ok_button_text = tr("menu.overwrite_confirm")
	_restart.cancel_button_text = tr("action.cancel")
	_restart.dialog_text = ""
	var setup: VBoxContainer = VBoxContainer.new()
	setup.custom_minimum_size.x = 600
	setup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var setup_scroll: ScrollContainer = ScrollContainer.new()
	setup_scroll.custom_minimum_size = Vector2(600, 400)
	setup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	setup_scroll.follow_focus = true
	_restart.add_child(setup_scroll)
	setup_scroll.add_child(setup)
	var confirmation: Label = _label(tr("year.restart_confirm"), "Caption")
	confirmation.autowrap_mode = TextServer.AUTOWRAP_OFF
	setup.add_child(confirmation)
	var seed_label: Label = _label(tr("setup.seed"))
	seed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	setup.add_child(seed_label)
	_seed = LineEdit.new()
	_seed.text = str(initial_seed)
	setup.add_child(_seed)
	_goal = OptionButton.new()
	for goal: String in ["none", "growth", "forest", "rice"]:
		_goal.add_item(tr("goal." + goal + ".name"))
	setup.add_child(_goal)
	setup.add_child(_label(tr("setup.leader")))
	_leader = OptionButton.new()
	for leader: String in MainMenu.LEADERS:
		_leader.add_item(tr("leader." + leader + ".name"))
	setup.add_child(_leader)
	setup.add_child(_label(tr("setup.difficulty")))
	_difficulty = SpinBox.new()
	_difficulty.max_value = 10
	_difficulty.value = initial_difficulty
	setup.add_child(_difficulty)
	setup.add_child(_label(tr("year.profile_help"), "Caption"))
	var project_label: Label = _label(tr("exp.new_project"))
	project_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	setup.add_child(project_label)
	_project = OptionButton.new()
	for project: String in ["food", "water", "craft"]:
		_project.add_item(tr("exp.project." + project))
	setup.add_child(_project)
	var years_label: Label = _label(tr("yearmulti.length"))
	years_label.visible = not session is TransportSession
	setup.add_child(years_label)
	_campaign_years = OptionButton.new()
	for years: int in [1, 3, 5]:
		_campaign_years.add_item(tr("yearmulti.years") % years)
	_campaign_years.visible = not session is TransportSession
	setup.add_child(_campaign_years)
	var years_help: Label = _label(tr("yearmulti.help"), "Caption")
	years_help.visible = _campaign_years.visible
	setup.add_child(years_help)
	_classic = CheckBox.new()
	_classic.text = tr("yearplus.enable")
	_classic.visible = not session is TransportSession
	setup.add_child(_classic)
	var classic_help: Label = _label(tr("yearplus.enable_help"), "Caption")
	classic_help.visible = _classic.visible
	setup.add_child(classic_help)
	_campaign_years.item_selected.connect(func(_index: int): _campaign_length_changed())
	_sync_new_year_form()
	_restart.confirmed.connect(_new_year)
	add_child(_restart)
	_populate_actions()
	if not session.year.is_empty():
		selected = session.year["structures"].find("hall")
	_build_settings()
	_leave_confirmation = ConfirmationDialog.new()
	_leave_confirmation.dialog_text = tr("msg.unsaved_progress")
	_leave_confirmation.confirmed.connect(func():
		if _quit_after_confirm:
			get_tree().quit()
		else:
			menu_requested.emit()
	)
	add_child(_leave_confirmation)
	_advance_confirmation = ConfirmationDialog.new()
	_advance_confirmation.title = tr("action.confirm")
	_advance_confirmation.ok_button_text = tr("action.confirm")
	_advance_confirmation.cancel_button_text = tr("action.cancel")
	_advance_confirmation.confirmed.connect(func(): _advance(_pending_days))
	_impact_button = _advance_confirmation.add_button(tr("yearplus.inspect_risk"), false, "inspect")
	_advance_confirmation.custom_action.connect(func(_action_name: StringName):
		_advance_confirmation.hide()
		if _impact_tile >= 0:
			_focus_tile(_impact_tile)
	)
	var review_scroll: ScrollContainer = ScrollContainer.new()
	review_scroll.custom_minimum_size = Vector2(620, 220)
	review_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	review_scroll.follow_focus = true
	_advance_confirmation.add_child(review_scroll)
	var review: VBoxContainer = VBoxContainer.new()
	review.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_scroll.add_child(review)
	_advance_text = _label("")
	review.add_child(_advance_text)
	_risk_choice = OptionButton.new()
	_risk_choice.fit_to_longest_item = false
	_risk_choice.item_selected.connect(func(index: int): _impact_tile = int(_risk_choice.get_item_metadata(index)))
	review.add_child(_risk_choice)
	_order_confirmation = ConfirmationDialog.new()
	_order_confirmation.title = tr("yeararea.preview")
	_order_confirmation.ok_button_text = tr("year.order")
	_order_confirmation.cancel_button_text = tr("action.cancel")
	_order_confirmation.confirmed.connect(_commit_tried_order)
	var order_scroll: ScrollContainer = ScrollContainer.new()
	order_scroll.custom_minimum_size = Vector2(650, 400)
	order_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	order_scroll.follow_focus = true
	_order_confirmation.add_child(order_scroll)
	_order_text = _label("")
	order_scroll.add_child(_order_text)
	add_child(_order_confirmation)
	_result_dialog = AcceptDialog.new()
	_result_dialog.title = tr("yearheritage.result")
	_result_dialog.ok_button_text = tr("action.close")
	add_child(_result_dialog)
	_area_dialog = AcceptDialog.new()
	_area_dialog.title = tr("yeararea.open")
	_area_dialog.ok_button_text = tr("action.close")
	_area_scroll = ScrollContainer.new()
	_area_scroll.custom_minimum_size = Vector2(700, 470)
	_area_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_area_scroll.follow_focus = true
	_area_dialog.add_child(_area_scroll)
	add_child(_area_dialog)
	add_child(_advance_confirmation)
	_refresh()
	_apply_reduced_motion()
	if initial_setup:
		show_new_year()


func _label(text: String, style: String = "") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not style.is_empty():
		label.theme_type_variation = style
	return label


func _title_key() -> String:
	return "yearmulti.title" if session != null and YearGame.multi_year(session.year) else "year.title"


func _make_board() -> YearBoard:
	return YearBoard3D.new()


func _preview_year() -> Dictionary:
	var reports: Array[TurnReport] = []
	var result: Dictionary = YearGame.preview(session.year, 1, reports)
	board.set_forecast_flow(null if reports.is_empty() else reports.back())
	return result["state"]


func _worker_count() -> int:
	return YearGame.workers(session.year)


func _button(key: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = tr(key)
	button.pressed.connect(callback)
	return button


func _tab(tabs: TabContainer, key: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tr(key))
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _populate_actions() -> void:
	_action.clear()
	for id: String in YearGame.config(session.year)["jobs"]:
		var group: String = action_group(id)
		if group == GROUPS[_group.selected]:
			_action.add_item(tr("year.action." + id))
			_action.set_item_metadata(_action.item_count - 1, id)
	_refresh_selection()


static func action_group(id: String) -> String:
	return "build" if id.begins_with("build_") or id.begins_with("improve_") or id == "upgrade_house" else ("food" if id in ["forage", "fish", "plant_paddy", "harvest"] else ("materials" if id.begins_with("gather_") or id in ["saw_planks", "fire_bricks", "assemble_kits"] else "land"))


func action_id() -> String:
	return "" if _action.selected < 0 else String(_action.get_item_metadata(_action.selected))


func select_tile(index: int) -> void:
	selected = index
	_refresh_selection()


func _materials(values: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for resource: String in YearGame.resources(session.year):
		if values.has(resource):
			parts.append("%s %d" % [tr("daily.resource." + resource), int(values[resource])])
	return " · ".join(parts) if not parts.is_empty() else tr("daily.none")


func _refresh_selection() -> void:
	if _order_button == null or session == null or session.year.is_empty() or selected < 0:
		return
	var s: Dictionary = session.year
	var tile: Dictionary = s["board"]["tiles"][selected]
	var structure: String = s["structures"][selected]
	var site: String = String(tile["feature"]) if structure.is_empty() else structure
	if structure.is_empty() and not String(s["deposits"][selected]).is_empty():
		site = s["deposits"][selected]
	_inspection.text = tr("year.tile") % [int(tile["q"]), int(tile["r"]), tr("year.site." + site), int(tile["elevation"]), float(tile["water"]), int(s["health"][selected]), int(s["crop_growth"][selected]), int(s["stock"][selected])]
	if YearHeritage.enabled(s):
		var record: Dictionary = YearHeritage.building(s, selected)
		if not record.is_empty():
			_inspection.text += "\n" + tr("yearheritage.building") % [int(record["built_day"]), YearHeritage.age(s, selected), tr("settlement.stage." + str(record["stage"]))]
	if YearGame.expanded(s):
		_inspection.text += "\n" + tr("exp.distance") % YearExpansion.distance_to_work(s, selected)
		var improvement: String = YearExpansion.upgrade(s, selected)
		if not improvement.is_empty():
			_inspection.text += " · " + tr("year.action.improve_" + improvement)
	if structure == "gate":
		_inspection.text += "\n" + tr("exp.gate." + ("half" if YearGame.expanded(s) and s["gate_half"][selected] else ("open" if tile["gate_open"] else "closed")))
	if _preview.button_pressed and not _predicted.is_empty():
		_inspection.text += "\n" + tr("year.preview_tile") % [float(_predicted["board"]["tiles"][selected]["water"]), int(_predicted["health"][selected])]
	_gate_button.disabled = structure != "gate" or int(s["health"][selected]) <= 0 or s["outcome"] != "running"
	_irrigation.visible = YearClassic.enabled(s) and tile["feature"] == "paddy"
	if _irrigation.visible:
		_irrigation.select(Irrigation.POLICIES.find(String(s["irrigation_policy"][selected])))
		_irrigation.disabled = s["outcome"] != "running"
		_inspection.text += "\n" + tr("yearplus.moisture") % int(s["soil_moisture"][selected])
	var id: String = action_id()
	if id.is_empty():
		_order_button.disabled = true
		_try_button.disabled = true
		board.model = s
		board.selected = selected
		board.targets.clear()
		board.predicted = _predicted if _preview.button_pressed else {}
		board.update_view()
		return
	var definition: Dictionary = YearGame.config(s)["jobs"][id]
	var reusable: bool = id in YearGame.repeatable(s)
	_repeat.disabled = not reusable
	if not reusable:
		_repeat.set_pressed_no_signal(false)
		_batches.value = 1
	_batches.max_value = 100 if reusable else 1
	_batches.editable = reusable and not _repeat.button_pressed
	_direction.visible = id == "build_wheel"
	_policy.visible = YearGame.expanded(s) and reusable
	_stop_at.editable = not definition["outputs"].is_empty()
	_reserve.editable = definition["inputs"].has("wood")
	_recipe.text = tr("year.recipe") % [int(definition["workers"]), YearGame._job_days(s, id, selected), _materials(YearExpansion.inputs(s, id, selected)), _materials(YearAreaDevelopment.expected_output(s, id, selected))]
	_recipe.text += "\n" + tr("year.action." + id + "_desc")
	var stop_at: int = int(_stop_at.value) if _policy.visible and _stop_at.editable else 0
	var reserve: int = int(_reserve.value) if _policy.visible and _reserve.editable else 0
	var error: String = YearGame.check_order(s, id, selected, int(_batches.value), _repeat.button_pressed, _direction.selected, stop_at, reserve)
	_reason.text = "" if error.is_empty() else tr(error)
	_order_button.disabled = not error.is_empty()
	_try_button.disabled = _order_button.disabled
	_try_button.visible = not session is TransportSession
	board.model = s
	board.selected = selected
	board.targets.clear()
	for index: int in range(session.year["structures"].size()):
		if YearGame.check_order(s, id, index, int(_batches.value), _repeat.button_pressed, _direction.selected, stop_at, reserve).is_empty():
			board.targets.append(index)
	board.predicted = _predicted if _preview.button_pressed else {}
	board.update_view()


func _refresh() -> void:
	if session.year.is_empty():
		for button: Button in _time_buttons:
			button.disabled = true
		_order_button.disabled = true
		_messages.text = tr(session.last_save_error)
		return
	var s: Dictionary = session.year
	_progress.max_value = YearGame.total_days(s)
	_progress.value = int(s["day"])
	_refresh_resource_chips()
	_refresh_history()
	var need: int = YearGame.food_need(s)
	_status.text = tr("year.status") % [YearGame.day_of_year(s) if int(s["day"]) > 0 else 0, tr("year.season." + YearGame.season(s)), int(s["population"]), YearGame.housing(s), _worker_count(), int(s["population"]), int(s["resources"]["food"]) / maxi(1, need), int(s["knowledge"])]
	if YearGame.multi_year(s):
		_status.text = tr("yearmulti.run") % [YearGame.year_number(s), int(s["campaign_years"])] + _status.text
	_resources.text = _materials(s["resources"])
	if s.get("ruleset") in ["year365_v3", "year365_v4", "year365_v5", "year365_v6"]:
		_status.text += " · " + tr("leader." + String(s["leader"]) + ".name") + " · " + tr("year.difficulty") % int(s["difficulty"])
	var forecast: PackedStringArray = PackedStringArray()
	for entry: Dictionary in YearWeather.forecast(s):
		forecast.append("%d: %.2f" % [int(entry["day"]), float(entry["inflow"])])
	_forecast.text = tr("year.forecast") + " · ".join(forecast)
	_predicted = _preview_year()
	_food_plan.text = tr("year.food_plan_summary") % [need, YearGame.housing(s), int(s["population"]) - _worker_count(), int(_predicted["resources"]["food"]) - int(s["resources"]["food"])]
	_food_plan.text += "\n" + tr("year.food_plan_hint")
	_refresh_planning()
	_refresh_selection()
	_undo.disabled = session.undo_plans.is_empty()
	_redo.disabled = session.redo_plans.is_empty()
	for button: Button in _time_buttons:
		button.disabled = s["outcome"] != "running"
	_summary.text = tr("year.summary") % [tr("year.outcome." + String(s["outcome"])), int(s["score"]), int(s["stats"]["harvest"]), int(s["stats"]["born"]), int(s["stats"]["departed"])]
	_summary.text += "\n" + (_medal_summary() if YearHeritage.enabled(s) else tr("year.goal." + String(s["goal"])))
	_refresh_heritage()
	if not session.last_save_error.is_empty():
		_summary.text += "\n" + tr(session.last_save_error)
	_messages.text = "\n".join(_log)
	_notice.text = _latest_notice
	_notice.visible = not _latest_notice.is_empty()
	var challenges: PackedStringArray = PackedStringArray()
	for id: String in YearGame.config()["challenges"]:
		challenges.append("%s · %s · +%d\n%s" % [tr("year.challenge." + id), tr("daily.done" if id in s["claimed"] else "daily.pending"), int(YearGame.config()["challenges"][id]), tr("year.challenge." + id + "_desc")])
	_challenges.text = "\n\n".join(challenges)
	for id: String in _research:
		var definition: Dictionary = YearGame.config()["research"][id]
		var learned: bool = id in s["research"]
		_research[id].text = tr("year.research." + id) + (" · " + tr("daily.done") if learned else " · %d" % int(definition["cost"]))
		_research[id].disabled = learned or s["outcome"] != "running" or int(s["knowledge"]) < int(definition["cost"]) or (not String(definition["requires"]).is_empty() and definition["requires"] not in s["research"])
	_refresh_project()
	_refresh_queue()


func _refresh_queue() -> void:
	if session.year.is_empty():
		return
	var s: Dictionary = session.year
	_queue_summary.text = tr("yearplan.queue_summary") % [s["jobs"].size(), _worker_count(), int(s["population"])]
	for child: Node in _queue_list.get_children():
		_queue_list.remove_child(child)
		child.queue_free()
	if s["jobs"].is_empty():
		_queue_list.add_child(_label(tr("daily.empty_queue")))
	var visible_jobs: int = 0
	for job: Dictionary in s["jobs"]:
		var index: int = int(job["tile"])
		var row_info: Dictionary = {}
		for row: Dictionary in _plan.get("jobs", []):
			if int(row["tile"]) == index:
				row_info = row
		var filter: String = ["all", "working", "blocked", "paused"][_queue_filter.selected]
		if filter != "all" and row_info.get("kind", "") != filter:
			continue
		visible_jobs += 1
		var container: VBoxContainer = VBoxContainer.new()
		_queue_list.add_child(container)
		container.add_child(_label(tr("year.action." + String(job["id"])) + " · " + tr(YearGame.job_status(s, job))))
		container.add_child(_label(tr("daily.job_progress") % [int(job["remaining"]), int(job["progress"]), YearGame._job_days(s, job["id"], index), tr("year.repeat") if job["repeat"] else tr("daily.working")], "Caption"))
		if YearGame.expanded(s):
			container.add_child(_label(tr("exp.policy_state") % [int(job["stop_at"]), int(job["reserve"])], "Caption"))
		var completion: int = int(row_info.get("completion_day", 0))
		if not session is TransportSession:
			container.add_child(_label(tr("yearplan.completion") % completion if completion > 0 else tr("yearplan.no_completion"), "Caption"))
		var row: HBoxContainer = HBoxContainer.new()
		container.add_child(row)
		row.add_child(_button("year.locate", _focus_tile.bind(index)))
		var pause: Button = _button("daily.resume" if job["paused"] else "daily.pause", _edit_job.bind(index, false))
		pause.name = "PauseTile_" + str(index)
		row.add_child(pause)
		var cancel: Button = _button("daily.cancel", _edit_job.bind(index, true))
		cancel.name = "CancelTile_" + str(index)
		row.add_child(cancel)

	if visible_jobs == 0 and not s["jobs"].is_empty():
		_queue_list.add_child(_label(tr("yearplan.empty_filter"), "Caption"))


func _edit(action: String, id: String = "") -> void:
	var stop_at: int = int(_stop_at.value) if _policy.visible and _stop_at.editable else 0
	var reserve: int = int(_reserve.value) if _policy.visible and _reserve.editable else 0
	var before_resources: Dictionary = _resource_snapshot()
	var error: String = session.edit_year(action, id, selected, int(_batches.value), _repeat.button_pressed, _direction.selected, stop_at, reserve)
	if not error.is_empty():
		_log.append(tr(error))
		_latest_notice = tr(error)
	_refresh()
	_show_resource_changes(before_resources)
	if action == "order":
		board.show_order(id, selected, error)


func _order() -> void:
	_edit("order", action_id())


func _learn(id: String) -> void:
	_edit("learn", id)


func _edit_job(index: int, cancel: bool) -> void:
	selected = index
	_edit("cancel" if cancel else "pause")


func _advance(days: int) -> void:
	if session == null or session.year.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_advance < 400:
		return
	_last_advance = now
	get_viewport().set_input_as_handled()
	var before_year: Dictionary = session.year.duplicate(true)
	var before_resources: Dictionary = _resource_snapshot()
	var before: Dictionary = session.year["resources"].duplicate(true)
	_history_day = -1
	var report: Dictionary = session.advance_year(days)
	var events: PackedStringArray = PackedStringArray()
	for event: String in report["events"]:
		if tr(event) not in events:
			events.append(tr(event))
	_latest_notice = " · ".join(events)
	_log.append(tr("year.report_day") % [int(session.year["day"]), int(report["days"])] + "\n" + " · ".join(events) + "\n" + _materials(before) + " → " + _materials(session.year["resources"]))
	while _log.size() > 30:
		_log.pop_front()
	_refresh()
	_show_resource_changes(before_resources)
	board.show_day_changes(before_year)
	board.show_actual_flow(session.visual_reports)
	_last_advance = Time.get_ticks_msec()
	if YearHeritage.enabled(session.year) and before_year["outcome"] == "running" and session.year["outcome"] != "running":
		_show_year_result()


func _new_year() -> void:
	initial_seed = SeedUtil.parse_seed_text(_seed.text)
	initial_goal = ["none", "growth", "forest", "rice"][_goal.selected]
	initial_project = ["food", "water", "craft"][_project.selected]
	var error: String
	if session is TransportSession:
		error = session.start_year(initial_seed, initial_goal, initial_project)
	else:
		error = session.start_campaign(initial_seed, initial_goal, initial_project, MainMenu.LEADERS[_leader.selected], int(_difficulty.value), _classic.button_pressed, _classic.button_pressed, [1, 3, 5][_campaign_years.selected])
	if not error.is_empty():
		_latest_notice = tr(error)
		_refresh()
		return
	_log.clear()
	_history_day = -1
	_history_view.clear()
	_history_return.hide()
	_resource_feedback.clear()
	board.clear_feedback()
	_latest_notice = ""
	if not session.year.is_empty():
		selected = session.year["structures"].find("hall")
	board.fit_map()
	_stop_at.value = 0
	_reserve.value = 0
	_populate_actions()
	_refresh()


func _refresh_project() -> void:
	var s: Dictionary = session.year
	var expanded: bool = YearGame.expanded(s)
	_village_project.visible = expanded
	_project_button.visible = expanded
	if not expanded:
		_project_text.text = tr("exp.legacy")
		return
	var project: String = s["project"]
	_village_project.select(["food", "water", "craft"].find(project))
	var stage: int = int(s["project_stage"])
	_village_project.disabled = stage > 0 or s["outcome"] != "running"
	_project_button.disabled = _village_project.disabled
	var rows: PackedStringArray = PackedStringArray([tr("exp.project." + project) + " · %d/3" % stage, tr("exp.project_help")])
	if project == "food":
		rows.append(tr("exp.progress.food") % [int(s["day"]), int(s["resources"]["food"]), int(s["stats"]["harvest"]), int(s["stats"]["fed_days"])])
	elif project == "water":
		rows.append(tr("exp.progress.water") % [int(s["day"]), int(s["stats"]["earthworks"]), int(s["stats"]["irrigated_days"]), int(s["health"][s["structures"].find("hall")])])
	else:
		rows.append(tr("exp.progress.craft") % [int(s["stats"]["planks"]), int(s["resources"]["bricks"]), int(s["stats"]["kits"]), YearGame.housing(s)])
	var ready: Array[bool] = YearExpansion.progress(s)
	var rewards: Dictionary = YearGame.config(s)["projects"][project]
	for step: int in range(3):
		rows.append("%d. %s · %s\n%s\n%s: %s · %s +%d\n%s" % [step + 1, tr("exp.stage." + project + str(step + 1)), tr("daily.done" if step < stage else ("exp.ready" if ready[step] else "daily.pending")), tr("exp.condition." + project + str(step + 1)), tr("exp.reward"), _materials(rewards["materials"][step]), tr("exp.knowledge"), int(rewards["knowledge"][step]), tr("exp.perk." + project + str(step + 1))])
		if step < stage:
			rows.append(tr("exp.story." + project + str(step + 1)))
	rows.append(tr("exp.recovery") % [int(s["stats"]["recovery_repairs"]), tr("daily.done" if s["recovery_claimed"] else "daily.pending")])
	_project_text.text = "\n\n".join(rows)


func show_new_year() -> void:
	_restart.popup_centered(Vector2i(650, 650))


func _refresh_history() -> void:
	_history_choice.clear()
	for child: Node in _history_rows.get_children():
		_history_rows.remove_child(child)
		child.queue_free()
	if session.daily_history.is_empty():
		_history.text = tr("year.history_empty")
		return
	var chosen: Dictionary = session.daily_history.back()
	for index: int in range(session.daily_history.size() - 1, -1, -1):
		var entry: Dictionary = session.daily_history[index]
		_history_choice.add_item(tr("year.history_days") % [int(entry["day"]), int(entry["day"])])
		_history_choice.set_item_metadata(_history_choice.item_count - 1, int(entry["day"]))
		if int(entry["day"]) == _history_day:
			chosen = entry
			_history_choice.select(_history_choice.item_count - 1)
	var rows: PackedStringArray = [tr("year.history_days") % [int(chosen["from_day"]) + 1, int(chosen["day"])]]
	for key: String in chosen["before"]:
		rows.append("%s: %d → %d (%+d)" % [_ledger_resource(key), int(chosen["before"][key]), int(chosen["after"][key]), int(chosen["delta"][key])])
	for cause: Dictionary in chosen.get("causes", []):
		var deltas: PackedStringArray = []
		for key: String in cause["delta"]:
			deltas.append("%s %+d" % [_ledger_resource(key), int(cause["delta"][key])])
		var at: String = " (%d,%d)" % [cause["coord"].x, cause["coord"].y] if cause.has("coord") else ""
		rows.append(tr(cause["cause"]) + at + ": " + " · ".join(deltas))
	for event: String in chosen["events"]:
		rows.append(tr(event))
	_history.text = "\n".join(rows)
	for fact: Dictionary in chosen.get("locations", []):
		var coord: Vector2i = fact["coord"]
		var text: String = "%s (%d,%d) · %s" % [tr(fact["kind"]), coord.x, coord.y, tr("year.site." + fact["site"])]
		if str(fact["before"]) != "" or str(fact["after"]) != "":
			text += " · %s → %s" % [_ledger_value(fact["before"]), _ledger_value(fact["after"])]
		if fact.has("source"):
			text += " · " + tr("yearplus.source") % [fact["source"].x, fact["source"].y]
		var button: Button = Button.new()
		button.text = text
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_inspect_history.bind(int(fact["tile"]), coord))
		_history_rows.add_child(button)


func _ledger_resource(key: String) -> String:
	var labels: Dictionary = {"people": "resource.people", "labor": "resource.labor", "housing": "resourcefx.housing", "knowledge": "yearplus.knowledge"}
	return tr(labels.get(key, "daily.resource." + key))


func _inspect_history(index: int, coord: Vector2i) -> void:
	if _history_view.is_empty():
		_history_view = board.view_draft()
		_history_selected = selected
	_focus_tile(index)
	if board is YearBoard3D:
		(board as YearBoard3D).village.show_result_location(coord)
	_history_return.show()


func _return_history() -> void:
	if not _history_view.is_empty():
		select_tile(_history_selected)
		board.restore_view_draft(_history_view)
		_history_view.clear()
	if board is YearBoard3D:
		(board as YearBoard3D).village.clear_result_location()
	_history_return.hide()
	_tabs.current_tab = 5


func _build_settings() -> void:
	_settings = AcceptDialog.new()
	_settings.title = tr("menu.settings")
	var content: VBoxContainer = VBoxContainer.new()
	_settings.add_child(content)
	content.add_child(_label(tr("year.shortcuts")))
	content.add_child(_button("menu.language", func(): language_requested.emit()))
	var confirm: CheckBox = CheckBox.new()
	confirm.text = tr("year.confirm_workers")
	confirm.button_pressed = GamePreferences.read()["confirm_unused_labor"]
	confirm.toggled.connect(func(enabled: bool):
		var error: String = GamePreferences.write({"confirm_unused_labor": enabled})
		if not error.is_empty():
			_latest_notice = tr(error)
			_refresh()
	)
	content.add_child(confirm)
	var motion: CheckBox = CheckBox.new()
	motion.text = tr("pause.reduced_motion")
	motion.button_pressed = GamePreferences.read()["reduced_motion"]
	motion.toggled.connect(func(enabled: bool):
		var error: String = GamePreferences.write({"reduced_motion": enabled})
		if error.is_empty():
			_apply_reduced_motion()
		else:
			_latest_notice = tr(error)
			_refresh()
	)
	content.add_child(motion)
	add_child(_settings)


func _request_advance(days: int) -> void:
	if session.year.is_empty() or session.year["outcome"] != "running":
		return
	_pending_days = days
	var idle: int = int(session.year["population"]) - _worker_count()
	_review_impacts.clear()
	var preview: Dictionary = _advance_preview(days)
	var impacts: Array[Dictionary] = YearOrderPreview.impacts(session.year, preview) if session is TransportSession else _review_impacts
	_impact_tile = -1
	var details: PackedStringArray = []
	_risk_choice.clear()
	for impact: Dictionary in impacts:
		var index: int = int(impact["tile"])
		if index >= 0 and _impact_tile < 0:
			_impact_tile = index
		if index >= 0:
			var tile: Dictionary = session.year["board"]["tiles"][index]
			_risk_choice.add_item(tr(impact["kind"]) + " (%d,%d)" % [int(tile["q"]), int(tile["r"])])
			_risk_choice.set_item_metadata(_risk_choice.item_count - 1, index)
		if details.size() < 8:
			var at: Dictionary = session.year["board"]["tiles"][index] if index >= 0 else {}
			details.append(tr(impact["kind"]) + (" (%d,%d)" % [int(at["q"]), int(at["r"])] if not at.is_empty() else "") + ": %d → %d" % [int(impact["before"]), int(impact["after"])])
	_impact_button.visible = _impact_tile >= 0
	_risk_choice.visible = _impact_tile >= 0
	var warnings: PackedStringArray = []
	if preview["outcome"] in ["lost_hall", "lost_population"]:
		warnings.append(tr("yearplan.confirm_loss") % [int(preview["day"]), tr("year.outcome." + String(preview["outcome"]))])
	elif not impacts.is_empty():
		warnings.append(tr("yearplus.confirm_impact") % [int(preview["day"]), impacts.size()])
	warnings.append_array(details)
	if GamePreferences.read()["confirm_unused_labor"] and idle > 0:
		warnings.append(tr("year.unused_workers") % idle)
	if not warnings.is_empty():
		_advance_confirmation.dialog_text = ""
		_advance_text.text = "\n".join(warnings)
		_advance_confirmation.popup_centered(Vector2i(700, 360))
	else:
		_advance(days)


func _request_menu() -> void:
	if not session.last_save_error.is_empty():
		_quit_after_confirm = false
		_leave_confirmation.popup_centered()
		return
	menu_requested.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if _restart.visible or _settings.visible or _advance_confirmation.visible or _leave_confirmation.visible or _order_confirmation.visible or _result_dialog.visible or _area_dialog.visible:
		return
	var code: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code == KEY_ESCAPE:
		_settings.popup_centered(Vector2i(600, 260))
	elif code == KEY_F2:
		_tabs.current_tab = 4
	elif code == KEY_H:
		_tabs.current_tab = 1
	elif code == KEY_F3:
		_tabs.current_tab = 5
	elif code == KEY_TAB:
		_preview.button_pressed = not _preview.button_pressed
	elif code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_request_advance(1)
	elif event.ctrl_pressed and code == KEY_Z:
		if event.shift_pressed:
			_redo_plan()
		else:
			_undo_plan()
	elif event.ctrl_pressed and code == KEY_Y:
		_redo_plan()
	elif code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT] and board is YearBoard3D:
		(board as YearBoard3D).pan_view(Vector2(-1 if code in [KEY_A, KEY_LEFT] else (1 if code in [KEY_D, KEY_RIGHT] else 0), -1 if code in [KEY_W, KEY_UP] else (1 if code in [KEY_S, KEY_DOWN] else 0)))
	elif board is YearBoard3D and code in [KEY_Q, KEY_E, KEY_L, KEY_V]:
		if code in [KEY_L, KEY_V]:
			(board as YearBoard3D).toggle_labels()
		else:
			(board as YearBoard3D).rotate_view(-1 if code == KEY_Q else 1)
	else:
		var tools: Dictionary = {KEY_1: "dig", KEY_2: "fill", KEY_3: "plant_paddy", KEY_4: "build_house", KEY_5: "upgrade_house", KEY_6: "build_raft", KEY_7: "build_gate", KEY_8: "build_reservoir", KEY_9: "build_fish_trap", KEY_0: "build_granary", KEY_C: "gather_wood", KEY_P: "plant_forest", KEY_B: "build_wheel", KEY_X: "demolish", KEY_R: "brace_house"}
		if not tools.has(code) or not _select_action(tools[code]):
			return
	get_viewport().set_input_as_handled()


func request_quit() -> void:
	if session.last_save_error.is_empty():
		get_tree().quit()
	else:
		_quit_after_confirm = true
		_leave_confirmation.popup_centered()


func ui_draft() -> Dictionary:
	return {"seed": _seed.text, "goal": _goal.selected, "project": _project.selected, "leader": _leader.selected, "difficulty": _difficulty.value, "group": _group.selected, "action": _action.selected, "batches": _batches.value, "repeat": _repeat.button_pressed, "direction": _direction.selected, "preview": _preview.button_pressed, "tab": _tabs.current_tab, "stop_at": _stop_at.value, "reserve": _reserve.value, "queue_filter": _queue_filter.selected, "classic": _classic.button_pressed, "campaign_years": _campaign_years.selected, "trial_horizon": _trial_horizon.selected, "history_day": _history_day, "history_view": _history_view.duplicate(true), "history_selected": _history_selected}


func restore_ui_draft(draft: Dictionary) -> void:
	_classic.button_pressed = bool(draft.get("classic", false))
	_campaign_years.select(int(draft.get("campaign_years", 0)))
	_campaign_length_changed()
	_trial_horizon.select(int(draft.get("trial_horizon", 0)))
	_history_day = int(draft.get("history_day", -1))
	_history_view = draft.get("history_view", {}).duplicate(true)
	_history_selected = int(draft.get("history_selected", -1))
	_history_return.visible = not _history_view.is_empty()
	_seed.text = draft["seed"]
	_goal.select(draft["goal"])
	_project.select(draft["project"])
	_leader.select(draft["leader"])
	_difficulty.value = draft["difficulty"]
	_group.select(draft["group"])
	_populate_actions()
	_action.select(draft["action"])
	_batches.value = draft["batches"]
	_repeat.button_pressed = draft["repeat"]
	_direction.select(draft["direction"])
	_preview.button_pressed = draft["preview"]
	_tabs.current_tab = draft["tab"]
	_stop_at.value = draft["stop_at"]
	_reserve.value = draft["reserve"]
	_queue_filter.select(int(draft.get("queue_filter", 0)))
	_refresh()


func _refresh_resource_chips() -> void:
	var values: Dictionary = _resource_snapshot()
	for key: String in _resource_chips:
		var chip: Label = _resource_chips[key]
		chip.get_parent().visible = values.has(key)
		if values.has(key):
			chip.text = "%s %d" % [tr("resource." + key) if key in ["people", "labor"] else tr("daily.resource." + key), int(values[key])]


func _show_resource_changes(before: Dictionary) -> void:
	var after: Dictionary = _resource_snapshot()
	# Legacy years do not have the expansion's fiber or kits.
	for key: String in ["fiber", "kits"]:
		if not before.has(key):
			before[key] = 0
		if not after.has(key):
			after[key] = 0
	_resource_feedback.show_changes(before, after)


func _undo_plan() -> void:
	if session.year.is_empty():
		return
	var before: Dictionary = _resource_snapshot()
	session.undo_year()
	board.clear_feedback()
	_refresh()
	_show_resource_changes(before)


func _redo_plan() -> void:
	if session.year.is_empty():
		return
	var before: Dictionary = _resource_snapshot()
	session.redo_year()
	board.clear_feedback()
	_refresh()
	_show_resource_changes(before)


func _apply_reduced_motion() -> void:
	var enabled: bool = GamePreferences.read()["reduced_motion"]
	board.set_reduced_motion(enabled)
	_resource_feedback.set_reduced_motion(enabled)


func _process(_delta: float) -> void:
	if board != null and _leave_confirmation != null:
		board.set_suspended(_settings.visible or _restart.visible or _advance_confirmation.visible or _leave_confirmation.visible or _order_confirmation.visible or _result_dialog.visible or _area_dialog.visible)


func _resource_snapshot() -> Dictionary:
	var result: Dictionary = YearPresentation.resources(session.year)
	result["labor"] = int(session.year["population"]) - _worker_count()
	return result


func _refresh_planning() -> void:
	_advice_card.visible = not session is TransportSession
	_planning_assumption.visible = _advice_card.visible
	_clear_planning_rows()
	if session is TransportSession:
		_plan = {"jobs": YearPlanner.job_rows(session.year)}
		return
	_plan = YearPlanner.describe(session.year)
	var advice: Dictionary = _plan["advice"]
	var message: String = tr("yearplan.advice." + String(advice["kind"]))
	_advice_text.text = message if advice["values"].is_empty() else message % advice["values"]
	if advice["kind"] == "blocked":
		for job: Dictionary in _plan["jobs"]:
			if int(job["tile"]) == int(advice["tile"]):
				_advice_text.text += "\n" + tr(String(job["status"]))
	_advice_button.visible = advice["kind"] not in ["safe", "finished"]
	_advice_button.text = tr("yearplan.prepare" if not String(advice["action"]).is_empty() else ("year.locate" if int(advice["tile"]) >= 0 else "yearplan.review_work"))
	for day: Dictionary in _plan["days"]:
		var row: VBoxContainer = VBoxContainer.new()
		_planning_rows.add_child(row)
		row.add_child(_label(tr("yearplan.day") % [int(day["day"]), int(day["food"]), int(day["population"]), int(day["housing"]), float(day["inflow"])]))
		var events: PackedStringArray = PackedStringArray()
		for event: String in day["events"]:
			if tr(event) not in events:
				events.append(tr(event))
		if not events.is_empty():
			row.add_child(_label(" · ".join(events), "Caption"))
		for index: int in day["damaged"]:
			var tile: Dictionary = session.year["board"]["tiles"][index]
			var locate: Button = _button("year.locate", _focus_tile.bind(index))
			locate.text = tr("yearplan.damage_location") % [int(tile["q"]), int(tile["r"])]
			row.add_child(locate)
		for index: int in day.get("crops", []):
			var tile: Dictionary = session.year["board"]["tiles"][index]
			var locate: Button = _button("year.locate", _focus_tile.bind(index))
			locate.text = tr("yearreview.crop_location") % [int(tile["q"]), int(tile["r"])]
			row.add_child(locate)
	if _plan["days"].is_empty():
		_planning_rows.add_child(_label(tr("yearplan.finished"), "Caption"))


func _clear_planning_rows() -> void:
	for child: Node in _planning_rows.get_children():
		_planning_rows.remove_child(child)
		child.queue_free()


func _act_on_advice() -> void:
	var advice: Dictionary = _plan.get("advice", {})
	if advice.is_empty():
		return
	var index: int = int(advice["tile"])
	var id: String = advice["action"]
	if index < 0:
		_tabs.current_tab = 1
		return
	if not id.is_empty():
		if not YearGame.check_order(session.year, id, index).is_empty():
			_refresh()
			return
		_repeat.set_pressed_no_signal(false)
		_batches.value = 1
		_stop_at.value = 0
		_reserve.value = 0
		_group.select(GROUPS.find(action_group(id)))
		_populate_actions()
		for option: int in range(_action.item_count):
			if _action.get_item_metadata(option) == id:
				_action.select(option)
	_focus_tile(index)


func _focus_tile(index: int) -> void:
	_tabs.current_tab = 0
	select_tile(index)
	board.focus_selected()


func _advance_preview(days: int) -> Dictionary:
	var reports: Array[TurnReport] = []
	var result: Dictionary = YearGame.preview(session.year, days, reports)
	for report: TurnReport in reports:
		for fact: Dictionary in report.year_ledger["locations"]:
			if fact["kind"] in ["year.event.damage", "year.event.crop_lost"]:
				_review_impacts.append(fact.duplicate(true))
	for impact: Dictionary in YearOrderPreview.impacts(session.year, result["state"]):
		if int(impact["tile"]) < 0:
			_review_impacts.append(impact)
	return result["state"]


func _sync_new_year_form() -> void:
	var s: Dictionary = session.year
	_seed.text = str(s["board"]["seed"]) if not s.is_empty() else str(initial_seed)
	_goal.select(["none", "growth", "forest", "rice"].find(String(s.get("goal", initial_goal))))
	_project.select(["food", "water", "craft"].find(String(s.get("project", initial_project))))
	_leader.select(MainMenu.LEADERS.find(String(s.get("leader", "farmer"))))
	_difficulty.value = int(s.get("difficulty", initial_difficulty))
	_classic.set_pressed_no_signal(YearClassic.enabled(s))
	_campaign_years.select([1, 3, 5].find(int(s.get("campaign_years", 1))))
	_campaign_length_changed()


func _campaign_length_changed() -> void:
	var multiple: bool = _campaign_years.selected > 0
	_classic.disabled = multiple
	if multiple:
		_classic.set_pressed_no_signal(true)


func open_area_development() -> void:
	if session.year.is_empty() or selected < 0 or session is TransportSession:
		return
	get_viewport().set_input_as_handled()
	if _area_panel != null:
		_area_scroll.remove_child(_area_panel)
		_area_panel.free()
	_area_panel = YearAreaDevelopmentPanel.new()
	_area_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area_scroll.add_child(_area_panel)
	_area_panel.command_requested.connect(_commit_area_order)
	_area_panel.configure(session.year, selected)
	_area_dialog.popup_centered(Vector2i(760, 600))


func _commit_area_order(order: Dictionary, snapshot: Dictionary) -> void:
	get_viewport().set_input_as_handled()
	var index: int = int(order["tile"])
	if session.year != snapshot:
		_area_panel.configure(session.year, index, tr("yearplus.stale"))
		return
	var before: Dictionary = _resource_snapshot()
	var error: String = session.edit_year(order["action"], order["id"], index, order["batches"], order["repeat"], order["direction"], order["stop_at"], order["reserve"])
	selected = index
	_refresh()
	_show_resource_changes(before)
	board.show_order(order["id"], index, error)
	var notice: String = tr(error) if not error.is_empty() else tr("yeararea.assigned")
	if not session.last_save_error.is_empty():
		notice += "\n" + tr(session.last_save_error)
	_area_panel.configure(session.year, index, notice)


func _select_action(id: String) -> bool:
	if not YearGame.config(session.year)["jobs"].has(id):
		return false
	_group.select(GROUPS.find(action_group(id)))
	_populate_actions()
	for index: int in range(_action.item_count):
		if _action.get_item_metadata(index) == id:
			_action.select(index)
	_tabs.current_tab = 0
	_refresh_selection()
	return true


func _try_order() -> void:
	_pending_order = {"id": action_id(), "tile": selected, "batches": int(_batches.value), "repeat": _repeat.button_pressed, "direction": _direction.selected, "stop_at": int(_stop_at.value) if _policy.visible and _stop_at.editable else 0, "reserve": int(_reserve.value) if _policy.visible and _reserve.editable else 0}
	var o: Dictionary = _pending_order
	var result: Dictionary = YearOrderPreview.describe(session.year, o["id"], o["tile"], o["batches"], o["repeat"], o["direction"], o["stop_at"], o["reserve"], _trial_horizon.selected == 1)
	if not String(result["error"]).is_empty():
		_latest_notice = tr(result["error"])
		_refresh()
		return
	_order_snapshot = session.year.duplicate(true)
	_order_text.text = YearPlanText.describe(session.year, result, selected)
	if o["repeat"] and _trial_horizon.selected == 1:
		_order_text.text = tr("yearreview.first_batch") + "\n\n" + _order_text.text
	_order_confirmation.popup_centered(Vector2i(740, 550))


func _commit_tried_order() -> void:
	if session.year != _order_snapshot or _pending_order.is_empty():
		_latest_notice = tr("yearplus.stale")
		_refresh()
		return
	var o: Dictionary = _pending_order.duplicate(true)
	_pending_order.clear()
	_order_snapshot.clear()
	var before: Dictionary = _resource_snapshot()
	var error: String = session.edit_year("order", o["id"], o["tile"], o["batches"], o["repeat"], o["direction"], o["stop_at"], o["reserve"])
	_latest_notice = tr(error) if not error.is_empty() else ""
	_refresh()
	_show_resource_changes(before)
	board.show_order(o["id"], o["tile"], error)


func _input(event: InputEvent) -> void:
	# Tab is otherwise consumed by default focus navigation before unhandled input.
	if event is InputEventKey and (event.physical_keycode == KEY_TAB or event.keycode == KEY_TAB):
		_unhandled_key_input(event)


func _cancel_tool() -> void:
	_action.select(-1)
	_reason.text = tr("yearplus.tool_cancelled")
	_recipe.text = ""
	_refresh_selection()


func _ledger_value(value: Variant) -> String:
	if value is String and value in ["sapling", "forest"]:
		return tr("year.site." + value)
	return str(value)


func _medal_summary() -> String:
	var s: Dictionary = session.year
	var progress: Dictionary = YearHeritage.progress(s)
	if s["goal"] == "none":
		return tr("goal.none.name")
	var name: String = tr("goal." + String(s["goal"]) + ".name")
	return name + " · " + (tr("yearheritage.earned") % [int(progress["achieved_day"]), int(progress["bonus"])] if progress["achieved"] else tr("yearheritage.pending") % int(progress["bonus"]))


func _refresh_heritage() -> void:
	var s: Dictionary = session.year
	var enabled: bool = YearHeritage.enabled(s)
	_heritage_button.visible = enabled
	_heritage_panel.visible = enabled
	if not enabled:
		return
	var history: Dictionary = s["settlement_progress"]
	_heritage_state.text = tr("yearheritage.condition") % [tr("settlement." + String(history["condition"])), int(history["evaluated_day"])]
	var next_review: int = int(history["evaluated_day"]) + int(YearHeritage.config()["period_days"])
	_heritage_state.text += "\n" + (tr("yearheritage.next_review") % next_review if next_review <= YearGame.total_days(s) and s["outcome"] == "running" else tr("yearheritage.no_review"))
	var progress: Dictionary = YearHeritage.progress(s)
	_heritage_goal.text = _medal_summary()
	if s["goal"] != "none":
		_heritage_goal.text += "\n" + tr("yearheritage.requirements") % [int(progress["population"]), int(progress["required_population"]), int(progress["forests"]), int(progress["required_forests"]), int(progress["harvest"]), int(progress["required_harvest"])]
		if progress["achieved"]:
			var receipt: Dictionary = s["goal_medal"]
			_heritage_goal.text += "\n" + tr("yearheritage.receipt") % [int(receipt["population"]), int(receipt["forests"]), int(receipt["harvest"])]
	_result_button.visible = s["outcome"] != "running"
	for child: Node in _heritage_buildings.get_children():
		_heritage_buildings.remove_child(child)
		child.queue_free()
	for index: int in range(s["structures"].size()):
		var record: Dictionary = YearHeritage.building(s, index)
		if record.is_empty():
			continue
		var tile: Dictionary = s["board"]["tiles"][index]
		var button: Button = Button.new()
		button.name = "BuildingAge_" + str(index)
		button.text = tr("year.site." + String(record["building"])) + " (%d,%d)\n" % [int(tile["q"]), int(tile["r"])] + tr("yearheritage.building") % [int(record["built_day"]), YearHeritage.age(s, index), tr("settlement.stage." + str(record["stage"]))]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_focus_tile.bind(index))
		_heritage_buildings.add_child(button)


func _show_year_result() -> void:
	if not YearHeritage.enabled(session.year) or session.year["outcome"] == "running":
		return
	var parts: Dictionary = YearHeritage.score_parts(session.year)
	_result_dialog.dialog_text = tr("year.outcome." + String(session.year["outcome"])) + "\n\n" + _medal_summary() + "\n\n" + tr("yearheritage.score_parts") % [int(parts["people"]), int(parts["food"]), int(parts["challenges"]), int(parts["project"]), int(parts["goal"]), int(parts["base"]), float(parts["multiplier"]), int(parts["total"])]
	_result_dialog.popup_centered(Vector2i(650, 0))
