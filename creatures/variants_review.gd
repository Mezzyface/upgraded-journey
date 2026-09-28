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
const COLS := 2  ## 2, not 3: the missing-still label ("gen.py restyle_party_mushroom") needs the width
const PITCH := Vector2(320, 110)  ## distance between groups (x: column, y: row)
const SLOT := 60.0  ## x distance between original, swap and still inside a group
const ORIGIN := Vector2(48, 60)  ## centre of the first group's original
const SCROLL_STEP := 32.0

var restyle_dir := RESTYLE_DIR  ## tests point this (and frames_dir) elsewhere before the scene enters the tree
var frames_dir := FRAMES_DIR

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
	for f in ResourceLoader.list_directory(frames_dir):
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
	var frames := load(frames_dir.path_join(id + ".tres")) as SpriteFrames
	for n in ["Original", "Swap"]:
		var s := AnimatedSprite2D.new()
		s.name = n
		s.sprite_frames = frames
		s.scale = Vector2.ONE * SPRITE_SCALE
		if n == "Swap":
			s.position.x = SLOT
			s.material = swap
		s.play(CreatureAnim.pick(frames, "idle", "right"))  # the pens' fallback when a pack lacks idle_right
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
