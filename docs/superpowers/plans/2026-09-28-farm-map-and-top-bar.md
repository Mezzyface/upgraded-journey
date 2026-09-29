# Farm Map and Hanging Top Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The main scene becomes the owner's farm map with a rope-and-strip top bar holding every stat and action, and every action opens its own popup scene over the dimmed farm.

**Architecture:** `shop/shop.tscn` is rebuilt in place: its old ranch layout and HUD are removed, the map nodes from `testing.tscn` are copied in, and a new `ui/top_bar.tscn` (script `TopBar`: `show_state` + five signals) is instanced at the top. `shop.gd` wires the bar's signals, a transparent `ShopDoor` over the building, and `%Pens` to popups opened in `%PanelHost`, which now dims the farm. New popups are separate scenes under `shop/panels/`.

**Tech Stack:** Godot 4.7 (GDScript), godot-ai MCP (editor_manage eval, script_create/script_patch, scene_open/scene_save, editor_screenshot).

**Spec:** `docs/superpowers/specs/2026-09-28-farm-map-and-top-bar-design.md`

## Global Constraints

- The Godot editor is open and owns the project. Make Godot changes through the godot-ai MCP: scripts with
  `script_create` / `script_patch`, scenes and resources with `editor_manage` op `eval` + `scene_save` /
  `ResourceSaver.save`. Never kill or restart the editor. Toggle plugins only with `EditorInterface.set_plugin_enabled`.
- `script_patch` matches exact bytes and inserts LF lines: anchor on single lines, confirm every patch with
  `git diff <file>`, and re-normalise a CRLF file to CRLF if the patch mixed endings (`file <path>` shows it).
- After every `scene_save` / resource save run `git status --short` on the whole tree and restore anything you did not
  mean to change.
- Never stage the owner's files: `creatures/frames/*.tres`, `project.godot`, `testing.tscn`. `testing.tscn` must not
  change at all (it is the owner's sandbox; its nodes are copied, not moved out of the file on disk).
- Commits: plain subject line, **no `Co-Authored-By` trailer**, stage files by name only, never push.
- Licensed pack art stays git-ignored (`art/sprout/**` except `.import` files).
- Viewport 640×360; the bar covers the top 40 px; tiles are 16 px.
- Godot suite: `$GODOT --headless --path . -s res://tests/run_tests.gd` must end `0 failed`, where
  `GODOT="C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`.
  One file: append `-- --only=test_x.gd`.
- Work on branch `farm-top-bar`, created from the current `HEAD` before Task 1.

## Review Focus

1. A click in the top 40 px that is not on a tag (e.g. a creature under the strip) must reach the farm: strip, rope
   and stats ignore the mouse. → Task 5 `test_the_bar_only_takes_clicks_on_its_tags`.
2. Choosing a creature in the Stable window replaces the Stable window with that creature's card (one popup at a
   time, no stacking). → Task 5 `test_stable_row_opens_the_card_in_place`.
3. Many retired creatures (12) must not push the Stable window off screen. → Task 5 `test_panel_fit` extension.
4. Big numbers (money 123456, reputation 999) must not push the stats under the tags. → Task 3
   `test_big_numbers_stay_clear_of_the_tags`.
5. Every new popup closes with its own Close button and with Esc, leaving the farm clickable again. → Task 4
   `test_each_popup_closes`.

---

### Task 1: Ground TileSet in `ranch/`, and its art in the Sync list

**Files:**
- Move (owner, in the FileSystem dock): `ground_tileset.tres` → `ranch/ground_tileset.tres`
- Modify: `addons/sprout_tools/sprout_sync.gd` (`FILES`)
- Modify: `tests/test_sprout_art.gd`
- Create: `tests/test_ground_tileset.gd`
- Commit: `ranch/ground_tileset.tres`, the 16 new `art/sprout/**/*.import` files

**Interfaces:**
- Produces: `res://ranch/ground_tileset.tres` — 16 atlas sources (ids 0–10, 12–14, 16, 17); terrain set 0 with 14
  terrains named `Soil, Grass, Grass Hills, Grass Layers, Grass Layers 2, Darker Grass, Darker Grass Hills,
  Darker Grass Layers, Darker Grass Layers 2, Soil Hills, Darker Soil, Darker Soil Hills, Stone, Stone Hills`;
  source 2 = `Grass_tiles_v2.png`, its plain grass centre tile at atlas `(1, 1)`.

- [ ] **Step 1: Move the TileSet (owner step)**

