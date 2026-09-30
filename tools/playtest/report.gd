class_name PlaytestReport
extends RefCounted
## Markdown for the bot playtest (tools/playtest/playtest.gd) and the stalls it flags. Scene-free and Game-free.

const FLAT_DAYS := 5  ## gold not growing this many days in a row is a stall


static func markdown(runs: Array) -> String:
	var out: PackedStringArray = ["# Bot playtest", ""]
	for run: Dictionary in runs:
		var days: Array = run["days"]
		out.append("## Seed %d" % run["seed"])
		out.append("")
		out.append("| Day | Gold | Δ | Rep | Tier | Owned | Retired | Eggs | Orders | Delivered | Missed | AP left | Actions |")
		out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
		for d: Dictionary in days:
			out.append("| %d | %d | %+d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %s |" % [d["day"], d["gold"],
				d["gold_delta"], d["rep"], d["tier"], d["owned"], d["retired"], d["eggs"], d["orders"], d["delivered"],
				d["missed"], d["ap_left"], "; ".join(d["actions"])])
		out.append("")
		out.append("**Goals**")
		for goal in run["goals"]:
			out.append("- %s: %s" % [goal, run["goals"][goal]])
		out.append("")
		for section in [["Errors", run["errors"]], ["Stalls", stalls(days)], ["UI gaps", run["gaps"]]]:
			out.append("**%s**" % section[0])
			var items: PackedStringArray = section[1]
			if items.is_empty():
				out.append("- none")
			for item in items:
				out.append("- " + item)
			out.append("")
	return "\n".join(out)


static func stalls(days: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for d: Dictionary in days:
		if (d["actions"] as PackedStringArray).is_empty() and int(d["ap_left"]) > 0:
			out.append("day %d: did nothing with %d AP left" % [d["day"], d["ap_left"]])
	var streak_start := -1  ## index of the first day of a stretch whose gold didn't rise over the day before
	for i in range(1, days.size() + 1):
		var flat: bool = i < days.size() and int(days[i]["gold"]) <= int(days[i - 1]["gold"])
		if flat and streak_start < 0:
			streak_start = i
		elif not flat and streak_start >= 0:
			if i - streak_start >= FLAT_DAYS:
				out.append("days %d-%d: gold did not grow" % [days[streak_start]["day"], days[i - 1]["day"]])
			streak_start = -1
	if not days.is_empty() and days.all(func(d: Dictionary) -> bool: return int(d["delivered"]) == 0):
		out.append("never delivered an order")
	return out
