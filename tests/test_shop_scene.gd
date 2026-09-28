extends TestSuite

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


func test_shop_shows_the_creatures_and_the_hud() -> void:
	var shop := _shop()
	await tree.process_frame
	eq(shop.get_node("%Pens").sprites().size(), Game.owned().size(), "one sprite per owned creature")
	eq(shop.get_node("%Stable").sprites().size(), 0, "nobody retired yet")
	eq(shop.get_node("%DayNumber").text, "1", "day 1")
	check(shop.get_node("%MoneyLabel").text.contains("500"), "money")
	eq(_full_hearts(shop), Game.state.ap, "one full heart per AP left")
	eq(shop.get_node("%FeedLabel").text, str(Game.state.inventory.get("feed", 0)), "feed stock")
	eq(shop.get_node("%PenSpaceLabel").text, "%d/%d" % [Market.pen_used(Game.state), Market.pen_capacity(Game.state)],
		"pen space used / total")
	_done(shop)


func test_actions_refresh_the_pens_and_hud() -> void:
	var shop := _shop()
	await tree.process_frame
	Game.retire(Game.owned()[0])
	await tree.process_frame
	eq(shop.get_node("%Stable").sprites().size(), 1, "the retired creature moved to the stable")
	eq(shop.get_node("%Pens").sprites().size(), Game.owned().size(), "and left the pens")
	shop.get_node("%EndDayButton").pressed.emit()
	await tree.process_frame
	eq(shop.get_node("%DayNumber").text, "2", "day 2 after End day")
	_done(shop)


func _full_hearts(shop: Node) -> int:
	var full: Texture2D = shop.heart_full
	var n := 0
	for heart: TextureRect in shop.get_node("%ApHearts").get_children():
		if heart.visible and heart.texture == full:
			n += 1
	return n


func test_placeholder_stations_toast() -> void:
	var shop := _shop()
	await tree.process_frame
	shop.get_node("%MarketStall").pressed.emit()
	check(shop.get_node("%Toast").text != "", "coming-soon message")
	_done(shop)


func test_creature_clicked_and_counter_open_their_panels() -> void:
	var shop := _shop()
	await tree.process_frame
	shop.get_node("%Pens").creature_clicked.emit(Game.owned()[0])
	await tree.process_frame
	eq(shop.get_node("%PanelHost").current().name, "CreatureCard", "creature_clicked opens the card")
	shop.get_node("%Counter").pressed.emit()
	await tree.process_frame
	eq(shop.get_node("%PanelHost").current().name, "OrdersPanel", "Counter opens the orders panel")
	_done(shop)


## Regression for the almost-unclickable counter: a later sibling drawn on top of a station must not eat its
## clicks unless it explicitly ignores the mouse (creature Hit buttons, which are descendants, still work).
func test_no_later_sibling_blocks_a_station() -> void:
	var shop := _shop()
	await tree.process_frame
	var children := shop.get_children()
	for station_name in ["%Counter", "%MarketStall", "%Door"]:
		var station: Control = shop.get_node(station_name)
		var station_rect := station.get_global_rect()
		var idx := children.find(station)
		for i in range(idx + 1, children.size()):
			var sib := children[i]
			if sib is Control and sib.get_global_rect().intersects(station_rect):
				eq(sib.mouse_filter, Control.MOUSE_FILTER_IGNORE,
						"%s overlaps %s and must ignore the mouse" % [sib.name, station.name])
	_done(shop)


func test_creatures_stay_inside_their_areas() -> void:
	var shop := _shop()
	await tree.process_frame
	Game.retire(Game.owned()[0])
	await tree.process_frame
	for area_name in ["%Pens", "%Stable"]:
		var area: SpawnArea = shop.get_node(area_name)
		eq(area.get_parent(), shop, "%s sits on the ranch, not in an old frame" % area_name)
		check(area.sprites().size() > 0, "%s has creatures" % area_name)
		for s in area.sprites():
			check(Rect2(Vector2.ZERO, area.size).has_point(s.position), "%s creature inside: %s" % [area_name, s.position])
		eq(area.sprite_scale, 1.4, "%s sprite_scale" % area_name)
	_done(shop)


func test_the_shop_uses_no_side_view_art() -> void:
	var text := FileAccess.get_file_as_string("res://shop/shop.tscn")
	check(not text.contains("res://shop/art/"), "shop.tscn references res://shop/art/")
	# Node names are only unique per parent (Ranch/House/Floor is a legitimate Task 6 node), so match
	# each removed node at the Shop root specifically, not by a bare name substring anywhere in the file.
	for gone in ["Floor", "PenFrame", "StableFrame"]:
		var at_root := false
		for line in text.split("\n"):
			if line.contains("[node name=\"%s\"" % gone) and line.contains("parent=\".\""):
				at_root = true
				break
		check(not at_root, "%s node removed from the root" % gone)
