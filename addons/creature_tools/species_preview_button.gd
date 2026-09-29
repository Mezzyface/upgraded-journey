@tool
extends EditorInspectorPlugin
## Puts a "Preview in pen" button at the top of a Species in the Inspector: runs creatures/species_preview.tscn with
## that species (passed through a user:// file, since play_custom_scene takes no arguments). Running saves the
## edited .tres first (Editor Settings > Run > Auto Save > Save Before Running, on by default).

const PREVIEW := "res://creatures/species_preview.tscn"
const PICK_FILE := "user://species_preview.txt"


func _can_handle(object: Object) -> bool:
	return object is Species


func _parse_begin(object: Object) -> void:
	var b := Button.new()
	b.text = "Preview in pen"
	b.icon = EditorInterface.get_editor_theme().get_icon(&"Play", &"EditorIcons")
	b.pressed.connect(_preview.bind(object))
	add_custom_control(b)


func _preview(sp: Species) -> void:
	if sp.resource_path == "" or sp.resource_path.contains("::"):
		push_warning("[creature_tools] save the species as its own .tres to preview it")
		return
	var f := FileAccess.open(PICK_FILE, FileAccess.WRITE)
	f.store_string(sp.resource_path)
	f.close()
	EditorInterface.play_custom_scene(PREVIEW)
