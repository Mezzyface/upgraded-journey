@tool
class_name NewGameSetup
extends Resource
## What a new game starts with (data/new_game.tres). The species become wild adults with random personalities.

@export var money: int = 500
@export var feed: int = 5
@export var species: Array[Species] = []
## The free pen a new game (and an old save from before pens were placed) starts with, and its top-left tile.
@export var start_pen: BuildableDef
@export var start_pen_cell := Vector2i(11, 14)