Ask the owner to drag `ground_tileset.tres` into `ranch/` in the Godot FileSystem dock (the dock updates every
reference, including `testing.tscn`'s). Wait for confirmation, then check: `ls ranch/ground_tileset.tres` exists,
`ls ground_tileset.tres` does not, and `git diff --stat testing.tscn` is empty or only its ext_resource path line
(Godot rewrites that path; that is the dock's doing and acceptable — but do not stage `testing.tscn`).

- [ ] **Step 2: Write the failing tests**

Append to `tests/test_sprout_art.gd`:

```gdscript
func test_ground_art_is_listed() -> void:
	for rel in ["tiles/Grass_tiles_v2.png", "tiles/Soil_Ground_Tiles.png", "tiles/Bitmask references 2.png",
			"tiles/Bush_Tiles.png", "tiles/Darker_Grass_Hills_Tiles_v2.png", "tiles/Darker_Grass_Tiles_v2.png",
			"tiles/Darker_Grass_Tile_Layers2.png", "tiles/Darker_Grass_Tile_Layers.png",
			"tiles/Darker_Soil_Ground_Hills_Tiles.png", "tiles/Darker_Soil_Ground_Tiles.png",
			"tiles/Grass_Hill_Tiles_v2.png", "tiles/Grass_Tile_layers2.png", "tiles/Grass_Tile_Layers.png",
			"tiles/Soil_Ground_HiIls_Tiles.png", "tiles/Stone_Ground_Hills_Tiles.png", "tiles/Stone_Ground_Tiles.png",
			"objects/Fences.png", "objects/grey_brick_houses_with_doors_grass.png"]:
		check(Sync.FILES.has(rel), "SproutSync.FILES lists %s" % rel)
```

Create `tests/test_ground_tileset.gd`:

```gdscript
extends TestSuite
## ranch/ground_tileset.tres: one terrain per ground sheet, all in terrain set 0 (set up in the editor).

const PATH := "res://ranch/ground_tileset.tres"
const NAMES := ["Soil", "Grass", "Grass Hills", "Grass Layers", "Grass Layers 2", "Darker Grass",
	"Darker Grass Hills", "Darker Grass Layers", "Darker Grass Layers 2", "Soil Hills", "Darker Soil",
	"Darker Soil Hills", "Stone", "Stone Hills"]


func test_terrains_are_named_one_per_sheet() -> void:
	var ts := load(PATH) as TileSet
	check(ts != null, "%s loads" % PATH)
	if ts == null:
		return
	eq(ts.get_terrains_count(0), NAMES.size(), "terrain count")
	for i in NAMES.size():
		eq(ts.get_terrain_name(0, i), NAMES[i], "terrain %d name" % i)


func test_grass_source_has_its_centre_tile() -> void:
	var ts := load(PATH) as TileSet
	var grass := ts.get_source(2) as TileSetAtlasSource
	eq(grass.texture.resource_path, "res://art/sprout/tiles/Grass_tiles_v2.png", "source 2 texture")
	check(grass.has_tile(Vector2i(1, 1)), "grass centre tile")
	eq(grass.get_tile_data(Vector2i(1, 1), 0).terrain, 1, "grass centre tile is terrain Grass")
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_sprout_art.gd`
Expected: `FAIL test_sprout_art.gd::test_ground_art_is_listed  SproutSync.FILES lists tiles/Bitmask references 2.png`
(and the other new sheets), plus `test_every_sprout_reference_is_synced` failures naming `ranch/ground_tileset.tres`.
Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_ground_tileset.gd`
Expected: PASS if Step 1 is done (it pins the owner's work), otherwise `res://ranch/ground_tileset.tres loads` fails.

- [ ] **Step 4: Add the Sync entries**

In `addons/sprout_tools/sprout_sync.gd` add the constant under `SPRITES_PREM`:

```gdscript
const SORRY := "Sprout Sorry pack/"
const GROUND := SPRITES_PREM + "Tilesets/ground tiles/"
```

and add these `FILES` entries after the `"tiles/Soil_Ground_Tiles.png"` line (script_patch anchored on that line,
confirm with `git diff`):

```gdscript
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
```

Then run the sync in the editor to prove every source exists (`editor_manage` eval):

```gdscript
var missing = preload("res://addons/sprout_tools/sprout_sync.gd").sync()
EditorInterface.get_resource_filesystem().scan()
return missing
```

Expected: `[]`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_sprout_art.gd` → `0 failed`.
Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_ground_tileset.gd` → `2 tests, 0 failed`.
(`test_every_sprout_reference_is_synced` still scans `testing.tscn`; it passes now that both objects files are listed.)

- [ ] **Step 6: Commit**

```bash
git add addons/sprout_tools/sprout_sync.gd tests/test_sprout_art.gd tests/test_ground_tileset.gd tests/test_ground_tileset.gd.uid ranch/ground_tileset.tres "art/sprout/tiles/Bitmask references 2.png.import" art/sprout/tiles/Bush_Tiles.png.import art/sprout/tiles/Darker_Grass_Hills_Tiles_v2.png.import art/sprout/tiles/Darker_Grass_Tiles_v2.png.import art/sprout/tiles/Darker_Grass_Tile_Layers2.png.import art/sprout/tiles/Darker_Grass_Tile_Layers.png.import art/sprout/tiles/Darker_Soil_Ground_Hills_Tiles.png.import art/sprout/tiles/Darker_Soil_Ground_Tiles.png.import art/sprout/tiles/Grass_Hill_Tiles_v2.png.import art/sprout/tiles/Grass_Tile_layers2.png.import art/sprout/tiles/Grass_Tile_Layers.png.import art/sprout/tiles/Soil_Ground_HiIls_Tiles.png.import art/sprout/tiles/Stone_Ground_Hills_Tiles.png.import art/sprout/tiles/Stone_Ground_Tiles.png.import art/sprout/objects/Fences.png.import art/sprout/objects/grey_brick_houses_with_doors_grass.png.import
git commit -m "Keep the ground TileSet in ranch/ and sync every sheet it uses"
```

---

### Task 2: Theme variations `RopeStrip`, `Rope`, `HangingTag`, shown in the gallery

**Files:**
- Modify (editor): `ui/theme/sprout_lands.tres`
- Modify (editor): `ui/gallery.tscn`
- Modify: `tests/test_theme.gd`

**Interfaces:**
- Produces: theme type variations `RopeStrip` (base `Panel`, `panel` = `StyleBoxTexture` tiling a plank region of
  `res://art/sprout/tiles/Wooden_House_Walls_Tilset.png`, `modulate_color.a` ≈ 0.7), `Rope` (base `Panel`,
  `panel` = `StyleBoxFlat` `#8c7369` with a 1 px `#c49a6c` top border), `HangingTag` (base `Button`, styleboxes
  `normal`/`hover`/`pressed`/`disabled` duplicated from `DecoratedButton` with 4 px side / 2 px top-bottom content
  margins).

- [ ] **Step 1: Write the failing test**

In `tests/test_theme.gd`, add to the `VARIATIONS` dictionary: `"RopeStrip": &"Panel", "Rope": &"Panel",
"HangingTag": &"Button",` and append:

```gdscript
func test_top_bar_variations_have_their_styles() -> void:
	var theme: Theme = load(THEME)
	var strip := theme.get_stylebox("panel", "RopeStrip") as StyleBoxTexture
	check(strip != null and strip.texture.resource_path == "res://art/sprout/tiles/Wooden_House_Walls_Tilset.png", "RopeStrip tiles the plank sheet")
	check(strip != null and strip.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE, "RopeStrip tiles horizontally")
	check(theme.get_stylebox("panel", "Rope") is StyleBoxFlat, "Rope is a flat brown line")
	for s in ["normal", "hover", "pressed"]:
		check(theme.get_stylebox(s, "HangingTag") is StyleBoxTexture, "HangingTag %s" % s)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_theme.gd`
Expected: FAIL `RopeStrip base: expected Panel, got ` and the style checks.

- [ ] **Step 3: Add the variations in the editor**

`editor_manage` eval:

```gdscript
var theme := load("res://ui/theme/sprout_lands.tres") as Theme
theme.set_type_variation("RopeStrip", "Panel")
var strip := StyleBoxTexture.new()
strip.texture = load("res://art/sprout/tiles/Wooden_House_Walls_Tilset.png")
strip.region_rect = Rect2(56, 18, 8, 12)  # horizontal planks inside the wall block; check the screenshot in Step 5
strip.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
strip.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
strip.modulate_color = Color(1, 1, 1, 0.7)
theme.set_stylebox("panel", "RopeStrip", strip)
theme.set_type_variation("Rope", "Panel")
var rope := StyleBoxFlat.new()
rope.bg_color = Color("#8c7369")
rope.border_width_top = 1
rope.border_color = Color("#c49a6c")
theme.set_stylebox("panel", "Rope", rope)
theme.set_type_variation("HangingTag", "Button")
for s in ["normal", "hover", "pressed", "disabled"]:
	var src := theme.get_stylebox(s, "DecoratedButton")
	if src:
		var sb := src.duplicate() as StyleBox
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		theme.set_stylebox(s, "HangingTag", sb)
return error_string(ResourceSaver.save(theme, "res://ui/theme/sprout_lands.tres"))
```

Expected: `OK`. `git status --short`; restore anything else.

- [ ] **Step 4: Show them in the gallery**

`scene_open` `res://ui/gallery.tscn`, then `editor_manage` eval:

```gdscript
var root := EditorInterface.get_edited_scene_root()
var rows := root.get_node("Scroll/Margin/Rows")
var head := Label.new()
head.name = "H9"
head.text = "Top bar"
head.theme_type_variation = &"HeaderLabel"
rows.add_child(head)
head.owner = root
var bar := Control.new()
bar.name = "TopBarSample"
bar.custom_minimum_size = Vector2(0, 44)
rows.add_child(bar)
bar.owner = root
var strip := Panel.new()
strip.name = "Strip"
strip.theme_type_variation = &"RopeStrip"
strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
strip.offset_bottom = 22
bar.add_child(strip)
strip.owner = root
var rope := Panel.new()
rope.name = "Rope"
rope.theme_type_variation = &"Rope"
rope.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
rope.offset_top = 21
rope.offset_bottom = 24
bar.add_child(rope)
rope.owner = root
var tag := Button.new()
tag.name = "Tag"
tag.text = "Market"
tag.theme_type_variation = &"HangingTag"
tag.position = Vector2(16, 27)
bar.add_child(tag)
tag.owner = root
return "added"
```

Then `scene_save`, `git status --short` (only `ui/gallery.tscn` and the theme should be modified).

- [ ] **Step 5: Verify**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_theme.gd` → `0 failed`.
Screenshot: `$GODOT --path . res://ui/gallery.tscn -- --screenshot=<scratchpad>/gallery_bar.png --scroll=2000`
(increase `--scroll` until the "Top bar" row shows). The strip must read as horizontal wood planks, the rope as a
brown line, the tag as a Sprout plate. If the strip shows a wall edge instead of planks, change only
`strip.region_rect` (a region fully inside the planks) with the Step 3 eval and re-save.

- [ ] **Step 6: Commit**

```bash
git add ui/theme/sprout_lands.tres ui/gallery.tscn tests/test_theme.gd
git commit -m "Add rope, strip and hanging tag styles to the theme and gallery"
```

---

### Task 3: The top bar scene

**Files:**
- Create: `ui/top_bar.gd` (via `script_create`)
- Create (editor): `ui/top_bar.tscn`
- Create: `tests/test_top_bar.gd`

**Interfaces:**
- Consumes: `RopeStrip`, `Rope`, `HangingTag`, `OnMapLabel` theme variations (Task 2); textures copied from the
  current `shop/shop.tscn` (hearts, coin, feed and pen icons, weather) — duplicated, so they are embedded in
  `top_bar.tscn` and survive Task 5 deleting the old HUD.
- Produces: `class_name TopBar extends Control` with
  `signal orders_pressed`, `signal stable_pressed`, `signal expedition_pressed`, `signal market_pressed`,
  `signal end_day_pressed`, `@export var heart_full: Texture2D`, `@export var heart_empty: Texture2D`,
  `func show_state(s: GameState, tier: int) -> void`. Unique-named children: `%DayLabel`, `%Hearts` (6
  TextureRects), `%Money`, `%Feed`, `%PenSpace`, `%Rep`, `%Stats`, `%Tags`, `%Orders`, `%Stable`, `%Expedition`,
  `%Market`, `%EndDay`, plus `Strip` and `Rope`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_top_bar.gd`:

```gdscript
extends TestSuite
## ui/top_bar.tscn: shows the state and turns tag presses into signals.

const SAVE := "user://test_top_bar_save.json"


func _bar() -> TopBar:
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)
	var bar: TopBar = load("res://ui/top_bar.tscn").instantiate()
	tree.root.add_child(bar)
	return bar


func _done(bar: Node) -> void:
	bar.queue_free()
	DirAccess.remove_absolute(SAVE)


func test_show_state_fills_every_stat() -> void:
	var bar := _bar()
	var s := Game.state
	bar.show_state(s, 2)
	eq(bar.get_node("%DayLabel").text, "Day %d" % s.day, "day")
	eq(bar.get_node("%Money").text, str(s.money), "money")
	eq(bar.get_node("%Feed").text, str(s.inventory.get("feed", 0)), "feed")
	eq(bar.get_node("%PenSpace").text, "%d/%d" % [Market.pen_used(s), Market.pen_capacity(s)], "pens")
	eq(bar.get_node("%Rep").text, "Rep %d · T2" % s.reputation, "reputation and tier")
	var full := 0
	for h: TextureRect in bar.get_node("%Hearts").get_children():
		if h.visible and h.texture == bar.heart_full:
			full += 1
	eq(full, s.ap, "one full heart per AP left")
	_done(bar)


func test_each_tag_emits_its_signal() -> void:
	var bar := _bar()
	var got: Array[String] = []
	for sig in ["orders_pressed", "stable_pressed", "expedition_pressed", "market_pressed", "end_day_pressed"]:
		bar.connect(sig, func() -> void: got.append(sig))
	for tag in ["%Orders", "%Stable", "%Expedition", "%Market", "%EndDay"]:
		bar.get_node(tag).pressed.emit()
	eq(got, ["orders_pressed", "stable_pressed", "expedition_pressed", "market_pressed", "end_day_pressed"], "signals in order")
	_done(bar)


func test_only_the_tags_take_clicks() -> void:
	var bar := _bar()
	for path in [".", "Strip", "Rope", "%Stats"]:
		eq(bar.get_node(path).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % path)
	for n in bar.get_node("%Stats").get_children():
		eq(n.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % n.name)
	_done(bar)


func test_big_numbers_stay_clear_of_the_tags() -> void:
	var bar := _bar()
	bar.size = Vector2(656, 40)
	Game.state.money = 123456
	Game.state.reputation = 999
	bar.show_state(Game.state, 9)
	await tree.process_frame
	await tree.process_frame
	var stats: Rect2 = bar.get_node("%Stats").get_global_rect()
	var tags: Rect2 = bar.get_node("%Tags").get_global_rect()
	check(stats.end.x <= tags.position.x or stats.end.y <= tags.position.y, "stats %s clear of tags %s" % [stats, tags])
	check(stats.end.x <= 640 + 8, "stats fit on screen: %s" % stats)
	_done(bar)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_top_bar.gd`
Expected: `does not compile` / script errors (`TopBar` and `res://ui/top_bar.tscn` do not exist).

- [ ] **Step 3: Write the script**

`script_create` `res://ui/top_bar.gd`:

```gdscript
class_name TopBar
extends Control
## The bar hanging from the top of the screen: a translucent wood strip with a rope along its lower edge, the
## stats on the strip and the action tags hanging from the rope. Laid out in ui/top_bar.tscn. Only the tags take
## clicks; everything else lets them through to the farm. shop.gd connects the signals and calls show_state().

signal orders_pressed
signal stable_pressed
signal expedition_pressed
signal market_pressed
signal end_day_pressed

## AP hearts: each child of %Hearts shows one AP point, full while unspent.
@export var heart_full: Texture2D
@export var heart_empty: Texture2D


func _ready() -> void:
	%Orders.pressed.connect(orders_pressed.emit)
	%Stable.pressed.connect(stable_pressed.emit)
	%Expedition.pressed.connect(expedition_pressed.emit)
	%Market.pressed.connect(market_pressed.emit)
	%EndDay.pressed.connect(end_day_pressed.emit)


func show_state(s: GameState, tier: int) -> void:
	%DayLabel.text = "Day %d" % s.day
	var max_ap := Day.max_ap(s)
	for i in %Hearts.get_child_count():
		var heart: TextureRect = %Hearts.get_child(i)
		# ponytail: hearts are placed in the editor (6 = max AP today); add nodes there if max AP grows
		heart.visible = i < max_ap
		heart.texture = heart_full if i < s.ap else heart_empty
	%Money.text = str(s.money)
	%Feed.text = str(s.inventory.get("feed", 0))
	%PenSpace.text = "%d/%d" % [Market.pen_used(s), Market.pen_capacity(s)]
	%Rep.text = "Rep %d · T%d" % [s.reputation, tier]
```

Confirm on disk.

- [ ] **Step 4: Build the scene in the editor**

`editor_manage` eval (builds and saves `ui/top_bar.tscn`; icons are duplicated from the current shop HUD):

```gdscript
var old := (load("res://shop/shop.tscn") as PackedScene).instantiate()
var tex := {
	"full": (old.get("heart_full") as Texture2D).duplicate(), "empty": (old.get("heart_empty") as Texture2D).duplicate(),
	"coin": (old.get_node("Hud/TopLeft/MoneyRow/Coin").texture as Texture2D).duplicate(),
	"feed": (old.get_node("Hud/TopLeft/FeedRow/Icon").texture as Texture2D).duplicate(),
	"pen": (old.get_node("Hud/TopLeft/PenRow/Icon").texture as Texture2D).duplicate(),
	"weather": (old.get_node("Hud/TopLeft/WeatherSlot").texture as Texture2D).duplicate(),
}
old.free()
var root := Control.new()
root.name = "TopBar"
root.set_script(load("res://ui/top_bar.gd"))
root.set_anchors_preset(Control.PRESET_TOP_WIDE)
root.offset_left = -8
root.offset_right = 8
root.offset_bottom = 40
root.mouse_filter = Control.MOUSE_FILTER_IGNORE
root.set("heart_full", tex.full)
root.set("heart_empty", tex.empty)
var own := func(n: Node, parent: Node, uname := false) -> Node:
	parent.add_child(n)
	n.owner = root
	n.unique_name_in_owner = uname
	return n
var strip := Panel.new()
strip.name = "Strip"
strip.theme_type_variation = &"RopeStrip"
strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
strip.offset_bottom = 22
strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
own.call(strip, root)
var rope := Panel.new()
rope.name = "Rope"
rope.theme_type_variation = &"Rope"
rope.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
rope.offset_top = 21
rope.offset_bottom = 24
rope.mouse_filter = Control.MOUSE_FILTER_IGNORE
own.call(rope, root)
var stats := HBoxContainer.new()
stats.name = "Stats"
stats.position = Vector2(16, 3)
stats.size = Vector2(400, 16)
stats.add_theme_constant_override("separation", 6)
stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
own.call(stats, root, true)
var icon := func(name: String, t: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.name = name
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(14, 14)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
var label := func(name: String, text: String) -> Label:
	var l := Label.new()
	l.name = name
	l.text = text
	l.theme_type_variation = &"OnMapLabel"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
own.call(icon.call("Weather", tex.weather), stats)
own.call(label.call("DayLabel", "Day 1"), stats, true)
var hearts := HBoxContainer.new()
hearts.name = "Hearts"
hearts.add_theme_constant_override("separation", 1)
hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
own.call(hearts, stats, true)
for i in 6:
	own.call(icon.call("Heart%d" % (i + 1), tex.full), hearts)
own.call(icon.call("Coin", tex.coin), stats)
own.call(label.call("Money", "0"), stats, true)
own.call(icon.call("FeedIcon", tex.feed), stats)
own.call(label.call("Feed", "0"), stats, true)
own.call(icon.call("PenIcon", tex.pen), stats)
own.call(label.call("PenSpace", "0/0"), stats, true)
own.call(label.call("Rep", "Rep 0 · T1"), stats, true)
var tags := HBoxContainer.new()
tags.name = "Tags"
tags.anchor_left = 1.0
tags.anchor_right = 1.0
tags.offset_left = -310
tags.offset_right = -16
tags.offset_top = 27
tags.offset_bottom = 40
tags.alignment = BoxContainer.ALIGNMENT_END
tags.add_theme_constant_override("separation", 4)
tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
own.call(tags, root, true)
for pair in [["Orders", "Orders"], ["Stable", "Stable"], ["Expedition", "Expedition"], ["Market", "Market"], ["EndDay", "End Day"]]:
	var b := Button.new()
	b.name = pair[0]
	b.text = pair[1]
	b.theme_type_variation = &"HangingTag"
	b.focus_mode = Control.FOCUS_NONE
	if pair[0] == "EndDay":
		b.self_modulate = Color(1, 0.85, 0.8)
	own.call(b, tags, true)
	var string := ColorRect.new()
	string.name = "String"
	string.color = Color("#754c60")
	string.anchor_left = 0.5
	string.anchor_right = 0.5
	string.offset_left = 0
	string.offset_right = 1
	string.offset_top = -3
	string.offset_bottom = 0
	string.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own.call(string, b)
var p := PackedScene.new()
p.pack(root)
var err := ResourceSaver.save(p, "res://ui/top_bar.tscn")
root.free()
EditorInterface.get_resource_filesystem().scan()
return error_string(err)
```

Expected: `OK`. `scene_open` `res://ui/top_bar.tscn` and `editor_screenshot` (`viewport_2d`) to see it; do not save
unless you change something. `git status --short`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_top_bar.gd` → `4 tests, 0 failed`.
If `test_big_numbers_stay_clear_of_the_tags` fails, shrink `%Stats` separation or the label font via the scene in
the editor (not the test) and re-run.

- [ ] **Step 6: Commit**

```bash
git add ui/top_bar.gd ui/top_bar.gd.uid ui/top_bar.tscn tests/test_top_bar.gd tests/test_top_bar.gd.uid
git commit -m "Add the hanging top bar scene"
```

---

### Task 4: Popup scenes and the dimming PanelHost

**Files:**
- Create: `shop/panels/closable_panel.gd`, `shop/panels/stable_panel.gd` (via `script_create`)
- Create (editor): `shop/panels/market_panel.tscn`, `shop/panels/expedition_panel.tscn`, `shop/panels/stable_panel.tscn`
- Modify: `shop/panel_host.gd`
- Create: `tests/test_popups.gd`

**Interfaces:**
- Produces: `StablePanel` (`shop/panels/stable_panel.gd`, `extends PanelContainer`) with
  `signal creature_chosen(c: CreatureData)` and `func show_creatures(retired: Array) -> void`; unique children
  `%Close`, `%List` (VBoxContainer), `%Empty` (Label). Root node names: `StablePanel`, `MarketPanel`,
  `ExpeditionPanel`. `PanelHost.backdrop: bool` (true while a panel is open).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_popups.gd`:

```gdscript
extends TestSuite
## The popup scenes (Stable, Market, Expedition) and PanelHost's backdrop.

const SAVE := "user://test_popups_save.json"
const SCENES := {"StablePanel": "res://shop/panels/stable_panel.tscn",
	"MarketPanel": "res://shop/panels/market_panel.tscn", "ExpeditionPanel": "res://shop/panels/expedition_panel.tscn"}


func _host() -> PanelHost:
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)
	var host := PanelHost.new()
	host.size = Vector2(640, 320)
	tree.root.add_child(host)
	return host


func _done(host: Node) -> void:
	host.queue_free()
	DirAccess.remove_absolute(SAVE)


func test_each_popup_closes() -> void:
	var host := _host()
	for name in SCENES:
		var panel: Control = load(SCENES[name]).instantiate()
		host.open(panel)
		eq(panel.name, name, "root name")
		check(host.backdrop, "%s: backdrop while open" % name)
		panel.get_node("%Close").pressed.emit()
		await tree.process_frame
		check(host.current() == null, "%s: Close closes it" % name)
		check(not host.backdrop, "%s: backdrop gone" % name)
		eq(host.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: farm clickable again" % name)
		host.open(load(SCENES[name]).instantiate())
		var esc := InputEventAction.new()
		esc.action = &"ui_cancel"
		esc.pressed = true
		host._unhandled_input(esc)
		await tree.process_frame
		check(host.current() == null, "%s: Esc closes it" % name)
	_done(host)


func test_stable_lists_retired_creatures_and_emits_the_choice() -> void:
	var host := _host()
	Game.retire(Game.owned()[0])
	var panel: StablePanel = load(SCENES.StablePanel).instantiate()
	host.open(panel)
	panel.show_creatures(Game.retired())
	eq(panel.get_node("%List").get_child_count(), Game.retired().size(), "one row per retired creature")
	check(not panel.get_node("%Empty").visible, "no empty text")
	var chosen: Array = []
	panel.creature_chosen.connect(func(c: CreatureData) -> void: chosen.append(c))
	(panel.get_node("%List").get_child(0) as Button).pressed.emit()
	eq(chosen, [Game.retired()[0]], "row press emits creature_chosen")
	_done(host)


func test_empty_stable_says_so() -> void:
	var host := _host()
	var panel: StablePanel = load(SCENES.StablePanel).instantiate()
	host.open(panel)
	panel.show_creatures([])
	eq(panel.get_node("%List").get_child_count(), 0, "no rows")
	check(panel.get_node("%Empty").visible, "empty text shown")
	_done(host)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_popups.gd`
Expected: `does not compile` (`StablePanel` unknown) / script errors.

- [ ] **Step 3: Write the scripts and the PanelHost backdrop**

`script_create` `res://shop/panels/closable_panel.gd`:

```gdscript
extends PanelContainer
## A popup whose %Close button closes it in its PanelHost (market_panel.tscn, expedition_panel.tscn). Everything
## else in those windows is laid out in their scenes.


func _ready() -> void:
	%Close.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close())
```

`script_create` `res://shop/panels/stable_panel.gd`:

```gdscript
class_name StablePanel
extends PanelContainer
## Retired creatures, one button each; pressing one emits creature_chosen (shop.gd opens its card in place).

signal creature_chosen(c: CreatureData)


func _ready() -> void:
	%Close.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close())


func show_creatures(retired: Array) -> void:
	for row in %List.get_children():
		%List.remove_child(row)
		row.queue_free()
	%Empty.visible = retired.is_empty()
	for c: CreatureData in retired:
		var b := Button.new()
		b.theme_type_variation = &"DecoratedButton"
		var sp := Game.species_of(c)
		b.text = "%s #%d" % [sp.display_name if sp else String(c.species), c.id]
		b.pressed.connect(creature_chosen.emit.bind(c))
		%List.add_child(b)
```

In `shop/panel_host.gd` (script_patch, one anchor per edit, confirm with `git diff`):
- after `const OUTLINE := Color(1, 1, 1, 0.7)` add
  ```gdscript
  const DIM := Color(0, 0, 0, 0.35)  ## backdrop over the farm while a window is open

  var backdrop := false
  ```
- replace the `_draw` body's first line `	if not Engine.is_editor_hint():` block with:
  ```gdscript
  	if not Engine.is_editor_hint():
  		if backdrop:
  			draw_rect(Rect2(Vector2.ZERO, size), DIM)
  		return
  ```
- at the end of `open()` add `	backdrop = true` and `	queue_redraw()`; at the end of `close()` add
  `	backdrop = false` and `	queue_redraw()`.

Update the header comment's first line to mention the backdrop.

- [ ] **Step 4: Build the three scenes in the editor**

`editor_manage` eval (one frame builder, three scenes; each is then editable on its own):

```gdscript
var build := func(root_name: String, title: String, script_path: String, body: Callable) -> String:
	var root := PanelContainer.new()
	root.name = root_name
	root.set_script(load(script_path))
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	root.add_child(margin)
	margin.owner = root
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	margin.add_child(rows)
	rows.owner = root
	var head := HBoxContainer.new()
	head.name = "Title"
	rows.add_child(head)
	head.owner = root
	var label := Label.new()
	label.name = "Label"
	label.text = title
	label.theme_type_variation = &"HeaderLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	label.owner = root
	var close := Button.new()
	close.name = "Close"
	close.text = "X"
	close.unique_name_in_owner = true
	head.add_child(close)
	close.owner = root
	body.call(root, rows)
	var p := PackedScene.new()
	p.pack(root)
	var path := "res://shop/panels/%s.tscn" % root_name.to_snake_case()
	var err := ResourceSaver.save(p, path)
	root.free()
	return "%s %s" % [path, error_string(err)]
var text_body := func(text: String) -> Callable:
	return func(root: Node, rows: Node) -> void:
		var l := Label.new()
		l.name = "Text"
		l.text = text
		rows.add_child(l)
		l.owner = root
var stable_body := func(root: Node, rows: Node) -> void:
	var empty := Label.new()
	empty.name = "Empty"
	empty.text = "No retired creatures yet"
	empty.unique_name_in_owner = true
	rows.add_child(empty)
	empty.owner = root
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(220, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	scroll.owner = root
	var list := VBoxContainer.new()
	list.name = "List"
	list.unique_name_in_owner = true
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	list.owner = root
var out := [
	build.call("MarketPanel", "Market", "res://shop/panels/closable_panel.gd", text_body.call("The market opens soon.")),
	build.call("ExpeditionPanel", "Expedition", "res://shop/panels/closable_panel.gd", text_body.call("Expeditions start soon.")),
	build.call("StablePanel", "Stable", "res://shop/panels/stable_panel.gd", stable_body),
]
EditorInterface.get_resource_filesystem().scan()
return "\n".join(out)
```

Expected: three `OK` lines for `market_panel.tscn`, `expedition_panel.tscn`, `stable_panel.tscn`. Open each with
`scene_open` and take an `editor_screenshot`; the Close button should match the orders panel's (if the orders panel's
`%Close` has a `theme_type_variation` or icon, copy it onto the three new Close buttons in the editor and save).
`git status --short`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_popups.gd` → `3 tests, 0 failed`.
Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_spawn_area.gd` → `0 failed`
(`test_panel_host_shows_one_panel_at_a_time` still passes with the backdrop).

