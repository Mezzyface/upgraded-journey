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
