class_name OrderNeed
extends HBoxContainer
## One line of "Needed" in the order details (order_details.gd makes one per requirement group): %Mark, a %Bonus
## prefix for bonus requirements, and %Text. Laid out and styled in order_need.tscn. On an accepted order %Text is
## coloured `met_color` or `missing_color` for your best-matching creature; on an offer it keeps its own colour.
## Colours go on the label's Label Settings when it has them (those override theme colours).

@export var met_color := Color("67835c")
@export var missing_color := Color("a35b70")


func _ready() -> void:
	var text: Label = %Text
	if text.label_settings:
		text.label_settings = text.label_settings.duplicate()  # instances share one; each line needs its own colour


## `met` is null when there is nothing to check against (an offer), else whether the requirement is met.
func show_need(description: String, bonus: bool, met: Variant = null) -> void:
	%Bonus.visible = bonus
	%Text.text = description
	if met == null:
		return
	var color: Color = met_color if met else missing_color
	var text: Label = %Text
	if text.label_settings:
		text.label_settings.font_color = color
	else:
		text.add_theme_color_override("font_color", color)
