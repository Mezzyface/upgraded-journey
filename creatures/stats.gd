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


## The sum of a creature's five stats (the card's score).
static func score(stats: Dictionary) -> int:
	var total := 0
	for s in NAMES:
		total += int(stats.get(s, 0))
	return total


## The card's rank badge: the grade of the average stat, with "+" in the upper half of that grade's band
## (S's band runs to MAX).
static func rank_name(stats: Dictionary) -> String:
	var avg := score(stats) / float(NAMES.size())
	var g := grade(int(avg))
	var top := BREAKPOINTS[g + 1] if g + 1 < BREAKPOINTS.size() else MAX + 1
	return GRADE_NAMES[g] + ("+" if avg >= (BREAKPOINTS[g] + top) / 2.0 else "")
