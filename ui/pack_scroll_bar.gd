@tool
extends VSlider
## Slider-style scrollbar from the Isle of Lore pack: a thin bar with a fixed-size knob.
## Godot's VScrollBar stretches its grabber, so this VSlider drives the ScrollContainer instead.
## Put it beside the ScrollContainer, set that container's vertical scroll mode to "Show Never",
## and give this node the `PackScrollBar` theme type variation.

@export var scroll_path: NodePath = ^"../Scroll"

var _bar: VScrollBar


func _ready() -> void:
	var scroll := get_node_or_null(scroll_path) as ScrollContainer
	if scroll == null:
		return
	_bar = scroll.get_v_scroll_bar()
	_bar.changed.connect(_sync_range)
	_bar.value_changed.connect(_from_scroll)
	value_changed.connect(_to_scroll)
	_sync_range()


## The knob is at the top when value == max_value (VSlider counts upward), so mirror it.
func _sync_range() -> void:
	min_value = 0
	max_value = maxf(_bar.max_value - _bar.page, 0)
	step = 1
	visible = max_value > 0
	set_value_no_signal(max_value - _bar.value)


func _from_scroll(v: float) -> void:
	set_value_no_signal(max_value - v)


func _to_scroll(v: float) -> void:
	_bar.value = max_value - v
