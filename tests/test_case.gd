class_name TestCase
extends RefCounted
## Small assertion API shared by the headless test suites.

var _failures: PackedStringArray = PackedStringArray()


func before_each() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		fail("expected true. " + message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("expected %s, got %s. %s" % [var_to_str(expected), var_to_str(actual), message])


func assert_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if is_nan(actual) or is_nan(expected) or absf(actual - expected) > tolerance:
		fail("expected %.9f +/- %g, got %.9f. %s" % [expected, tolerance, actual, message])


func fail(message: String) -> void:
	_failures.append(message)


func take_failures() -> PackedStringArray:
	var result: PackedStringArray = _failures
	_failures = PackedStringArray()
	return result
