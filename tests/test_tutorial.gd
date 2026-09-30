extends TestSuite
## Tutorial.advance: only the current step's action moves on; skipped and finished stay put.


func test_each_step_advances_on_its_own_action() -> void:
	for i in Tutorial.STEPS.size():
		eq(Tutorial.advance(i, Tutorial.STEPS[i]["done"]), i + 1, "step %d on %s" % [i, Tutorial.STEPS[i]["done"]])


func test_other_actions_do_not_advance() -> void:
	eq(Tutorial.advance(0, &"breed"), 0, "a later step's action early")
	eq(Tutorial.advance(3, &"orders"), 3, "an earlier step's action again")
	eq(Tutorial.advance(0, &"nonsense"), 0, "unknown")


func test_skipped_and_finished_stay_put() -> void:
	eq(Tutorial.advance(Tutorial.SKIPPED, Tutorial.STEPS[0]["done"]), Tutorial.SKIPPED, "skipped")
	var n := Tutorial.STEPS.size()
	eq(Tutorial.advance(n, &"orders"), n, "finished")
	check(not Tutorial.active(Tutorial.SKIPPED) and not Tutorial.active(n) and Tutorial.active(0), "active range")


func test_the_steps_are_the_spec_order() -> void:
	eq(Tutorial.STEPS.map(func(s: Dictionary) -> StringName: return s["done"]),
		[&"orders", &"accept", &"card", &"train", &"care", &"market", &"end_day", &"expedition", &"breed", &"deliver"],
		"ten steps")
