class_name GamePreferences
extends RefCounted
## Small M4 settings store. Preserve fields owned by later settings screens
## while exposing only preferences that this version can validate and use.

const DEFAULT_PATH: String = "user://settings.json"


static func read(path: String = DEFAULT_PATH) -> Dictionary:
	var stored: Dictionary = _read_existing(path)
	return _validated(stored["values"])


static func write(values: Dictionary, path: String = DEFAULT_PATH) -> String:
	if path.is_empty():
		return "msg.settings_failed"
	for key: Variant in values:
		match key:
			"language":
				if not values[key] is String or values[key] not in ["th", "en"]:
					return "msg.settings_failed"
			"confirm_unused_labor":
				if typeof(values[key]) != TYPE_BOOL:
					return "msg.settings_failed"
			_:
				return "msg.settings_failed"
	var stored: Dictionary = _read_existing(path)
	if stored["read_failed"]:
		return "msg.settings_failed"
	var data: Dictionary = stored["values"]
	# Repair invalid known fields using OS defaults, retaining all unrelated
	# JSON values from a successfully parsed settings dictionary.
	var valid: Dictionary = _validated(data)
	valid.merge(values, true)
	data.merge(valid, true)
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "msg.settings_failed"
	file.store_string(JSON.stringify(data, "", true, true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return "msg.settings_failed"
	var renamed: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)
	)
	if renamed != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return "msg.settings_failed"
	return ""


static func _defaults() -> Dictionary:
	return {
		"language": "th" if OS.get_locale().to_lower().begins_with("th") else "en",
		"confirm_unused_labor": true,
	}


static func _validated(data: Dictionary) -> Dictionary:
	var result: Dictionary = _defaults()
	if data.get("language") is String and data["language"] in ["th", "en"]:
		result["language"] = data["language"]
	if typeof(data.get("confirm_unused_labor")) == TYPE_BOOL:
		result["confirm_unused_labor"] = data["confirm_unused_labor"]
	return result


static func _read_existing(path: String) -> Dictionary:
	var empty: Dictionary = {"values": {}, "read_failed": false}
	if path.is_empty():
		return empty
	if not FileAccess.file_exists(path):
		empty["read_failed"] = DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))
		return empty
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"values": {}, "read_failed": true}
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	var error: Error = file.get_error()
	file.close()
	if bytes.size() != length or error not in [OK, ERR_FILE_EOF]:
		return {"values": {}, "read_failed": true}
	if not _valid_utf8(bytes):
		return empty
	var parser: JSON = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return empty
	return {"values": parser.data, "read_failed": false}


static func _valid_utf8(bytes: PackedByteArray) -> bool:
	# Validate before decoding: Godot logs an engine error for malformed UTF-8,
	# but a damaged preferences file should quietly use the OS defaults.
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first <= 0x7f:
			index += 1
			continue
		var count: int = 0
		if first >= 0xc2 and first <= 0xdf:
			count = 2
		elif first >= 0xe0 and first <= 0xef:
			count = 3
		elif first >= 0xf0 and first <= 0xf4:
			count = 4
		else:
			return false
		if index + count > bytes.size():
			return false
		for offset: int in range(1, count):
			if bytes[index + offset] < 0x80 or bytes[index + offset] > 0xbf:
				return false
		var second: int = bytes[index + 1]
		if (first == 0xe0 and second < 0xa0) or (first == 0xed and second >= 0xa0):
			return false
		if (first == 0xf0 and second < 0x90) or (first == 0xf4 and second > 0x8f):
			return false
		index += count
	return true
