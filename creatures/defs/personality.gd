@tool
class_name Personality
extends Resource
## Training on the favored stat gains 25% more, on the disfavored stat 25% less.

@export var id: StringName
@export var display_name: String
@export_enum("power", "guard", "speed", "wits", "heart") var favored_stat: String = "power"
@export_enum("none", "power", "guard", "speed", "wits", "heart") var disfavored_stat: String = "none"
