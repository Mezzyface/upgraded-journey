@tool
class_name PanelHost
extends Control
## Where panels open over the farm, one at a time, centred in this rect over a dim backdrop. In the editor it draws
## a placeholder frame so its position and size can be adjusted; Esc or the panel's close button closes the open panel.

const OUTLINE := Color(1, 1, 1, 0.7)
const DIM := Color(0, 0, 0, 0.35)  ## backdrop over the farm while a window is open

var backdrop := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not Engine.is_editor_hint():
		if backdrop:
			draw_rect(Rect2(Vector2.ZERO, size), DIM)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.15))
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(12, 28), "Panels open here", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, OUTLINE)


func open(panel: Control) -> void:
	close()
	add_child(panel)
	_fit(panel)
	panel.minimum_size_changed.connect(_fit.bind(panel))  # wrapped text settles after the first layout pass
	mouse_filter = Control.MOUSE_FILTER_STOP  # the scene behind doesn't take clicks while a panel is open
	backdrop = true
	queue_redraw()


## Shrinks (or grows) the panel to its minimum size and centres it.
func _fit(panel: Control) -> void:
	panel.reset_size()
	panel.position = ((size - panel.size) / 2.0).max(Vector2.ZERO)


func close() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop = false
	queue_redraw()


func current() -> Control:
	return get_child(0) as Control if get_child_count() > 0 else null


func _unhandled_input(event: InputEvent) -> void:
	if current() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
