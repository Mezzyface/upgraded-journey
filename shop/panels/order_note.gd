class_name OrderNote
extends PanelContainer
## A customer's request in the dialog style, built like the pack's premade dialog box from BarPanel (the plate),
## PortraitFrameWood and SpeechBox. The one scene for it: used on the request board (orders_panel.tscn) and as the head
## of the order details. Their face sits in the wooden frame: the order's `portrait`, or until one is set an emote from
## the Teemo emote sheet (EmoteFace on %Face), picked by their name. Their name sits beside it, above the speech box
## that holds their request. Accepted orders use the light frame and show a countdown ("3 days left") coloured by how close it is. Clicking
## it emits `pressed`; the board opens the order's details.

signal pressed

@export_group("Countdown")
@export var plenty_color := Color("67835c")  ## more than `soon_days` days left
@export var soon_color := Color("b09643")  ## `soon_days` days left or fewer
@export var urgent_color := Color("a16159")  ## `urgent_days` days left or fewer
@export var soon_days := 2
@export var urgent_days := 1
@export_group("")


func _ready() -> void:
	var tag: Label = %Tag
	if tag.label_settings:
		tag.label_settings = tag.label_settings.duplicate()  # notes share one; each countdown needs its own colour


## `days` (see days_left()) >= 0 for an accepted order: the light frame and a coloured countdown tag. -1 for an
## offer. `accepted` alone gives the light frame without a tag (the details window's head).
func show_order(t: OrderTemplate, days := -1, accepted := days >= 0) -> void:
	%Frame.theme_type_variation = &"PortraitFrameWoodLight" if accepted else &"PortraitFrameWood"
	if t.portrait:
		%Face.stop()
		%Face.texture = t.portrait
	else:
		%Face.play_random(hash(t.customer))  # the same customer always makes the same face
	%Who.text = t.customer
	%Line.text = t.request_text
	%Tag.visible = days >= 0
	if days >= 0:
		%Tag.text = days_left_text(days)
		_tint_tag(countdown_color(days))


func countdown_color(days: int) -> Color:
	if days <= urgent_days:
		return urgent_color
	if days <= soon_days:
		return soon_color
	return plenty_color


func _tint_tag(color: Color) -> void:
	var tag: Label = %Tag
	if tag.label_settings:
		tag.label_settings.font_color = color
	else:
		tag.add_theme_color_override("font_color", color)


## Days you can still deliver an order, today included: it expires the evening of its deadline day
## (OrderBoard.expire), so on its deadline day it has 1 left. Never negative.
static func days_left(deadline_day: int, today: int) -> int:
	return maxi(deadline_day - today + 1, 0)


static func days_left_text(days: int) -> String:
	return "1 day left" if days == 1 else "%d days left" % days


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
