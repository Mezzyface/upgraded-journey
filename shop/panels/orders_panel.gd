extends PanelContainer
## The counter: active orders (requirements coloured met/missing for your best-matching creature, Deliver…) and
## today's offers (Accept). Every action goes through Game; a refused one shows its reason.

const MET := Color(0.2, 0.6, 0.25)
const MISSING := Color(0.75, 0.2, 0.2)


func _ready() -> void:
	%Close.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close())
	Game.changed.connect(refresh)
	refresh()


func refresh() -> void:
	%Slots.text = "%d of %d slots" % [Game.state.orders.size(), OrderBoard.slots(Game.state)]
	for child in %List.get_children():
		%List.remove_child(child)
		child.queue_free()
	for i in Game.state.orders.size():
		%List.add_child(_active_row(i))
	var header := Label.new()
	header.text = "On the board today"
	header.theme_type_variation = &"HeaderLabel"
	%List.add_child(header)
	for id in Game.state.board:
		%List.add_child(_offer_row(id))


func _active_row(i: int) -> Control:
	var t := Game.order_template(i)
	var best := Game.best_match(i)
	var box := _row_box()
	var rows: VBoxContainer = box.get_child(0)
	rows.add_child(_label("%s · due day %d · %d + %d gold" % [t.customer, int(Game.state.orders[i]["deadline_day"]),
		t.reward_money, t.bonus_money if not t.bonus.is_empty() else 0]))
	rows.add_child(_label(t.request_text))
	var groups := HFlowContainer.new()
	for g in t.required:
		var l := _chip(g.describe())
		l.add_theme_color_override("font_color", MET if Game.group_met(best, g) else MISSING)
		groups.add_child(l)
	for g in t.bonus:
		groups.add_child(_chip("Bonus: " + g.describe()))
	rows.add_child(groups)
	var deliver := MenuButton.new()
	deliver.text = "Deliver…"
	deliver.flat = false
	var menu := deliver.get_popup()
	for c in Game.owned():
		if Game.order_check(i, c)["ok"]:
			menu.add_item(_who(c), c.id)
	if menu.item_count == 0:
		menu.add_item("Nobody meets this yet", -1)
		menu.set_item_disabled(0, true)
	menu.id_pressed.connect(func(id: int) -> void:
		var reason := Game.deliver(i, Game.state.get_creature(id))
		_message(reason))
	rows.add_child(deliver)
	return box


func _offer_row(id: StringName) -> Control:
	var t: OrderTemplate = Game.db.orders[id]
	var box := _row_box()
	var line := HBoxContainer.new()
	var text := _label("%s — %s · %d gold · due day %d" % [t.customer,
		" · ".join(t.required.map(func(g: RequirementGroup) -> String: return g.describe())),
		t.reward_money, Game.offer_days(id)])
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(text)
	var accept := Button.new()
	accept.text = "Accept"
	accept.pressed.connect(func() -> void: _message(Game.accept(id)))
	line.add_child(accept)
	box.get_child(0).add_child(line)
	return box


func _row_box() -> PanelContainer:
	var box := PanelContainer.new()
	box.theme_type_variation = &"FlatPanel"
	box.add_child(VBoxContainer.new())
	return box


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _chip(text: String) -> Label:
	# Unlike _label, no autowrap: inside an HFlowContainer an autowrap label's minimum width
	# collapses to ~0, which the flow container then honours literally (one letter per line).
	var l := Label.new()
	l.text = text
	return l


func _who(c: CreatureData) -> String:
	var sp := Game.species_of(c)
	return "%s #%d" % [sp.display_name if sp else String(c.species), c.id]


func _message(reason: String) -> void:
	%Message.text = reason.left(1).to_upper() + reason.substr(1)
