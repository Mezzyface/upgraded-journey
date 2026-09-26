@tool
class_name Location
extends Resource
## A place to train (and, in Plan 2, to send expeditions). Training here may teach `trains_trait`.

@export var id: StringName
@export var display_name: String
@export var trains_trait: TraitDef
@export_range(0.0, 1.0) var trait_chance: float = 0.15
