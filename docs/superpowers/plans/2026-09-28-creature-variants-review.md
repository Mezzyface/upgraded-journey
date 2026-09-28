# Creature Variants Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Godot review scene that shows every creature as original | Sprout palette swap | Sprout-style still, with
the pipeline improved where the baseline stills fall short.

**Architecture:** The palette swap is a `canvas_item` shader (nearest Sprout palette colour per pixel) on a
ShaderMaterial, applied to the existing SpriteFrames: no derived files. Stills come from `gen.py` `restyle` jobs into
the git-ignored `asset-pipeline/assets/restyle/`. `creatures/variants_review.gd` (`@tool`) builds the whole review
grid as unowned nodes, so the saved scene is just a root and a camera.

**Tech Stack:** Godot 4.7 (GDScript, Godot shading language), godot-ai MCP, Python 3 + Pillow, `agy`, Aseprite.

**Spec:** `docs/superpowers/specs/2026-09-28-creature-variants-review-design.md`

## Global Constraints

- The Godot editor is open and owns the project. Make Godot changes through the godot-ai MCP: scripts with
  `script_create` / `script_patch`, everything else with `editor_manage` op `eval` (EditorInterface APIs) and
  `scene_save`. Never kill or restart the editor. Toggle plugins only with `EditorInterface.set_plugin_enabled`
  (never `plugin_manage`).
- `script_patch` matches exact bytes and many `.gd` files are CRLF: anchor on single lines, and after every patch
  confirm the file on disk (`git diff <file>`). It sometimes reports success without writing.
- After every `scene_save` or resource save run `git status --short` on the whole tree and `git restore` anything
  you did not mean to change (a stale Script Editor buffer can be flushed into a file).
- `creatures/frames/slime.tres` and `creatures/frames/spider.tres` have the owner's uncommitted line-ending changes:
  never stage, restore or edit them.
- Commits: plain subject line, **no `Co-Authored-By` trailer**. Stage files by name only (never `git add -A` / `.`).
  Never push.
- Never commit licensed or derived art: `creatures/pack/`, `art/sprout/**` (only `.import` files are committed),
  `asset-pipeline/sprout-lands/`, `asset-pipeline/assets/restyle/` stay git-ignored.
