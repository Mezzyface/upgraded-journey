@tool
class_name OrderTemplate
extends Resource
## A customer request. All `required` groups must pass; `bonus` groups add `bonus_money` when they all pass too.

@export var id: StringName
@export var customer: String
@export_multiline var request_text: String
@export var required: Array[RequirementGroup] = []
@export var bonus: Array[RequirementGroup] = []
@export var reward_money: int = 100
@export var bonus_money: int = 50
@export var reward_rep: int = 5
@export var deadline_days: int = 5
@export_range(0, 4) var min_rep_tier: int = 0