- [ ] **Step 6: Commit**

```bash
git add shop/panels/closable_panel.gd shop/panels/closable_panel.gd.uid shop/panels/stable_panel.gd shop/panels/stable_panel.gd.uid shop/panels/market_panel.tscn shop/panels/expedition_panel.tscn shop/panels/stable_panel.tscn shop/panel_host.gd tests/test_popups.gd tests/test_popups.gd.uid
git commit -m "Add Stable, Market and Expedition popups and dim the farm behind popups"
```

---

### Task 5: Rebuild the main scene around the farm and the bar

**Files:**
- Modify: `shop/shop.gd` (rewrite via `script_create`)
- Modify (editor): `shop/shop.tscn`
- Rewrite: `tests/test_shop_scene.gd`; Modify: `tests/test_panel_fit.gd`; Delete: `tests/test_ranch_map.gd`

**Interfaces:**
- Consumes: `TopBar` (Task 3), `StablePanel` + popup scenes + `PanelHost.backdrop` (Task 4), the `testing.tscn`
  nodes `BaseMap`, `Shop`, `Pen` (copied, `Shop` renamed `ShopBuilding`).
- Produces: `shop.tscn` root children in draw order: `BaseMap`, `ShopBuilding`, `Pen`, `Pens` (SpawnArea, unique),
  `ShopDoor` (Button, unique), `TopBar` (unique), `Toast` (unique), `PanelHost` (unique). `shop.gd` functions
  `open_card(c)`, `open_orders()`, `open_stable()`, `open_market()`, `open_expedition()`, `end_day()`, `toast(msg)`;
  `--open=card|orders|summary|stable|market|expedition`.

