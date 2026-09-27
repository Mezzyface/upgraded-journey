@tool
extends RefCounted
## Copies the Sprout Lands files the project uses from the extracted packs in asset-pipeline/sprout-lands/
## (git-ignored, licensed) into art/sprout/ (art git-ignored, .import files committed). Pack art only: it never
## writes a .tres/.tscn. Add an entry when a scene or resource starts using another pack file.

const SRC := "res://asset-pipeline/sprout-lands"
const DST := "res://art/sprout"
const UI_BASIC := "Sprout Lands - UI Pack - Basic pack/"
const UI_PREM := "Sprout Lands - UI Pack - Premium pack/"

## destination (relative to DST) -> source (relative to SRC)
const FILES := {
	"ui/Sprite sheet for Basic Pack.png": UI_BASIC + "Sprite sheets/Sprite sheet for Basic Pack.png",
	"ui/Catpaw Mouse icon.png": UI_PREM + "UI Sprites/Mouse sprites/Catpaw Mouse icon.png",
	"ui/backdrops_a1.png": UI_PREM + "UI Sprites/Dialouge UI/Character Backdrop-frame/backdrops_a1.png",
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
