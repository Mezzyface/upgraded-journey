extends PanelContainer
## The request board, in two sections laid out in the scene: %Accepted (your accepted orders: light frame, a coloured "3 days left";
## hidden with its title when there are none) and %Offers (today's new requests), one OrderNote each in two
## columns. Clicking a note opens %Details over the board, where the order is accepted or delivered; closing it shows
## the board again.

const NOTE := preload("res://shop/panels/order_note.tscn")


func _ready() -> void:
	%Close.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close())
	%Details.closed.connect(func() -> void: %DetailsLayer.hide())
	Game.changed.connect(refresh)
	refresh()


func refresh() -> void:
	%Slots.text = "%d of %d taken" % [Game.state.orders.size(), OrderBoard.slots(Game.state)]
	for grid: Node in [%Accepted, %Offers]:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	for i in Game.state.orders.size():
		var days := OrderNote.days_left(int(Game.state.orders[i]["deadline_day"]), Game.state.day)
		_note(%Accepted, Game.order_template(i), days).pressed.connect(open_active.bind(i))
	for id in Game.state.board:
		_note(%Offers, Game.db.orders[id]).pressed.connect(open_offer.bind(id))
	var any_accepted: bool = %Accepted.get_child_count() > 0
	%AcceptedTitle.visible = any_accepted
	%Accepted.visible = any_accepted
	%Message.text = "No new requests today." if %Offers.get_child_count() == 0 else ""


func open_offer(id: StringName) -> void:
	%Details.show_offer(id)
	%DetailsLayer.show()


func open_active(i: int) -> void:
	%Details.show_active(i)
	%DetailsLayer.show()


func _note(grid: Node, t: OrderTemplate, days := -1) -> OrderNote:
	var note: OrderNote = NOTE.instantiate()
	grid.add_child(note)
	note.show_order(t, days)
	return note
