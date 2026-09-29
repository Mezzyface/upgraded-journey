class_name TopBar
extends Control
## The bar hanging from the top of the screen: a translucent wood strip with a rope along its lower edge, the
## stats on the strip and the action tags hanging from the rope. Laid out in ui/top_bar.tscn. Only the tags take
## clicks; everything else lets them through to the farm. shop.gd connects the signals and calls show_state().

signal orders_pressed
signal stable_pressed
signal expedition_pressed
signal market_pressed
signal end_day_pressed

## AP hearts: each child of %Hearts shows one AP point, full while unspent.
@export var heart_full: Texture2D
@export var heart_empty: Texture2D


func _ready() -> void:
	%Orders.pressed.connect(orders_pressed.emit)
	%Stable.pressed.connect(stable_pressed.emit)
	%Expedition.pressed.connect(expedition_pressed.emit)
	%Market.pressed.connect(market_pressed.emit)
	%EndDay.pressed.connect(end_day_pressed.emit)


func show_state(s: GameState, tier: int) -> void:
	%DayLabel.text = "Day %d" % s.day
	var max_ap := Day.max_ap(s)
	for i in %Hearts.get_child_count():
		var heart: TextureRect = %Hearts.get_child(i)
		# ponytail: hearts are placed in the editor (6 = max AP today); add nodes there if max AP grows
		heart.visible = i < max_ap
		heart.texture = heart_full if i < s.ap else heart_empty
	%Money.text = str(s.money)
	%Feed.text = str(s.inventory.get("feed", 0))
	%PenSpace.text = "%d/%d" % [Market.pen_used(s), Market.pen_capacity(s)]
	%Rep.text = "Rep %d · T%d" % [s.reputation, tier]
