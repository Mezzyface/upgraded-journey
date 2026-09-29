@tool
class_name UpgradeDef
extends Resource
## A shop upgrade, bought once. The rules key its effect by id: extra_ap, gene_scanner.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var cost: int = 100
@export_range(0, 4) var min_tier: int = 0
