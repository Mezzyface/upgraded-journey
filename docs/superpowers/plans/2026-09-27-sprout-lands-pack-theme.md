# Sprout Lands: packs, theme and pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Sprout Lands packs into the project through our own sync tool, make a Sprout Lands theme the
project theme at a 640×360 pixel grid, point the asset pipeline at Sprout Lands (references + palette lock), and run
a throwaway creature-restyle experiment.

**Architecture:** Licensed packs live extracted in `asset-pipeline/sprout-lands/` (git-ignored). An `EditorPlugin`
copies the handful of files resources use into `art/sprout/` (art git-ignored, `.import` files committed). The theme
starts as a one-time copy of Maaack's `sprout_lands_theme.tres` and is then owned by the Theme editor. The Python
pipeline gains a `palette` field that makes `refine.lua` remap to the Sprout palette PNG.

**Tech Stack:** Godot 4.7.2 (GDScript, godot-ai MCP), Python 3.12 + Pillow, Aseprite 1.3 batch Lua, `agy` CLI.

**Spec:** `docs/superpowers/specs/2026-09-27-sprout-lands-pack-theme-design.md`

## Global Constraints

- Pack art (PNG/TTF/WAV/zips) is never committed. `.import` files under `art/sprout/` are committed.
- Maaack's addons are never copied into `addons/` or enabled; they are reference only.
- Godot changes go through the editor via the godot-ai MCP while the editor is open (`CLAUDE.md`). Text edits to
  `.tscn/.tres` only when the MCP is unavailable, followed by `$GODOT --headless --path . --import` with no errors.
- Viewport 640×360, window override 1280×720, stretch `canvas_items`, nearest filter, snap 2D transforms to pixel.
- Theme variation names stay exactly: `DecoratedButton`, `HeaderLabel`, `BannerLabel`, `OnDarkLabel`, `FlatPanel`,
  `BarPanel`, `InsetPanel`, `InventorySlot`, `InventorySlotSelected`, `NamePlate`, `PackScrollBar`, `TooltipLabel`,
  `TooltipPanel`.
- Palette PNG: `asset-pipeline/sprout-lands/Sprout Lands - Sprites - premium pack/Sprout Lands color pallet/Sprout Lands defautlt palette.png`
  (about 99 colours; the filler cell colour `#713970` is one of them).
- Commit messages: plain, **no `Co-Authored-By` trailer** (owner rule for this repo).
- `GODOT` below means `"C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`.
  Tests: `$GODOT --headless --path . -s res://tests/run_tests.gd`. Pipeline tests: `python asset-pipeline/test_gen.py`.
- Shots go to the session scratchpad, e.g. `$SHOTS=C:/Users/ozark/AppData/Local/Temp/claude/C--upgraded-journey/<session>/scratchpad`.

## Review Focus

1. **Fresh clone, packs not extracted** — Sync must name every missing source in one error, not half-copy silently
   (test in Task 2).
2. **Theme uses a texture the sync list doesn't copy** — a fresh clone would render blank boxes; every texture/font the
   theme references must be under `res://art/sprout/` and listed in `SproutSync.FILES` (test in Task 3, re-run in 4).
3. **UIDs/import settings lost on clone** — `.import` files must be tracked while the art is ignored, or the theme's
   `uid://` refs break and the pixel font imports antialiased (git check in Task 1).
4. **Palette remap eats outline pixels** — near-black opaque pixels must never map to the transparent index; the opaque
   pixel count must be unchanged by the remap (runtime WARN + Aseprite-gated test in Task 7).
5. **Panels overflow the 640×360 screen** — every panel opened by the shop must fit inside the viewport (test in Task 5).

---

### Task 1: Move the packs and set up ignores

**Files:**
- Move: `sprout-lands/*` → `asset-pipeline/sprout-lands/`
- Modify: `.gitignore`

- [ ] **Step 1: Move and extract**

```powershell
New-Item -ItemType Directory -Force asset-pipeline/sprout-lands | Out-Null
Move-Item sprout-lands/* asset-pipeline/sprout-lands/
Remove-Item sprout-lands
```

```bash
cd asset-pipeline/sprout-lands && python - <<'PY'
import glob, zipfile
for z in glob.glob("*.zip"):
    zipfile.ZipFile(z).extractall(".")   # each zip has its own top folder
    print("extracted", z)
PY
```

Expected: folders `Sprout Lands - Sprites - premium pack/`, `Sprout Lands - Sprites - Basic pack/`,
`Sprout Lands - UI Pack - Premium pack/`, `Sprout Lands - UI Pack - Basic pack/`, `Sprout Sorry pack/`, `Fonts/`,
`Sprout-Lands-Tilemap-0.2.0/`, `Sprout-Lands-UI-0.2.0/`.

- [ ] **Step 2: Ignore rules** — append to `.gitignore`:

```gitignore
asset-pipeline/sprout-lands/
# Sprout Lands art copied by Project > Tools > Sprout Lands: Sync pack files (licensed). Keep the .import files so
# UIDs and import settings (pixel font without antialiasing) survive a fresh clone.
art/sprout/**
!art/sprout/**/
!art/sprout/**/*.import
```

- [ ] **Step 3: Verify the rules**

Run: `git check-ignore -v art/sprout/ui/a.png asset-pipeline/sprout-lands/x.zip; git check-ignore art/sprout/ui/a.png.import; echo "exit=$?"`
Expected: the first two print matching rules; the `.import` line prints nothing and `exit=1` (not ignored).
Run: `git status --short` — expected: only `.gitignore` modified; no `sprout-lands/` entry.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "Ignore the Sprout Lands packs and synced art, keep their import files"
```

---

### Task 2: Sprout Lands sync tool

**Files:**
- Create: `addons/sprout_tools/plugin.cfg`, `addons/sprout_tools/plugin.gd`, `addons/sprout_tools/sprout_sync.gd`,
  `addons/sprout_tools/sync_cli.gd`
- Modify: `project.godot` (`[editor_plugins] enabled`) — via the editor's Project Settings > Plugins
- Test: `tests/test_sprout_sync.gd`

**Interfaces:**
- Produces: `SproutSync` script (preload path `res://addons/sprout_tools/sprout_sync.gd`) with
  `const SRC := "res://asset-pipeline/sprout-lands"`, `const DST := "res://art/sprout"`,
  `const FILES: Dictionary` (destination relative to DST → source relative to SRC),
  `static func sync(src := SRC, dst := DST) -> PackedStringArray` (returns missing source paths; empty = all copied).

