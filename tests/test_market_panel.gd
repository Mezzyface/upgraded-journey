extends TestSuite
## The Market panel (market_panel.tscn): feed, eggs, upgrades and pens, each Buy enabled only when it would work.

const SAVE := "user://test_market_panel_save.json"


## Fixture content with the starter pen; money 1000, reputation tier 0. Returns [host, panel]; await it.
func _market() -> Array:
	await tree.process_frame
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.start_pen = db.buildables[&"pen"]
	Game.start_new(setup, db, 3)
	Game.state.money = 1000
	var host := PanelHost.new()
	host.size = Vector2(640, 320)
	tree.root.add_child(host)
	var panel: MarketPanel = load("res://shop/panels/market_panel.tscn").instantiate()
	host.open(panel)
	await tree.process_frame
	return [host, panel]


func _done(host: Node) -> void:
	host.queue_free()
	DirAccess.remove_absolute(SAVE)


func _buy(panel: Node, list: String, item: String) -> Button:
	return panel.get_node("%" + list).get_node(item).get_node("%Buy")


func test_sections_and_rows() -> void:
	var parts: Array = await _market()
	var panel: MarketPanel = parts[1]
	eq(panel.get_node("%Feed").get_children().map(func(r: Node) -> String: return r.name), ["feed_1", "feed_5"], "feed rows")
	eq(panel.get_node("%Feed/feed_5/%Name").text, "Feed ×5", "feed name")
	eq(panel.get_node("%Feed/feed_1/%Holds").text, "%d in stock" % Game.state.inventory["feed"], "stock")
	eq(panel.get_node("%Feed/feed_5/%Price").text, "50", "price")
	eq(panel.get_node("%Eggs").get_children().map(func(r: Node) -> String: return r.name), ["slime", "spider"], "eggs by price")
	check(_buy(panel, "Eggs", "spider").disabled, "locked egg disabled")
	eq(_buy(panel, "Eggs", "spider").tooltip_text, "Needs reputation tier 1", "and says why")
	eq(panel.get_node("%Eggs/spider/%Holds").text, "Unlocks at T1", "visibly and short (the bar says T0, T1)")
	eq(panel.get_node("%Eggs/slime/%Holds").text, "", "nothing to say for one on sale")
	check(not _buy(panel, "Eggs", "slime").disabled, "tier-0 egg on sale")
	eq(panel.get_node("%Upgrades").get_child_count(), 3, "every upgrade")
	eq(panel.get_node("%Pens").get_child_count(), 1, "pens kept")
	_done(parts[0])


func test_buying_feed_and_eggs() -> void:
	var parts: Array = await _market()
	var panel: MarketPanel = parts[1]
	var said: Array = []
	panel.bought.connect(func(t: String) -> void: said.append(t))
	var feed: int = Game.state.inventory["feed"]
	_buy(panel, "Feed", "feed_5").pressed.emit()
	eq(Game.state.inventory["feed"], feed + 5, "five feed")
	eq(panel.get_node("%Feed/feed_1/%Holds").text, "%d in stock" % (feed + 5), "stock refreshed")
	_buy(panel, "Eggs", "slime").pressed.emit()
	eq(Game.owned().filter(func(c: CreatureData) -> bool: return c.stage == "egg").size(), 1, "an egg")
	eq(said, ["Bought 5 feed", "Bought a Slime egg"], "bought emitted")
	_done(parts[0])


func test_buying_an_upgrade_marks_it_owned() -> void:
	var parts: Array = await _market()
	var panel: MarketPanel = parts[1]
	_buy(panel, "Upgrades", "extra_pen").pressed.emit()
	check(Game.state.upgrades.has(&"extra_pen"), "bought")
	check(_buy(panel, "Upgrades", "extra_pen").disabled, "can't buy twice")
	eq(_buy(panel, "Upgrades", "extra_pen").text, "Owned", "reads Owned")
	_done(parts[0])


func test_rows_follow_the_money() -> void:
	var parts: Array = await _market()
	var panel: MarketPanel = parts[1]
	check(not _buy(panel, "Feed", "feed_5").disabled, "affordable")
	Game.state.money = 20
	Game.changed.emit()
	check(_buy(panel, "Feed", "feed_5").disabled, "50 > 20: disabled")
	eq(_buy(panel, "Feed", "feed_5").tooltip_text, "Not enough money", "says why")
	check(not _buy(panel, "Feed", "feed_1").disabled, "one still affordable")
	_done(parts[0])


func test_pens_still_ask_the_farm_to_build() -> void:
	var parts: Array = await _market()
	var panel: MarketPanel = parts[1]
	var asked: Array = []
	panel.build_requested.connect(func(id: StringName) -> void: asked.append(id))
	_buy(panel, "Pens", "pen").pressed.emit()
	eq(asked, [&"pen"], "build_requested")
	_done(parts[0])