- Nothing built by `variants_review.gd` may be saved into `variants_review.tscn` (built nodes have no owner).
- Stills are shown at 1× (native Sprout size); originals and swaps at `SPRITE_SCALE := 1.4` (the pens' value).
- Godot test suite (must end with `0 failed`; it is 169 tests before this plan):
  `"C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tests/run_tests.gd`
- Pipeline checks: `python asset-pipeline/test_gen.py` (every test prints `ok`).
- In this plan `GODOT` means `"C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`.

## Review Focus

1. The scene is open in the editor and the `@tool` script reloads (or `build()` runs twice): groups must not
   duplicate. → Task 2 test `test_build_twice_does_not_duplicate`.
2. The owner saves the review scene in the editor: the built grid must not be written into the `.tscn`.
   → Task 2 test `test_built_nodes_are_not_saved`.
3. A still file exists but is broken (0 bytes after a failed `agy` run): show the missing-still label, don't crash.
   → Task 2 test `test_broken_still_shows_the_gen_command`.
4. Fresh clone before "Sync pack files": the palette texture is missing. The scene must still build (swap renders
   unchanged, a warning names the fix). → Task 2 test `test_builds_without_the_palette`.
5. A species' SpriteFrames lacks `idle_right`: its original and swap would be invisible. → Task 2 test
   `test_one_group_per_species_with_all_three_slots` checks every SpriteFrames has `idle_right`.

---

### Task 1: Palette-swap shader and material

**Files:**
- Modify: `addons/sprout_tools/sprout_sync.gd` (one `FILES` entry)
- Create: `creatures/sprout_palette.gdshader`
- Create (in the editor): `creatures/sprout_palette.tres`
- Create: `tests/test_sprout_palette.gd`
- Modify: `tests/run_tests.gd` (`--only=<file>` user arg)
- Commit: `art/sprout/palette/Sprout Lands default palette.png.import` (the PNG itself stays ignored)

**Interfaces:**
- Produces: `res://creatures/sprout_palette.tres` — `ShaderMaterial`, shader `res://creatures/sprout_palette.gdshader`,
  shader parameter `palette` = `res://art/sprout/palette/Sprout Lands default palette.png`.
- Produces: `run_tests.gd` accepts `-- --only=<test file name>` to run one test file.

- [ ] **Step 1: Add the palette to the Sync tool**

In `addons/sprout_tools/sprout_sync.gd`, add this entry to `FILES` directly after the
`"sprites/grass-n-ground-tile-items.png": ...` line (use `script_patch` anchored on that single line, then
`git diff addons/sprout_tools/sprout_sync.gd` to confirm):

```gdscript
	"palette/Sprout Lands default palette.png": SPRITES_PREM + "Sprout Lands color pallet/Sprout Lands defautlt palette.png",
```

Then run the sync and import in the editor (`editor_manage` op `eval`):

```gdscript
var missing = preload("res://addons/sprout_tools/sprout_sync.gd").sync()
EditorInterface.get_resource_filesystem().scan()
return missing
```

Expected: `[]`, and `art/sprout/palette/Sprout Lands default palette.png` + `.import` exist on disk.

- [ ] **Step 2: Write the failing tests**

Create `tests/test_sprout_palette.gd`:

```gdscript
extends TestSuite
## The Sprout palette swap (creatures/sprout_palette.tres) recolours opaque pixels to a Sprout palette colour and
## leaves transparent ones alone. The render check needs a window, so headless runs skip it. Run it with:
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/run_tests.gd -- --only=test_sprout_palette.gd

const SWAP_PATH := "res://creatures/sprout_palette.tres"
const PALETTE := "res://art/sprout/palette/Sprout Lands default palette.png"
const SOURCE := Color8(1, 254, 3)  ## a colour the Sprout palette does not have


func test_material_uses_the_synced_palette() -> void:
	var swap := load(SWAP_PATH) as ShaderMaterial
	check(swap != null, "%s loads as a ShaderMaterial" % SWAP_PATH)
	if swap == null:
		return
	var tex := swap.get_shader_parameter("palette") as Texture2D
	check(tex != null and tex.resource_path == PALETTE, "palette parameter is %s" % PALETTE)


func test_opaque_pixels_land_on_the_palette() -> void:
	if DisplayServer.get_name() == "headless":
		print("  skip: sprout palette render check needs a window (see tests/test_sprout_palette.gd)")
		return
	var src := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	src.set_pixel(0, 0, SOURCE)
	src.set_pixel(1, 0, Color(0, 0, 0, 0))
	var vp := SubViewport.new()
	vp.size = Vector2i(2, 1)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(src)
	s.centered = false
	s.material = load(SWAP_PATH)
	vp.add_child(s)
	tree.root.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var out := vp.get_texture().get_image()
	var got := out.get_pixel(0, 0)
	check(_palette().any(func(p: Color) -> bool: return _close(p, got)), "opaque pixel %s is a palette colour" % got.to_html())
	check(not _close(got, SOURCE), "opaque pixel was recoloured")
	eq(out.get_pixel(1, 0).a8, 0, "transparent pixel alpha")
	vp.queue_free()


func _palette() -> Array:
	var img := (load(PALETTE) as Texture2D).get_image()
	var out := []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				out.append(c)
	return out


func _close(a: Color, b: Color) -> bool:
	return absi(a.r8 - b.r8) + absi(a.g8 - b.g8) + absi(a.b8 - b.b8) <= 3
```

In `tests/run_tests.gd`, support `--only=`. Replace the two lines

```gdscript
	var ran := 0
	var failed := 0
```

with

```gdscript
	var ran := 0
	var failed := 0
	var only := ""  ## `-- --only=test_x.gd` runs just that file (e.g. a render test, without --headless)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
```

and the line `if not (file.begins_with("test_") and file.ends_with(".gd")):` with

```gdscript
		if not (file.begins_with("test_") and file.ends_with(".gd")) or (only != "" and file != only):
```

Update the runner's header comment's usage line to mention `-- --only=test_x.gd`. Confirm both files on disk.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_sprout_palette.gd`
Expected: `FAIL test_sprout_palette.gd::test_material_uses_the_synced_palette  res://creatures/sprout_palette.tres loads as a ShaderMaterial` (the render test prints its skip line), `2 tests, 1 failed`.

- [ ] **Step 4: Write the shader**

Create `creatures/sprout_palette.gdshader` (Write, then `EditorInterface.get_resource_filesystem().scan()` via eval):

```glsl
shader_type canvas_item;
// Sprout Lands palette swap: every opaque pixel becomes the nearest colour of the palette texture.
// Used by creatures/sprout_palette.tres (creature variants review, docs/superpowers/specs/2026-09-28-creature-variants-review-design.md).

uniform sampler2D palette : filter_nearest;

void fragment() {
	vec4 c = COLOR;
	if (c.a > 0.0) {
		ivec2 size = textureSize(palette, 0);
		vec3 best = c.rgb;
		float best_d = 1e9;
		// ponytail: plain RGB distance; switch to OKLab in this loop if colours land badly.
		for (int y = 0; y < size.y; y++) {
			for (int x = 0; x < size.x; x++) {
				vec4 p = texelFetch(palette, ivec2(x, y), 0);
				if (p.a < 0.5) {
					continue;
				}
				vec3 d = p.rgb - c.rgb;
				float dist = dot(d, d);
				if (dist < best_d) {
					best_d = dist;
					best = p.rgb;
				}
			}
		}
		c.rgb = best;
	}
	COLOR = c;
}
```

- [ ] **Step 5: Create the material in the editor**

`editor_manage` op `eval`:

```gdscript
var m := ShaderMaterial.new()
m.shader = load("res://creatures/sprout_palette.gdshader")
m.set_shader_parameter("palette", load("res://art/sprout/palette/Sprout Lands default palette.png"))
var err := ResourceSaver.save(m, "res://creatures/sprout_palette.tres")
EditorInterface.get_resource_filesystem().scan()
return error_string(err)
```

Expected: `OK`. Then `logs_read` (or the editor Output) shows no shader compile error for `sprout_palette.gdshader`.
Run `git status --short` and restore anything unintended.

- [ ] **Step 6: Run the tests to verify they pass, headless and with a window**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_sprout_palette.gd`
Expected: `2 tests, 0 failed` (render test prints its skip line).

Run (no `--headless`, a window opens briefly): `$GODOT --path . -s res://tests/run_tests.gd -- --only=test_sprout_palette.gd`
Expected: `2 tests, 0 failed`, no skip line.

Run the full suite: `$GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: `171 tests, 0 failed` (169 + 2; `test_sprout_art.gd` also passes, proving the new `.tres` reference is in `FILES`).

- [ ] **Step 7: Commit**

```bash
git add addons/sprout_tools/sprout_sync.gd creatures/sprout_palette.gdshader creatures/sprout_palette.tres "art/sprout/palette/Sprout Lands default palette.png.import" tests/test_sprout_palette.gd tests/run_tests.gd
git commit -m "Add the Sprout palette swap shader and material"
```

Also commit any `.uid` files Godot created for the new shader (`git status --short` shows them; add by name).

---

### Task 2: Review scene

**Files:**
- Create: `creatures/variants_review.gd` (via `script_create`)
- Create (in the editor): `creatures/variants_review.tscn`
- Create: `tests/test_variants_review.gd`

**Interfaces:**
- Consumes: `res://creatures/sprout_palette.tres` (Task 1).
- Produces: `variants_review.tscn` root (`Node2D`, script `variants_review.gd`) with saved child `Camera` (`Camera2D`).
  After `_ready()` the root has one unowned `Node2D` child per `creatures/frames/*.tres`, named by species id
  (file stem), with children `Original` (`AnimatedSprite2D`), `Swap` (`AnimatedSprite2D`, `material` =
  `sprout_palette.tres`), `Still` (`Sprite2D`) **or** `Missing` (`Label`, text contains `restyle_<id>`), and `Name`
  (`Label`). Plus an unowned `Ground` (`TileMapLayer`).
- Produces: `var restyle_dir: String` (default `"res://asset-pipeline/assets/restyle"`), settable before the scene
  enters the tree; `func build() -> void` rebuilds everything idempotently.
- Produces: CLI after `--`: `--scroll=<px>`, `--screenshot=<png>`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_variants_review.gd`:

```gdscript
extends TestSuite
## creatures/variants_review.tscn: one group per species (original | palette swap | still), built without saving.

const SCENE := "res://creatures/variants_review.tscn"
const FRAMES_DIR := "res://creatures/frames"
const SWAP_PATH := "res://creatures/sprout_palette.tres"


func _ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for f in ResourceLoader.list_directory(FRAMES_DIR):
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
	return ids


## Untyped members: restyle_dir and build() live on the scene's script, not on Node, so use set()/call().
func _open(restyle_dir := "") -> Node:
	var r: Node = load(SCENE).instantiate()
	if restyle_dir != "":
		r.set("restyle_dir", restyle_dir)
	tree.root.add_child(r)
	return r


func _groups(r: Node) -> int:
	var n := 0
	for id in _ids():
		n += 1 if r.has_node(NodePath(id)) else 0
	return n


func test_one_group_per_species_with_all_three_slots() -> void:
	var r := _open()
	await tree.process_frame
	var ids := _ids()
	check(ids.size() >= 13, "found the species SpriteFrames")
	var swap := load(SWAP_PATH)
	for id in ids:
		var g := r.get_node_or_null(NodePath(id))
		check(g != null, "group for %s" % id)
		if g == null:
			continue
		var orig := g.get_node_or_null("Original") as AnimatedSprite2D
		check(orig != null and orig.sprite_frames.has_animation(&"idle_right") and orig.is_playing(), "%s original plays idle_right" % id)
		var sw := g.get_node_or_null("Swap") as AnimatedSprite2D
		check(sw != null and sw.material == swap and sw.is_playing(), "%s swap uses sprout_palette.tres" % id)
		check(g.has_node("Still") != g.has_node("Missing"), "%s has a still or the missing label" % id)
		check(g.get_node_or_null("Name") is Label, "%s has a name label" % id)
	r.queue_free()


func test_missing_still_shows_the_gen_command() -> void:
	var r := _open("res://no/such/dir")
	await tree.process_frame
	var l := r.get_node_or_null("slime/Missing") as Label
	check(l != null and l.text.contains("restyle_slime"), "missing still label names gen.py restyle_slime")
	check(not r.has_node("slime/Still"), "no Still when the file is missing")
	r.queue_free()


func test_broken_still_shows_the_gen_command() -> void:
	DirAccess.make_dir_recursive_absolute("user://variants_test")
	FileAccess.open("user://variants_test/restyle_slime.png", FileAccess.WRITE).close()  # 0 bytes
	var r := _open("user://variants_test")
	await tree.process_frame
	check(r.has_node("slime/Missing") and not r.has_node("slime/Still"), "a 0-byte still shows the missing label")
	r.queue_free()
	DirAccess.remove_absolute("user://variants_test/restyle_slime.png")


func test_build_twice_does_not_duplicate() -> void:
	var r := _open()
	await tree.process_frame
	var before := r.get_child_count()
	r.call("build")
	eq(r.get_child_count(), before, "child count after a second build")
	eq(_groups(r), _ids().size(), "one group per species after a second build")
	r.queue_free()


func test_built_nodes_are_not_saved() -> void:
	var r := _open()
	await tree.process_frame
	var packed := PackedScene.new()
	packed.pack(r)
	eq(packed.get_state().get_node_count(), 2, "saved nodes (root + Camera)")
	r.queue_free()


func test_builds_without_the_palette() -> void:
	var swap := load(SWAP_PATH) as ShaderMaterial
	var pal: Variant = swap.get_shader_parameter("palette")
	swap.set_shader_parameter("palette", null)
	var r := _open()
	await tree.process_frame
	eq(_groups(r), _ids().size(), "groups built with no palette texture")
	swap.set_shader_parameter("palette", pal)
	r.queue_free()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_variants_review.gd`
Expected: failures / script errors because `res://creatures/variants_review.tscn` does not exist.

- [ ] **Step 3: Write the script**

`script_create` `res://creatures/variants_review.gd` (then confirm it on disk):

```gdscript
@tool
extends Node2D
## Creature variants review (docs/superpowers/specs/2026-09-28-creature-variants-review-design.md).
## One group per creatures/frames/*.tres: original | Sprout palette swap | Sprout-style still from the asset
## pipeline (python asset-pipeline/gen.py restyle_<id>). Everything is built in build() as unowned nodes, so it shows
## (animated) when the scene is open in the editor and is never saved into the scene.
## After `--`: `--scroll=<px>` moves the camera down first, `--screenshot=<path>` saves a capture and quits:
##   godot --path . res://creatures/variants_review.tscn -- --screenshot=out.png --scroll=0

const FRAMES_DIR := "res://creatures/frames"
const RESTYLE_DIR := "res://asset-pipeline/assets/restyle"  ## git-ignored gen.py output, loaded by path (no .import)
const SWAP_PATH := "res://creatures/sprout_palette.tres"
const TILESET_PATH := "res://ranch/ranch_tileset.tres"
const GRASS := Vector2i(1, 1)  ## ranch TileSet source 0 (Grass_tiles_v2.png): plain grass centre tile
const SPRITE_SCALE := 1.4  ## the pens' sprite_scale (shop.tscn SpawnAreas)
const COLS := 3
const PITCH := Vector2(208, 104)  ## distance between groups (x: column, y: row)
const SLOT := 60.0  ## x distance between original, swap and still inside a group
const ORIGIN := Vector2(48, 60)  ## centre of the first group's original
const SCROLL_STEP := 32.0

var restyle_dir := RESTYLE_DIR  ## tests point this elsewhere before the scene enters the tree

@onready var _camera: Camera2D = $Camera


func _ready() -> void:
	build()
	if Engine.is_editor_hint():
		return
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scroll="):
			_camera.position.y += int(arg.trim_prefix("--scroll="))
		elif arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
	if shot != "":
		await RenderingServer.frame_post_draw
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b == null or not b.pressed:
		return
	if b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_camera.position.y += SCROLL_STEP
	elif b.button_index == MOUSE_BUTTON_WHEEL_UP:
		_camera.position.y = maxf(180.0, _camera.position.y - SCROLL_STEP)


## Rebuilds the grid. Idempotent: frees what the last build made (unowned children) first.
func build() -> void:
	for c in get_children():
		if c.owner == null:
			remove_child(c)
			c.free()
	var swap := load(SWAP_PATH) as ShaderMaterial
	if swap == null or swap.get_shader_parameter("palette") == null:
		push_warning("[variants_review] Sprout palette missing: run Project > Tools > Sprout Lands: Sync pack files")
	var ids := PackedStringArray()
	for f in ResourceLoader.list_directory(FRAMES_DIR):
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
	ids.sort()
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = load(TILESET_PATH)
	add_child(ground)
	move_child(ground, 0)
	var rows := ceili(ids.size() / float(COLS))
	for y in range(-4, ceili((ORIGIN.y + rows * PITCH.y) / 16.0) + 4):
		for x in range(-4, 44):
			ground.set_cell(Vector2i(x, y), 0, GRASS)
	for i in ids.size():
		add_child(_group(ids[i], ORIGIN + Vector2(i % COLS * PITCH.x, i / COLS * PITCH.y), swap))


func _group(id: String, at: Vector2, swap: Material) -> Node2D:
	var g := Node2D.new()
	g.name = id
	g.position = at
	var frames := load(FRAMES_DIR.path_join(id + ".tres")) as SpriteFrames
	for n in ["Original", "Swap"]:
		var s := AnimatedSprite2D.new()
		s.name = n
		s.sprite_frames = frames
		s.scale = Vector2.ONE * SPRITE_SCALE
		if n == "Swap":
			s.position.x = SLOT
			s.material = swap
		s.play(&"idle_right")
		g.add_child(s)
	var img := Image.new()
	var path := ProjectSettings.globalize_path(restyle_dir.path_join("restyle_%s.png" % id))
	if FileAccess.file_exists(path) and img.load(path) == OK:
		var still := Sprite2D.new()
		still.name = "Still"
		still.texture = ImageTexture.create_from_image(img)
		still.position.x = SLOT * 2
		g.add_child(still)
	else:
		g.add_child(_label("Missing", "gen.py\nrestyle_%s" % id, Vector2(SLOT * 2 - 24, -12)))
	g.add_child(_label("Name", id, Vector2(-24, 30)))
	return g


func _label(n: String, text: String, at: Vector2) -> Label:
	var l := Label.new()
	l.name = n
	l.text = text
	l.position = at
	return l
```

- [ ] **Step 4: Create the scene in the editor**

`editor_manage` op `eval`:

```gdscript
var root := Node2D.new()
root.name = "VariantsReview"
root.set_script(load("res://creatures/variants_review.gd"))
var cam := Camera2D.new()
cam.name = "Camera"
cam.position = Vector2(320, 180)
root.add_child(cam)
cam.owner = root
var p := PackedScene.new()
p.pack(root)
var err := ResourceSaver.save(p, "res://creatures/variants_review.tscn")
root.free()
EditorInterface.get_resource_filesystem().scan()
return error_string(err)
```

Expected: `OK`. Open it with `scene_open` `res://creatures/variants_review.tscn`, take an `editor_screenshot`, and
check the grid is visible in the 2D view. Do **not** `scene_save` it after opening (nothing to save; if you do,
`git diff creatures/variants_review.tscn` must be empty). Run `git status --short`; restore anything unintended.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd -- --only=test_variants_review.gd`
Expected: `6 tests, 0 failed`.

- [ ] **Step 6: Screenshot and tune the layout**

Run: `$GODOT --path . res://creatures/variants_review.tscn -- --screenshot=<scratchpad>/variants_0.png --scroll=0`
and again with `--scroll=300`. Look at both. Every group must show three creatures (or the missing label) side by
side without overlapping the next group, and the name under each group. If they overlap or clip, change only
`PITCH`, `SLOT`, `ORIGIN` or the label offsets in `variants_review.gd`, re-run Step 5 and re-screenshot.

- [ ] **Step 7: Full suite and commit**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: `177 tests, 0 failed`.

```bash
git add creatures/variants_review.gd creatures/variants_review.gd.uid creatures/variants_review.tscn tests/test_variants_review.gd tests/test_variants_review.gd.uid
git commit -m "Add the creature variants review scene"
```

(Add `.uid` files only if Godot created them; also `tests/test_sprout_palette.gd.uid` if Task 1 left it untracked.)

---

### Task 3: Baseline Sprout-style stills

**Files:**
- Modify: `asset-pipeline/jobs.json` (10 jobs)
- Delete: `asset-pipeline/restyle_compare.py`
- Modify: `asset-pipeline/README.md` (restyle section)

**Interfaces:**
- Consumes: `variants_review.tscn` (Task 2) loads `asset-pipeline/assets/restyle/restyle_<id>.png`.
- Produces: `restyle_<id>` jobs for all 13 species; baseline stills copied to `asset-pipeline/assets/restyle/baseline/`
  (git-ignored) for Task 4's before/after.

- [ ] **Step 1: Add the jobs**

Append these 10 objects to `asset-pipeline/jobs.json` (before the closing `]`, keep one object per line, comma after
the current last object). The refs match the three existing `restyle_*` jobs exactly:

```json
  {"name": "restyle_dog", "type": "restyle", "prompt": "a small grey dog standing side-on", "refs": ["../creatures/pack/dog/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_green_golem", "type": "restyle", "prompt": "a small dark stone golem with green crystal spikes on its head and shoulders and one glowing green eye", "refs": ["../creatures/pack/green_golem/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_red_golem", "type": "restyle", "prompt": "a small dark stone golem with red crystal spikes on its head and shoulders and one glowing red eye", "refs": ["../creatures/pack/red_golem/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_yellow_golem", "type": "restyle", "prompt": "a small dark stone golem with golden crystal spikes on its head and shoulders and one glowing yellow eye", "refs": ["../creatures/pack/yellow_golem/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_party_mushroom", "type": "restyle", "prompt": "a tiny slender mushroom creature with an orange cap and a pale stem", "refs": ["../creatures/pack/party_mushroom/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_slime_antenna", "type": "restyle", "prompt": "a small round green slime with a little antenna sprout on top", "refs": ["../creatures/pack/slime_antenna/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_spider", "type": "restyle", "prompt": "a tiny spider with a dark purple body and orange legs", "refs": ["../creatures/pack/spider/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_spider_albino", "type": "restyle", "prompt": "a spider with a pale grey body and orange-brown legs", "refs": ["../creatures/pack/spider_albino/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_spider_large", "type": "restyle", "prompt": "a large spider with a dark purple body and orange-brown legs", "refs": ["../creatures/pack/spider_large/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]},
  {"name": "restyle_wolf", "type": "restyle", "prompt": "a black wolf standing side-on", "refs": ["../creatures/pack/wolf/idle.png#0,256,128,128", "sprout-lands/Sprout Lands - Sprites - premium pack/Animals/Chicken/chicken default.png", "sprout-lands/Sprout Lands - Sprites - premium pack/Characters/Premium Charakter Spritesheet.png"]}
```

Verify: `python -c "import json;j=json.load(open('asset-pipeline/jobs.json'));r=[x['name'] for x in j if x['type']=='restyle'];print(len(r),sorted(r))"`
Expected: `13` names, one per `creatures/frames/*.tres` stem.

- [ ] **Step 2: Delete the spike script and update the README**

`git rm asset-pipeline/restyle_compare.py`. In `asset-pipeline/README.md`, in `## Restyle experiment result`,
replace the last sentence `Run: \`python asset-pipeline/restyle_compare.py\` (outputs git-ignored).` with nothing,
and add after that section:

```markdown
## Creature variants review

Every creature has a `restyle_<species>` job (one idle frame facing right, redrawn in Sprout style) writing
`assets/restyle/restyle_<species>.png` (git-ignored). `python asset-pipeline/gen.py restyle_wolf` makes one;
`python asset-pipeline/gen.py` makes any missing; `--force restyle_wolf` redoes one. Review them in Godot in
`creatures/variants_review.tscn` (original | Sprout palette swap | still, on ranch grass); from the command line:
`godot --path . res://creatures/variants_review.tscn -- --screenshot=out.png --scroll=0`.
```

Run `python asset-pipeline/test_gen.py` — every test prints `ok`.

- [ ] **Step 3: Commit**

```bash
git add asset-pipeline/jobs.json asset-pipeline/README.md
git commit -m "Add restyle jobs for every creature and drop the restyle spike script"
```

(`git rm` already staged the deletion.)

- [ ] **Step 4: Generate the baseline stills**

Run in the background (model calls; expect several minutes per job, a reviewer WARN after 3 failed attempts is
expected and keeps the last output):

```bash
python asset-pipeline/gen.py restyle_dog restyle_green_golem restyle_red_golem restyle_yellow_golem restyle_party_mushroom restyle_slime_antenna restyle_spider restyle_spider_albino restyle_spider_large restyle_wolf > <scratchpad>/baseline.log 2>&1
```

Expected: `ls asset-pipeline/assets/restyle/restyle_*.png` lists 13 files. Then copy them for the before/after:

```bash
mkdir -p asset-pipeline/assets/restyle/baseline && cp asset-pipeline/assets/restyle/restyle_*.png asset-pipeline/assets/restyle/baseline/
```

- [ ] **Step 5: Screenshot and checkpoint**

Run `$GODOT --path . res://creatures/variants_review.tscn -- --screenshot=<scratchpad>/baseline_0.png --scroll=0`
and `--scroll=300` → `baseline_1.png`. Look at every still and record, per species, which of these baseline
failures it shows (write them in the task report):

1. **Identity lost** — not recognisably the same creature (missing eye/spikes/cap/antenna/legs, different body).
2. **Too small** — the creature is much smaller than about 32 px tall on its 64 px canvas.
3. **Style off** — not reading as Sprout Lands (outline, shading, proportions) next to the ranch art.
4. **Source misread** — the model drew the wrong subject or pose (sign it saw mostly empty cell).

Also list the WARN lines from `baseline.log`. The controller sends both screenshots to the owner and decides which
Task 4 steps apply. No commit in this step (outputs are git-ignored).

---

### Task 4: Pipeline improvement round

Apply **only** the steps whose failure the Task 3 checkpoint recorded (step 1 ↔ failure 1, step 2 ↔ failure 2,
step 3 ↔ failure 3, step 4 ↔ failure 4). Skip the rest and say so in the report.

**Files:**
- Modify: `asset-pipeline/gen.py` (`review`, `STYLES["restyle"]["prefix"]`, `as_png`, `job_refs`)
- Modify: `asset-pipeline/jobs.json` (restyle style refs, step 3 only)
- Modify: `asset-pipeline/test_gen.py`

**Interfaces:**
- Produces (step 1): `gen.review_instruction(view: str, job: dict, refs: list[str]) -> str`; `review()` uses it.
- Produces (step 4): `gen.as_png(ref: str, trim: bool = False) -> str`, `gen.TRIM_PAD = 2`; `job_refs(job)` trims the
  first ref of `restyle` jobs only.

- [ ] **Step 1 (failure 1): Identity-aware reviewer**

Add to `asset-pipeline/test_gen.py` (above the `if __name__` block):

```python
def test_restyle_review_checks_identity_against_the_source():
    text = gen.review_instruction("v.png", {"type": "restyle", "prompt": "a golem"}, ["src.png", "s1.png", "s2.png"])
    assert "source creature" in text and '"src.png"' in text and "distinctive features" in text
    other = gen.review_instruction("v.png", {"type": "prop", "prompt": "a crate"}, ["s1.png"])
    assert "source creature" not in other and "distinctive features" not in other
```

Run `python asset-pipeline/test_gen.py` → `AttributeError: module 'gen' has no attribute 'review_instruction'`.

In `gen.py`, replace the `instruction = (...)` assignment inside `review()` with
`instruction = review_instruction(view, job, refs)` and add above `review()`:

```python
def review_instruction(view, job, refs):
    """The reviewer prompt. For restyle jobs the first ref is the creature being redrawn, so identity is checked
    against it and only the remaining refs are style references."""
    if job["type"] == "restyle":
        look = f"the source creature {json.dumps(refs[0])} and then the style references {json.dumps(refs[1:])}"
        identity = ("it is not recognisably the same creature as the source creature (lost distinctive features such "
                    "as its eyes, spikes, crystals, cap, antenna, legs or markings, or a different body shape), "
                    "it does not face right, ")
    else:
        look, identity = f"the style references {json.dumps(refs)}", ""
    return (
        f"You are an art director QA-ing a game asset. Use view_file ONLY (never run_command) to look at the "
        f"candidate {view} and then {look}. The candidate was generated for: "
        f"{json.dumps(job['prompt'])} as a {job['type']} in the reference style. Fail it if: it does not depict the "
        f"prompt, {identity}it is not pixel art in the reference style, it contains text, watermarks or extra subjects, or "
        f"(for portrait/sprite/ui) any background other than the flat magenta remains (magenta #FF00FF in the candidate "
        f"means transparent and is correct; a small drop shadow under the subject is part of the sprite, not background). "
        f"Be strict but not pedantic. "
        f"Reply with JSON: pass (bool) and issues (short concrete fix instructions, empty if pass)."
    )
```

Run `python asset-pipeline/test_gen.py` → all `ok`. Commit:

```bash
git add asset-pipeline/gen.py asset-pipeline/test_gen.py
git commit -m "Have the restyle reviewer check the creature against its source frame"
```

- [ ] **Step 2 (failure 2): Size in the restyle prefix**

In `gen.py` `STYLES["restyle"]["prefix"]`, replace `as a tiny 16-bit farm game sprite` with
`as a 16-bit farm game sprite whose creature fills about half the image height`. (Text only; no test.) Commit:

```bash
git add asset-pipeline/gen.py
git commit -m "Ask restyles for a creature about half the canvas tall"
```

- [ ] **Step 3 (failure 3): Single-sprite style refs**

Replace the two style refs of every `restyle_*` job in `jobs.json` (refs 2 and 3) with one-sprite crops of the Sprout
light cow (32 px, facing right) and chicken (16 px):

```bash
python -c "p='asset-pipeline/jobs.json';S='sprout-lands/Sprout Lands - Sprites - premium pack/';q=chr(34);t=open(p,newline='').read();t=t.replace(S+'Animals/Chicken/chicken default.png'+q,S+'Animals/Cow/Light cow animations.png#0,0,32,32'+q).replace(S+'Characters/Premium Charakter Spritesheet.png'+q,S+'Animals/Chicken/chicken default.png#0,0,16,16'+q);open(p,'w',newline='').write(t)"
```

(Plain text replace with `newline=''`, so no other line or line ending changes. The two whole-sheet refs only occur
in restyle jobs.)

Also set `STYLES["restyle"]["refs"]` in `gen.py` to the same two crops (the default when a job gives no refs):

```python
        refs=[SL_PREM + "Animals/Cow/Light cow animations.png#0,0,32,32", SL_PREM + "Animals/Chicken/chicken default.png#0,0,16,16"]),
```

Check `git diff --stat asset-pipeline/jobs.json` shows exactly 13 changed lines, all `restyle_*`. Run
`python asset-pipeline/test_gen.py` → all `ok`. Commit:

```bash
git add asset-pipeline/gen.py asset-pipeline/jobs.json
git commit -m "Give restyles single-sprite Sprout style refs"
```

- [ ] **Step 4 (failure 4): Trim the source frame**

Add to `test_gen.py`:

```python
def test_as_png_trims_to_opaque_bounds_with_padding():
    src = save("cell.png", (16, 16), {(5, 6): (255, 0, 0, 255), (7, 9): (0, 255, 0, 255)})
    out = Image.open(gen.as_png(src + "#0,0,16,16", trim=True)).convert("RGBA")
    assert out.size == (3 + 2 * gen.TRIM_PAD, 4 + 2 * gen.TRIM_PAD)
    assert out.getpixel((gen.TRIM_PAD, gen.TRIM_PAD)) == (255, 0, 0, 255)


def test_restyle_trims_only_the_source_ref():
    calls, orig = [], gen.as_png
    gen.as_png = lambda r, trim=False: calls.append(trim) or r
    try:
        gen.job_refs({"type": "restyle", "refs": ["a#0,0,1,1", "b", "c"]})
        assert calls == [True, False, False]
        calls.clear()
        gen.job_refs({"type": "prop", "refs": ["a", "b"]})
        assert calls == [False, False]
    finally:
        gen.as_png = orig
```

Run → fails (`as_png() got an unexpected keyword argument 'trim'`). In `gen.py` add `TRIM_PAD = 2` next to
`REWORKS`, and change `as_png` / `job_refs`:

```python
def as_png(ref, trim=False):
    """generate_image only takes still images: GIF refs become a PNG of their first frame, and 'path#x,y,w,h'
    refs become a PNG of that region (e.g. one frame of a sprite sheet). trim=True also crops to the opaque
    pixels plus TRIM_PAD, so a small creature in a big cell fills the ref. Cached in the temp dir."""
    path, _, crop = ref.partition("#")
    path = os.path.join(ROOT, path)
    if not crop and not trim and not path.lower().endswith(".gif"):
        return path
    tag = (("_" + crop.replace(",", "_")) if crop else "") + ("_trim" if trim else "")
```

keep the existing hash/cache lines, and in the `if not os.path.exists(cached):` block, after the `if crop: ... else: ...`
conversion and before `im.save(cached)`, add:

```python
        if trim:
            im = im.convert("RGBA")
            box = im.getbbox()
            if box:
                im = im.crop((box[0] - TRIM_PAD, box[1] - TRIM_PAD, box[2] + TRIM_PAD, box[3] + TRIM_PAD))
```

```python
def job_refs(job):
    refs = job.get("refs", STYLES[job["type"]]["refs"])[:3]
    # restyle: the first ref is the creature to redraw; trim it so the model sees the creature, not an empty cell
    return [as_png(r, trim=job["type"] == "restyle" and i == 0) for i, r in enumerate(refs)]
```

Run `python asset-pipeline/test_gen.py` → all `ok`. Commit:

```bash
git add asset-pipeline/gen.py asset-pipeline/test_gen.py
git commit -m "Trim the restyle source frame to the creature"
```

- [ ] **Step 5: Regenerate and compare**

If any of steps 1–4 were applied, regenerate the species that failed (all 13 if steps 2–4 applied, since they change
every restyle):

```bash
python asset-pipeline/gen.py --force restyle_<id> [restyle_<id> ...] > <scratchpad>/round1.log 2>&1
```

Screenshot the review scene again (`round1_0.png`, `round1_1.png`, `--scroll=0` / `300`). In the report, list per
species: baseline failure(s) → fixed / still failing, judged side by side with `assets/restyle/baseline/`. The
controller sends the before/after screenshots to the owner. Outputs are git-ignored; nothing to commit.

---

### Task 5: Final verification

- [ ] **Step 1:** `$GODOT --headless --path . -s res://tests/run_tests.gd` → `0 failed` (177 tests).
- [ ] **Step 2:** `$GODOT --path . -s res://tests/run_tests.gd -- --only=test_sprout_palette.gd` → `2 tests, 0 failed`, no skip.
- [ ] **Step 3:** `python asset-pipeline/test_gen.py` → all `ok`.
- [ ] **Step 4:** `scene_open res://creatures/variants_review.tscn` and `editor_screenshot`: the grid shows in the editor.
- [ ] **Step 5:** `git status --short` shows only ` M creatures/frames/slime.tres` and ` M creatures/frames/spider.tres`;
  `git ls-files art/sprout creatures/pack asset-pipeline/assets/restyle | grep -v "\.import$"` prints nothing.
