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
