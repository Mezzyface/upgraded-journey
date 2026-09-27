@tool
class_name Location
extends Resource
## A place to train and to send expeditions. Training here may teach trains_trait.

@export var id: StringName
@export var display_name: String
@export var trains_trait: TraitDef
@export_range(0.0, 1.0) var trait_chance: float = 0.15
@export_group("Expedition")
## Each group is one challenge; it passes if any team member meets any requirement in it.
@export var challenges: Array[RequirementGroup] = []
@export var loot: Array[LootEntry] = []
@export var money_min: int = 10
@export var money_max: int = 40
