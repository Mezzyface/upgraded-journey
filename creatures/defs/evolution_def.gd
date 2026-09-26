@tool
class_name EvolutionDef
extends Resource
## One evolution branch. Every set condition must hold; unset ones are ignored.

@export var into: Species
@export_enum("none", "power", "guard", "speed", "wits", "heart") var stat: String = "none"
@export_enum("E", "D", "C", "B", "A", "S") var min_grade: int = 0
@export var required_trait: TraitDef
@export var personality: Personality
@export var min_age_days: int = 0
