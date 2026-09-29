extends TestSuite
## The main scene: the farm map, creatures in the pen, the hanging bar and the popups its tags open.

const SAVE := "user://test_shop_save.json"


func _shop() -> Control:
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)
	var shop: Control = load("res://shop/shop.tscn").instantiate()
	tree.root.add_child(shop)
	return shop


func _done(shop: Control) -> void:
	shop.queue_free()
	DirAccess.remove_absolute(SAVE)


func _open_name(shop: Node) -> String:
	var p: Control = shop.get_node("%PanelHost").current()
	return p.name if p else ""


func test_the_bar_shows_the_state_and_refreshes() -> void:
	var shop := _shop()
	await tree.process_frame
	var bar: TopBar = shop.get_node("%TopBar")
	eq(bar.get_node("%DayLabel").text, "Day 1", "day 1")
	eq(bar.get_node("%Money").text, str(Game.state.money), "money")
	bar.end_day_pressed.emit()
	await tree.process_frame
	eq(bar.get_node("%DayLabel").text, "Day 2", "day 2 after End Day")
	eq(_open_name(shop), "DaySummary", "End Day opens the day summary")
	_done(shop)


func test_each_tag_and_the_shop_door_open_their_popup() -> void:
	var shop := _shop()
	await tree.process_frame
	var bar: TopBar = shop.get_node("%TopBar")
	for pair in [["orders_pressed", "OrdersPanel"], ["stable_pressed", "StablePanel"],
			["expedition_pressed", "ExpeditionPanel"], ["market_pressed", "MarketPanel"]]:
		bar.emit_signal(pair[0])
		await tree.process_frame
		eq(_open_name(shop), pair[1], "%s opens %s" % pair)
	shop.get_node("%PanelHost").close()
	shop.get_node("%ShopDoor").pressed.emit()
	await tree.process_frame
	eq(_open_name(shop), "OrdersPanel", "the shop building opens Orders")
	_done(shop)


func test_creatures_live_in_the_pen_and_open_their_card() -> void:
	var shop := _shop()
	await tree.process_frame
	var pens: SpawnArea = shop.get_node("%Pens")
	eq(pens.sprites().size(), Game.owned().size(), "one sprite per owned creature")
	eq(pens.sprite_scale, 1.4, "sprite_scale")
	var pen_rect := _pen_rect(shop)
	check(pen_rect.encloses(pens.get_global_rect()), "Pens %s inside the pen %s" % [pens.get_global_rect(), pen_rect])
	for s in pens.sprites():
		check(Rect2(Vector2.ZERO, pens.size).has_point(s.position), "creature inside: %s" % s.position)
	pens.creature_clicked.emit(Game.owned()[0])
	await tree.process_frame
	eq(_open_name(shop), "CreatureCard", "a creature opens its card")
	_done(shop)


func _pen_rect(shop: Node) -> Rect2:
	var r := Rect2()
	for layer: TileMapLayer in shop.get_node("Pen").find_children("*", "TileMapLayer", true, false):
		var used := layer.get_used_rect()
		var px := Rect2(layer.to_global(layer.map_to_local(used.position)) - Vector2(8, 8), Vector2(used.size) * 16)
		r = px if r.size == Vector2.ZERO else r.merge(px)
	return r


func test_stable_row_opens_the_card_in_place() -> void:
	var shop := _shop()
	await tree.process_frame
	Game.retire(Game.owned()[0])
	shop.call("open_stable")
	await tree.process_frame
	var stable: StablePanel = shop.get_node("%PanelHost").current()
	(stable.get_node("%List").get_child(0) as Button).pressed.emit()
	await tree.process_frame
	eq(_open_name(shop), "CreatureCard", "the card replaces the Stable window")
	eq(shop.get_node("%PanelHost").get_child_count(), 1, "one popup at a time")
	_done(shop)


func test_the_old_layout_is_gone() -> void:
	var shop := _shop()
	for gone in ["Ranch", "Hud", "Counter", "MarketStall", "Door", "Stable"]:
		check(not shop.has_node(gone), "%s removed" % gone)
	for kept in ["BaseMap", "ShopBuilding", "Pen"]:
		check(shop.has_node(kept), "%s from the farm map" % kept)
	_done(shop)


func test_the_bar_only_takes_clicks_on_its_tags() -> void:
	var shop := _shop()
	await tree.process_frame
	var bar: TopBar = shop.get_node("%TopBar")
	for path in [".", "Strip", "Rope", "%Stats"]:
		eq(bar.get_node(path).mouse_filter, Control.MOUSE_FILTER_IGNORE, "bar %s ignores the mouse" % path)
	var children := shop.get_children()
	var door: Control = shop.get_node("%ShopDoor")
	for i in range(children.find(door) + 1, children.size()):
		var sib: Node = children[i]
		if sib is Control and sib.get_global_rect().intersects(door.get_global_rect()):
			eq(sib.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s overlaps the shop door and must ignore the mouse" % sib.name)
	_done(shop)
