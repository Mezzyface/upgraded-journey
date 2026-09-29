@tool
class_name Species
extends Resource
## A kind of creature. Potentials are the typical stat caps of a wild one; bred ones inherit their parents' instead.

@export var id: StringName
@export var display_name: String
## Evolution line shared by every stage, e.g. &"spider" for Spider, Spider Albino and Spider Large.
@export var line: StringName
@export_range(1, 3) var stage: int = 1
@export var element: StringName
@export var egg_group: StringName
@export_group("Potential")
@export_range(0, 999) var potential_power: int = 300
@export_range(0, 999) var potential_guard: int = 300
@export_range(0, 999) var potential_speed: int = 300
@export_range(0, 999) var potential_wits: int = 300
@export_range(0, 999) var potential_heart: int = 300
@export_group("")
@export var natural_traits: Array[TraitDef] = []
@export var moves: Array[MoveUnlock] = []
## Checked in order at the end of each day; the first satisfied branch wins.
@export var evolutions: Array[EvolutionDef] = []
@export var sprite_frames: SpriteFrames
## Size in the pen, in 16 px ranch tiles: the longest side of the idle frame's body is scaled to this many tiles.
@export_range(0.25, 4.0, 0.05) var size_tiles := 1.0
@export_group("Market")
## Price of an egg at the market; market_tier is the reputation tier that unlocks it (-1 = never sold).
@export var market_price: int = 0
@export_range(-1, 4) var market_tier: int = -1
@export_group("")


func potential(stat: String) -> int:
	return get("potential_" + stat)
