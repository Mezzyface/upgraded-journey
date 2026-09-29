@tool
extends RefCounted
## Copies the Sprout Lands files the project uses from the extracted packs in asset-pipeline/sprout-lands/
## (git-ignored, licensed) into art/sprout/ (art git-ignored, .import files committed). Pack art only: it never
## writes a .tres/.tscn. Add an entry when a scene or resource starts using another pack file.

const SRC := "res://asset-pipeline/sprout-lands"
const DST := "res://art/sprout"
const UI_BASIC := "Sprout Lands - UI Pack - Basic pack/"
const UI_PREM := "Sprout Lands - UI Pack - Premium pack/"
const SPRITES_PREM := "Sprout Lands - Sprites - premium pack/"
const SORRY := "Sprout Sorry pack/"
const GROUND := SPRITES_PREM + "Tilesets/ground tiles/"

## destination (relative to DST) -> source (relative to SRC)
const FILES := {
	"ui/Sprite sheet for Basic Pack.png": UI_BASIC + "Sprite sheets/Sprite sheet for Basic Pack.png",
	"ui/Catpaw Mouse icon.png": UI_PREM + "UI Sprites/Mouse sprites/Catpaw Mouse icon.png",
	"ui/backdrops_a1.png": UI_PREM + "UI Sprites/Dialouge UI/Character Backdrop-frame/backdrops_a1.png",
	"ui/ALL UI ASSETS on one sheet.png": UI_PREM + "UI Sprites/ALL UI ASSETS on one sheet.png",
	"ui/Inventory_Spritesheet.png": UI_PREM + "emojis/emoji style ui/Inventory_Spritesheet.png",
	"ui/Weather_Icons_Big.png": UI_PREM + "emojis/emoji style ui/weather/Weather_Icons_Big.png",
	"ui/Weather_UI.png": UI_PREM + "emojis/emoji style ui/weather/Weather_UI.png",
	"sprites/Farming Plants items.png": SPRITES_PREM + "Objects/Items/Farming Plants items.png",
	"sprites/grass-n-ground-tile-items.png": SPRITES_PREM + "Objects/Items/grass-n-ground-tile-items.png",
	"palette/Sprout Lands default palette.png": SPRITES_PREM + "Sprout Lands color pallet/Sprout Lands defautlt palette.png",
	"tiles/Grass_tiles_v2.png": SPRITES_PREM + "Tilesets/ground tiles/New tiles/Grass_tiles_v2.png",
	"tiles/Soil_Ground_Tiles.png": SPRITES_PREM + "Tilesets/ground tiles/New tiles/Soil_Ground_Tiles.png",
	"tiles/Bitmask references 2.png": GROUND + "Bitmask references 2.png",
	"tiles/Bush_Tiles.png": GROUND + "New tiles/Bush_Tiles.png",
	"tiles/Darker_Grass_Hills_Tiles_v2.png": GROUND + "New tiles/Darker_Grass_Hills_Tiles_v2.png",
	"tiles/Darker_Grass_Tiles_v2.png": GROUND + "New tiles/Darker_Grass_Tiles_v2.png",
	"tiles/Darker_Grass_Tile_Layers2.png": GROUND + "New tiles/Darker_Grass_Tile_Layers2.png",
	"tiles/Darker_Grass_Tile_Layers.png": GROUND + "New tiles/Darker_Grass_Tile_Layers.png",
	"tiles/Darker_Soil_Ground_Hills_Tiles.png": GROUND + "New tiles/Darker_Soil_Ground_Hills_Tiles.png",
	"tiles/Darker_Soil_Ground_Tiles.png": GROUND + "New tiles/Darker_Soil_Ground_Tiles.png",
	"tiles/Grass_Hill_Tiles_v2.png": GROUND + "New tiles/Grass_Hill_Tiles_v2.png",
	"tiles/Grass_Tile_layers2.png": GROUND + "New tiles/Grass_Tile_layers2.png",
	"tiles/Grass_Tile_Layers.png": GROUND + "New tiles/Grass_Tile_Layers.png",
	"tiles/Soil_Ground_HiIls_Tiles.png": GROUND + "New tiles/Soil_Ground_HiIls_Tiles.png",
	"tiles/Stone_Ground_Hills_Tiles.png": GROUND + "New tiles/Stone_Ground_Hills_Tiles.png",
	"tiles/Stone_Ground_Tiles.png": GROUND + "New tiles/Stone_Ground_Tiles.png",
	"objects/Fences.png": SPRITES_PREM + "Tilesets/Building parts/Fences.png",
	"objects/grey_brick_houses_with_doors_grass.png": SORRY + "Early Access/Village pack/houses/Grey brick house/grey_brick_houses_with_doors_grass.png",
	"tiles/Fences.png": SPRITES_PREM + "Tilesets/Building parts/Fences.png",
	"tiles/Wooden_House_Walls_Tilset.png": SPRITES_PREM + "Tilesets/Building parts/Wooden_House_Walls_Tilset.png",
	"objects/Basic_Furniture.png": SPRITES_PREM + "Tilesets/Building parts/Basic_Furniture.png",
	"objects/Chikcen_Houses.png": SPRITES_PREM + "Tilesets/Building parts/Animal Structures/Chikcen_Houses.png",
	"objects/Barn structures.png": SPRITES_PREM + "Tilesets/Building parts/Animal Structures/Barn structures.png",
	"objects/Fence gates animation sprites .png": SPRITES_PREM + "Tilesets/Building parts/Fence gates animation sprites .png",
	"objects/signs.png": SPRITES_PREM + "Objects/signs.png",
	"objects/Egg_Spritesheet.png": SPRITES_PREM + "Animals/Chicken_Egg/Egg_Spritesheet.png",
	"fonts/pixelFont-7-8x14-sproutLands.ttf": UI_PREM + "fonts/Font files TTF/pixelFont-7-8x14-sproutLands.ttf",
}


## Returns the source paths that were missing or failed to copy; empty means everything was copied.
static func sync(src := SRC, dst := DST) -> PackedStringArray:
	var missing := PackedStringArray()
	for rel in FILES:
		var from := ProjectSettings.globalize_path(src.path_join(FILES[rel]))
		var to := ProjectSettings.globalize_path(dst.path_join(rel))
		if not FileAccess.file_exists(from):
			missing.append(FILES[rel])
			continue
		DirAccess.make_dir_recursive_absolute(to.get_base_dir())
		var err := DirAccess.copy_absolute(from, to)
		if err != OK:
			missing.append("%s (copy failed: %s)" % [FILES[rel], error_string(err)])
	return missing
