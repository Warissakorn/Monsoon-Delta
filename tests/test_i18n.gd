extends TestCase

const CSV_PATH: String = "res://translations/strings.csv"


func test_csv_has_unique_keys_and_both_languages() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_true(file != null, "translation source exists")
	if file == null:
		return
	assert_eq(file.get_csv_line(), PackedStringArray(["keys", "en", "th"]))
	var seen: Dictionary = {}
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		assert_eq(row.size(), 3, "CSV row has exactly three columns: " + str(row))
		if row.size() != 3:
			continue
		assert_true(not row[0].strip_edges().is_empty(), "each row has a key")
		assert_true(not seen.has(row[0]), "duplicate translation key: " + row[0])
		seen[row[0]] = true
		for index: int in [1, 2]:
			assert_true(not row[index].strip_edges().is_empty(), "missing translation: " + row[0])
	assert_true(seen.size() >= 100, "game vocabulary is present")


func test_positional_placeholders_match_between_languages() -> void:
	var placeholder: RegEx = RegEx.create_from_string("%[-+0 #]*[0-9]*(?:\\.[0-9]+)?[a-zA-Z%]")
	var rows: Dictionary = _rows()
	for key: String in rows:
		var row: PackedStringArray = rows[key]
		var english: PackedStringArray = PackedStringArray()
		var thai: PackedStringArray = PackedStringArray()
		for match_result: RegExMatch in placeholder.search_all(row[1]):
			english.append(match_result.get_string())
		for match_result: RegExMatch in placeholder.search_all(row[2]):
			thai.append(match_result.get_string())
		assert_eq(thai, english, "format placeholders: " + key)


func test_ui_literal_keys_and_core_messages_are_translated() -> void:
	var rows: Dictionary = _rows()
	var literal_tr: RegEx = RegEx.create_from_string("\\btr\\(\\s*[\"']([^\"']+)[\"']\\s*\\)")
	# UI builders also pass literal keys into shared label/button helpers.
	var ui_key: RegEx = RegEx.create_from_string("[\"']((?:app|menu|setup|credits|language|hud|tile|preview|history|goal|feedback|action|summary|gameover|confirm|pause|msg|err|help)\\.[a-z0-9_]+)[\"']")
	for path: String in _scripts("res://ui"):
		var source: String = FileAccess.get_file_as_string(path)
		for match_result: RegExMatch in literal_tr.search_all(source):
			assert_true(rows.has(match_result.get_string(1)), path + ": " + match_result.get_string(1))
		for match_result: RegExMatch in ui_key.search_all(source):
			assert_true(rows.has(match_result.get_string(1)), path + ": " + match_result.get_string(1))
	var message: RegEx = RegEx.create_from_string("[\"']((?:err|msg)\\.[a-z_]+)[\"']")
	for path: String in _scripts("res://core"):
		var source: String = FileAccess.get_file_as_string(path)
		for match_result: RegExMatch in message.search_all(source):
			assert_true(rows.has(match_result.get_string(1)), path + ": " + match_result.get_string(1))


func test_commands_leaders_and_dynamic_enum_names_are_translated() -> void:
	var rows: Dictionary = _rows()
	for command_id: String in CommandRules.DEFS:
		assert_true(rows.has("cmd.%s.name" % command_id), "command name: " + command_id)
		assert_true(rows.has("cmd.%s.desc" % command_id), "command description: " + command_id)
	for leader_id: String in DataDB.balance()["leaders"]:
		assert_true(rows.has("leader.%s.name" % leader_id), "leader name: " + leader_id)
		assert_true(rows.has("leader.%s.desc" % leader_id), "leader description: " + leader_id)
	for mode_id: String in DataDB.balance()["run_modes"]:
		assert_true(rows.has("run_mode.%s.name" % mode_id))
		assert_true(rows.has("run_mode.%s.desc" % mode_id))
	for goal_id: String in DataDB.balance()["village_goals"]:
		assert_true(rows.has("goal.%s.name" % goal_id))
		assert_true(rows.has("goal.%s.desc" % goal_id))
	var enums: Dictionary = {
		"season": C.Season, "building": C.Building, "feature": C.Feature,
		"phase": C.Phase, "outcome": C.Outcome,
	}
	for group: String in enums:
		for enum_key: String in enums[group]:
			var key: String = "%s.%s" % [group, enum_key.to_lower()]
			assert_true(rows.has(key), "dynamic enum key: " + key)
	for level: int in range(4):
		assert_true(rows.has("level.%d" % level), "water level name")
	assert_true(rows.has("map.plains.name"))
	assert_true(rows.has("map.plains.desc"))


func test_language_switch_translates_and_preserves_formatting() -> void:
	var original: String = TranslationServer.get_locale()
	Localization.setup("en")
	assert_eq(String(TranslationServer.translate("menu.new_game")), "New game")
	assert_eq(String(TranslationServer.translate("hud.command_cost")) % [2, 3], "Labor 2 · Wood 3")
	assert_true(Localization.change_language("th"))
	assert_eq(String(TranslationServer.translate("menu.new_game")), "เกมใหม่")
	assert_eq(String(TranslationServer.translate("hud.command_cost")) % [2, 3], "แรงงาน 2 · ไม้ 3")
	assert_true(not Localization.change_language("fr"), "unsupported locale is rejected")
	assert_eq(TranslationServer.get_locale(), "th", "invalid choice preserves selected language")
	TranslationServer.set_locale(original)


func test_setup_is_repeatable_and_uses_supported_locale() -> void:
	var original: String = TranslationServer.get_locale()
	Localization.setup("en")
	var translation: Translation = TranslationServer.get_translation_object("en")
	Localization.setup("en")
	assert_true(TranslationServer.get_translation_object("en") == translation, "setup registers resources once")
	Localization.setup("th_TH")
	assert_eq(TranslationServer.get_locale(), "th")
	Localization.setup("fr")
	assert_eq(TranslationServer.get_locale(), "en", "unsupported system languages use English")
	Localization.setup()
	assert_true(TranslationServer.get_locale() in ["en", "th"], "OS language is mapped to a supported language")
	TranslationServer.set_locale(original)


func test_export_resources_translate_without_csv_source() -> void:
	# An exported pack may omit the editor CSV while retaining its .translation
	# dependencies. Use a missing path to exercise the same source-selection path.
	var translations: Array[Translation] = Localization._load_translations("res://tests/without_translation_source.csv")
	assert_eq(translations.size(), 2)
	if translations.size() != 2:
		return
	var rows: Dictionary = _rows()
	for index: int in range(translations.size()):
		var translation: Translation = translations[index]
		assert_eq(translation.locale, ["en", "th"][index])
		for key: String in rows:
			var row: PackedStringArray = rows[key]
			assert_eq(String(translation.get_message(key)), row[index + 1], "exported translation: " + key)


func _rows() -> Dictionary:
	var rows: Dictionary = {}
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return rows
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 3 and not row[0].is_empty():
			rows[row[0]] = row
	return rows


func _scripts(path: String) -> Array[String]:
	var scripts: Array[String] = []
	for filename: String in DirAccess.get_files_at(path):
		if filename.ends_with(".gd"):
			scripts.append(path.path_join(filename))
	for directory: String in DirAccess.get_directories_at(path):
		scripts.append_array(_scripts(path.path_join(directory)))
	return scripts
