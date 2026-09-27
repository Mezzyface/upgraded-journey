@tool
class_name NewGameSetup
extends Resource
## What a new game starts with (data/new_game.tres). The species become wild adults with random personalities.

@export var money: int = 500
@export var feed: int = 5
@export var species: Array[Species] = []
