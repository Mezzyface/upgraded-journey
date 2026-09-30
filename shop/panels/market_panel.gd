class_name MarketPanel
extends "res://shop/panels/closable_panel.gd"
## The Market: one scrolling list of Feed, Eggs, Upgrades and Pens (docs/superpowers/specs/2026-09-30-market-goods-design.md),
## a buildable_row.tscn per item (%Name, %Holds as the detail, %Price, %Buy), named after the item. A Buy that would
## be refused is disabled with the reason as its tooltip. Feed, eggs and upgrades are bought at once (bought is
## emitted for the shop's toast); a pen's Buy asks the farm to start placement (paid when placed). Refreshes on
## Game.changed.

signal build_requested(def_id: StringName)
signal bought(text: String)

const ROW := preload("res://shop/panels/buildable_row.tscn")
const FEED_PACKS: PackedInt32Array = [1, 5]


func _ready() -> void:
	super()
	Game.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for list in [%Feed, %Eggs, %Upgrades, %Pens]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	for n in FEED_PACKS:
		var row := _row(%Feed, "feed_%d" % n, "Feed ×%d" % n, "%d in stock" % int(Game.state.inventory.get("feed", 0)),
				Market.FEED_PRICE * n, Game.feed_reason(n))
		row.get_node("%Buy").pressed.connect(_buy.bind(func() -> String: return Game.buy_feed(n), "Bought %d feed" % n))
	for sp in Game.eggs_on_offer():
		var reason := Game.egg_reason(sp.id)
		var why := reason.left(1).to_upper() + reason.substr(1)
		if sp.market_tier > Game.tier():
			why = "Unlocks at T%d" % sp.market_tier  # short enough for the column; the bar says T0, T1
		var row := _row(%Eggs, String(sp.id), "%s egg" % sp.display_name, why, sp.market_price, reason)
		row.get_node("%Buy").pressed.connect(_buy.bind(func() -> String: return Game.buy_egg(sp.id), "Bought a %s egg" % sp.display_name))
	for u in Game.upgrades_on_offer():
		var reason := Game.upgrade_reason(u.id)
		var locked := u.min_tier > Game.tier() and reason != "already bought"
		var row := _row(%Upgrades, String(u.id), u.display_name, "Unlocks at T%d" % u.min_tier if locked else u.description,
				u.cost, reason)
		row.get_node("%Holds").tooltip_text = u.description
		if reason == "already bought":
			row.get_node("%Buy").text = "Owned"
		row.get_node("%Buy").pressed.connect(_buy.bind(func() -> String: return Game.buy_upgrade(u.id), "Bought %s" % u.display_name))
	var defs: Array = Game.db.buildables.values().filter(func(d: BuildableDef) -> bool: return d.capacity > 0)
	defs.sort_custom(func(a: BuildableDef, b: BuildableDef) -> bool: return a.cost < b.cost)
	for def: BuildableDef in defs:
		var money := "" if Game.state.money >= def.cost else "not enough money"
		var row := _row(%Pens, String(def.id), def.display_name, "holds %d" % def.capacity, def.cost, money)
		if money == "":
			row.get_node("%Buy").tooltip_text = def.description
		row.get_node("%Buy").pressed.connect(func() -> void: build_requested.emit(def.id))


func _row(list: Node, id: String, title: String, detail: String, price: int, reason: String) -> Control:
	var row: Control = ROW.instantiate()
	row.name = id
	list.add_child(row)
	row.get_node("%Name").text = title
	row.get_node("%Holds").text = detail
	row.get_node("%Holds").tooltip_text = detail
	row.get_node("%Price").text = str(price)
	var buy: Button = row.get_node("%Buy")
	buy.disabled = reason != ""
	buy.tooltip_text = reason.left(1).to_upper() + reason.substr(1)
	return row


func _buy(action: Callable, text: String) -> void:
	if action.call() == "":
		bought.emit(text)
