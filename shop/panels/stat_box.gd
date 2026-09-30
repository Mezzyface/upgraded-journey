@tool
class_name StatBox
extends PanelContainer
## One stat on the creature card (creature_card.tscn places five): a coloured header with the stat's name, its grade
## letter coloured by grade, and the value. `stat` and `header_color` are set per box in the Inspector; the grade
## colours are shared defaults here.

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
	if not Engine.is_editor_hint() and %Grade.label_settings:
		%Grade.label_settings = %Grade.label_settings.duplicate()  # the five boxes share one; each needs its own colour


## Shows `value` and its grade letter in that grade's colour. Label Settings override theme colours, so the colour goes
## on the (per-box) Label Settings when the label has them.
func show_value(value: int) -> void:
	var g := Stats.grade(value)
	var grade: Label = %Grade
	grade.text = Stats.GRADE_NAMES[g]
	if grade.label_settings:
		grade.label_settings.font_color = grade_colors[g]
	else:
		grade.add_theme_color_override("font_color", grade_colors[g])
	%Value.text = str(value)


func _dress() -> void:
	if not is_node_ready():
		return
	%Header.self_modulate = header_color
	%StatName.text = stat.capitalize()
