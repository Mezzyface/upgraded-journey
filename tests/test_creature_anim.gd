extends TestSuite

const Importer := preload("res://addons/creature_tools/pack_importer.gd")


func _frames(anims: Array) -> SpriteFrames:
	var tex := ImageTexture.create_from_image(Image.create(512, 512, false, Image.FORMAT_RGBA8))
	var d := {}
	for a in anims:
		d[a] = tex
	return Importer.frames_from_textures(d)


func test_missing_animations_fall_back() -> void:
	var f := _frames(["idle", "melee"])  # like mushroom: no move, melee instead of attack
	eq(CreatureAnim.pick(f, "move", "left"), &"idle_left", "move -> idle")
	eq(CreatureAnim.pick(f, "attack", "right"), &"melee_right", "attack -> melee")
	eq(CreatureAnim.pick(f, "idle", "up"), &"idle_up", "idle as is")
	var only_ability := _frames(["ability"])
	eq(CreatureAnim.pick(only_ability, "idle", "down"), &"ability_down", "anything, same facing, rather than nothing")


func test_no_frames_is_safe() -> void:
	eq(CreatureAnim.pick(null, "idle", "down"), &"", "null frames")
	eq(CreatureAnim.pick(SpriteFrames.new(), "idle", "down"), &"", "empty frames (only 'default', no frames)")
	check(CreatureAnim.portrait(null) == null, "no portrait")


func test_portrait_is_the_centre_of_the_first_idle_frame() -> void:
	var p := CreatureAnim.portrait(_frames(["idle"]))
	check(p is AtlasTexture, "an atlas crop")
	eq((p as AtlasTexture).region, Rect2(32, 32, 64, 64), "centre 64 px of the 128 px cell")


func test_portrait_hugs_a_small_opaque_blob() -> void:
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(20, 90, 10, 8), Color.WHITE)  # a small body low in the first 128px cell
	var tex := ImageTexture.create_from_image(img)
	var p := CreatureAnim.portrait(Importer.frames_from_textures({"idle": tex}))
	check(p is AtlasTexture, "an atlas crop")
	eq((p as AtlasTexture).region, Rect2(18, 87, 14, 14), "blob bbox (10x8) + 2px padding each side, centred on it")
