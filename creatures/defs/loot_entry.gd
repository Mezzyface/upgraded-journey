@tool
class_name LootEntry
extends Resource
## One possible wild egg on an expedition; its chance is weight / total weight of the location's loot.

@export var species: Species
@export_range(1, 100) var weight: int = 1
