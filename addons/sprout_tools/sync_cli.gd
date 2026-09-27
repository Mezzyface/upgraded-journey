extends SceneTree
## godot --headless --path . -s res://addons/sprout_tools/sync_cli.gd   (then run --import once)

func _initialize() -> void:
	var missing: PackedStringArray = preload("res://addons/sprout_tools/sprout_sync.gd").sync()
	for m in missing:
		printerr("missing: ", m)
	quit(1 if missing.size() > 0 else 0)
