class_name FoodPlanPanel
extends VBoxContainer
## Displays detached planning facts. It never runs or changes the simulation.


func configure(budget: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 12)
	var next: Dictionary = budget["next"]
	var exact: bool = next.get("kind") == "harvest"
	var blocked: bool = next.get("kind") == "hall_loss"
	add_child(_label(tr("foodplan.meal") % [int(budget["population"]), int(budget["per_person"]), int(budget["needed"])], "FoodPlanMeal", 22))
	add_child(_label(tr("foodplan.deadline") % int(budget["turns_left"]), "FoodPlanDeadline"))
	var table: GridContainer = GridContainer.new()
	table.name = "FoodPlanTable"
	table.columns = 3
	table.add_theme_constant_override("h_separation", 12)
	table.add_theme_constant_override("v_separation", 8)
	add_child(table)
	_cell(table, "", "FoodPlanHeading", true)
	_cell(table, tr("foodplan.now"), "FoodPlanNow")
	_cell(table, tr("foodplan.before_harvest" if exact else "foodplan.after_turn"), "FoodPlanNext")
	_row(table, "stored", int(budget["stored"]), next.get("stored") if not blocked else null)
	_row(table, "rice", int(budget["rice"]), next.get("rice") if not blocked else null)
	_row(table, "needed", int(budget["needed"]), next.get("needed") if not blocked else null)
	var gap: int = maxi(0, int(budget["needed"]) - int(budget["stored"]) - int(budget["rice"]))
	_row(table, "gap", gap, next.get("gap") if not blocked else null)
	if blocked:
		add_child(_label(tr("foodplan.hall_loss"), "FoodPlanWarning", 20, "danger"))
	elif not next.is_empty():
		add_child(_label(tr("foodplan.fish") % int(next["fish"]), "FoodPlanFish"))
		if exact:
			var harvest: Dictionary = next["harvest"]
			add_child(_label(tr("foodplan.harvest_result") % [int(harvest["eaten"]), int(harvest["born"]) * int(budget["growth_cost"]), int(harvest["spoiled"]), int(harvest["food_after"])], "FoodPlanHarvest"))
			add_child(_label(tr("foodplan.people_result") % [int(harvest["left_hunger"]), int(harvest["left_housing"]), int(harvest["population_after"])], "FoodPlanPeople", 19, "danger" if int(harvest["left_hunger"]) > 0 or int(harvest["left_housing"]) > 0 else "success"))
		else:
			add_child(_label(tr("foodplan.conditional"), "FoodPlanConditional", 18))
	add_child(_label(tr("foodplan.rice_help"), "FoodPlanRiceHelp"))
	add_child(_label(tr("foodplan.storage_help") % int(budget["rot_percent"]), "FoodPlanStorageHelp"))


func _row(table: GridContainer, key: String, now: int, after: Variant) -> void:
	_cell(table, tr("foodplan.metric." + key), "FoodPlanMetric_" + key, true)
	_cell(table, str(now), "FoodPlanNow_" + key)
	var value: Label = _cell(table, "—" if after == null else str(int(after)), "FoodPlanNext_" + key)
	if key == "gap" and after != null:
		value.add_theme_color_override("font_color", Color(ThemeBuilder.palette()["danger" if int(after) > 0 else "success"]))


func _cell(table: GridContainer, text: String, node_name: String, title: bool = false) -> Label:
	var label: Label = _label(text, node_name)
	label.custom_minimum_size.x = 320 if title else 150
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_child(label)
	return label


func _label(text: String, node_name: String, font_size: int = 19, tone: String = "") -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	if not tone.is_empty():
		label.add_theme_color_override("font_color", Color(ThemeBuilder.palette()[tone]))
	return label
