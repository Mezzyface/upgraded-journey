extends SceneTree
## Bot playtest (docs/superpowers/specs/2026-09-30-bot-playtest-design.md):
##   godot --headless --path . -s res://tools/playtest/playtest.gd -- --days=30 --seeds=1,2,3 --out=user://playtest_report.md
## Plays each seed from a fresh game for --days days with tools/playtest/bot.gd, then checks a mid-run reload, and writes
## the Markdown report (tools/playtest/report.gd). Never touches the player's save.


class ErrorCatcher extends Logger:
	var script_errors: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			script_errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file, line])


func _initialize() -> void:
	await process_frame
	var days := 30
	var seeds: PackedInt32Array = [1, 2, 3]
	var out := "user://playtest_report.md"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			days = int(arg.trim_prefix("--days="))
		elif arg.begins_with("--seeds="):
			seeds = PackedInt32Array(Array(arg.trim_prefix("--seeds=").split(",")).map(func(s: String) -> int: return int(s)))
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var game: Node = root.get_node("Game")
	var runs: Array = []
	for seed_value in seeds:
		game.save_path = "user://playtest_%d.json" % seed_value
		DirAccess.remove_absolute(game.save_path)
		game.start_new(load("res://data/new_game.tres"), Db.load_dir(), seed_value)
		var shop: Control = load("res://shop/shop.tscn").instantiate()
		root.add_child(shop)
		await process_frame
		var bot = load("res://tools/playtest/bot.gd").new(shop)
		var records: Array = []
		var errors: PackedStringArray = []
		for n in days:
			catcher.script_errors.clear()
			var record: Dictionary = await bot.play_day()
			for e in catcher.script_errors:
				errors.append("day %d: %s" % [record["day"], e])
			records.append(record)
			print("seed %d day %d: gold %d, rep %d, %d actions" % [seed_value, record["day"], record["gold"], record["rep"],
				(record["actions"] as PackedStringArray).size()])
		var goals: Dictionary = bot.goals()
		var before: Dictionary = game.state.to_dict()
		game.start(game.db)  # a real reload from the save written by the last action / evening
		goals["mid-run reload restores the state"] = "yes" if game.state.to_dict() == before else "NO"
		runs.append({"seed": seed_value, "days": records, "errors": errors, "gaps": bot.gaps, "goals": goals})
		shop.queue_free()
		await process_frame
	var md: String = load("res://tools/playtest/report.gd").markdown(runs)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(md)
	f.close()
	print("report: ", ProjectSettings.globalize_path(out))
	quit()
