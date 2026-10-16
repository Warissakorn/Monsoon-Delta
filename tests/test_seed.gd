extends TestCase


func test_fnv1a_known_vectors() -> void:
	assert_eq(SeedUtil.fnv1a32(""), 2166136261)
	assert_eq(SeedUtil.fnv1a32("a"), 3826002220)
	assert_eq(SeedUtil.fnv1a32("abc"), 440920331)
	assert_eq(SeedUtil.fnv1a32("hello"), 1335831723)


func test_derived_streams_are_repeatable_and_separate() -> void:
	for seed_value: int in [0, 1, 42, 2147483647]:
		var first: int = SeedUtil.derive_seed(seed_value, 9000)
		assert_eq(first, SeedUtil.derive_seed(seed_value, 9000), "repeatable derivation")
		assert_true(first != SeedUtil.derive_seed(seed_value, 9001), "different streams need separate seeds")
		assert_true(first != SeedUtil.derive_seed(seed_value + 1, 9000), "different base seeds")


func test_seed_text_accepts_numbers_and_stable_names() -> void:
	assert_eq(SeedUtil.parse_seed_text(" 42 "), 42)
	assert_eq(SeedUtil.parse_seed_text("-17"), -17)
	assert_eq(SeedUtil.parse_seed_text("9223372036854775000"), 9223372036854775000)
	assert_eq(SeedUtil.parse_seed_text(""), 0)
	assert_eq(SeedUtil.parse_seed_text("abc"), 440920331)
	assert_eq(SeedUtil.parse_seed_text(" เมืองน้ำ "), SeedUtil.parse_seed_text("เมืองน้ำ"))
