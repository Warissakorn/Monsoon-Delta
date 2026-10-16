class_name DataDB
extends RefCounted
## Read-only shared data, loaded once per process.

static var _balance: Dictionary = {}
static var _balance_loaded: bool = false
static var _palette: Dictionary = {}
static var _palette_loaded: bool = false


static func balance() -> Dictionary:
	if not _balance_loaded:
		_balance = _read_dictionary("res://data/balance.json")
		_balance_loaded = true
	return _balance


static func palette() -> Dictionary:
	if not _palette_loaded:
		if FileAccess.file_exists("res://data/palette.json"):
			_palette = _read_dictionary("res://data/palette.json")
		_palette_loaded = true
	return _palette


static func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing game data: " + path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot read game data: " + path)
		return {}
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	if error != OK or not parser.data is Dictionary:
		push_error("Invalid game data at %s: %s" % [path, parser.get_error_message()])
		return {}
	return parser.data as Dictionary
