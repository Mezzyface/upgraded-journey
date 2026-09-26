class_name Stats
extends RefCounted
## Stat names, the 0-999 range and the grade breakpoints that orders and evolutions use.

enum Grade { E, D, C, B, A, S }

const NAMES: PackedStringArray = ["power", "guard", "speed", "wits", "heart"]
const MAX := 999
const GRADE_NAMES: PackedStringArray = ["E", "D", "C", "B", "A", "S"]
const BREAKPOINTS: PackedInt32Array = [0, 100, 250, 400, 600, 800]


static func grade(value: int) -> int:
	for g in range(BREAKPOINTS.size() - 1, 0, -1):
		if value >= BREAKPOINTS[g]:
			return g
	return Grade.E


static func grade_name(value: int) -> String:
	return GRADE_NAMES[grade(value)]
