extends TestSuite


func test_grade_breakpoints() -> void:
	eq(Stats.grade(0), Stats.Grade.E, "0")
	eq(Stats.grade(99), Stats.Grade.E, "99")
	eq(Stats.grade(100), Stats.Grade.D, "100")
	eq(Stats.grade(249), Stats.Grade.D, "249")
	eq(Stats.grade(250), Stats.Grade.C, "250")
	eq(Stats.grade(399), Stats.Grade.C, "399")
	eq(Stats.grade(400), Stats.Grade.B, "400")
	eq(Stats.grade(600), Stats.Grade.A, "600")
	eq(Stats.grade(799), Stats.Grade.A, "799")
	eq(Stats.grade(800), Stats.Grade.S, "800")
	eq(Stats.grade(999), Stats.Grade.S, "999")


func test_grade_name() -> void:
	eq(Stats.grade_name(450), "B", "450")
	eq(Stats.grade_name(0), "E", "0")
	eq(Stats.NAMES.size(), 5, "five stats")


func test_score_sums_the_five_stats() -> void:
	eq(Stats.score({"power": 300, "guard": 240, "speed": 90, "wits": 90, "heart": 150}), 870, "sum")
	eq(Stats.score({}), 0, "missing stats count as 0")


func test_rank_is_the_average_grade_with_a_plus_in_the_upper_half() -> void:
	var even := func(v: int) -> Dictionary:
		return {"power": v, "guard": v, "speed": v, "wits": v, "heart": v}
	eq(Stats.rank_name(even.call(0)), "E", "bottom")
	eq(Stats.rank_name(even.call(99)), "E+", "E runs 0-99: upper half from 50")
	eq(Stats.rank_name(even.call(250)), "C", "C starts at 250")
	eq(Stats.rank_name(even.call(325)), "C+", "C's midpoint is 325")
	eq(Stats.rank_name(even.call(899)), "S", "S runs to 999: plus from 900")
	eq(Stats.rank_name(even.call(900)), "S+", "top")
	eq(Stats.rank_name({"power": 999, "guard": 0, "speed": 0, "wits": 0, "heart": 0}), "D+", "averaged: 199.8, past D's midpoint 175")