- [ ] **Step 1: Write the failing test** — `tests/test_sprout_sync.gd`:

```gdscript
extends TestSuite

const Sync := preload("res://addons/sprout_tools/sprout_sync.gd")
const SRC := "user://sprout_src"
const DST := "user://sprout_dst"


func test_copies_listed_files_and_reports_every_missing_one() -> void:
	var first: String = Sync.FILES.keys()[0]
	var src_file := ProjectSettings.globalize_path(SRC).path_join(Sync.FILES[first])
	DirAccess.make_dir_recursive_absolute(src_file.get_base_dir())
	var f := FileAccess.open(src_file, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	var missing := Sync.sync(SRC, DST)
	check(FileAccess.file_exists(ProjectSettings.globalize_path(DST).path_join(first)), "listed file copied")
	eq(missing.size(), Sync.FILES.size() - 1, "every other source reported")
	check(not missing.has(Sync.FILES[first]), "the present source is not reported")


func test_list_only_names_pack_art() -> void:
	for dst in Sync.FILES:
		check(dst.get_extension() in ["png", "ttf", "wav"], "pack art only, never resources: %s" % dst)
```

- [ ] **Step 2: Run to verify it fails**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_sprout_sync.gd  does not compile` (the preload is missing).

- [ ] **Step 3: Implement** — `addons/sprout_tools/sprout_sync.gd`:

```gdscript
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


## Returns the source paths that were missing; empty means everything was copied.
static func sync(src := SRC, dst := DST) -> PackedStringArray:
	var missing := PackedStringArray()
	for rel in FILES:
		var from := ProjectSettings.globalize_path(src.path_join(FILES[rel]))
		var to := ProjectSettings.globalize_path(dst.path_join(rel))
		if not FileAccess.file_exists(from):
			missing.append(FILES[rel])
			continue
		DirAccess.make_dir_recursive_absolute(to.get_base_dir())
		DirAccess.copy_absolute(from, to)
	return missing
```

`addons/sprout_tools/plugin.gd`:

```gdscript
@tool
extends EditorPlugin
## Project > Tools > "Sprout Lands: Sync pack files". Only copies pack art; never touches editor-edited resources.

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
		push_error("[sprout_tools] missing in %s (extract the zips there first):\n%s" % [Sync.SRC, "\n".join(missing)])
```

`addons/sprout_tools/sync_cli.gd` (headless equivalent for fresh clones and agents):

```gdscript
extends SceneTree
## godot --headless --path . -s res://addons/sprout_tools/sync_cli.gd   (then run --import once)

func _initialize() -> void:
	var missing: PackedStringArray = preload("res://addons/sprout_tools/sprout_sync.gd").sync()
	for m in missing:
		printerr("missing: ", m)
	quit(1 if missing.size() > 0 else 0)
```

`addons/sprout_tools/plugin.cfg`:

```ini
[plugin]

name="Sprout Lands Tools"
description="Tools menu: copy the Sprout Lands pack files the project uses into art/sprout."
author="Upgraded Journey"
version="1.0"
script="plugin.gd"
```

- [ ] **Step 4: Run the tests** — Expected: `0 failed` (count includes the 2 new tests).

- [ ] **Step 5: Enable the plugin and sync** — in the open editor (godot-ai `plugin_manage` enable
  `res://addons/sprout_tools/plugin.cfg`, or Project Settings > Plugins), then run **Project > Tools > Sprout Lands:
  Sync pack files** (or `$GODOT --headless --path . -s res://addons/sprout_tools/sync_cli.gd` then
  `$GODOT --headless --path . --import`).
  Expected: `[sprout_tools] synced 4 files into res://art/sprout`; `art/sprout/**/*.import` files exist.

- [ ] **Step 6: Font import settings** — select `art/sprout/fonts/pixelFont-7-8x14-sproutLands.ttf` in the FileSystem
  dock, Import dock: Antialiasing **None**, Hinting **None**, Subpixel Positioning **Disabled**, Generate Mipmaps off,
  Multichannel SDF off → Reimport. Check the `.import` file contains `antialiasing=0`.

- [ ] **Step 7: Commit**

```bash
git add addons/sprout_tools tests/test_sprout_sync.gd project.godot art/sprout
git status --short   # expected: only .import files under art/sprout, no png/ttf
git commit -m "Add the Sprout Lands sync tool"
```

---

### Task 3: Sprout Lands theme, 640×360 grid and cursor

