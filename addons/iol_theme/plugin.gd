@tool
extends EditorPlugin
## Adds "Isle of Lore" entries to Project > Tools. The theme itself is a normal resource edited in the
## Theme editor; "Rebuild" is the only thing that overwrites it, and it says so in its name.

const Builder := preload("res://addons/iol_theme/theme_builder.gd")

func _enter_tree() -> void:
	add_tool_menu_item("Isle of Lore: Sync UI pack files", _sync)
	add_tool_menu_item("Isle of Lore: Rebuild theme from pack (overwrites edits)", _rebuild)

func _exit_tree() -> void:
	remove_tool_menu_item("Isle of Lore: Sync UI pack files")
	remove_tool_menu_item("Isle of Lore: Rebuild theme from pack (overwrites edits)")

func _sync() -> void:
	var n := Builder.sync()
	EditorInterface.get_resource_filesystem().scan()
	print("[iol_theme] synced %d pack files into %s" % [n, Builder.OUT_DIR])

func _rebuild() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs.is_scanning():
		push_warning("[iol_theme] filesystem still importing the pack files; run Rebuild again in a moment")
		return
	var err := Builder.build()
	if err == OK:
		fs.scan()
		print("[iol_theme] rebuilt %s" % Builder.THEME_PATH)
	else:
		push_error("[iol_theme] rebuild failed: %s" % error_string(err))
