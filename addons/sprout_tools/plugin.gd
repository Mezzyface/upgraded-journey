@tool
extends EditorPlugin
## Project > Tools: "Sprout Lands: Sync pack files" (copies pack art only).

const Sync := preload("res://addons/sprout_tools/sprout_sync.gd")
const MENU := "Sprout Lands: Sync pack files"


func _enter_tree() -> void:
	add_tool_menu_item(MENU, _sync)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)


func _sync() -> void:
	var missing := Sync.sync()
	EditorInterface.get_resource_filesystem().scan()
	if missing.is_empty():
		print("[sprout_tools] synced %d files into %s" % [Sync.FILES.size(), Sync.DST])
	else:
		push_error("[sprout_tools] not synced (missing under %s — extract the zips there first — or failed to copy):\n%s" % [Sync.SRC, "\n".join(missing)])
