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
