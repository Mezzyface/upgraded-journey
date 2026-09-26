extends SceneTree
## Headless test runner (no framework). From the repo root:
##   godot --headless --path . -s res://tests/run_tests.gd
## Runs every test_* method of every tests/test_*.gd. Exit code 1 if anything fails.


func _init() -> void:
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
			suite.call(name)
			ran += 1
			if suite.failures.is_empty():
				continue
			failed += 1
			for f in suite.failures:
				printerr("FAIL %s::%s  %s" % [file, name, f])
	print("%d tests, %d failed" % [ran, failed])
	quit(1 if failed > 0 else 0)
