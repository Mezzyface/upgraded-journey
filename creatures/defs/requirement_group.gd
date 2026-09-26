class_name RequirementGroup
extends Resource
## Passes when any one of its requirements passes. An order passes when all its groups pass.

@export var any_of: Array[Requirement] = []


func describe() -> String:
	return " or ".join(any_of.map(func(r: Requirement) -> String: return r.describe()))
