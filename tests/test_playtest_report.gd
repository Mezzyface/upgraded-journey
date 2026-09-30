extends TestSuite
## PlaytestReport: the Markdown the bot playtest writes, and the stalls it flags.


func _day(n: int, gold: int, actions: Array, delivered := 0, ap_left := 0) -> Dictionary:
	return {"day": n, "gold": gold, "gold_delta": 0, "rep": 0, "tier": 0, "owned": 3, "retired": 0, "eggs": 0,
		"orders": 1, "delivered": delivered, "missed": 0, "ap_left": ap_left,
		"actions": PackedStringArray(actions), "events": PackedStringArray()}


func test_markdown_has_a_day_table_errors_gaps_and_goals() -> void:
	var run := {"seed": 7, "days": [_day(1, 500, ["trained Spider #1's power"]), _day(2, 480, [])],
		"errors": PackedStringArray(["day 2: boom"]), "gaps": PackedStringArray(["no spot to build a pen"]),
		"goals": {"order kinds filled": "stat, trait"}}
	var md := PlaytestReport.markdown([run])
	check(md.contains("## Seed 7"), "a section per seed")
	check(md.contains("| Day | Gold |"), "a day table")
	check(md.contains("| 1 | 500 |"), "a row per day")
	check(md.contains("day 2: boom"), "errors listed")
	check(md.contains("no spot to build a pen"), "gaps listed")
	check(md.contains("order kinds filled: stat, trait"), "goals listed")


func test_stalls_flag_idle_days_flat_gold_and_no_deliveries() -> void:
	var days := [_day(1, 500, [], 0, 3)]
	for n in range(2, 8):
		days.append(_day(n, 500, ["x"]))
	var found := PlaytestReport.stalls(days)
	check(found.has("day 1: did nothing with 3 AP left"), "idle day: %s" % [found])
	check(found.has("days 2-7: gold did not grow"), "flat gold: %s" % [found])
	check(found.has("never delivered an order"), "no deliveries: %s" % [found])
	eq(PlaytestReport.stalls([_day(1, 500, ["x"], 1), _day(2, 600, ["x"])]).size(), 0, "a healthy run has none")
