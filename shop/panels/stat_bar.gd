class_name StatBar
extends Control
## A stat out of 999 with the creature's cap (potential) marked.

const MAX := 999
const TRACK := Color(0.2, 0.2, 0.2, 0.25)
const FILL := Color(0.15, 0.55, 0.95)
const CAP := Color(0.1, 0.1, 0.1)

var value := 0:
	set(v):
		value = v
		queue_redraw()
var cap := 0:
	set(v):
		cap = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(64, 8)  # fills the card's width; this is only the floor
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, TRACK)
	draw_rect(Rect2(r.position, Vector2(r.size.x * value / MAX, r.size.y)), FILL)
	var x := r.size.x * cap / MAX
	draw_line(Vector2(x, -2), Vector2(x, r.size.y + 2), CAP, 2.0)
