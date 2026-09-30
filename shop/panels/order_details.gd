class_name OrderDetails
extends PanelContainer
## The smaller window a request-board note opens (inside orders_panel.tscn): the customer's OrderNote (the same scene
## as on the board), what is needed (an OrderNeed per requirement, coloured met or missing for your best-matching
## creature; bonus ones below), the reward, and Accept (an offer) or Deliver… (an accepted order). Every action goes
## through Game; a refused one shows its reason. Emits `closed` when done so the board shows again.

signal closed

const NEED := preload("res://shop/panels/order_need.tscn")  ## one line of "Needed", styled in that scene

var _offer: StringName  ## the offer shown, or &""
var _active := -1  ## the index in Game.state.orders shown, or -1


func _ready() -> void:
	%Accept.pressed.connect(func() -> void: _done(Game.accept(_offer)))
	%Back.pressed.connect(func() -> void: closed.emit())
	%Deliver.get_popup().id_pressed.connect(func(id: int) -> void:
		_done(Game.deliver(_active, Game.state.get_creature(id))))


## An offer on today's board: nothing to check against yet, so requirements show plain.
func show_offer(id: StringName) -> void:
	_offer = id
	_active = -1
	var t: OrderTemplate = Game.db.orders[id]
	_fill(t, null, OrderNote.days_left_text(OrderNote.days_left(Game.offer_days(id), Game.state.day)))
	%Accept.show()
	%Deliver.hide()


## Accepted order `i`: requirements coloured for the best-matching creature, and who can be delivered.
func show_active(i: int) -> void:
	_active = i
	_offer = &""
	var t := Game.order_template(i)
	var due := int(Game.state.orders[i]["deadline_day"])
	_fill(t, Game.best_match(i), OrderNote.days_left_text(OrderNote.days_left(due, Game.state.day)))
	%Accept.hide()
	%Deliver.show()
	var menu: PopupMenu = %Deliver.get_popup()
	menu.clear()
	for c in Game.owned():
		if Game.order_check(i, c)["ok"]:
			var sp := Game.species_of(c)
			menu.add_item("%s #%d" % [sp.display_name if sp else String(c.species), c.id], c.id)
	if menu.item_count == 0:
		menu.add_item("Nobody meets this yet", -1)
		menu.set_item_disabled(0, true)


func _fill(t: OrderTemplate, best: CreatureData, due: String) -> void:
	%Prompt.show_order(t, -1, _active >= 0)
	for child in %Needs.get_children():
		%Needs.remove_child(child)
		child.queue_free()
	for g in t.required:
		_need(g, false, best)
	for g in t.bonus:
		_need(g, true, best)
	var reward := "%d gold" % t.reward_money
	if not t.bonus.is_empty():
		reward += " (+%d bonus)" % t.bonus_money
	%Reward.text = "%s · +%d reputation · %s" % [reward, t.reward_rep, due]
	%Message.text = ""
	%Message.hide()


func _need(g: RequirementGroup, bonus: bool, best: CreatureData) -> void:
	var line: OrderNeed = NEED.instantiate()
	%Needs.add_child(line)
	line.show_need(g.describe(), bonus, (Game.group_met(best, g) as Variant) if _active >= 0 else null)


func _done(reason: String) -> void:
	if reason == "":
		closed.emit()
		return
	%Message.text = reason.left(1).to_upper() + reason.substr(1)
	%Message.show()
