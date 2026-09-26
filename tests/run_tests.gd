extends SceneTree
## Headless test runner (no framework). From the repo root:
##   godot --headless --path . -s res://tests/run_tests.gd
## Runs every test_* method of every tests/test_*.gd. Exit code 1 if anything fails.


## Catches script errors (e.g. a null call) that a test triggers. Without this, a test that aborts on a
## script error before reaching any check() would be counted as passed. push_error()/push_warning() are a
## different error type and are not caught, so expected-error tests (duplicate id, save warnings) are unaffected.
class ErrorCatcher extends Logger:
	var script_errors: PackedStringArray = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			script_errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file, line])


func _init() -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var ran := 0
	var failed := 0
	for file in ResourceLoader.list_directory("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: Script = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			printerr("FAIL %s  does not compile" % file)
			failed += 1
			continue
		var suite: TestSuite = script.new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			suite.failures.clear()
			catcher.script_errors.clear()
			suite.call(name)
			ran += 1
			for e in catcher.script_errors:
				suite.failures.append("script error: %s" % e)
			if suite.failures.is_empty():
				continue
			failed += 1
			for f in suite.failures:
				printerr("FAIL %s::%s  %s" % [file, name, f])
	print("%d tests, %d failed" % [ran, failed])
	quit(1 if failed > 0 else 0)