- [ ] **Step 1: Write the failing tests**

Replace `tests/test_shop_scene.gd` with:

```gdscript
extends TestSuite
## The main scene: the farm map, creatures in the pen, the hanging bar and the popups its tags open.

const SAVE := "user://test_shop_save.json"


func _shop() -> Control:
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)
	var shop: Control = load("res://shop/shop.tscn").instantiate()
	tree.root.add_child(shop)
	return shop


func _done(shop: Control) -> void:
	shop.queue_free()
	DirAccess.remove_absolute(SAVE)


func _open_name(shop: Node) -> String:
	var p: Control = shop.get_node("%PanelHost").current()
	return p.name if p else ""


func test_the_bar_shows_the_state_and_refreshes() -> void:
	var shop := _shop()
	await tree.process_frame
	var bar: TopBar = shop.get_node("%TopBar")
	eq(bar.get_node("%DayLabel").text, "Day 1", "day 1")
	eq(bar.get_node("%Money").text, str(Game.state.money), "money")
	bar.end_day_pressed.emit()
	await tree.process_frame
	eq(bar.get_node("%DayLabel").text, "Day 2", "day 2 after End Day")
	eq(_open_name(shop), "DaySummary", "End Day opens the day summary")
	_done(shop)


func test_each_tag_and_the_shop_door_open_their_popup() -> void:
	var shop := _shop()
	await tree.process_frame
	var bar: TopBar = shop.get_node("%TopBar")
	for pair in [["orders_pressed", "OrdersPanel"], ["stable_pressed", "StablePanel"],
			["expedition_pressed", "ExpeditionPanel"], ["market_pressed", "MarketPanel"]]:
		bar.emit_signal(pair[0])
		await tree.process_frame
		eq(_open_name(shop), pair[1], "%s opens %s" % pair)
	shop.get_node("%PanelHost").close()
	shop.get_node("%ShopDoor").pressed.emit()
	await tree.process_frame
	eq(_open_name(shop), "OrdersPanel", "the shop building opens Orders")
	_done(shop)


func test_creatures_live_in_the_pen_and_open_their_card() -> void:
	var shop := _shop()
	await tree.process_frame
	var pens: SpawnArea = shop.get_node("%Pens")
	eq(pens.sprites().size(), Game.owned().size(), "one sprite per owned creature")
	eq(pens.sprite_scale, 1.4, "sprite_scale")
	var pen_rect := _pen_rect(shop)
	check(pen_rect.encloses(pens.get_global_rect()), "Pens %s inside the pen %s" % [pens.get_global_rect(), pen_rect])
	for s in pens.sprites():
		check(Rect2(Vector2.ZERO, pens.size).has_point(s.position), "creature inside: %s" % s.position)
	pens.creature_clicked.emit(Game.owned()[0])
	await tree.process_frame
	eq(_open_name(shop), "CreatureCard", "a creature opens its card")
	_done(shop)


func _pen_rect(shop: Node) -> Rect2:
	var r := Rect2()
	for layer: TileMapLayer in shop.get_node("Pen").find_children("*", "TileMapLayer", true, false):
		var used := layer.get_used_rect()
		var px := Rect2(layer.to_global(layer.map_to_local(used.position)) - Vector2(8, 8), Vector2(used.size) * 16)
		r = px if r.size == Vector2.ZERO else r.merge(px)
	return r


func test_stable_row_opens_the_card_in_place() -> void:
	var shop := _shop()
	await tree.process_frame
	Game.retire(Game.owned()[0])
	shop.call("open_stable")
	await tree.process_frame
	var stable: StablePanel = shop.get_node("%PanelHost").current()
	(stable.get_node("%List").get_child(0) as Button).pressed.emit()
	await tree.process_frame
	eq(_open_name(shop), "CreatureCard", "the card replaces the Stable window")
	eq(shop.get_node("%PanelHost").get_child_count(), 1, "one popup at a time")
	_done(shop)


func test_the_old_layout_is_gone() -> void:
	var shop := _shop()
	for gone in ["Ranch", "Hud", "Counter", "MarketStall", "Door", "Stable"]:
		check(not shop.has_node(gone), "%s removed" % gone)
	for kept in ["BaseMap", "ShopBuilding", "Pen"]:
		check(shop.has_node(kept), "%s from the farm map" % kept)
	_done(shop)


func test_the_bar_only_takes_clicks_on_its_tags() -> void:
	var shop := _shop()
	await tree.process_frame
	var bar: TopBar = shop.get_node("%TopBar")
	for path in [".", "Strip", "Rope", "%Stats"]:
		eq(bar.get_node(path).mouse_filter, Control.MOUSE_FILTER_IGNORE, "bar %s ignores the mouse" % path)
	var children := shop.get_children()
	var door: Control = shop.get_node("%ShopDoor")
	for i in range(children.find(door) + 1, children.size()):
		var sib: Node = children[i]
		if sib is Control and sib.get_global_rect().intersects(door.get_global_rect()):
			eq(sib.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s overlaps the shop door and must ignore the mouse" % sib.name)
	_done(shop)
```

