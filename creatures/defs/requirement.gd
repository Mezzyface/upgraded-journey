@tool
class_name Requirement
extends Resource
## One condition an order checks. `id` is the species id, line id, stat name, trait id, element, move kind
## ("damaging"/"utility"), personality id, or (lineage) the line id.

@export_enum("species", "line", "stat", "trait", "move_element", "move_kind", "personality", "lineage")
var kind: String = "species"
@export var id: StringName
@export_enum("E", "D", "C", "B", "A", "S") var min_grade: int = 0  ## stat only
@export_range(1, 5) var generations: int = 2  ## lineage only


func describe() -> String:
	var name := String(id).capitalize()
	match kind:
		"species":
			return "a %s" % name
		"line":
			return "any %s" % name
		"stat":
			return "%s ≥ %s" % [name, Stats.GRADE_NAMES[min_grade]]
		"move_element":
			return "%s move" % name
		"move_kind":
			return "%s move" % id
		"personality":
			return "%s personality" % name
		"lineage":
			return "%d generations of %s" % [generations, name]
	return name  # trait
