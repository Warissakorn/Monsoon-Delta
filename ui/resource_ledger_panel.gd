class_name ResourceLedgerPanel
extends VBoxContainer
## Formats the chosen historical entry; never consults the live board.


func configure(ledger: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	add_child(_label(tr("ledger.title"), 23))
	if ledger.is_empty():
		add_child(_label(tr("ledger.unavailable"), 18))
		return
	for key: String in ResourceLedger.KEYS:
		var before: int = int(ledger["before"][key])
		var after: int = int(ledger["after"][key])
		var title: String = tr("resourcefx.housing" if key == "housing" else "resource." + key)
		var summary: Label = _label(tr("ledger.total") % [title, before, after, after - before], 20)
		summary.name = "LedgerTotal_" + key
		_color(summary, after - before)
		add_child(summary)
		for cause: Dictionary in ledger["causes"]:
			if cause["resource"] != key:
				continue
			var line: Label = _label(tr("ledger.cause") % [tr("ledger.reason." + String(cause["reason"])), int(cause["amount"])], 18)
			line.name = "LedgerCause_" + key + "_" + String(cause["reason"])
			_color(line, int(cause["amount"]))
			add_child(line)
	add_child(_label(tr("ledger.recorded"), 16))


static func summary(ledger: Dictionary) -> String:
	var parts: PackedStringArray = []
	if ledger.is_empty():
		return ""
	for key: String in ResourceLedger.KEYS:
		var delta: int = int(ledger["after"][key]) - int(ledger["before"][key])
		if delta != 0:
			parts.append("%s %+d" % [String(TranslationServer.translate("resourcefx.housing" if key == "housing" else "resource." + key)), delta])
	return " · ".join(parts)


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _color(label: Label, amount: int) -> void:
	if amount != 0:
		label.add_theme_color_override("font_color", Color(ThemeBuilder.palette()["success" if amount > 0 else "danger"]))