In `tests/test_panel_fit.gd` replace the `opens` dictionary and add retired creatures before it:

```gdscript
	for i in 12:  # a full stable must still fit (Review Focus 3)
		Fixtures.adult(Game.state, "spider").status = CreatureData.Status.RETIRED
	Game.changed.emit()
	var opens := {"card": func(): shop.call("open_card", Game.owned()[0]),
		"orders": Callable(shop, "open_orders"), "summary": Callable(shop, "end_day"),
		"stable": Callable(shop, "open_stable"), "market": Callable(shop, "open_market"),
		"expedition": Callable(shop, "open_expedition")}
```

(`Fixtures.adult` adds the creature to the state; `Game.retired()` then lists all 12.)

`git rm tests/test_ranch_map.gd tests/test_ranch_map.gd.uid` (it tests the removed `Ranch` layout).

- [ ] **Step 2: Run them to verify they fail**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_shop_scene.gd`
Expected: failures / script errors (`%TopBar`, `%ShopDoor`, `ShopBuilding` missing).

- [ ] **Step 3: Rewrite `shop.gd`**

`script_create` `res://shop/shop.gd` (overwrite):

```gdscript
extends Control
## The farm. The map is laid out in the editor; creatures are spawned into %Pens, the hanging %TopBar shows the
## state and its tags (and %ShopDoor, over the shop building) open popups in %PanelHost, each its own scene.

const TOAST_SECONDS := 2.5
const CARD := preload("res://shop/panels/creature_card.tscn")
const ORDERS := preload("res://shop/panels/orders_panel.tscn")
const SUMMARY := preload("res://shop/panels/day_summary.tscn")
const STABLE := preload("res://shop/panels/stable_panel.tscn")
const MARKET := preload("res://shop/panels/market_panel.tscn")
const EXPEDITION := preload("res://shop/panels/expedition_panel.tscn")

var _rng := RandomNumberGenerator.new()


## After `--`: `--save=<path>` uses that save file (for screenshots),
## `--open=card|orders|summary|stable|market|expedition` opens a popup, `--screenshot=<path>` saves a capture and
## quits. The same pattern as ui/gallery.gd. `--screenshot=` without `--save=` never touches the real save.
func _read_save_arg() -> void:
	var args := OS.get_cmdline_user_args()
	var has_save := false
	var has_screenshot := false
	for arg in args:
		if arg.begins_with("--save="):
			Game.save_path = arg.trim_prefix("--save=")
			has_save = true
		elif arg.begins_with("--screenshot="):
			has_screenshot = true
	if has_screenshot and not has_save:
		Game.save_path = "user://shot_save.json"


func _handle_cmdline() -> void:
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		match arg:
			"--open=card":
				if not Game.owned().is_empty():
					open_card(Game.owned()[0])
			"--open=orders":
				open_orders()
			"--open=summary":
				end_day()
			"--open=stable":
				open_stable()
			"--open=market":
				open_market()
			"--open=expedition":
				open_expedition()
		if arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
	if shot != "":
		await RenderingServer.frame_post_draw
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _ready() -> void:
	_rng.randomize()
	_read_save_arg()
	if Game.state == null:
		Game.start()
	Game.changed.connect(_refresh)
	%TopBar.orders_pressed.connect(open_orders)
	%TopBar.stable_pressed.connect(open_stable)
	%TopBar.expedition_pressed.connect(open_expedition)
	%TopBar.market_pressed.connect(open_market)
	%TopBar.end_day_pressed.connect(end_day)
	%ShopDoor.pressed.connect(open_orders)
	%Pens.creature_clicked.connect(open_card)
	_refresh()
	_handle_cmdline()


func _refresh() -> void:
	%TopBar.show_state(Game.state, Game.tier())
	%Pens.sync(Game.owned(), Game.db, _rng)


func open_card(c: CreatureData) -> void:
	var card := CARD.instantiate()
	%PanelHost.open(card)
	card.show_creature(c)


func open_orders() -> void:
	%PanelHost.open(ORDERS.instantiate())


func open_stable() -> void:
	var stable: StablePanel = STABLE.instantiate()
	%PanelHost.open(stable)
	stable.show_creatures(Game.retired())
	stable.creature_chosen.connect(open_card)


func open_market() -> void:
	%PanelHost.open(MARKET.instantiate())


func open_expedition() -> void:
	%PanelHost.open(EXPEDITION.instantiate())


func end_day() -> void:
	var day := Game.state.day
	var events := Game.end_day()
	var summary := SUMMARY.instantiate()
	%PanelHost.open(summary)
	summary.show_events(day, events)


func toast(msg: String) -> void:
	%Toast.text = msg
	get_tree().create_timer(TOAST_SECONDS).timeout.connect(func() -> void:
		if %Toast.text == msg:
			%Toast.text = "")
```

