@tool
class_name StatBox
extends PanelContainer
## One stat on the creature card (creature_card.tscn places five): a coloured header with the stat's name, its grade
## letter coloured by grade, the value, and a thin bar toward the creature's cap. `stat` and `header_color` are set per
## box in the Inspector; the grade colours are shared defaults here.

@export var stat := "power":
	set(v):
		stat = v
		_dress()
@export var header_color := Color(0.96, 0.6, 0.3):
	set(v):
		header_color = v
		_dress()
## One per grade, E to S (Stats.GRADE_NAMES).
@export var grade_colors: PackedColorArray = [
	Color(0.72, 0.56, 0.84), Color(0.45, 0.66, 0.9), Color(0.55, 0.8, 0.35),
	Color(0.93, 0.5, 0.65), Color(0.97, 0.6, 0.25), Color(0.98, 0.8, 0.2)]


func _ready() -> void:
	_dress()


func show_value(value: int, cap: int) -> void:
	var g := Stats.grade(value)
	%Grade.text = Stats.GRADE_NAMES[g]
	%Grade.add_theme_color_override("font_color", grade_colors[g])
	%Value.text = str(value)
	%Bar.value = value
	%Bar.cap = cap


func _dress() -> void:
	if not is_node_ready():
		return
	%Header.self_modulate = header_color
	%StatName.text = stat.capitalize()
