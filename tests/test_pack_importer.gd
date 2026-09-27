extends TestSuite

const Importer := preload("res://addons/creature_tools/pack_importer.gd")


func test_variant_ids() -> void:
	eq(Importer.variant_id("Updated Slime Antenna"), "slime_antenna", "strips Updated")
	eq(Importer.variant_id("Updated Blue Golem"), "blue_golem", "two words")
	eq(Importer.variant_id("Wolf"), "wolf", "no prefix")


func test_common_prefix_finds_animation_names() -> void:
	eq(Importer.common_prefix(["Slime_Attack.png", "Slime_Idle.png", "Slime_Move.png"]), "Slime_", "slime")
	eq(Importer.common_prefix(["Mushroom_Party_Ability.png", "Mushroom_Party_Attack.png",
		"Mushroom_Party_Attack_FX.png", "Mushroom_Party_Idle.png"]), "Mushroom_Party_", "party mushroom")
	eq(Importer.common_prefix(["Golem_Blue_Idle.png"]), "Golem_Blue_", "single sheet")


func test_frames_from_textures_slices_cells_by_facing() -> void:
	var move := ImageTexture.create_from_image(Image.create(768, 512, false, Image.FORMAT_RGBA8))
	var attack := ImageTexture.create_from_image(Image.create(768, 512, false, Image.FORMAT_RGBA8))
	var sf: SpriteFrames = Importer.frames_from_textures({"move": move, "attack": attack})
	eq(sf.get_animation_names().size(), 8, "2 anims x 4 facings")
	check(not sf.has_animation(&"default"), "default animation removed")
	eq(sf.get_frame_count(&"move_left"), 6, "6 columns")
	var frame: AtlasTexture = sf.get_frame_texture(&"move_right", 1)
	eq(frame.region, Rect2(128, 256, 128, 128), "row 2 = right, column 1")
	check(sf.get_animation_loop(&"move_down"), "move loops")
	check(not sf.get_animation_loop(&"attack_down"), "attack plays once")


func test_sheets_dir_handles_all_three_pack_layouts() -> void:
	var root := ProjectSettings.globalize_path("user://test_packs")
	for layout in ["Spritesheets", "Spritesheet"]:
		var pack := root.path_join("pack_" + layout)
		DirAccess.make_dir_recursive_absolute(pack.path_join(layout).path_join("Updated Slime"))
		eq(Importer.sheets_dir(pack), pack.path_join(layout), layout)
	var flat := root.path_join("pack_flat")
	DirAccess.make_dir_recursive_absolute(flat.path_join("Monk"))
	eq(Importer.sheets_dir(flat), flat, "variant folders directly in the pack folder")
