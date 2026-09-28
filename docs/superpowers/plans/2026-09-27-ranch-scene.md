# Ranch Scene Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the side-view shop into a top-down Sprout Lands ranch on one 640×360 screen: a terrain TileSet
(grass, soil, fences), a roofless shop house with two generated counters, a fenced pen and stable yard, the owner's
HUD on top.

**Architecture:** `shop.tscn` keeps its `Control` root, `shop.gd`, HUD and `PanelHost`. A new `Ranch` `Node2D`
(first child) holds `TileMapLayer`s painted from `ranch/ranch_tileset.tres`, the house (NinePatchRect pieces) and
decor sprites. Stations stay `TextureButton`s and the pens stay `SpawnArea`s, so `shop.gd` barely changes. Terrain
bits come from an on-demand editor tool (`addons/sprout_tools/ranch_terrains.gd`) holding tables decoded from the
pack's `Bitmask references 2.png`.

**Tech Stack:** Godot 4.7.2 (GDScript, `TileMapLayer`, terrains), the godot-ai MCP for all editor edits, the
repo's GDScript test runner, the Python asset pipeline (`asset-pipeline/gen.py`, `agy`, Aseprite).

**Spec:** `docs/superpowers/specs/2026-09-27-ranch-scene-design.md`

**Spec amendment (found while planning, applied here):** `Wooden_House_Walls_Tilset.png` is not on a 16 px grid
(its left piece is 26 px wide). Its 32×32 piece at `(48, 0)` is exactly a roofless room from above — a wall-top
frame around a plank floor (rows 0–19) over the front wall face (rows 20–31). So the house is built from
`NinePatchRect`s on that piece (a stretchable room, plus two front-wall pieces leaving a doorway gap), not from a
`House` `TileMapLayer`, and the TileSet has **three** atlas sources (grass, soil, fences), not four. Everything else
in the spec stands.

## Global Constraints

- Pack art (PNG/TTF/WAV/zips) is never committed; `.import` files under `art/sprout/` are committed. Our own
  generated art (`ranch/art/*.png`) is committed with its `.import`.
- Maaack's addons (`asset-pipeline/sprout-lands/Sprout-Lands-*-0.2.0/`) are reference only: never copied into
  `addons/`, never enabled.
- Godot changes go through the open editor via the godot-ai MCP (`CLAUDE.md`): scene edits with `editor_manage`
  op `eval` on `EditorInterface.get_edited_scene_root()` + `scene_save`, scripts with `script_patch` /
  `script_create`, resources saved from the editor process. Text-edit `.tscn/.tres` only if the MCP is unavailable,
  then `$GODOT --headless --path . --import` must show no errors. Never text-edit `project.godot` or a scene the
  editor has open. Never kill, close or restart the editor or any python/godot-ai process.
- Viewport 640×360, window 1280×720, stretch `canvas_items`, nearest filter, snap 2D transforms to pixel. Tiles are
  16 px; everything is placed on whole pixels at 1× scale.
- Node names `%Counter`, `%MarketStall`, `%Door`, `%Pens`, `%Stable`, `%PanelHost`, `%Toast` and the HUD
  (`Hud/TopLeft`, `%EndDayButton`, `%RepLabel`) keep their names and unique-name flags.
- Terrain tool menu text exactly: `Sprout Lands: Set up ranch terrains (overwrites terrain bits)`.
- TileSet source ids: grass `0`, soil `1`, fences `2`. Terrain set 0 (Match Corners and Sides): terrain 0
  `Grass`, terrain 1 `Soil`. Terrain set 1 (Match Sides): terrain 0 `Fence`.
- Creature `sprite_scale` 1.4 (median adult idle frame is 23 px tall → ≈32 px), `wander_speed` 16 px/s.
- Commit messages: plain subject, **no `Co-Authored-By` trailer** (owner rule). Never push. Stage files by name —
  never `git add -A`/`git add .` (the owner has unrelated line-ending-only changes in `creatures/frames/*.tres`).
- `GODOT` = `"C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`.
  Tests: `$GODOT --headless --path . -s res://tests/run_tests.gd` (prints `N tests, M failed`).
  Pipeline tests: `python asset-pipeline/test_gen.py`.
- Game screenshots: `$GODOT --path . -- --screenshot=$SHOTS/<name>.png` (add `--open=card|orders|summary`);
  `$SHOTS` is the session scratchpad. Read every screenshot you take.

## Review Focus

1. **Fresh clone, packs not synced** — running the terrain tool with a missing atlas texture must name the file
   and change nothing (Task 2 test).
2. **Owner edits survive a re-run** — the owner adds collision or custom data to tiles in the TileSet editor, then
   re-runs the terrain tool; those edits must survive (Task 2 test).
3. **A scene references pack art the sync list doesn't copy** — a fresh clone renders blank tiles; every
   `res://art/sprout/` path in any `.tscn`/`.tres`/`project.godot` must be in `SproutSync.FILES` (Task 1 test).
4. **Map pieces swallow clicks** — house/decor `Control`s drawn near a station must ignore the mouse, or the
   counters become unclickable (Task 6 test).
5. **Creatures wander outside their fence** — every creature's position stays inside its `SpawnArea` after the
   areas move out of the old frames (Task 7 test).

---

### Task 1: Sync the ranch art, and guard every pack reference

**Files:**
- Modify: `addons/sprout_tools/sprout_sync.gd` (`FILES`)
- Create: `tests/test_sprout_art.gd`
- Create (by the sync + import): the `.import` files for the ten new files under `art/sprout/tiles/` and
  `art/sprout/objects/`

**Interfaces:**
- Consumes: `SproutSync` (`res://addons/sprout_tools/sprout_sync.gd`): `const SRC`, `const DST := "res://art/sprout"`,
  `const FILES` (destination relative to DST → source relative to SRC), `const SPRITES_PREM`.
- Produces: the ten destination paths below, used by Tasks 2–7.

- [ ] **Step 1: Write the failing test** — `tests/test_sprout_art.gd` (create with godot-ai `script_create`):

```gdscript
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
```

- [ ] **Step 2: Run to verify it fails** — `$GODOT --headless --path . -s res://tests/run_tests.gd`.
  Expected: `FAIL test_sprout_art.gd::test_ranch_art_is_listed  SproutSync.FILES lists tiles/Grass_tiles_v2.png`
  (the first test passes today).

