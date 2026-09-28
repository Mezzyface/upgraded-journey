@tool
extends EditorPlugin
## Project > Tools: "Sprout Lands: Sync pack files" (copies pack art only) and "Sprout Lands: Set up ranch terrains (overwrites terrain bits)".

const Sync := preload("res://addons/sprout_tools/sprout_sync.gd")
const MENU := "Sprout Lands: Sync pack files"
const Terrains := preload("res://addons/sprout_tools/ranch_terrains.gd")
const TERRAIN_MENU := "Sprout Lands: Set up ranch terrains (overwrites terrain bits)"
const TILESET := "res://ranch/ranch_tileset.tres"


func _enter_tree() -> void:
	add_tool_menu_item(MENU, _sync)
	add_tool_menu_item(TERRAIN_MENU, _set_up_terrains)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	remove_tool_menu_item(TERRAIN_MENU)


func _sync() -> void:
	var missing := Sync.sync()
	EditorInterface.get_resource_filesystem().scan()
	if missing.is_empty():
		print("[sprout_tools] synced %d files into %s" % [Sync.FILES.size(), Sync.DST])
	else:
		push_error("[sprout_tools] not synced (missing under %s — extract the zips there first — or failed to copy):\n%s" % [Sync.SRC, "\n".join(missing)])


func _set_up_terrains() -> void:
	var ts := load(TILESET) as TileSet
	if ts == null:
		push_error("[sprout_tools] %s not found — create it with a TileSet from RanchTerrains.new_tileset() (see README)" % TILESET)
		return
	var errors := Terrains.apply(ts)
	if not errors.is_empty():
		push_error("[sprout_tools] terrains not set up:\n" + "\n".join(errors))
		return
	var err := ResourceSaver.save(ts, TILESET)
	if err != OK:
		push_error("[sprout_tools] failed to save %s: %s" % [TILESET, error_string(err)])
		return
	print("[sprout_tools] ranch terrains set up in %s" % TILESET)
