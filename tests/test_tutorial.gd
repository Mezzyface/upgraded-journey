extends TestSuite
## Tutorial.advance: only the current step's action moves on; skipped and finished stay put.


func test_each_step_advances_on_its_own_action() -> void:
	for i in Tutorial.STEPS.size():
		eq(Tutorial.advance(i, Tutorial.STEPS[i]["done"]), i + 1, "step %d on %s" % [i, Tutorial.STEPS[i]["done"]])


func test_other_actions_do_not_advance() -> void:
	eq(Tutorial.advance(0, &"expedition"), 0, "a later step's action early")
	eq(Tutorial.advance(3, &"orders"), 3, "an earlier step's action again")
	eq(Tutorial.advance(0, &"nonsense"), 0, "unknown")


func test_skipped_and_finished_stay_put() -> void:
	eq(Tutorial.advance(Tutorial.SKIPPED, Tutorial.STEPS[0]["done"]), Tutorial.SKIPPED, "skipped")
	var n := Tutorial.STEPS.size()
	eq(Tutorial.advance(n, &"orders"), n, "finished")
	check(not Tutorial.active(Tutorial.SKIPPED) and not Tutorial.active(n) and Tutorial.active(0), "active range")


func test_the_steps_are_the_spec_order() -> void:
	eq(Tutorial.STEPS.map(func(s: Dictionary) -> StringName: return s["done"]),
		[&"orders", &"accept", &"card", &"train", &"care", &"market", &"end_day", &"expedition", &"stable", &"deliver"],
		"ten steps")


func test_every_step_has_a_short_line_for_narrow_moments() -> void:
	for step: Dictionary in Tutorial.STEPS:
		check(step.has("short") and String(step["short"]).length() <= 14, "short line: %s" % step)


func test_the_breeding_step_never_asks_to_retire_on_a_fresh_ranch() -> void:
	var text: String = Tutorial.STEPS[8]["text"]
	check(text.contains("same egg group"), "explains the pairing rule: %s" % text)
	check(text.contains("permanent"), "warns that retiring is permanent")
	eq(Tutorial.STEPS[8]["done"], &"stable", "finished by opening the Stable, not by breeding")