**Files:**
- Create: `ui/theme/sprout_lands.tres` (one-time copy of Maaack's theme, then editor-owned)
- Modify: `project.godot` (display, rendering, gui theme, cursor) — via Project Settings in the editor
- Test: `tests/test_theme.gd`

**Interfaces:**
- Consumes: `SproutSync.FILES`, `SproutSync.DST` (Task 2).
- Produces: `res://ui/theme/sprout_lands.tres` as `gui/theme/custom`; `tests/test_theme.gd` with `const VARIATIONS`
  (extended in Task 4) and helper `_theme_resource_paths(theme) -> PackedStringArray`.

- [ ] **Step 1: Write the failing test** — `tests/test_theme.gd`:

```gdscript
extends TestSuite

const Sync := preload("res://addons/sprout_tools/sprout_sync.gd")
const THEME := "res://ui/theme/sprout_lands.tres"


func test_project_uses_the_sprout_theme_on_a_640x360_grid() -> void:
	eq(ProjectSettings.get_setting("gui/theme/custom"), THEME, "project theme")
	eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640, "viewport width")
	eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360, "viewport height")
	eq(ProjectSettings.get_setting("display/window/size/window_width_override"), 1280, "window width")
	eq(ProjectSettings.get_setting("display/window/size/window_height_override"), 720, "window height")
	eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "stretch mode")
	check(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"), "pixel snap")


## Everything the theme draws with must come from art/sprout and be in the sync list, or a fresh clone breaks.
func test_theme_art_is_all_synced() -> void:
	var theme: Theme = load(THEME)
	var paths := _theme_resource_paths(theme)
	check(paths.size() > 0, "theme references some art")
	check(theme.default_font != null, "default font set")
	for p in paths:
		check(p.begins_with(Sync.DST + "/"), "under art/sprout: %s" % p)
		check(Sync.FILES.has(p.trim_prefix(Sync.DST + "/")), "in SproutSync.FILES: %s" % p)
		check(FileAccess.file_exists(p), "synced (run Sprout Lands: Sync pack files): %s" % p)


func _theme_resource_paths(theme: Theme) -> PackedStringArray:
	var out := PackedStringArray()
	var add := func(r: Resource) -> void:
		if r is AtlasTexture:
			r = r.atlas
		if r is StyleBoxTexture:
			r = r.texture
		if r != null and r.resource_path != "" and not out.has(r.resource_path):
			out.append(r.resource_path)
	if theme.default_font:
		add.call(theme.default_font)
	for type in theme.get_type_list():
		for n in theme.get_stylebox_list(type):
			add.call(theme.get_stylebox(n, type))
		for n in theme.get_icon_list(type):
			add.call(theme.get_icon(n, type))
		for n in theme.get_font_list(type):
			add.call(theme.get_font(n, type))
	return out
```

- [ ] **Step 2: Run to verify it fails** — Expected: `FAIL test_theme.gd::test_project_uses_the_sprout_theme_on_a_640x360_grid  project theme: expected res://ui/theme/sprout_lands.tres, got res://ui/theme/isle_of_lore.tres` (and viewport lines), and a load failure for the missing theme.

- [ ] **Step 3: One-time copy of Maaack's theme** (a copy, not a generator; after this the editor owns the file):

```bash
python - <<'PY'
src = "asset-pipeline/sprout-lands/Sprout-Lands-UI-0.2.0/addons/sprout_lands_ui/content/sprout_lands_theme.tres"
t = open(src, encoding="utf-8").read()
t = t.replace("res://addons/sprout_lands_ui/content/assets/", "res://art/sprout/ui/")
import re
t = re.sub(r' uid="uid://[0-9a-z]+"', "", t)                       # let the editor assign fresh uids
t = "\n".join(l for l in t.splitlines() if not l.startswith("SkipButton/")) + "\n"  # unused type
open("ui/theme/sprout_lands.tres", "w", encoding="utf-8", newline="\n").write(t)
PY
```

Then in the editor open `ui/theme/sprout_lands.tres` and save it once (the editor drops the orphaned SkipButton
styleboxes and writes uids). Run `$GODOT --headless --path . --import` — expected: no errors mentioning `sprout_lands`.

- [ ] **Step 4: Default font** — in the Theme editor (godot-ai `theme_manage`): Default Font =
  `res://art/sprout/fonts/pixelFont-7-8x14-sproutLands.ttf`. Pick Default Font Size: add a temporary Label to
  `ui/gallery.tscn` with text `The quick brown fox 0123`, set sizes 14, 16, 28 and 32 in turn, `editor_screenshot` each
  at 100% zoom; choose the smallest size whose glyphs have uniform 1-px strokes (no half-pixel blur). Remove the label.
  Record the chosen size in the theme (`default_font_size`).

- [ ] **Step 5: Project settings** (Project Settings dialog / godot-ai `project_manage`):
  `display/window/size/viewport_width=640`, `viewport_height=360`, `window_width_override=1280`,
  `window_height_override=720`, `display/window/stretch/mode="canvas_items"` (already), 
  `rendering/2d/snap/snap_2d_transforms_to_pixel=true`, `gui/theme/custom="res://ui/theme/sprout_lands.tres"`,
  `display/mouse_cursor/custom_image="res://art/sprout/ui/Catpaw Mouse icon.png"`,
  `display/mouse_cursor/custom_image_hotspot=Vector2(2, 2)`. Keep `default_texture_filter=0`.
  Note: the cursor PNG is in `SproutSync.FILES` already.

- [ ] **Step 6: Run the tests** — Expected: `test_theme.gd` passes. Other suites may show layout-independent passes;
  any failure is a real regression — fix before continuing.

- [ ] **Step 7: Screenshot** — `$GODOT --path . res://ui/gallery.tscn -- --screenshot=$SHOTS/gallery_t3.png`; read it.
  Expected: Sprout Lands buttons/panels on core controls, crisp pixel font; variations still look unstyled (Task 4).

- [ ] **Step 8: Commit**

```bash
git add ui/theme/sprout_lands.tres project.godot tests/test_theme.gd art/sprout
git commit -m "Switch to the Sprout Lands theme on a 640x360 pixel grid"
```

---

### Task 4: Theme variations in Sprout Lands art

**Files:**
- Modify: `ui/theme/sprout_lands.tres` (Theme editor / godot-ai `theme_manage`)
- Test: `tests/test_theme.gd`

**Interfaces:**
- Consumes: `tests/test_theme.gd::_theme_resource_paths` (Task 3).
- Produces: the 13 variations (names in Global Constraints) in the project theme.

All regions below are on `res://art/sprout/ui/Sprite sheet for Basic Pack.png` (896×240), measured from the sheet's
opaque bounds. Every stylebox is a `StyleBoxTexture` with `axis_stretch` = Stretch unless noted. Ink colours are Sprout
palette entries: `INK = Color8(100, 85, 82)` (#645552), `LIGHT = Color8(243, 244, 231)` (#f3f4e7).

- [ ] **Step 1: Extend the failing test** — add to `tests/test_theme.gd`:

```gdscript
const VARIATIONS := {
	"DecoratedButton": &"Button", "HeaderLabel": &"Label", "BannerLabel": &"Label", "OnDarkLabel": &"Label",
	"FlatPanel": &"PanelContainer", "BarPanel": &"PanelContainer", "InsetPanel": &"PanelContainer",
	"InventorySlot": &"PanelContainer", "InventorySlotSelected": &"PanelContainer", "NamePlate": &"PanelContainer",
	"PackScrollBar": &"VSlider", "TooltipLabel": &"Label", "TooltipPanel": &"PanelContainer",
}


func test_variations_keep_their_names_and_bases() -> void:
	var theme: Theme = load(THEME)
	for v in VARIATIONS:
		eq(theme.get_type_variation_base(v), VARIATIONS[v], "%s base" % v)
	for v in ["FlatPanel", "BarPanel", "InsetPanel", "InventorySlot", "InventorySlotSelected", "NamePlate", "TooltipPanel"]:
		check(theme.get_stylebox("panel", v) is StyleBoxTexture, "%s has a Sprout panel" % v)
	check(theme.get_stylebox("normal", "DecoratedButton") is StyleBoxTexture, "DecoratedButton normal")
	check(theme.get_icon("grabber", "PackScrollBar") != null, "PackScrollBar grabber")
```

- [ ] **Step 2: Run to verify it fails** — Expected: `DecoratedButton base: expected Button, got ` (empty) etc.

- [ ] **Step 3: Panels** (each `panel` stylebox; content margins in brackets):

| Variation | region | texture margins l,t,r,b | content margins |
|---|---|---|---|
| FlatPanel | `Rect2(11, 59, 26, 28)` cream plate | 6, 6, 6, 8 | 8, 6, 8, 8 |
| BarPanel | `Rect2(11, 107, 26, 28)` tan plate | 6, 6, 6, 8 | 8, 4, 8, 6 |
| InsetPanel | `Rect2(59, 107, 26, 26)` pressed tan | 6, 6, 6, 6 | 6, 6, 6, 6 |
| InventorySlot | `Rect2(153, 9, 30, 30)` wood frame, light | 8, 8, 8, 8 | 4, 4, 4, 4 |
| InventorySlotSelected | `Rect2(153, 105, 30, 30)` wood frame, dark | 8, 8, 8, 8 | 4, 4, 4, 4 |
| NamePlate | `Rect2(434, 71, 28, 18)` small plate | 6, 6, 6, 6 | 6, 2, 6, 3 |
| TooltipPanel | `Rect2(11, 11, 26, 28)` white plate | 6, 6, 6, 8 | 4, 2, 4, 4 |

Also set `PanelContainer/styles/panel` = the FlatPanel stylebox (panels without a variation look Sprout too).

- [ ] **Step 4: Buttons** — `DecoratedButton` (base Button): normal/hover/focus = `Rect2(163, 178, 90, 27)`,
  pressed = `Rect2(259, 180, 90, 25)`, disabled = normal with `modulate_color = Color(1,1,1,0.5)`; texture margins
  8, 8, 8, 9; content margins 10, 4, 10, 6; `font_color = INK`, `font_pressed_color = INK`, `font_hover_color = INK`.

- [ ] **Step 5: Labels** — `HeaderLabel`: font_color INK, font size = 2× default size if that stays under 1/10 of the
  screen height, else default size. `BannerLabel`: `normal` stylebox = the DecoratedButton normal stylebox, font_color
  INK, same size as HeaderLabel. `OnDarkLabel`: font_color LIGHT. `TooltipLabel`: font_color INK.

- [ ] **Step 6: PackScrollBar** (base VSlider): `slider` = `Rect2(326, 133, 4, 38)` texture margins 0, 4, 0, 4;
  icons `grabber` = AtlasTexture `Rect2(247, 132, 18, 8)`, `grabber_highlight` = AtlasTexture `Rect2(247, 148, 18, 8)`,
  `grabber_disabled` = AtlasTexture `Rect2(247, 164, 18, 8)`; `grabber_area` / `grabber_area_highlight` = StyleBoxEmpty.

- [ ] **Step 7: Run the tests** — Expected: `test_theme.gd` 3 tests pass, all suites `0 failed`.

- [ ] **Step 8: Screenshot the gallery** (`--screenshot=$SHOTS/gallery_t4.png`, and `--scroll=600` for the lower
  half) and read both. Expected: every variation drawn with Sprout art, 9-patch corners not stretched, text readable.
  If a corner smears, raise that stylebox's texture margins by 1–2 px and re-shoot.

- [ ] **Step 9: Commit**

```bash
git add ui/theme/sprout_lands.tres tests/test_theme.gd
git commit -m "Redraw the theme variations with Sprout Lands art"
```

---

### Task 5: Relayout for 640×360

**Files:**
- Modify (editor, godot-ai `node_set_property`): `shop/shop.tscn`, `shop/panels/creature_card.tscn`,
  `shop/panels/orders_panel.tscn`, `shop/panels/day_summary.tscn`, `ui/gallery.tscn`
- Test: `tests/test_panel_fit.gd`

**Interfaces:**
- Consumes: shop API `open_card(c: CreatureData)`, `open_orders()`, `end_day()`, `%PanelHost.current() -> Control`;
  test setup as in `tests/test_shop_scene.gd` (`Game.save_path`, `Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)`).

- [ ] **Step 1: Write the failing test** — `tests/test_panel_fit.gd`:

```gdscript
extends TestSuite
## Every panel the shop opens must fit on the 640x360 screen.

const SAVE := "user://test_panel_fit_save.json"


func test_every_panel_fits_on_screen() -> void:
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)
	var shop: Control = load("res://shop/shop.tscn").instantiate()
	tree.root.add_child(shop)
	await tree.process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(640, 360))
	var opens := {"card": func(): shop.call("open_card", Game.owned()[0]),
		"orders": Callable(shop, "open_orders"), "summary": Callable(shop, "end_day")}
	for name in opens:
		opens[name].call()
		await tree.process_frame
		var panel: Control = shop.get_node("%PanelHost").current()
		check(panel != null, "%s opened" % name)
		if panel:
			check(screen.encloses(panel.get_global_rect()), "%s fits: %s" % [name, panel.get_global_rect()])
	shop.queue_free()
	DirAccess.remove_absolute(SAVE)
```

- [ ] **Step 2: Run to verify it fails** — Expected: `card fits: [P: (…), S: (620, 460)]`-style failures
  (panels still sized for 1280×720).

- [ ] **Step 3: Panels** — halve every size: `custom_minimum_size` CreatureCard `(310, 230)`, OrdersPanel `(380, 280)`,
  DaySummary `(280, 210)`, Portrait `(48, 48)`; each `Margin` container's margin constants halved (e.g. 24 → 12);
  remove per-node `theme_override_font_sizes` (the theme sizes now apply). If a panel's content then overflows
  (combined minimum > the numbers above), reduce separations before shrinking text.

- [ ] **Step 4: Shop** (kept working until sub-project 2 rebuilds it) — halve every `offset_*`: HUD bottom 32;
  Counter `230, 221, 358, 301`; MarketStall `492, 45, 620, 125`; PenFrame `20, 115, 320, 340`; Pens
  `110, 126, -130, -94`; StableFrame `330, 115, 520, 340`; Stable `60, 125, -70, -92`; Door `540, 165, 620, 325`;
  Toast top/bottom `-24, -14`; PanelHost `95, 40, 545, 350`. `sprite_scale` on Pens and Stable `2.6 → 1.3`.
  Texture nodes keep `expand_mode`/stretch so the art scales with its rect.

- [ ] **Step 5: Gallery** — halve offsets/min sizes the same way. Replace the Isle of Lore textures:
  round `TextureButton` normal/pressed → AtlasTextures on the Basic sheet `Rect2(311, 5, 18, 20)` /
  `Rect2(343, 6, 18, 19)`; portrait → `res://art/sprout/ui/backdrops_a1.png`; the three heart TextureRects →
  AtlasTextures on the Basic sheet picked in the region editor (hearts column right of the round buttons, grid snap
  on, full/half/empty), confirmed by screenshot. After this the gallery has no `res://ui/theme/pack/` ext_resource.

- [ ] **Step 6: Run the tests** — Expected: all suites `0 failed`, including `test_panel_fit.gd`.

- [ ] **Step 7: Screenshots** — read each:
  `$GODOT --path . -- --screenshot=$SHOTS/shop.png`, and with `--open=card`, `--open=orders`, `--open=summary`;
  gallery top and `--scroll=300`. Expected: nothing cut off, pixel-crisp, readable.

- [ ] **Step 8: Commit**

```bash
git add shop ui/gallery.tscn tests/test_panel_fit.gd
git commit -m "Lay out the shop, panels and gallery for 640x360"
```

---

### Task 6: Remove Isle of Lore, update docs

**Files:**
- Delete: `ui/theme/isle_of_lore.tres`, `addons/iol_theme/`
- Modify: `project.godot` (disable iol_theme plugin via Project Settings > Plugins first), `.gitignore`
  (drop `ui/theme/pack/`), `README.md`, `CLAUDE.md`
- Test: `tests/test_theme.gd`

- [ ] **Step 1: Write the failing test** — add to `tests/test_theme.gd`:

```gdscript
func test_nothing_references_isle_of_lore() -> void:
	for path in _project_text_files("res://"):
		var text := FileAccess.get_file_as_string(path)
		check(not text.contains("ui/theme/pack/") and not text.contains("isle_of_lore"), "still referenced in %s" % path)


func _project_text_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d not in ["addons", "asset-pipeline", "docs", "tests"]:
			out.append_array(_project_text_files(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["tscn", "tres", "godot", "gd"]:
			out.append(dir.path_join(f))
	return out
```

- [ ] **Step 2: Run to verify it fails** — Expected: `still referenced in res://ui/theme/isle_of_lore.tres` and
  `res://project.godot` (plugin list).

- [ ] **Step 3: Remove** — disable "Isle of Lore Theme Tools" in Project Settings > Plugins, then:

```bash
git rm -r addons/iol_theme ui/theme/isle_of_lore.tres
```

Remove the `ui/theme/pack/` line from `.gitignore`. Leave the local `ui/theme/pack/` and `asset-pipeline/ui-pack/`
folders on disk (owner's call).

- [ ] **Step 4: Docs** — `README.md`: replace the "UI theme (Isle of Lore 2 UI Pack)" section with:

```markdown
## UI theme (Sprout Lands)

`ui/theme/sprout_lands.tres` is the project theme (`gui/theme/custom`); edit it in the Theme editor. The game renders
on a 640×360 pixel grid (`canvas_items` stretch, window 1280×720). Pack art is licensed and git-ignored:

1. Put the Sprout Lands zips in `asset-pipeline/sprout-lands/` and extract each one there.
2. **Project > Tools > Sprout Lands: Sync pack files** copies the files the project uses into `art/sprout/`
   (headless: `godot --headless --path . -s res://addons/sprout_tools/sync_cli.gd`, then `--import`).

The `.import` files under `art/sprout/` are committed so UIDs and the pixel-font import settings survive a clone. Add a
line to `FILES` in `addons/sprout_tools/sprout_sync.gd` whenever a scene or resource starts using another pack file.
Maaack's Sprout-Lands-Tilemap/UI addons in the pack folder are reference only; never enable them.

Type variations: `DecoratedButton`, `HeaderLabel`, `BannerLabel`, `OnDarkLabel`, `FlatPanel`, `BarPanel`, `InsetPanel`,
`InventorySlot`, `InventorySlotSelected`, `NamePlate`, `PackScrollBar`, `TooltipLabel`, `TooltipPanel`.
```

Keep the scrollbar paragraph. In the tests paragraph replace "the UI pack sync, above" with "the Sprout Lands sync,
above". In `CLAUDE.md` replace the `isle_of_lore.tres` bullet with:

```markdown
- `ui/theme/sprout_lands.tres` is the project theme (`gui/theme/custom`), on a 640×360 pixel grid. Edit it in the
  Theme editor. `Project > Tools > Sprout Lands: Sync pack files` copies the pack art it uses from
  `asset-pipeline/sprout-lands/` (git-ignored, licensed) into `art/sprout/` (art ignored, `.import` files committed).
```

- [ ] **Step 5: Run the tests and a clean import** — tests `0 failed`; `$GODOT --headless --path . --import` no errors.

- [ ] **Step 6: Commit**

```bash
git add -A .gitignore README.md CLAUDE.md project.godot tests/test_theme.gd
git commit -m "Remove the Isle of Lore theme and document the Sprout Lands setup"
```

---

### Task 7: Pipeline — Sprout references, palette lock, prop type

**Files:**
- Modify: `asset-pipeline/gen.py`, `asset-pipeline/refine.lua`, `asset-pipeline/jobs.json`, `asset-pipeline/README.md`
- Create: `asset-pipeline/test_gen.py`

**Interfaces:**
- Produces (in `gen.py`): `PALETTES: dict[str, str]`; `palette_of(job) -> str | None` (absolute path);
  `palette_colors(png) -> set[tuple[int,int,int]]`; `opaque_count(png) -> int`; `off_palette(png, pal_png) -> int`;
  `as_png(ref)` accepting `"path#x,y,w,h"` crops; `remap(ref, out) -> None`; `STYLES["prop"]`; `refine.lua` param
  `palette=<png>`.

- [ ] **Step 1: Write the failing tests** — `asset-pipeline/test_gen.py`:

```python
"""Checks for gen.py helpers (no framework). python asset-pipeline/test_gen.py"""
import os, shutil, tempfile
from PIL import Image
import gen

TMP = tempfile.mkdtemp()


def save(name, size, pixels):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    for xy, c in pixels.items():
        im.putpixel(xy, c)
    path = os.path.join(TMP, name)
    im.save(path)
    return path


def test_off_palette_counts_only_opaque_strangers():
    pal = save("pal.png", (2, 1), {(0, 0): (10, 20, 30, 255), (1, 0): (40, 50, 60, 255)})
    img = save("img.png", (3, 1), {(0, 0): (10, 20, 30, 255), (1, 0): (99, 99, 99, 255)})  # (2,0) transparent
    assert gen.off_palette(img, pal) == 1
    assert gen.opaque_count(img) == 2


def test_as_png_crops_a_region():
    src = save("sheet.png", (4, 4), {(2, 2): (255, 0, 0, 255)})
    out = Image.open(gen.as_png(src + "#2,2,2,2")).convert("RGBA")
    assert out.size == (2, 2) and out.getpixel((0, 0)) == (255, 0, 0, 255)


def test_palette_defaults_and_override():
    assert gen.palette_of({"type": "prop"}).endswith("Sprout Lands defautlt palette.png")
    assert gen.palette_of({"type": "ui"}) == gen.palette_of({"type": "prop"})
    assert gen.palette_of({"type": "sprite"}) is None
    assert gen.palette_of({"type": "sprite", "palette": "sprout"}) is not None


def test_sprout_palette_is_extracted():
    assert len(gen.palette_colors(gen.palette_of({"type": "prop"}))) > 90  # ~99 swatches; fails if not extracted


def test_remap_keeps_every_opaque_pixel():  # a black outline must not become transparent
    if not os.path.exists(gen.ASEPRITE):
        print("  skip: Aseprite not found")
        return
    src = save("dark.png", (3, 1), {(0, 0): (0, 0, 0, 255), (1, 0): (5, 5, 5, 255), (2, 0): (250, 250, 250, 255)})
    out = os.path.join(TMP, "dark_remap.png")
    gen.remap(src, out)
    assert gen.opaque_count(out) == 3
    assert gen.off_palette(out, gen.palette_of({"type": "prop"})) == 0


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print("ok  ", name)
    shutil.rmtree(TMP)
```

- [ ] **Step 2: Run to verify it fails**

Run: `python asset-pipeline/test_gen.py`
Expected: `AttributeError: module 'gen' has no attribute 'off_palette'`.

- [ ] **Step 3: gen.py** — add after `SIZES`:

```python
SL = "sprout-lands/"
SL_PREM = SL + "Sprout Lands - Sprites - premium pack/"
SL_UI_BASIC = SL + "Sprout Lands - UI Pack - Basic pack/"
SL_UI_PREM = SL + "Sprout Lands - UI Pack - Premium pack/"
PALETTES = {"sprout": SL_PREM + "Sprout Lands color pallet/Sprout Lands defautlt palette.png"}
```

Replace the `"ui"` style and add `"prop"`:

```python
    "ui": dict(
        aspect="1:1", size=32, colors=0, palette="sprout",
        prefix="Tiny pixel art game UI element matching the style of the reference (Sprout Lands UI pack) exactly: "
               "soft cream and wood-brown pastel palette, 1px dark outline, flat shading with a one-pixel highlight, "
               "no anti-aliasing, centered, no text, on a solid flat magenta #FF00FF background. Element: ",
        refs=[SL_UI_BASIC + "Sprite sheets/Sprite sheet for Basic Pack.png",
              SL_UI_PREM + "UI Sprites/Dialouge UI/dialog box.png"]),
    "prop": dict(
        aspect="1:1", size="small", colors=0, palette="sprout",
        prefix="Tiny top-down (3/4 view) pixel art farm game object matching the style of the reference sprite sheets "
               "exactly (Sprout Lands): soft pastel palette, 1px dark brown outline, simple flat shading, no "
               "anti-aliasing, sized for a 16x16 tile grid, one object centered, no text, on a solid flat magenta "
               "#FF00FF background. Object: ",
        refs=[SL_PREM + "Objects/Trees, stumps and bushes.png", SL_PREM + "Objects/work station.png",
              SL_PREM + "Tilesets/Building parts/Chest.png"]),
```

Replace `as_png` and add the helpers after it:

```python
def as_png(ref):
    """generate_image only takes still images: GIF refs become a PNG of their first frame, and 'path#x,y,w,h'
    refs become a PNG of that region (e.g. one frame of a sprite sheet). Cached in the temp dir."""
    path, _, crop = ref.partition("#")
    path = os.path.join(ROOT, path)
    if not crop and not path.lower().endswith(".gif"):
        return path
    tag = ("_" + crop.replace(",", "_")) if crop else ""
    cached = os.path.join(tempfile.gettempdir(), "agy_refs", os.path.basename(path) + tag + ".png")
    if not os.path.exists(cached):
        os.makedirs(os.path.dirname(cached), exist_ok=True)
        im = Image.open(path)
        if crop:
            x, y, w, h = map(int, crop.split(","))
            im = im.convert("RGBA").crop((x, y, x + w, y + h))
        else:
            im = im.convert("RGB")
        im.save(cached)
    return cached


def _rgba(png):
    b = Image.open(png).convert("RGBA").tobytes()
    return (tuple(b[i:i + 4]) for i in range(0, len(b), 4))


def palette_colors(png):
    return {c[:3] for c in _rgba(png) if c[3]}


def opaque_count(png):
    return sum(1 for c in _rgba(png) if c[3])


def off_palette(png, pal_png):
    pal = palette_colors(pal_png)
    return sum(1 for c in _rgba(png) if c[3] and c[:3] not in pal)


def palette_of(job):
    name = job.get("palette", STYLES[job["type"]].get("palette"))
    return os.path.join(ROOT, PALETTES[name]) if name else None
```

Replace `refine`:

```python
def refine(dest, job):
    """Aseprite pass: remap to the job's palette PNG (or quantize to `colors`), save a .aseprite for hand edits."""
    colors = job.get("colors", STYLES[job["type"]]["colors"])
    pal = palette_of(job)
    if not (colors or pal) or not os.path.exists(ASEPRITE):
        return
    before = opaque_count(dest)
    param = f"palette={pal}" if pal else f"colors={colors}"
    r = subprocess.run([ASEPRITE, "-b", "--script-param", f"in={dest}", "--script-param", param,
                        "--script", os.path.join(ROOT, "refine.lua")], capture_output=True, text=True)
    print("     ", (r.stdout.strip() or r.stderr.strip()).splitlines()[-1])
    if pal:
        off, lost = off_palette(dest, pal), before - opaque_count(dest)
        if off or lost:
            print(f"WARN  {dest}: {off} pixels off the palette, {lost} opaque pixels lost in the remap")


def remap(ref, out):
    """Put an existing image on the Sprout palette (no model call): `gen.py --remap <path[#x,y,w,h]> [--out <png>]`."""
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.open(as_png(ref)).convert("RGBA").save(out)
    refine(out, {"type": "prop", "palette": "sprout"})
```

In `__main__`, before the jobs loop:

```python
    if "--remap" in sys.argv:
        ref = sys.argv[sys.argv.index("--remap") + 1]
        name = os.path.basename(os.path.dirname(ref.partition("#")[0]))
        out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else os.path.join(OUT, "restyle", name + "_palette.png")
        remap(ref, out)
        print(f"wrote {out}")
        sys.exit()
```

Update the module docstring's type list to `portrait|splash|sprite|ui|prop|restyle` and mention `palette` and `--remap`.

- [ ] **Step 4: refine.lua** — replace the file:

```lua
-- Aseprite batch refine: remap to a palette PNG, or quantize to N colors; write .aseprite for hand edits.
--   aseprite -b --script-param in=X.png --script-param colors=16 --script asset-pipeline/refine.lua
--   aseprite -b --script-param in=X.png --script-param palette=P.png --script asset-pipeline/refine.lua
local src, colors, palpath = app.params["in"], tonumber(app.params["colors"] or 16), app.params["palette"]
local spr = Sprite{ fromFile = src }
if palpath then
  -- index 0 is the transparent slot; make it a colour no art uses (magenta) so dark outline pixels can't map to it
  local img, seen, list = Image{ fromFile = palpath }, {}, {}
  for it in img:pixels() do
    local px = it()
    if app.pixelColor.rgbaA(px) > 0 and not seen[px] then seen[px] = true; list[#list + 1] = px end
  end
  local pal = Palette(#list + 1)
  pal:setColor(0, Color{ r = 255, g = 0, b = 255, a = 0 })
  for i, px in ipairs(list) do
    pal:setColor(i, Color{ r = app.pixelColor.rgbaR(px), g = app.pixelColor.rgbaG(px), b = app.pixelColor.rgbaB(px), a = 255 })
  end
  spr:setPalette(pal)
else
  app.command.ColorQuantization{ ui = false, withAlpha = true, maxColors = colors }
end
app.command.ChangePixelFormat{ format = "indexed", dithering = "none" }
spr:saveAs(src:gsub("%.png$", ".aseprite"))
spr:saveCopyAs(src)
print("refined", src, "palette", #spr.palettes[1])
```

- [ ] **Step 5: Run the tests** — `python asset-pipeline/test_gen.py`. Expected: five `ok` lines. If
  `test_remap_keeps_every_opaque_pixel` fails on `opaque_count`, the indexed conversion mapped a pixel to index 0:
  set `spr.transparentColor = 0` explicitly before `ChangePixelFormat` and re-run.

- [ ] **Step 6: Example job** — append to `jobs.json`:

```json
  {"name": "order_board", "type": "prop", "prompt": "a small wooden notice board on two posts with three pinned paper order slips", "size": [32, 32]}
```

Run: `python asset-pipeline/gen.py order_board`. Expected: `wrote …/assets/prop/order_board.png`, no palette `WARN`.
Read the PNG (enlarge ×8 for viewing) and check it reads as Sprout Lands style.

- [ ] **Step 7: README** — in `asset-pipeline/README.md`: first line now says references come from `art-example/`,
  `80_Monster_Packs/` and `sprout-lands/`; add rows to the type table:

```markdown
| ui       | 1:1    | 32       | —      | magenta keyed, nearest, Sprout palette     | Sprout UI sheet + dialog box |
| prop     | 1:1    | small    | —      | magenta keyed, nearest, Sprout palette     | Sprout trees, work station, chest |
| restyle  | 1:1    | small    | —      | magenta keyed, nearest, Sprout palette     | job refs: creature frame first, then Sprout refs |
```

(remove the old `ui` row and the "ui is smooth vector-style" note) and a section:

```markdown
## Palette lock

`"palette": "sprout"` (default for `ui`, `prop`, `restyle`) makes `refine.lua` remap the image to the Sprout Lands
palette PNG instead of quantizing to `colors`. After the pass `gen.py` prints a `WARN` if any opaque pixel is off the
palette or the remap made pixels transparent. `python asset-pipeline/gen.py --remap <png>[#x,y,w,h] [--out <png>]`
puts any existing image (or one cell of a sheet) on the palette without a model call. Refs accept the same
`#x,y,w,h` suffix to use one frame of a sprite sheet. Checks: `python asset-pipeline/test_gen.py`.
```

- [ ] **Step 8: Commit**

```bash
git add asset-pipeline/gen.py asset-pipeline/refine.lua asset-pipeline/jobs.json asset-pipeline/README.md asset-pipeline/test_gen.py asset-pipeline/assets/prop
git commit -m "Point the asset pipeline at Sprout Lands and lock props and UI to its palette"
```

---

### Task 8: Creature restyle experiment (spike, throwaway)

**Files:**
- Modify: `asset-pipeline/gen.py` (`restyle` style), `asset-pipeline/jobs.json`, `.gitignore`
- Create: `asset-pipeline/restyle_compare.py`

**Interfaces:**
- Consumes: `gen.remap`, `gen.run`, `gen.as_png`, `gen.OUT`, `gen.SL_PREM`, `STYLES` (Task 7).

- [ ] **Step 1: Ignore the outputs** (derived from licensed monster art) — append to `.gitignore`:
  `asset-pipeline/assets/restyle/`

- [ ] **Step 2: restyle style** — add to `STYLES` in `gen.py`:

```python
    "restyle": dict(  # job refs: [creature frame to redraw, style ref, style ref]
        aspect="1:1", size="small", colors=0, palette="sprout",
        prefix="Redraw the creature from the FIRST reference image as a tiny 16-bit farm game sprite in the exact "
               "style of the OTHER reference images (Sprout Lands): same creature, same pose and silhouette, colours "
               "moved to that soft pastel palette, 1px dark outline, simple flat shading, no anti-aliasing, one "
               "creature centered and facing right, no text, on a solid flat magenta #FF00FF background. Creature: ",
        refs=[SL_PREM + "Animals/Chicken/chicken default.png", SL_PREM + "Characters/Premium Charakter Spritesheet.png"]),
```

- [ ] **Step 3: Jobs** — append to `jobs.json` (frame = idle, row 2 = facing right, column 0):

```json
  {"name": "restyle_slime", "type": "restyle", "prompt": "a small round slime", "refs": ["../creatures/pack/slime/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_mushroom", "type": "restyle", "prompt": "a walking mushroom creature", "refs": ["../creatures/pack/mushroom/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_blue_golem", "type": "restyle", "prompt": "a small blue stone golem", "refs": ["../creatures/pack/blue_golem/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]}
```

- [ ] **Step 4: Comparison script** — `asset-pipeline/restyle_compare.py`:

```python
"""Spike (throwaway): how close can the pipeline bring our creatures to Sprout Lands?
Per creature: original idle frame | palette remap only | full restyle, each on Sprout grass at the same pixel scale.
    python asset-pipeline/restyle_compare.py      -> asset-pipeline/assets/restyle/comparison.png
"""
import json, os
from PIL import Image
import gen

CREATURES = ["slime", "mushroom", "blue_golem"]
FRAME = "#0,256,128,128"  # idle sheet, row 2 (facing right), column 0
GRASS = gen.SL_PREM + ("Tilesets/ground tiles/New tiles/simpel versions/Grass tiles v2 simple cutout/"
                       "Grass_tiles_v2_Mid.png")
S = 2  # display scale; every image and the 16px grass tile get the same factor
OUT = os.path.join(gen.OUT, "restyle")


def cell(path):
    grass = Image.open(os.path.join(gen.ROOT, GRASS)).convert("RGBA")
    grass = grass.resize((grass.width * S, grass.height * S), Image.NEAREST)
    c = Image.new("RGBA", (128 * S, 128 * S))
    for y in range(0, c.height, grass.height):
        for x in range(0, c.width, grass.width):
            c.paste(grass, (x, y))
    if path and os.path.exists(path):
        im = Image.open(path).convert("RGBA")
        im = im.resize((im.width * S, im.height * S), Image.NEAREST)
        c.alpha_composite(im, ((c.width - im.width) // 2, (c.height - im.height) // 2))
    return c


if __name__ == "__main__":
    jobs = {j["name"]: j for j in json.load(open(os.path.join(gen.ROOT, "jobs.json")))}
    rows = []
    for name in CREATURES:
        ref = f"../creatures/pack/{name}/idle.png{FRAME}"
        gen.remap(ref, os.path.join(OUT, name + "_palette.png"))
        gen.run(jobs["restyle_" + name])
        rows.append([gen.as_png(ref), os.path.join(OUT, name + "_palette.png"),
                     os.path.join(gen.OUT, "restyle", "restyle_" + name + ".png")])
    sheet = Image.new("RGBA", (3 * 128 * S, len(rows) * 128 * S))
    for r, paths in enumerate(rows):
        for c, p in enumerate(paths):
            sheet.paste(cell(p), (c * 128 * S, r * 128 * S))
    sheet.save(os.path.join(OUT, "comparison.png"))
    print("wrote", os.path.join(OUT, "comparison.png"))
```

- [ ] **Step 5: Run it** — `python asset-pipeline/restyle_compare.py`. Expected: three `wrote …restyle_*.png` (or a
  kept last attempt with `WARN`), no palette `WARN`, then `wrote …/comparison.png`. Read `comparison.png`.

- [ ] **Step 6: Report** — send `comparison.png` to the owner (SendUserFile) with a recommendation — keep originals /
  palette-remap / restyle — judged on: readability next to a 16px tile at the same scale, palette harmony with the
  grass, and how much of each creature's identity survived. State the creature size (px) that reads well against
  16px tiles; sub-project 2 uses it for `sprite_scale`. Nothing is wired into the game.

- [ ] **Step 7: Commit** (script, style and jobs only; outputs are ignored)

```bash
git add .gitignore asset-pipeline/gen.py asset-pipeline/jobs.json asset-pipeline/restyle_compare.py
git commit -m "Add the creature restyle experiment"
```
