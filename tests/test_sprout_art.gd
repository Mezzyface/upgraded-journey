extends TestSuite
## A fresh clone only has the pack files SproutSync copies: every res://art/sprout/ path a scene, resource or
## project.godot uses must be in SproutSync.FILES, or it renders blank.

const Sync := preload("res://addons/sprout_tools/sprout_sync.gd")
const SKIP := ["addons", "asset-pipeline", "docs", "tests"]


func test_every_sprout_reference_is_synced() -> void:
	var re := RegEx.create_from_string("res://art/sprout/([^\"]+)")
	for path in _text_files("res://"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			check(Sync.FILES.has(m.get_string(1)), "%s uses art/sprout/%s, not in SproutSync.FILES" % [path, m.get_string(1)])


func test_ranch_art_is_listed() -> void:
	for rel in ["tiles/Grass_tiles_v2.png", "tiles/Soil_Ground_Tiles.png", "tiles/Fences.png",
			"tiles/Wooden_House_Walls_Tilset.png", "objects/Basic_Furniture.png", "objects/Chikcen_Houses.png",
			"objects/Barn structures.png", "objects/Fence gates animation sprites .png", "objects/signs.png",
			"objects/Egg_Spritesheet.png"]:
		check(Sync.FILES.has(rel), "SproutSync.FILES lists %s" % rel)


func _text_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d not in SKIP:
			out.append_array(_text_files(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["tscn", "tres", "godot"]:
			out.append(dir.path_join(f))
	return out