Confirm on disk (`git diff --stat shop/shop.gd`).

- [ ] **Step 4: Rebuild `shop.tscn` in the editor**

`scene_open` `res://shop/shop.tscn`, then `editor_manage` eval:

```gdscript
var root := EditorInterface.get_edited_scene_root()
for gone in ["Ranch", "Hud", "Counter", "MarketStall", "Door", "Stable"]:
	var n := root.get_node_or_null(gone)
	if n:
		root.remove_child(n)
		n.free()
var farm := (load("res://testing.tscn") as PackedScene).instantiate()
var copied := []
for pair in [["BaseMap", "BaseMap"], ["Shop", "ShopBuilding"], ["Pen", "Pen"]]:
	var n := farm.get_node(pair[0])
	farm.remove_child(n)
	n.name = pair[1]
	root.add_child(n)
	root.move_child(n, copied.size())
	copied.append(n)
	n.owner = root
	for d in n.find_children("*", "", true, false):
		d.owner = root
farm.free()
var building := root.get_node("ShopBuilding") as TileMapLayer
var used := building.get_used_rect()
var door := Button.new()
door.name = "ShopDoor"
door.flat = true
door.focus_mode = Control.FOCUS_NONE
door.position = building.to_global(building.map_to_local(used.position)) - Vector2(8, 8)
door.size = Vector2(used.size) * 16
root.add_child(door)
door.owner = root
door.unique_name_in_owner = true
var pen_rect := Rect2()
for layer: TileMapLayer in root.get_node("Pen").find_children("*", "TileMapLayer", true, false):
	var u := layer.get_used_rect()
	var px := Rect2(layer.to_global(layer.map_to_local(u.position)) - Vector2(8, 8), Vector2(u.size) * 16)
	pen_rect = px if pen_rect.size == Vector2.ZERO else pen_rect.merge(px)
var pens := root.get_node("%Pens") as Control
pens.position = pen_rect.position + Vector2(16, 16)
pens.size = pen_rect.size - Vector2(32, 32)
var bar: Control = (load("res://ui/top_bar.tscn") as PackedScene).instantiate()
root.add_child(bar)
bar.owner = root
bar.unique_name_in_owner = true
var order := ["BaseMap", "ShopBuilding", "Pen", "Pens", "ShopDoor", "TopBar", "Toast", "PanelHost"]
for i in order.size():
	root.move_child(root.get_node(order[i]), i)
var host := root.get_node("%PanelHost") as Control
host.position = Vector2(0, 40)
host.size = Vector2(640, 320)
return "door %s pens %s pen %s children %s" % [door.get_rect(), pens.get_rect(), pen_rect, root.get_children().map(func(c): return c.name)]
```

