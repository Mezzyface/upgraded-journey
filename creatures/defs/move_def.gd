class_name MoveDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var element: StringName
@export_enum("damaging", "utility") var kind: String = "damaging"
