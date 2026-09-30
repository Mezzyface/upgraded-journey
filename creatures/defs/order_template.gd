@tool
class_name OrderTemplate
extends Resource
## A customer request. All `required` groups must pass; `bonus` groups add `bonus_money` when they all pass too.
## The deadline is computed from the requirements (OrderDifficulty).

@export var id: StringName
@export var customer: String
## Shown in the customer's frame on the request board; until it is set, the frame shows their initial.
@export var portrait: Texture2D
@export_multiline var request_text: String
@export var required: Array[RequirementGroup] = []
@export var bonus: Array[RequirementGroup] = []
@export var reward_money: int = 100
@export var bonus_money: int = 50
@export var reward_rep: int = 5
@export var extra_days: int = 0  ## added to the computed deadline (OrderDifficulty); use to hand-tune one order
@export_range(0, 4) var min_rep_tier: int = 0
