@tool
extends RefCounted
## Copies a monster pack's spritesheets into creatures/pack/ (git-ignored, licensed art) and creates a
## SpriteFrames (creatures/frames/) and a starter Species (data/species/) per variant. Create-only: an existing
## SpriteFrames or Species is never touched, so edits made in the editor are safe.
## Sheet layout (all packs): 128x128 cells, one row per facing (FACINGS, top to bottom), columns are frames.

const PACKS_DIR := "res://asset-pipeline/80_Monster_Packs/Monster Packs"
const OUT_DIR := "res://creatures/pack"
const FRAMES_DIR := "res://creatures/frames"
const SPECIES_DIR := "res://data/species"
const CELL := 128
const FACINGS: PackedStringArray = ["down", "left", "right", "up"]  ## sheet rows top to bottom; confirmed visually on spider (2026-09-26)
const FPS := 8.0


static func variant_id(folder: String) -> String:
	return folder.trim_prefix("Updated ").strip_edges().to_lower().replace(" ", "_")


## The shared "<Name>_" part of a variant's sheet names; what follows it is the animation name.
static func common_prefix(files: Array) -> String:
	var stems: Array = files.map(func(f: String) -> String: return f.get_basename())
	var p: String = stems[0]
	for s: String in stems:
		while not s.begins_with(p):
			p = p.left(-1)
	var cut := p.rfind("_")
	return p.left(cut + 1) if cut >= 0 else ""


## Where a pack keeps its variant folders: "Spritesheets/" (most packs), "Spritesheet/" (a few), or the pack
## folder itself (e.g. Knights 3-6, Tales 5-7).
static func sheets_dir(pack_dir: String) -> String:
	for name in ["Spritesheets", "Spritesheet"]:
		if DirAccess.dir_exists_absolute(pack_dir.path_join(name)):
			return pack_dir.path_join(name)
	return pack_dir


## pack_dir is an absolute OS path. Returns {variant_id: {anim: res_path}}; already-copied files are reused.
static func copy_pack(pack_dir: String) -> Dictionary:
	var sheets := sheets_dir(pack_dir)
	var out := {}
	for folder in DirAccess.get_directories_at(sheets):
		if folder.begins_with("Old"):
			continue
		var src := sheets.path_join(folder)
		var pngs := Array(DirAccess.get_files_at(src)).filter(func(f: String) -> bool: return f.ends_with(".png"))
		if pngs.is_empty():
			continue
		var vid := variant_id(folder)
		var dst := OUT_DIR.path_join(vid)
		DirAccess.make_dir_recursive_absolute(dst)
		var prefix := common_prefix(pngs)
		var anims := {}
		for f: String in pngs:
			var anim := f.get_basename().substr(prefix.length()).to_lower()
			var to := dst.path_join(anim + ".png")
			if not FileAccess.file_exists(to):
				DirAccess.copy_absolute(src.path_join(f), ProjectSettings.globalize_path(to))
			anims[anim] = to
		out[vid] = anims
	return out


static func frames_from_textures(textures: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for anim: String in textures:
		var tex: Texture2D = textures[anim]
		var cols := tex.get_width() / CELL
		var rows := mini(tex.get_height() / CELL, FACINGS.size())
		for r in rows:
			var name := StringName("%s_%s" % [anim, FACINGS[r]])
			sf.add_animation(name)
			sf.set_animation_speed(name, FPS)
			sf.set_animation_loop(name, anim == "idle" or anim == "move")
			for col in cols:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(col * CELL, r * CELL, CELL, CELL)
				sf.add_frame(name, at)
	return sf


## Creates missing SpriteFrames and Species for copied variants. A variant whose PNGs are not imported yet is
## skipped (run the menu item again after the import finishes).
static func build_resources(copied: Dictionary) -> PackedStringArray:
	var made: PackedStringArray = []
	DirAccess.make_dir_recursive_absolute(FRAMES_DIR)
	DirAccess.make_dir_recursive_absolute(SPECIES_DIR)
	for vid: String in copied:
		var frames_path := FRAMES_DIR.path_join(vid + ".tres")
		if not ResourceLoader.exists(frames_path):
			var textures := {}
			for anim: String in copied[vid]:
				var path: String = copied[vid][anim]
				if not ResourceLoader.exists(path):
					textures = {}
					break
				textures[anim] = load(path)
			if textures.is_empty():
				push_warning("[creature_tools] %s: textures not imported yet; run the import again" % vid)
				continue
			ResourceSaver.save(frames_from_textures(textures), frames_path)
			made.append(frames_path)
		var species_path := SPECIES_DIR.path_join(vid + ".tres")
		if not ResourceLoader.exists(species_path):
			var sp := Species.new()
			sp.id = StringName(vid)
			sp.display_name = vid.capitalize()
			sp.line = StringName(vid)
			sp.sprite_frames = load(frames_path)
			ResourceSaver.save(sp, species_path)
			made.append(species_path)
	return made
