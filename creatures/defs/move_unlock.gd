class_name MoveUnlock
extends Resource
## A species learns `move` once `stat` reaches `grade`.

@export var move: MoveDef
@export_enum("power", "guard", "speed", "wits", "heart") var stat: String = "power"
@export_enum("E", "D", "C", "B", "A", "S") var grade: int = 1
