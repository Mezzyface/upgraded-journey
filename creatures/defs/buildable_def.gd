@tool
class_name BuildableDef
extends Resource
## Something the player buys in the Market and places on the farm grid: a pen now, other areas later
## (docs/superpowers/specs/2026-09-29-buildable-pens-design.md). `scene` is laid out in the editor with its top-left
## tile at cell (0, 0), covering `footprint` tiles; a pen's scene has a `%Creatures` SpawnArea.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var cost: int = 0
@export var capacity: int = 0  ## creatures it holds; 0 for areas that aren't pens
@export var footprint := Vector2i(1, 1)  ## size in 16 px tiles, fence included
@export var scene: PackedScene