- [ ] **Step 3: Add the files to the sync list** — with `script_patch` on `res://addons/sprout_tools/sprout_sync.gd`,
  anchor on the line `	"sprites/grass-n-ground-tile-items.png": SPRITES_PREM + "Objects/Items/grass-n-ground-tile-items.png",`
  and append after it (names verbatim, including the pack's typos and the space before `.png`):

```gdscript
	"tiles/Grass_tiles_v2.png": SPRITES_PREM + "Tilesets/ground tiles/New tiles/Grass_tiles_v2.png",
	"tiles/Soil_Ground_Tiles.png": SPRITES_PREM + "Tilesets/ground tiles/New tiles/Soil_Ground_Tiles.png",
	"tiles/Fences.png": SPRITES_PREM + "Tilesets/Building parts/Fences.png",
	"tiles/Wooden_House_Walls_Tilset.png": SPRITES_PREM + "Tilesets/Building parts/Wooden_House_Walls_Tilset.png",
	"objects/Basic_Furniture.png": SPRITES_PREM + "Tilesets/Building parts/Basic_Furniture.png",
	"objects/Chikcen_Houses.png": SPRITES_PREM + "Tilesets/Building parts/Animal Structures/Chikcen_Houses.png",
	"objects/Barn structures.png": SPRITES_PREM + "Tilesets/Building parts/Animal Structures/Barn structures.png",
	"objects/Fence gates animation sprites .png": SPRITES_PREM + "Tilesets/Building parts/Fence gates animation sprites .png",
	"objects/signs.png": SPRITES_PREM + "Objects/signs.png",
	"objects/Egg_Spritesheet.png": SPRITES_PREM + "Animals/Chicken_Egg/Egg_Spritesheet.png",
```

  (`script_patch` matches exact bytes; if the file has CRLF endings and the multi-line anchor fails, anchor on the
  single line above and pass the new lines in `new_text`.)

- [ ] **Step 4: Sync and import** — run `$GODOT --headless --path . -s res://addons/sprout_tools/sync_cli.gd`
  (expected: no `missing:` lines, exit 0), then godot-ai `filesystem_manage` op `scan` so the open editor imports
  the new files. Check the ten `.import` files exist:
  `ls art/sprout/tiles/*.import art/sprout/objects/*.import`.

- [ ] **Step 5: Run the tests** — Expected: `test_sprout_art.gd` passes, all suites `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add addons/sprout_tools/sprout_sync.gd tests/test_sprout_art.gd tests/test_sprout_art.gd.uid art/sprout/tiles/*.import art/sprout/objects/*.import
git diff --cached --name-only   # no .png — only .gd/.uid/.import
git commit -m "Sync the Sprout Lands ranch art and check every pack reference is synced"
```

---

### Task 2: The ranch terrain tool

**Files:**
- Create: `addons/sprout_tools/ranch_terrains.gd`
- Modify: `addons/sprout_tools/plugin.gd` (second menu item)
- Test: `tests/test_ranch_terrains.gd`

**Interfaces:**
- Consumes: the synced sheets `res://art/sprout/tiles/Grass_tiles_v2.png`, `Soil_Ground_Tiles.png`, `Fences.png`
  (Task 1).
- Produces (`const RanchTerrains := preload("res://addons/sprout_tools/ranch_terrains.gd")`):
  - `const GRASS := 0`, `const SOIL := 1`, `const FENCE := 2` (source ids), `const TEXTURES: Dictionary`
    (source id → texture path)
  - `const BLOB: Dictionary` (`Vector2i` atlas coords → mask string like `".../.##/.##"`, rows top to bottom),
    `const GRASS_FILL: Array[Vector2i]`, `const SOIL_FILL: Array[Vector2i]`, `const FENCE_SIDES: Dictionary`
    (`Vector2i` → string of `N`/`E`/`S`/`W`)
  - `static func apply(ts: TileSet) -> PackedStringArray` — returns errors (empty = done); writes nothing when
    it returns errors.
  - `static func new_tileset() -> TileSet` — a TileSet with the three atlas sources at the ids above, 16 px, tiles
    created for every table cell (used by tests and by Task 3).

The tables below were decoded from `Tilesets/ground tiles/Bitmask references 2.png` (47 tiles, 47 distinct
patterns, all valid blob patterns) and from the fence sheet's edge pixels. `#` = that neighbour is the same
terrain; the middle character of the middle row is the tile itself.

- [ ] **Step 1: Write the failing tests** — `tests/test_ranch_terrains.gd` (`script_create`):

```gdscript
extends TestSuite
## The terrain tables match the pack's bitmask reference, and apply() makes Godot's terrain painter pick the
## right edge/corner tiles.

const T := preload("res://addons/sprout_tools/ranch_terrains.gd")


func test_blob_table_is_47_distinct_valid_patterns() -> void:
	eq(T.BLOB.size(), 47, "blob tiles")
	var seen := {}
	for c in T.BLOB:
		var m: String = T.BLOB[c]
		check(m.length() == 11 and m[5] == "#", "%s: centre set, 3x3 mask: %s" % [c, m])
		check(not seen.has(m), "%s duplicates %s" % [c, seen.get(m)])
		seen[m] = c
		# a corner only counts when both sides next to it are set (blob rule)
		for corner in [[0, 1, 4], [2, 1, 6], [8, 4, 9], [10, 6, 9]]:
			if m[corner[0]] == "#":
				check(m[corner[1]] == "#" and m[corner[2]] == "#", "%s: corner without its sides: %s" % [c, m])


func test_fence_table_covers_all_16_side_combinations() -> void:
	eq(T.FENCE_SIDES.size(), 16, "fence tiles")
	var seen := {}
	for c in T.FENCE_SIDES:
		check(not seen.has(T.FENCE_SIDES[c]), "%s duplicates sides %s" % [c, T.FENCE_SIDES[c]])
		seen[T.FENCE_SIDES[c]] = c


func test_apply_sets_up_the_terrains() -> void:
	var ts := T.new_tileset()
	eq(T.apply(ts), PackedStringArray(), "no errors")
	eq(ts.get_terrain_sets_count(), 2, "terrain sets")
	eq(ts.get_terrain_set_mode(0), TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES, "set 0 mode")
	eq(ts.get_terrain_set_mode(1), TileSet.TERRAIN_MODE_MATCH_SIDES, "set 1 mode")
	eq([ts.get_terrain_name(0, 0), ts.get_terrain_name(0, 1), ts.get_terrain_name(1, 0)], ["Grass", "Soil", "Fence"], "names")


func test_painting_picks_the_right_tiles() -> void:
	var ts := T.new_tileset()
	T.apply(ts)
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	tree.root.add_child(layer)
	var island: Array[Vector2i] = []
	for y in 3:
		for x in 3:
			island.append(Vector2i(x, y))
	layer.set_cells_terrain_connect(island, 0, 0)
	var expect := {Vector2i(0, 0): Vector2i(0, 0), Vector2i(1, 0): Vector2i(1, 0), Vector2i(2, 0): Vector2i(2, 0),
		Vector2i(0, 1): Vector2i(0, 1), Vector2i(2, 1): Vector2i(2, 1),
		Vector2i(0, 2): Vector2i(0, 2), Vector2i(1, 2): Vector2i(1, 2), Vector2i(2, 2): Vector2i(2, 2)}
	for cell in expect:
		eq(layer.get_cell_atlas_coords(cell), expect[cell], "grass island cell %s" % cell)
	var centre := layer.get_cell_atlas_coords(Vector2i(1, 1))
	check(centre == Vector2i(1, 1) or centre in T.GRASS_FILL, "island centre is a fill tile: %s" % centre)
	var lone: Array[Vector2i] = [Vector2i(10, 10)]
	layer.set_cells_terrain_connect(lone, 0, 1)
	eq(layer.get_cell_source_id(Vector2i(10, 10)), T.SOIL, "lone soil cell uses the soil sheet")
	eq(layer.get_cell_atlas_coords(Vector2i(10, 10)), Vector2i(3, 3), "lone soil cell is the single tile")
	var post: Array[Vector2i] = [Vector2i(20, 0), Vector2i(21, 0), Vector2i(22, 0)]
	layer.set_cells_terrain_connect(post, 1, 0)
	eq(layer.get_cell_atlas_coords(Vector2i(20, 0)), Vector2i(1, 3), "fence run: left end connects east")
	eq(layer.get_cell_atlas_coords(Vector2i(21, 0)), Vector2i(2, 3), "fence run: middle connects east+west")
	eq(layer.get_cell_atlas_coords(Vector2i(22, 0)), Vector2i(3, 3), "fence run: right end connects west")
	layer.queue_free()


func test_missing_texture_is_named_and_nothing_is_written() -> void:
	var ts := T.new_tileset()
	(ts.get_source(T.SOIL) as TileSetAtlasSource).texture = null
	var errors := T.apply(ts)
	eq(errors.size(), 1, "one error")
	check(errors.size() == 1 and errors[0].contains("Soil_Ground_Tiles.png") and errors[0].contains("Sync pack files"),
		"error names the file and the sync menu: %s" % [errors])
	eq(ts.get_terrain_sets_count(), 0, "nothing written")


func test_rerun_keeps_owner_edits() -> void:
	var ts := T.new_tileset()
	T.apply(ts)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "owner_note")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	var td := (ts.get_source(T.GRASS) as TileSetAtlasSource).get_tile_data(Vector2i(1, 1), 0)
	td.set_custom_data("owner_note", "keep me")
	T.apply(ts)
	eq((ts.get_source(T.GRASS) as TileSetAtlasSource).get_tile_data(Vector2i(1, 1), 0).get_custom_data("owner_note"),
		"keep me", "custom data survives a re-run")
	eq(ts.get_terrain_sets_count(), 2, "still exactly two terrain sets after a re-run")
```

- [ ] **Step 2: Run to verify it fails** — Expected: the suite reports a load failure for
  `res://addons/sprout_tools/ranch_terrains.gd` (file missing) and `test_ranch_terrains.gd` tests fail.

- [ ] **Step 3: Write the tool** — `addons/sprout_tools/ranch_terrains.gd` (`script_create`):

```gdscript
@tool
extends RefCounted
## Sets up the ranch TileSet's terrains from the Sprout Lands bitmask reference (Tilesets/ground tiles/Bitmask
## references 2.png). Run from Project > Tools > "Sprout Lands: Set up ranch terrains (overwrites terrain bits)".
## Writes only terrain sets, terrains, peering bits and tile probabilities; collision, custom data and everything
## else set in the TileSet editor is left alone. Never runs on its own.

const GRASS := 0
const SOIL := 1
const FENCE := 2
const TEXTURES := {
	GRASS: "res://art/sprout/tiles/Grass_tiles_v2.png",
	SOIL: "res://art/sprout/tiles/Soil_Ground_Tiles.png",
	FENCE: "res://art/sprout/tiles/Fences.png",
}
const FILL_PROBABILITY := 0.2  ## plain fill variants, next to the main centre tile's 1.0

## Grass_tiles_v2.png and Soil_Ground_Tiles.png share this 11x7 layout. Mask rows top to bottom;
## "#" = that neighbour is the same terrain.
const BLOB := {
	Vector2i(0, 0): ".../.##/.##", Vector2i(1, 0): ".../###/###", Vector2i(2, 0): ".../##./##.",
	Vector2i(3, 0): ".../.#./.#.", Vector2i(4, 0): ".../.##/.#.", Vector2i(5, 0): ".../###/##.",
	Vector2i(6, 0): ".../###/.##", Vector2i(7, 0): ".../##./.#.", Vector2i(8, 0): ".../###/.#.",
	Vector2i(9, 0): "##./###/.##",
	Vector2i(0, 1): ".##/.##/.##", Vector2i(1, 1): "###/###/###", Vector2i(2, 1): "##./##./##.",
	Vector2i(3, 1): ".#./.#./.#.", Vector2i(4, 1): ".##/.##/.#.", Vector2i(5, 1): "###/###/##.",
	Vector2i(6, 1): "###/###/.##", Vector2i(7, 1): "##./##./.#.", Vector2i(8, 1): "###/###/.#.",
	Vector2i(9, 1): ".##/###/##.",
	Vector2i(0, 2): ".##/.##/...", Vector2i(1, 2): "###/###/...", Vector2i(2, 2): "##./##./...",
	Vector2i(3, 2): ".#./.#./...", Vector2i(4, 2): ".#./.##/.##", Vector2i(5, 2): "##./###/###",
	Vector2i(6, 2): ".##/###/###", Vector2i(7, 2): ".#./##./##.", Vector2i(8, 2): ".#./###/###",
	Vector2i(9, 2): ".#./###/.##", Vector2i(10, 2): ".#./###/##.",
	Vector2i(0, 3): ".../.##/...", Vector2i(1, 3): ".../###/...", Vector2i(2, 3): ".../##./...",
	Vector2i(3, 3): ".../.#./...", Vector2i(4, 3): ".#./.##/...", Vector2i(5, 3): "##./###/...",
	Vector2i(6, 3): ".##/###/...", Vector2i(7, 3): ".#./##./...", Vector2i(8, 3): ".#./###/...",
	Vector2i(9, 3): ".##/###/.#.", Vector2i(10, 3): "##./###/.#.",
	Vector2i(4, 4): ".#./.##/.#.", Vector2i(5, 4): "##./###/##.", Vector2i(6, 4): ".##/###/.##",
	Vector2i(7, 4): ".#./##./.#.", Vector2i(8, 4): ".#./###/.#.",
}
## Plain full tiles (flowers, tufts) under the blob block: same all-neighbours mask as (1, 1), lower probability.
const GRASS_FILL: Array[Vector2i] = [
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
	Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
]
const SOIL_FILL: Array[Vector2i] = [
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5),
	Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6),
]
## Fences.png columns 0-3: every combination of connected sides. Columns 4-7 are broken-fence decorations and stay
## plain tiles (no terrain).
const FENCE_SIDES := {
	Vector2i(0, 0): "S", Vector2i(0, 1): "NS", Vector2i(0, 2): "N", Vector2i(0, 3): "",
	Vector2i(1, 0): "ES", Vector2i(2, 0): "ESW", Vector2i(3, 0): "SW",
	Vector2i(1, 1): "NES", Vector2i(2, 1): "NESW", Vector2i(3, 1): "NSW",
	Vector2i(1, 2): "NE", Vector2i(2, 2): "NEW", Vector2i(3, 2): "NW",
	Vector2i(1, 3): "E", Vector2i(2, 3): "EW", Vector2i(3, 3): "W",
}
## Mask character index -> neighbour (index 5 is the tile itself; 3 and 7 are the "/" separators).
const MASK_NEIGHBOURS := {
	0: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, 1: TileSet.CELL_NEIGHBOR_TOP_SIDE,
	2: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, 4: TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	6: TileSet.CELL_NEIGHBOR_RIGHT_SIDE, 8: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	9: TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, 10: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
}
const SIDES := {
	"N": TileSet.CELL_NEIGHBOR_TOP_SIDE, "E": TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	"S": TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, "W": TileSet.CELL_NEIGHBOR_LEFT_SIDE,
}


## Errors first, then writes. Empty result = terrains set up.
static func apply(ts: TileSet) -> PackedStringArray:
	var errors := PackedStringArray()
	for id in TEXTURES:
		var src := ts.get_source(id) as TileSetAtlasSource if ts.has_source(id) else null
		if src == null or src.texture == null:
			errors.append("ranch TileSet source %d has no texture: %s (run Project > Tools > Sprout Lands: Sync pack files)" % [id, TEXTURES[id]])
	if not errors.is_empty():
		return errors
	while ts.get_terrain_sets_count() > 0:
		ts.remove_terrain_set(0)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(0)
	ts.set_terrain_name(0, 0, "Grass")
	ts.set_terrain_color(0, 0, Color(0.55, 0.8, 0.35))
	ts.add_terrain(0)
	ts.set_terrain_name(0, 1, "Soil")
	ts.set_terrain_color(0, 1, Color(0.8, 0.6, 0.4))
	ts.add_terrain_set()
	ts.set_terrain_set_mode(1, TileSet.TERRAIN_MODE_MATCH_SIDES)
	ts.add_terrain(1)
	ts.set_terrain_name(1, 0, "Fence")
	ts.set_terrain_color(1, 0, Color(0.6, 0.4, 0.25))
	for pair in [[GRASS, 0, GRASS_FILL], [SOIL, 1, SOIL_FILL]]:
		var src := ts.get_source(pair[0]) as TileSetAtlasSource
		for coords in BLOB:
			_set_blob(_tile(src, coords), pair[1], BLOB[coords], 1.0)
		for coords in pair[2]:
			_set_blob(_tile(src, coords), pair[1], BLOB[Vector2i(1, 1)], FILL_PROBABILITY)
	var fences := ts.get_source(FENCE) as TileSetAtlasSource
	for coords in FENCE_SIDES:
		var td := _tile(fences, coords)
		td.terrain_set = 1
		td.terrain = 0
		for side in SIDES:
			td.set_terrain_peering_bit(SIDES[side], 0 if FENCE_SIDES[coords].contains(side) else -1)
	return errors


## A TileSet with the three ranch atlas sources and a tile for every table cell (the editor's Task 3 resource is
## made the same way; tests use it directly).
static func new_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	for id in TEXTURES:
		var src := TileSetAtlasSource.new()
		src.texture = load(TEXTURES[id])
		src.texture_region_size = Vector2i(16, 16)
		ts.add_source(src, id)
		var cells: Array = FENCE_SIDES.keys() if id == FENCE else BLOB.keys() + (GRASS_FILL if id == GRASS else SOIL_FILL)
		for coords in cells:
			_tile(src, coords)
	return ts


static func _tile(src: TileSetAtlasSource, coords: Vector2i) -> TileData:
	if not src.has_tile(coords):
		src.create_tile(coords)
	return src.get_tile_data(coords, 0)


static func _set_blob(td: TileData, terrain: int, mask: String, probability: float) -> void:
	td.terrain_set = 0
	td.terrain = terrain
	td.probability = probability
	for i in MASK_NEIGHBOURS:
		td.set_terrain_peering_bit(MASK_NEIGHBOURS[i], terrain if mask[i] == "#" else -1)
```

- [ ] **Step 4: Add the menu item** — `script_patch` on `res://addons/sprout_tools/plugin.gd`:
  - after `const MENU := "Sprout Lands: Sync pack files"` add:

```gdscript
const Terrains := preload("res://addons/sprout_tools/ranch_terrains.gd")
const TERRAIN_MENU := "Sprout Lands: Set up ranch terrains (overwrites terrain bits)"
const TILESET := "res://ranch/ranch_tileset.tres"
```

  - in `_enter_tree()` after `add_tool_menu_item(MENU, _sync)` add `	add_tool_menu_item(TERRAIN_MENU, _set_up_terrains)`
  - in `_exit_tree()` after `remove_tool_menu_item(MENU)` add `	remove_tool_menu_item(TERRAIN_MENU)`
  - append at the end of the file:

```gdscript


func _set_up_terrains() -> void:
	var ts := load(TILESET) as TileSet
	if ts == null:
		push_error("[sprout_tools] %s not found — create it first (see docs/superpowers/plans/2026-09-27-ranch-scene.md, Task 3)" % TILESET)
		return
	var errors := Terrains.apply(ts)
	if not errors.is_empty():
		push_error("[sprout_tools] terrains not set up:\n" + "\n".join(errors))
		return
	ResourceSaver.save(ts, TILESET)
	print("[sprout_tools] ranch terrains set up in %s" % TILESET)
```

  Update the file's first doc line to: `## Project > Tools: "Sprout Lands: Sync pack files" (copies pack art only) and "Sprout Lands: Set up ranch terrains (overwrites terrain bits)".`

- [ ] **Step 5: Run the tests** — Expected: all `test_ranch_terrains.gd` tests pass, all suites `0 failed`.
  If `test_painting_picks_the_right_tiles` fails on one cell, re-check that cell's mask against
  `Bitmask references 2.png` (each cell is 38 px, grid lines at x = 28 + 38·col, y = 32 + 38·row; the 3×3 squares
  sit at offsets 4–14 / 15–25 / 26–36 inside the cell) — fix the table, not the test.

- [ ] **Step 6: Reload the plugin** — `editor_manage` eval
  `EditorInterface.set_plugin_enabled("res://addons/sprout_tools/plugin.cfg", false)` then again with `true`.
  Never use `plugin_manage` (it returns INTERNAL_ERROR and once corrupted `project.godot`'s plugin list). Then
  `logs_read` source `editor`: no new errors from `addons/sprout_tools/`, and `project.godot`'s `[editor_plugins]`
  line still lists each plugin exactly once.

- [ ] **Step 7: Commit**

```bash
git add addons/sprout_tools/ranch_terrains.gd addons/sprout_tools/ranch_terrains.gd.uid addons/sprout_tools/plugin.gd tests/test_ranch_terrains.gd tests/test_ranch_terrains.gd.uid
git commit -m "Add the ranch terrain tool with the Sprout Lands bitmask tables"
```

---

### Task 3: The ranch TileSet resource

**Files:**
- Create: `ranch/ranch_tileset.tres` (in the editor)
- Test: `tests/test_ranch_tileset.gd`

**Interfaces:**
- Consumes: `RanchTerrains.new_tileset()`, `RanchTerrains.apply()`, the Tools menu item (Task 2).
- Produces: `res://ranch/ranch_tileset.tres` with sources 0/1/2 and terrains set up — used by Task 6.

- [ ] **Step 1: Write the failing test** — `tests/test_ranch_tileset.gd` (`script_create`):

```gdscript
extends TestSuite
## The project's ranch TileSet exists with the three sheets and its terrains set up.

const T := preload("res://addons/sprout_tools/ranch_terrains.gd")
const TILESET := "res://ranch/ranch_tileset.tres"


func test_ranch_tileset_has_its_terrains() -> void:
	var ts := load(TILESET) as TileSet
	check(ts != null, "%s exists" % TILESET)
	if ts == null:
		return
	eq(ts.tile_size, Vector2i(16, 16), "tile size")
	for id in T.TEXTURES:
		var src := ts.get_source(id) as TileSetAtlasSource
		eq(src.texture.resource_path, T.TEXTURES[id], "source %d texture" % id)
	eq(ts.get_terrain_sets_count(), 2, "terrain sets")
	for coords in T.BLOB:
		var td := (ts.get_source(T.GRASS) as TileSetAtlasSource).get_tile_data(coords, 0)
		eq([td.terrain_set, td.terrain], [0, 0], "grass %s is Grass terrain" % coords)
	for coords in T.FENCE_SIDES:
		var td := (ts.get_source(T.FENCE) as TileSetAtlasSource).get_tile_data(coords, 0)
		eq([td.terrain_set, td.terrain], [1, 0], "fence %s is Fence terrain" % coords)
```

- [ ] **Step 2: Run to verify it fails** — Expected: `FAIL ... res://ranch/ranch_tileset.tres exists`.

- [ ] **Step 3: Create the resource in the editor** — godot-ai `editor_manage` op `eval`:

```gdscript
DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ranch"))
var ts: TileSet = preload("res://addons/sprout_tools/ranch_terrains.gd").new_tileset()
var err := ResourceSaver.save(ts, "res://ranch/ranch_tileset.tres")
EditorInterface.get_resource_filesystem().scan()
return err
```

  Expected: `0` (OK). This saves the three atlas sources (tiles only, no terrains yet).

- [ ] **Step 4: Set up the terrains** — `editor_manage` eval, running the same code as the menu item:

```gdscript
var ts := load("res://ranch/ranch_tileset.tres") as TileSet
var errors: PackedStringArray = preload("res://addons/sprout_tools/ranch_terrains.gd").apply(ts)
if errors.is_empty():
	ResourceSaver.save(ts, "res://ranch/ranch_tileset.tres")
return errors
```

  Expected: `[]`. (The owner will use Project > Tools > "Sprout Lands: Set up ranch terrains (overwrites terrain
  bits)" for later resets; it runs the same code.)

- [ ] **Step 5: Look at it** — open the TileSet in the editor (`editor_manage` eval
  `EditorInterface.edit_resource(load("res://ranch/ranch_tileset.tres"))`), take an `editor_screenshot`
  (source `viewport_2d` is fine if the TileSet panel is visible; otherwise skip) and read it.

- [ ] **Step 6: Run the tests** — Expected: `test_ranch_tileset.gd` passes; all suites `0 failed`.

- [ ] **Step 7: Commit**

```bash
git add ranch/ranch_tileset.tres tests/test_ranch_tileset.gd tests/test_ranch_tileset.gd.uid
git commit -m "Add the ranch TileSet with grass, soil and fence terrains"
```

---

### Task 4: Eggs from the pack

**Files:**
- Create: `creatures/egg.tres` (AtlasTexture, in the editor)
- Modify: `shop/creature_sprite.tscn` (`Egg` texture), `shop/creature_sprite.gd:4` (doc comment),
  `shop/panels/creature_card.gd:5` (`EGG_TEXTURE`), `tests/test_creature_card.gd:80`

**Interfaces:**
- Consumes: `res://art/sprout/objects/Egg_Spritesheet.png` (Task 1).
- Produces: `res://creatures/egg.tres` — the egg texture everywhere; `shop/art/egg.png` becomes unused (deleted in
  Task 8).

- [ ] **Step 1: Update the test first** — in `tests/test_creature_card.gd` line 80 replace
  `load("res://shop/art/egg.png")` with `load("res://creatures/egg.tres")` (text edit; the editor doesn't have test
  scripts open).

- [ ] **Step 2: Run to verify it fails** — Expected: the egg assertion in `test_creature_card.gd` fails (and
  `egg.tres` fails to load).

- [ ] **Step 3: Create the egg texture** — `editor_manage` eval:

```gdscript
var egg := AtlasTexture.new()
egg.atlas = load("res://art/sprout/objects/Egg_Spritesheet.png")
egg.region = Rect2(0, 0, 16, 16)  # the whole cream egg, first frame
var err := ResourceSaver.save(egg, "res://creatures/egg.tres")
EditorInterface.get_resource_filesystem().scan()
return err
```

- [ ] **Step 4: Point the users at it**
  - `script_patch` `res://shop/panels/creature_card.gd`: `const EGG_TEXTURE := preload("res://shop/art/egg.png")` →
    `const EGG_TEXTURE := preload("res://creatures/egg.tres")`.
  - `script_patch` `res://shop/creature_sprite.gd`: `## Eggs show the Egg sprite (shop/art/egg.png) until they hatch.`
    → `## Eggs show the Egg sprite (creatures/egg.tres, from the Sprout Lands egg sheet) until they hatch.`
  - `scene_open` `res://shop/creature_sprite.tscn`, then `editor_manage` eval:

```gdscript
var r = EditorInterface.get_edited_scene_root()
r.get_node("Egg").texture = load("res://creatures/egg.tres")
EditorInterface.mark_scene_as_unsaved()
return str(r.get_node("Egg").texture.resource_path)
```

    then `scene_save`. Check: `grep -n "shop/art" shop/creature_sprite.tscn shop/panels/creature_card.gd shop/creature_sprite.gd`
    prints nothing.

- [ ] **Step 5: Run the tests** — Expected: all suites `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add creatures/egg.tres shop/creature_sprite.tscn shop/creature_sprite.gd shop/panels/creature_card.gd tests/test_creature_card.gd
git commit -m "Use the Sprout Lands egg for eggs"
```

---

### Task 5: Generate the two counters

**Files:**
- Modify: `asset-pipeline/jobs.json`, `asset-pipeline/README.md`
- Create (pipeline output, committed): `asset-pipeline/assets/prop/orders_counter.{png,aseprite,review.json}`,
  `asset-pipeline/assets/prop/market_counter.{png,aseprite,review.json}`
- Create (copied, committed): `ranch/art/orders_counter.png`, `ranch/art/market_counter.png` (+ `.import`)

**Interfaces:**
- Consumes: `gen.py` `prop` style (palette-locked to Sprout, job-level `size`, `aspect`, `refs`).
- Produces: `res://ranch/art/orders_counter.png` and `res://ranch/art/market_counter.png`, 48×32 — used by Task 7.

- [ ] **Step 1: Add the jobs** — append to `asset-pipeline/jobs.json` (keep valid JSON; add a comma after the
  previous last entry):

```json
  {"name": "orders_counter", "type": "prop", "aspect": "3:2", "size": [48, 32], "prompt": "a small wooden shop counter seen from the front and slightly above, with an open ledger book and three pinned paper order slips on top", "refs": ["sprout-lands/Sprout Lands - Sprites - premium pack/Tilesets/Building parts/Basic_Furniture.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Tilesets/Building parts/Wooden_House_Walls_Tilset.png"]},
  {"name": "market_counter", "type": "prop", "aspect": "3:2", "size": [48, 32], "prompt": "a small wooden shop counter seen from the front and slightly above, with a crate of vegetables and a tiny price sign on top", "refs": ["sprout-lands/Sprout Lands - Sprites - premium pack/Tilesets/Building parts/Basic_Furniture.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Tilesets/Building parts/Wooden_House_Walls_Tilset.png"]}
```

- [ ] **Step 2: Check the pipeline still passes** — `python asset-pipeline/test_gen.py` → all `ok`.

- [ ] **Step 3: Generate** — `python asset-pipeline/gen.py orders_counter` then
  `python asset-pipeline/gen.py market_counter`. Expected: `wrote …/assets/prop/<name>.png` (or a kept last attempt
  with a review `WARN`), and **no** palette `WARN`. If `agy` is unavailable or both jobs fail outright, stop and
  report BLOCKED with the output — do not log in or change credentials.

- [ ] **Step 4: Verify the images** — run:

```bash
python -c "
import sys; sys.path.insert(0, 'asset-pipeline'); import gen
from PIL import Image
for n in ['orders_counter', 'market_counter']:
    p = 'asset-pipeline/assets/prop/%s.png' % n
    im = Image.open(p); print(n, im.size, 'off-palette', gen.off_palette(p, gen.PALETTES['sprout']))
"
```

  Expected: `(48, 32)` and `off-palette 0` for both. Enlarge each ×8 into `$SHOTS` and read it: a counter that
  reads at 48×32 next to the pack's furniture.

- [ ] **Step 5: Copy into the game** — `mkdir -p ranch/art && cp asset-pipeline/assets/prop/orders_counter.png asset-pipeline/assets/prop/market_counter.png ranch/art/`,
  then godot-ai `filesystem_manage` op `scan` (the editor imports them).

- [ ] **Step 6: README line** — in `asset-pipeline/README.md`, under the type table's `prop` row or the Palette lock
  section, add: `Props used in the game are copied by hand from assets/prop/ into ranch/art/ (committed; they are our own art, not pack art).`

- [ ] **Step 7: Commit**

```bash
git add asset-pipeline/jobs.json asset-pipeline/README.md asset-pipeline/assets/prop/orders_counter.png asset-pipeline/assets/prop/orders_counter.aseprite asset-pipeline/assets/prop/orders_counter.review.json asset-pipeline/assets/prop/market_counter.png asset-pipeline/assets/prop/market_counter.aseprite asset-pipeline/assets/prop/market_counter.review.json ranch/art/orders_counter.png ranch/art/orders_counter.png.import ranch/art/market_counter.png ranch/art/market_counter.png.import
git commit -m "Generate the orders and market counters for the ranch house"
```

  (Leave out any `.review.json` the run didn't produce.)

---

### Task 6: The ranch map (ground, paths, fences, house, decor)

**Files:**
- Modify: `shop/shop.tscn` (new `Ranch` subtree, in the editor)
- Test: `tests/test_ranch_map.gd`

**Interfaces:**
- Consumes: `res://ranch/ranch_tileset.tres` (Task 3); `res://art/sprout/tiles/Wooden_House_Walls_Tilset.png`,
  `objects/Basic_Furniture.png`, `objects/Chikcen_Houses.png`, `objects/Barn structures.png`,
  `objects/Fence gates animation sprites .png` (Task 1).
- Produces: `Shop/Ranch` (`Node2D`, first child) with `Ground`, `Paths`, `Fences` (`TileMapLayer`), `House`
  (`Node2D`: `Room`, `FrontLeft`, `FrontRight` — `NinePatchRect`), `Decor` (`Node2D`, y-sorted `Sprite2D`s).
  Layout in 16 px cells: pen fence ring cols 1–16 × rows 12–20 with a gate gap at cols 8–10 of row 12; stable fence
  ring cols 24–35 × rows 13–20 with a gate gap at cols 28–30 of row 13; house room at (240, 48) 160×80, front wall
  at y 128 with a doorway gap x 308–332. Task 7 places stations and pens against these.

- [ ] **Step 1: Write the failing test** — `tests/test_ranch_map.gd` (`script_create`):

```gdscript
extends TestSuite
## The ranch map under the shop: grass everywhere on screen, fences around the pen and stable yard, and map pieces
## that never take a click.

const SAVE := "user://test_ranch_map_save.json"


func _shop() -> Control:
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)
	var shop: Control = load("res://shop/shop.tscn").instantiate()
	tree.root.add_child(shop)
	return shop


func test_grass_covers_the_screen() -> void:
	var shop := _shop()
	await tree.process_frame
	var ground: TileMapLayer = shop.get_node("Ranch/Ground")
	var bare := 0
	for y in 23:
		for x in 40:
			if ground.get_cell_source_id(Vector2i(x, y)) != 0:
				bare += 1
	eq(bare, 0, "on-screen cells without grass")
	_done(shop)


func test_fences_ring_the_pen_and_the_stable_yard() -> void:
	var shop := _shop()
	await tree.process_frame
	var fences: TileMapLayer = shop.get_node("Ranch/Fences")
	for cell in [Vector2i(1, 12), Vector2i(16, 20), Vector2i(1, 20), Vector2i(24, 13), Vector2i(35, 20)]:
		eq(fences.get_cell_source_id(cell), 2, "fence at %s" % cell)
	for gate in [Vector2i(9, 12), Vector2i(29, 13)]:
		eq(fences.get_cell_source_id(gate), -1, "gate gap at %s" % gate)
	_done(shop)


func test_map_pieces_ignore_the_mouse() -> void:
	var shop := _shop()
	await tree.process_frame
	var stack: Array[Node] = [shop.get_node("Ranch")]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			eq(n.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % n.name)
		stack.append_array(n.get_children())
	eq(shop.get_child(0).name, "Ranch", "the map draws first, under everything")
	_done(shop)


func _done(shop: Control) -> void:
	shop.queue_free()
	DirAccess.remove_absolute(SAVE)
```

- [ ] **Step 2: Run to verify it fails** — Expected: `test_ranch_map.gd` tests fail (no `Ranch` node).

- [ ] **Step 3: Build the map in the editor** — `scene_open` `res://shop/shop.tscn`, then `editor_manage` eval:

```gdscript
var r = EditorInterface.get_edited_scene_root()
if r.scene_file_path != "res://shop/shop.tscn" or r.has_node("Ranch"):
	return "wrong scene or Ranch already exists"
var ts := load("res://ranch/ranch_tileset.tres") as TileSet
var own := func(n: Node, parent: Node) -> Node:
	parent.add_child(n)
	n.owner = r
	return n
var ranch: Node2D = own.call(Node2D.new(), r)
ranch.name = "Ranch"
r.move_child(ranch, 0)
var layer := func(layer_name: String) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = ts
	return own.call(l, ranch)
var ground: TileMapLayer = layer.call("Ground")
var paths: TileMapLayer = layer.call("Paths")
var fences: TileMapLayer = layer.call("Fences")
# grass one cell past every screen edge so no edge tiles show on screen (40 x 23 cells visible)
var grass: Array[Vector2i] = []
for y in range(-1, 24):
	for x in range(-1, 41):
		grass.append(Vector2i(x, y))
ground.set_cells_terrain_connect(grass, 0, 0)
# soil: doorway stub (cols 19-20, rows 8-9), the road (rows 10-11, col 9 to the right edge), stable-gate stub
var soil: Array[Vector2i] = []
for y in [8, 9]:
	for x in [19, 20]:
		soil.append(Vector2i(x, y))
for y in [10, 11]:
	for x in range(9, 41):
		soil.append(Vector2i(x, y))
for x in [28, 29, 30]:
	soil.append(Vector2i(x, 12))
paths.set_cells_terrain_connect(soil, 0, 1)
var ring := func(x0: int, y0: int, x1: int, y1: int, gap: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			if (x == x0 or x == x1 or y == y0 or y == y1) and not gap.has(c):
				cells.append(c)
	return cells
fences.set_cells_terrain_connect(ring.call(1, 12, 16, 20, [Vector2i(8, 12), Vector2i(9, 12), Vector2i(10, 12)]), 1, 0)
fences.set_cells_terrain_connect(ring.call(24, 13, 35, 20, [Vector2i(28, 13), Vector2i(29, 13), Vector2i(30, 13)]), 1, 0)
# the roofless house: wall-top frame + plank floor, then two front-wall pieces with a doorway gap
var walls := load("res://art/sprout/tiles/Wooden_House_Walls_Tilset.png")
var house: Node2D = own.call(Node2D.new(), ranch)
house.name = "House"
var piece := func(piece_name: String, region: Rect2, margins: Array, pos: Vector2, sz: Vector2) -> void:
	var n := NinePatchRect.new()
	n.name = piece_name
	n.texture = walls
	n.region_rect = region
	n.patch_margin_left = margins[0]
	n.patch_margin_top = margins[1]
	n.patch_margin_right = margins[2]
	n.patch_margin_bottom = margins[3]
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own.call(n, house)
	n.position = pos
	n.size = sz
piece.call("Room", Rect2(48, 0, 32, 20), [5, 5, 5, 4], Vector2(240, 48), Vector2(160, 80))
piece.call("FrontLeft", Rect2(48, 20, 32, 12), [2, 1, 2, 1], Vector2(240, 128), Vector2(68, 12))
piece.call("FrontRight", Rect2(48, 20, 32, 12), [2, 1, 2, 1], Vector2(332, 128), Vector2(68, 12))
# decor: y-sorted sprites, top-left anchored
var decor: Node2D = own.call(Node2D.new(), ranch)
decor.name = "Decor"
decor.y_sort_enabled = true
var sprite := func(sprite_name: String, sheet: String, region: Rect2, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.name = sprite_name
	s.texture = load(sheet)
	s.centered = false
	s.region_enabled = true
	s.region_rect = region
	own.call(s, decor)
	s.position = pos
var furniture := "res://art/sprout/objects/Basic_Furniture.png"
sprite.call("Rug", furniture, Rect2(0, 80, 48, 16), Vector2(296, 104))
sprite.call("Plant", furniture, Rect2(64, 0, 16, 16), Vector2(248, 104))
sprite.call("Clock", furniture, Rect2(80, 48, 16, 16), Vector2(376, 104))
sprite.call("Coop", "res://art/sprout/objects/Chikcen_Houses.png", Rect2(160, 80, 32, 48), Vector2(528, 224))
sprite.call("Hay", "res://art/sprout/objects/Barn structures.png", Rect2(0, 32, 32, 16), Vector2(400, 304))
var gates := "res://art/sprout/objects/Fence gates animation sprites .png"
sprite.call("PenGate", gates, Rect2(0, 0, 48, 16), Vector2(128, 192))
sprite.call("StableGate", gates, Rect2(0, 0, 48, 16), Vector2(448, 208))
EditorInterface.mark_scene_as_unsaved()
return "ok"
```

  then `scene_save`. `Ranch` is child 0, so the HUD, stations, pens and panels draw above it.

- [ ] **Step 4: Look at it** — `$GODOT --path . -- --screenshot=$SHOTS/ranch_t6.png`; read it. Expected: grass
  everywhere, a soil path from the house door gap down to the road, the road running to the right edge, two fenced
  areas with gates on their top edges, a roofless house (wall-top frame, plank floor, front wall with a doorway),
  rug/plant/clock inside, coop and hay in the right yard. The old side-view art still draws on top (removed in
  Task 7) — that's expected here. If a soil or fence tile looks wrong, it's a table error: fix `ranch_terrains.gd`
  (Task 2 tests), re-run the terrain set-up (Task 3 Step 4) and re-paint (delete `Ranch` and re-run Step 3).

- [ ] **Step 5: Run the tests** — Expected: `test_ranch_map.gd` passes; all suites `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add shop/shop.tscn tests/test_ranch_map.gd tests/test_ranch_map.gd.uid
git commit -m "Paint the ranch map under the shop: grass, paths, fences, the house and decor"
```

---

### Task 7: Stations and creatures on the ranch

**Files:**
- Modify: `shop/shop.tscn` (stations, pens; remove `Floor`, `PenFrame`, `StableFrame`)
- Test: `tests/test_shop_scene.gd` (extend)

**Interfaces:**
- Consumes: the Task 6 layout; `res://ranch/art/orders_counter.png`, `market_counter.png` (Task 5);
  `res://art/sprout/objects/signs.png` (Task 1); `SpawnArea` (`shop/spawn_area.gd`: `sprites()`,
  `sprite_scale`, `wander_speed`, `preview_frames`, `preview_count`).
- Produces: `%Counter` (orders counter at (256, 64), 48×32), `%MarketStall` (market counter at (336, 64), 48×32),
  `%Door` (signpost at (616, 136), 16×16), `%Pens` at (48, 224) 192×80 and `%Stable` at (416, 240) 96×64 as direct
  children of `Shop`; no node or file references `res://shop/art/`.

- [ ] **Step 1: Write the failing tests** — append to `tests/test_shop_scene.gd`:

```gdscript


func test_creatures_stay_inside_their_areas() -> void:
	var shop := _shop()
	await tree.process_frame
	Game.retire(Game.owned()[0])
	await tree.process_frame
	for area_name in ["%Pens", "%Stable"]:
		var area: SpawnArea = shop.get_node(area_name)
		eq(area.get_parent(), shop, "%s sits on the ranch, not in an old frame" % area_name)
		check(area.sprites().size() > 0, "%s has creatures" % area_name)
		for s in area.sprites():
			check(Rect2(Vector2.ZERO, area.size).has_point(s.position), "%s creature inside: %s" % [area_name, s.position])
		eq(area.sprite_scale, 1.4, "%s sprite_scale" % area_name)
	_done(shop)


func test_the_shop_uses_no_side_view_art() -> void:
	var text := FileAccess.get_file_as_string("res://shop/shop.tscn")
	check(not text.contains("res://shop/art/"), "shop.tscn references res://shop/art/")
	for gone in ["Floor", "PenFrame", "StableFrame"]:
		check(not text.contains("[node name=\"%s\"" % gone), "%s node removed" % gone)
```

- [ ] **Step 2: Run to verify it fails** — Expected: `test_creatures_stay_inside_their_areas` fails on
  `sits on the ranch` and `sprite_scale`; `test_the_shop_uses_no_side_view_art` fails.

- [ ] **Step 3: Rework the stations and pens in the editor** — `scene_open` `res://shop/shop.tscn`, then
  `editor_manage` eval:

```gdscript
var r = EditorInterface.get_edited_scene_root()
if r.scene_file_path != "res://shop/shop.tscn" or not r.has_node("Ranch"):
	return "open shop.tscn with the Task 6 Ranch first"
var station := func(n: TextureButton, tex: Texture2D, pos: Vector2, sz: Vector2) -> void:
	n.texture_normal = tex
	n.ignore_texture_size = false
	n.stretch_mode = TextureButton.STRETCH_KEEP
	n.set_anchors_preset(Control.PRESET_TOP_LEFT)
	n.position = pos
	n.size = sz
station.call(r.get_node("%Counter"), load("res://ranch/art/orders_counter.png"), Vector2(256, 64), Vector2(48, 32))
station.call(r.get_node("%MarketStall"), load("res://ranch/art/market_counter.png"), Vector2(336, 64), Vector2(48, 32))
var signpost := AtlasTexture.new()
signpost.atlas = load("res://art/sprout/objects/signs.png")
signpost.region = Rect2(0, 0, 16, 16)
station.call(r.get_node("%Door"), signpost, Vector2(616, 136), Vector2(16, 16))
# pens: out of the old frames, onto the ranch, inside the fences with a one-tile margin
# (n untyped: sprite_scale / wander_speed live on the SpawnArea script, not on Control)
var area := func(n, pos: Vector2, sz: Vector2, before: Node) -> void:
	n.reparent(r, false)
	n.owner = r
	r.move_child(n, before.get_index())
	n.set_anchors_preset(Control.PRESET_TOP_LEFT)
	n.position = pos
	n.size = sz
	n.sprite_scale = 1.4
	n.wander_speed = 16.0
var pens: Control = r.get_node("%Pens")
var stable: Control = r.get_node("%Stable")
area.call(pens, Vector2(48, 224), Vector2(192, 80), r.get_node("%Counter"))
area.call(stable, Vector2(416, 240), Vector2(96, 64), r.get_node("%Counter"))
for gone in ["Floor", "PenFrame", "StableFrame"]:
	var n := r.get_node(gone)
	r.remove_child(n)
	n.free()
EditorInterface.mark_scene_as_unsaved()
var out := []
for n in r.get_children():
	out.append([n.name, n.get_class()])
return out
```

  then `scene_save`. Check the unique names survived: `grep -n -A1 'name="\(Counter\|MarketStall\|Door\|Pens\|Stable\)"' shop/shop.tscn`
  shows `unique_name_in_owner = true` under each; if one is missing, set it with eval
  (`r.get_node("<path>").unique_name_in_owner = true`) and save again.

- [ ] **Step 4: Run the tests** — Expected: all `test_shop_scene.gd` tests pass (including
  `test_no_later_sibling_blocks_a_station`), all suites `0 failed`.

- [ ] **Step 5: Screenshots** — `$GODOT --path . -- --screenshot=$SHOTS/ranch_t7.png`, and with `--open=card`,
  `--open=orders`, `--open=summary`; read all four. Expected: the ranch with both counters inside the house, the
  signpost at the road's end, owned creatures in the pen, the HUD on top, panels centred over the map, nothing cut
  off. In the editor, `scene_open` `res://shop/shop.tscn` and take an `editor_screenshot` source `viewport_2d`:
  the SpawnArea ghosts sit inside the fences.

- [ ] **Step 6: Commit**

```bash
git add shop/shop.tscn tests/test_shop_scene.gd
git commit -m "Put the counters, signpost and pens on the ranch"
```

---

### Task 8: Remove the side-view art

**Files:**
- Delete: `shop/art/` (all `.png` + `.import`)
- Modify: `asset-pipeline/jobs.json` (remove 7 side-view jobs)
- Delete: the tracked outputs of those jobs under `asset-pipeline/assets/`

**Interfaces:**
- Consumes: Tasks 4 and 7 (nothing references `shop/art/` any more).
- Produces: a repo with no side-view shop art.

- [ ] **Step 1: Confirm nothing uses it** — `grep -rn "shop/art" --include=*.gd --include=*.tscn --include=*.tres --include=*.godot . | grep -v "^./docs\|^./.superpowers"`
  → only the `test_the_shop_uses_no_side_view_art` string in `tests/test_shop_scene.gd`.

- [ ] **Step 2: Delete the art** — godot-ai `filesystem_manage` op `delete` for each of
  `res://shop/art/shop_floor.png`, `shop_counter.png`, `market_stall.png`, `shop_door.png`, `pen_grass.png`,
  `stable_hay.png`, `egg.png` (it removes the `.import` sidecars too), then `git add -u shop/art`.
  The owner's uncommitted line-ending-only edits to `shop/art/*.import` go with them (agreed in the spec).

- [ ] **Step 3: Remove the jobs** — delete these entries from `asset-pipeline/jobs.json` (keep valid JSON):
  `shop_floor`, `shop_counter`, `market_stall`, `shop_door`, `pen_grass`, `stable_hay`, `egg`. Then remove their
  tracked outputs:

```bash
git ls-files asset-pipeline/assets | grep -E "/(shop_floor|shop_counter|market_stall|shop_door|pen_grass|stable_hay|egg)\." | xargs -r git rm -q
```

  Run `python asset-pipeline/test_gen.py` → all `ok`.

- [ ] **Step 4: Full verification** — tests `0 failed`; `$GODOT --headless --path . --import` with no errors;
  `python asset-pipeline/test_gen.py` all `ok`; screenshots `ranch_final.png` plus `--open=card|orders|summary`,
  read each.

- [ ] **Step 5: Commit**

```bash
git add asset-pipeline/jobs.json
git commit -m "Remove the side-view shop art and its pipeline jobs"
```
