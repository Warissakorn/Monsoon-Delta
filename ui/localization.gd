class_name Localization
extends RefCounted
## Prefer editable CSV in a checkout; use imported resources in an export.

const STRINGS_PATH: String = "res://translations/strings.csv"
const LANGUAGES: PackedStringArray = ["en", "th"]

static var _registered: bool = false
static var _translations: Array[Translation] = []


static func setup(language: String = "") -> void:
	if not _registered:
		_register_translations()
	var requested: String = language.to_lower().split("_")[0].split("-")[0]
	if requested.is_empty():
		requested = OS.get_locale_language().to_lower()
	if requested not in LANGUAGES:
		requested = "en"
	TranslationServer.set_locale(requested)


static func change_language(language: String) -> bool:
	if language not in LANGUAGES:
		return false
	setup(language)
	return true


static func _register_translations() -> void:
	var translations: Array[Translation] = _load_translations()
	if translations.size() != LANGUAGES.size():
		return
	for translation: Translation in translations:
		TranslationServer.add_translation(translation)
	_translations = translations
	_registered = true


static func _load_translations(source_path: String = STRINGS_PATH) -> Array[Translation]:
	if not FileAccess.file_exists(source_path):
		return _load_imported_translations()
	var translations: Array[Translation] = []
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		push_error("Cannot read translation source: " + source_path)
		return []
	var header: PackedStringArray = file.get_csv_line()
	if header != PackedStringArray(["keys", "en", "th"]):
		push_error("Invalid translation CSV header")
		return []
	for language: String in LANGUAGES:
		var translation: Translation = Translation.new()
		translation.locale = language
		translations.append(translation)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		if row.size() != 3 or row[0].is_empty():
			push_error("Invalid translation CSV row")
			return []
		for index: int in range(LANGUAGES.size()):
			translations[index].add_message(row[0], row[index + 1])
	return translations


static func _load_imported_translations() -> Array[Translation]:
	var translations: Array[Translation] = []
	for language: String in LANGUAGES:
		var path: String = "res://translations/strings.%s.translation" % language
		if not ResourceLoader.exists(path, "Translation"):
			push_error("Cannot find translation resource: " + path)
			return []
		var translation: Translation = ResourceLoader.load(path, "Translation") as Translation
		# OptimizedTranslation cannot enumerate message keys or report their count.
		if translation == null or translation.locale != language or String(translation.get_message("app.title")).is_empty():
			push_error("Invalid translation resource: " + path)
			return []
		translations.append(translation)
	return translations
