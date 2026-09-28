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
