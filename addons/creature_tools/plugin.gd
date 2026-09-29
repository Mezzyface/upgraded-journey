@tool
extends EditorPlugin
## Project > Tools > "Creatures: Import monster pack…": pick a pack folder; each variant is copied into
## creatures/pack/ and gets a SpriteFrames and a starter Species. Create-only, never overwrites.
## Also adds the Inspector's "Preview in pen" button on a Species (species_preview_button.gd).

const Importer := preload("res://addons/creature_tools/pack_importer.gd")
const MENU := "Creatures: Import monster pack…"

var _dialog: EditorFileDialog
var _preview_button := preload("res://addons/creature_tools/species_preview_button.gd").new()


func _enter_tree() -> void:
	add_tool_menu_item(MENU, _open)
	add_inspector_plugin(_preview_button)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	remove_inspector_plugin(_preview_button)
	if _dialog:
		_dialog.queue_free()


func _open() -> void:
	if _dialog == null:
		_dialog = EditorFileDialog.new()
		_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
		_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		_dialog.title = "Pick a Monster Pack folder"
		_dialog.dir_selected.connect(_import)
		EditorInterface.get_base_control().add_child(_dialog)
	_dialog.current_dir = ProjectSettings.globalize_path(Importer.PACKS_DIR)
	_dialog.popup_file_dialog()


func _import(pack_dir: String) -> void:
	var copied := Importer.copy_pack(pack_dir)
	if copied.is_empty():
		push_warning("[creature_tools] no spritesheets found in %s" % pack_dir)
		return
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	await get_tree().process_frame
	while fs.is_scanning() or fs.is_importing():
		await get_tree().process_frame
	var made := Importer.build_resources(copied)
	fs.scan()
	print("[creature_tools] %s: %d variants, created %s" % [pack_dir.get_file(), copied.size(), made])
