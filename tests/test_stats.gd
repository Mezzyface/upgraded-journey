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
