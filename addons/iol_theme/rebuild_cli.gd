extends SceneTree
## Headless entry point for the same tools, for a fresh clone or CI:
##   godot --headless --path . -s addons/iol_theme/rebuild_cli.gd sync
##   godot --headless --path . --import
##   godot --headless --path . -s addons/iol_theme/rebuild_cli.gd build

const Builder := preload("res://addons/iol_theme/theme_builder.gd")

func _init() -> void:
	var args := OS.get_cmdline_args()
	if "sync" in args:
		print("synced %d files" % Builder.sync())
	elif "build" in args:
		print("build: ", error_string(Builder.build()))
	else:
		print("usage: -s addons/iol_theme/rebuild_cli.gd sync|build")
	quit()
