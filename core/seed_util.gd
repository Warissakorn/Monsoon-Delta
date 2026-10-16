class_name SeedUtil
extends RefCounted


static func fnv1a32(text: String) -> int:
	var hash_value: int = 2166136261
	for byte: int in text.to_utf8_buffer():
		hash_value = ((hash_value ^ byte) * 16777619) & 0xffffffff
	return hash_value


static func derive_seed(seed_value: int, salt: int) -> int:
	# Decimal separators keep the two integers unambiguous across platforms.
	return fnv1a32("%d:%d" % [seed_value, salt])


static func parse_seed_text(text: String) -> int:
	var stripped: String = text.strip_edges()
	if stripped.is_empty():
		return 0
	if stripped.is_valid_int():
		return stripped.to_int()
	return fnv1a32(stripped)
