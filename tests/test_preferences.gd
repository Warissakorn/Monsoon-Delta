extends TestCase

const DIRECTORY: String = "user://tests/preferences"
const PATH: String = DIRECTORY + "/settings.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for path: String in [PATH, PATH + ".tmp", DIRECTORY + "/directory"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _defaults() -> Dictionary:
	return {
		"language": "th" if OS.get_locale().to_lower().begins_with("th") else "en",
		"confirm_unused_labor": true,
		"reduced_motion": false,
	}


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	assert_true(file != null)
	if file != null:
		file.store_string(text)
		file.close()


func test_missing_and_invalid_settings_use_os_defaults_without_mutating_file() -> void:
	assert_eq(GamePreferences.read(PATH), _defaults())
	assert_true(not FileAccess.file_exists(PATH))
	for malformed: String in ["{broken", "[]", "null", "123", "\"text\""]:
		_write(malformed)
		assert_eq(GamePreferences.read(PATH), _defaults())
		assert_eq(FileAccess.get_file_as_string(PATH), malformed)
	assert_eq(GamePreferences.read(""), _defaults())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_invalid_utf8_falls_back_quietly_and_preserves_original_bytes() -> void:
	for bytes: PackedByteArray in [
		PackedByteArray([0xff]), PackedByteArray([0xc0, 0xaf]),
		PackedByteArray([0xe0, 0x80, 0x80]), PackedByteArray([0xed, 0xa0, 0x80]),
		PackedByteArray([0xf4, 0x90, 0x80, 0x80]), PackedByteArray([0xe0, 0xa0]),
	]:
		var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
		assert_eq(GamePreferences.read(PATH), _defaults())
		assert_eq(FileAccess.get_file_as_bytes(PATH), bytes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_known_preferences_roundtrip_and_merge_without_resetting_other_choice() -> void:
	assert_eq(GamePreferences.write({"language": "th", "confirm_unused_labor": false, "reduced_motion": true}, PATH), "")
	assert_eq(GamePreferences.read(PATH), {"language": "th", "confirm_unused_labor": false, "reduced_motion": true})
	assert_eq(GamePreferences.write({"language": "en"}, PATH), "")
	assert_eq(GamePreferences.read(PATH), {"language": "en", "confirm_unused_labor": false, "reduced_motion": true})
	assert_eq(GamePreferences.write({"confirm_unused_labor": true}, PATH), "")
	assert_eq(GamePreferences.read(PATH), {"language": "en", "confirm_unused_labor": true, "reduced_motion": true})
	assert_eq(GamePreferences.write({"reduced_motion": false}, PATH), "")
	assert_eq(GamePreferences.read(PATH), {"language": "en", "confirm_unused_labor": true, "reduced_motion": false})
	assert_true(not FileAccess.file_exists(PATH + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_existing_volume_fullscreen_and_future_fields_survive_merge() -> void:
	var future: Dictionary = {
		"master": 0.8, "music": 0.6, "sfx": 0.8, "ambience": 0.7,
		"fullscreen": true, "future": {"name": "ภาษาไทย 🌧️", "values": [1, false, null]},
		"language": "en", "confirm_unused_labor": false, "reduced_motion": true,
	}
	_write(JSON.stringify(future, "", true, true))
	assert_eq(GamePreferences.write({"language": "th"}, PATH), "")
	var updated: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	future["language"] = "th"
	# Compare JSON forms so Godot's parser converting JSON numbers to floats
	# does not turn this preservation check into an integer-type assertion.
	assert_eq(updated, JSON.parse_string(JSON.stringify(future, "", true, true)))
	assert_eq(GamePreferences.read(PATH), {"language": "th", "confirm_unused_labor": false, "reduced_motion": true})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_invalid_stored_known_fields_fall_back_independently() -> void:
	_write('{"language":"th","confirm_unused_labor":"false","reduced_motion":"true","fullscreen":true}')
	assert_eq(GamePreferences.read(PATH), {"language": "th", "confirm_unused_labor": true, "reduced_motion": false})
	_write('{"language":"unsupported","confirm_unused_labor":false,"reduced_motion":true,"fullscreen":true}')
	var expected: Dictionary = _defaults()
	expected["confirm_unused_labor"] = false
	expected["reduced_motion"] = true
	assert_eq(GamePreferences.read(PATH), expected)
	assert_eq(GamePreferences.write({"confirm_unused_labor": true}, PATH), "")
	var updated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(updated["language"], _defaults()["language"])
	assert_eq(updated["confirm_unused_labor"], true)
	assert_eq(updated["reduced_motion"], true)
	assert_eq(updated["fullscreen"], true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_invalid_arguments_never_modify_existing_settings() -> void:
	assert_eq(GamePreferences.write({"language": "th"}, PATH), "")
	var previous: String = FileAccess.get_file_as_string(PATH)
	for invalid: Dictionary in [
		{"language": "TH"}, {"language": "fr"}, {"language": null}, {"language": 1},
		{"confirm_unused_labor": "false"}, {"confirm_unused_labor": 0}, {"confirm_unused_labor": null},
		{"reduced_motion": "true"}, {"reduced_motion": 1}, {"reduced_motion": 0.0},
		{"reduced_motion": null}, {"reduced_motion": []}, {"reduced_motion": {}},
		{"fullscreen": true}, {1: "en"}, {"language": "en", "other": false},
	]:
		assert_eq(GamePreferences.write(invalid, PATH), "msg.settings_failed")
		assert_eq(FileAccess.get_file_as_string(PATH), previous)
		assert_true(not FileAccess.file_exists(PATH + ".tmp"))
	assert_eq(GamePreferences.write({"language": "en"}, ""), "msg.settings_failed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_atomic_write_failure_preserves_previous_and_retry_can_succeed() -> void:
	assert_eq(GamePreferences.write({"language": "th", "confirm_unused_labor": false, "reduced_motion": true}, PATH), "")
	var previous: String = FileAccess.get_file_as_string(PATH)
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	assert_eq(GamePreferences.write({"language": "en", "reduced_motion": false}, PATH), "msg.settings_failed")
	assert_eq(FileAccess.get_file_as_string(PATH), previous)
	assert_eq(GamePreferences.read(PATH), {"language": "th", "confirm_unused_labor": false, "reduced_motion": true})
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp")), OK)
	assert_eq(GamePreferences.write({"language": "en", "reduced_motion": false}, PATH), "")
	assert_eq(GamePreferences.read(PATH), {"language": "en", "confirm_unused_labor": false, "reduced_motion": false})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_corrupt_file_can_be_replaced_but_directory_errors_remain_untouched() -> void:
	_write("broken settings")
	assert_eq(GamePreferences.write({"language": "th"}, PATH), "")
	assert_eq(GamePreferences.read(PATH), {"language": "th", "confirm_unused_labor": true, "reduced_motion": false})
	var directory: String = DIRECTORY + "/directory"
	assert_eq(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(directory)), OK)
	assert_eq(GamePreferences.read(directory), _defaults())
	assert_eq(GamePreferences.write({"language": "en"}, directory), "msg.settings_failed")
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)))
	assert_true(not FileAccess.file_exists(directory + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_legacy_settings_default_to_full_motion_without_rewriting_until_a_choice_is_saved() -> void:
	var legacy: String = '{"language":"th","confirm_unused_labor":false,"future":{"volume":0.75}}'
	_write(legacy)
	assert_eq(GamePreferences.read(PATH), {"language": "th", "confirm_unused_labor": false, "reduced_motion": false})
	assert_eq(FileAccess.get_file_as_string(PATH), legacy, "reading old settings does not migrate the file")
	assert_eq(GamePreferences.write({"reduced_motion": true}, PATH), "")
	assert_eq(GamePreferences.read(PATH), {"language": "th", "confirm_unused_labor": false, "reduced_motion": true})
	var updated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(updated["future"], {"volume": 0.75}, "saving the new choice retains later screens' settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_read_failure_uses_defaults_and_cannot_overwrite_existing_motion_choice() -> void:
	assert_eq(GamePreferences.write({"language": "th", "confirm_unused_labor": false, "reduced_motion": true}, PATH), "")
	var previous: String = FileAccess.get_file_as_string(PATH)
	if OS.has_feature("linux") or OS.has_feature("macos"):
		var permissions: int = FileAccess.get_unix_permissions(PATH)
		assert_eq(FileAccess.set_unix_permissions(PATH, 0), OK)
		var probe: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if probe == null:
			assert_eq(GamePreferences.read(PATH), _defaults())
			assert_eq(GamePreferences.write({"reduced_motion": false}, PATH), "msg.settings_failed")
			assert_true(not FileAccess.file_exists(PATH + ".tmp"))
		else:
			probe.close() # Privileged hosts can bypass Unix permission bits.
		assert_eq(FileAccess.set_unix_permissions(PATH, permissions), OK)
	assert_eq(FileAccess.get_file_as_string(PATH), previous)
	assert_eq(GamePreferences.read(PATH), {"language": "th", "confirm_unused_labor": false, "reduced_motion": true})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
