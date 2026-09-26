class_name TestSuite
extends RefCounted
## Base for tests/test_*.gd. `check` records a failure instead of stopping, so one run reports everything.

var failures: PackedStringArray = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, what: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [what, expected, actual])