Read the returned rects: `ShopDoor` must cover the building, `Pens` must sit inside the fence (one tile in from the
pen's outer bounds). If the pen's layers include decoration far outside the fence, set `Pens` in the editor to the
dirt interior instead. Then `scene_save`, `git status --short` (expected: `shop/shop.tscn` modified; `testing.tscn`
unchanged — restore it if not), and `editor_screenshot` (`viewport_2d`).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_shop_scene.gd` → `0 failed`.
Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_panel_fit.gd` → `0 failed`.
Run the full suite → `0 failed` (expect `test_sprout_art` to pass: every `art/sprout` path in `shop.tscn` came from
`testing.tscn` and is listed since Task 1).

- [ ] **Step 6: Screenshots**

```bash
$GODOT --path . -- --screenshot=<scratchpad>/farm.png
$GODOT --path . -- --screenshot=<scratchpad>/farm_orders.png --open=orders
$GODOT --path . -- --screenshot=<scratchpad>/farm_stable.png --open=stable
$GODOT --path . -- --screenshot=<scratchpad>/farm_market.png --open=market
$GODOT --path . -- --screenshot=<scratchpad>/farm_expedition.png --open=expedition
$GODOT --path . -- --screenshot=<scratchpad>/farm_card.png --open=card
```

Look at each: the rope bar runs off both edges, the stats are readable on the strip, the tags hang from the rope,
creatures are inside the pen, popups centre on the dimmed farm below the bar. Layout fixes happen in the editor
(`ui/top_bar.tscn`, `shop.tscn`), then re-run Step 5.

- [ ] **Step 7: Commit**

```bash
git add shop/shop.gd shop/shop.tscn tests/test_shop_scene.gd tests/test_panel_fit.gd
git commit -m "Make the farm map the main scene with the hanging top bar and popups"
```

(`git rm` in Step 1 already staged the ranch map test removal.)

---

### Task 6: Remove the old ranch pieces and update the docs

**Files:**
- Delete: `ranch/ranch_tileset.tres`, `addons/sprout_tools/ranch_terrains.gd(.uid)`, `tests/test_ranch_terrains.gd(.uid)`,
  `tests/test_ranch_tileset.gd(.uid)`, `ranch/art/orders_counter.png(.import)`, `ranch/art/market_counter.png(.import)`
- Modify: `addons/sprout_tools/plugin.gd`, `creatures/variants_review.gd`, `README.md`, `CLAUDE.md`,
  `asset-pipeline/README.md`, `tests/test_variants_review.gd` (only if it names the ranch TileSet)

**Interfaces:**
- Consumes: `res://ranch/ground_tileset.tres` source 2 grass centre `(1, 1)` (Task 1).

- [ ] **Step 1: Prove nothing else uses them**

```bash
grep -rn "ranch_tileset\|ranch_terrains\|ranch/art/\|RanchTerrains" --include=*.gd --include=*.tscn --include=*.tres --include=*.cfg --include=*.md . | grep -v "^./.godot\|docs/superpowers\|.superpowers"
```

Expected hits only in: `addons/sprout_tools/plugin.gd`, `creatures/variants_review.gd`, the two ranch tests,
`README.md`, `CLAUDE.md`, `asset-pipeline/README.md`. Anything else: stop and keep that file.

- [ ] **Step 2: Point the variants review at the ground TileSet (test first)**

The review scene's grass now comes from the ground TileSet. Run
`$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_variants_review.gd` → passes (baseline).
In `creatures/variants_review.gd` patch (single-line anchors, confirm with `git diff`):
- `const TILESET_PATH := "res://ranch/ranch_tileset.tres"` → `const TILESET_PATH := "res://ranch/ground_tileset.tres"`
- `const GRASS := Vector2i(1, 1)  ## ranch TileSet source 0 (Grass_tiles_v2.png): plain grass centre tile` →
  `const GRASS := Vector2i(1, 1)  ## ground TileSet source GRASS_SOURCE (Grass_tiles_v2.png): plain grass centre tile`
  and add below it `const GRASS_SOURCE := 2`
- `			ground.set_cell(Vector2i(x, y), 0, GRASS)` → `			ground.set_cell(Vector2i(x, y), GRASS_SOURCE, GRASS)`

Add to `tests/test_variants_review.gd`:

```gdscript
func test_ground_is_grass_from_the_ground_tileset() -> void:
	var r := _open()
	await tree.process_frame
	var ground := r.get_node_or_null("Ground") as TileMapLayer
	check(ground != null and ground.tile_set.resource_path == "res://ranch/ground_tileset.tres", "ground TileSet")
	if ground:
		eq(ground.get_cell_source_id(Vector2i(0, 0)), 2, "grass source")
	r.queue_free()
```

Run it → PASS (write it before the patch to see it fail on the TileSet path).

- [ ] **Step 3: Remove the terrain tool from the plugin**

In `addons/sprout_tools/plugin.gd` remove the lines `const Terrains := preload(...)`, `const TERRAIN_MENU := ...`,
`const TILESET := ...`, `	add_tool_menu_item(TERRAIN_MENU, _set_up_terrains)`,
`	remove_tool_menu_item(TERRAIN_MENU)` and the whole `func _set_up_terrains() -> void:` function; update the header
comment to list only "Sprout Lands: Sync pack files". Use `script_create` to rewrite the file (it is short), then
reload the plugin: `editor_manage` eval
`EditorInterface.set_plugin_enabled("sprout_tools", false); EditorInterface.set_plugin_enabled("sprout_tools", true); return "ok"`.

- [ ] **Step 4: Delete the files and update the docs**

```bash
git rm ranch/ranch_tileset.tres addons/sprout_tools/ranch_terrains.gd addons/sprout_tools/ranch_terrains.gd.uid tests/test_ranch_terrains.gd tests/test_ranch_terrains.gd.uid tests/test_ranch_tileset.gd tests/test_ranch_tileset.gd.uid ranch/art/orders_counter.png ranch/art/orders_counter.png.import ranch/art/market_counter.png ranch/art/market_counter.png.import
```

Then `EditorInterface.get_resource_filesystem().scan()` via eval.
- `CLAUDE.md`: replace the `ranch/ranch_tileset.tres` bullet with: "`ranch/ground_tileset.tres` is the ground TileSet
  (one terrain per Sprout ground sheet, set up in the TileSet editor). The main scene `shop/shop.tscn` is the farm map
  (built in `testing.tscn`, the owner's sandbox) with `ui/top_bar.tscn` hanging at the top; every action opens a popup
  scene from `shop/panels/` in `%PanelHost`."
- `README.md`: replace the ranch section (the lines about `Ranch` under `shop/shop.tscn`, `ranch_tileset.tres` and
  `RanchTerrains.new_tileset()`) with the same three facts.
- `asset-pipeline/README.md`: change the "Props used in the game are copied by hand ... into ranch/art/" line to
  "Props used in the game are copied by hand from assets/prop/ into the project (committed; our own art)."

- [ ] **Step 5: Full verification**

- `$GODOT --headless --path . -s res://tests/run_tests.gd` → `0 failed`.
- `$GODOT --path . -s res://tests/run_tests.gd -- --only=test_sprout_palette.gd` → `0 failed` (windowed render check).
- `$GODOT --path . res://creatures/variants_review.tscn -- --screenshot=<scratchpad>/variants_after.png --scroll=0`:
  grass still under the groups.
- `scene_open res://shop/shop.tscn` + `editor_screenshot` (viewport_2d): the farm with the bar.
- `git status --short`: only the owner's files (`creatures/frames/*.tres`, `project.godot`, `testing.tscn` if the dock
  touched it) remain modified.

- [ ] **Step 6: Commit**

```bash
git add addons/sprout_tools/plugin.gd creatures/variants_review.gd tests/test_variants_review.gd README.md CLAUDE.md asset-pipeline/README.md
git commit -m "Remove the old ranch TileSet, terrain tool and counter art"
```
