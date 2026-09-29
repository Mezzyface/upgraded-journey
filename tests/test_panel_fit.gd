extends TestSuite
## Every panel the shop opens must fit on the 640x360 screen.

const SAVE := "user://test_panel_fit_save.json"


func test_every_panel_fits_on_screen() -> void:
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)
	var shop: Control = load("res://shop/shop.tscn").instantiate()
	tree.root.add_child(shop)
	await tree.process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(640, 360))
	for i in 12:  # a full stable must still fit
		Fixtures.adult(Game.state, "spider").status = CreatureData.Status.RETIRED
	Game.changed.emit()
	var opens := {"card": func(): shop.call("open_card", Game.owned()[0]),
		"orders": Callable(shop, "open_orders"), "summary": Callable(shop, "end_day"),
		"stable": Callable(shop, "open_stable"), "market": Callable(shop, "open_market"),
		"expedition": Callable(shop, "open_expedition")}
	for name in opens:
		opens[name].call()
		await tree.process_frame
		var panel: Control = shop.get_node("%PanelHost").current()
		check(panel != null, "%s opened" % name)
		if panel:
			check(screen.encloses(panel.get_global_rect()), "%s fits: %s" % [name, panel.get_global_rect()])
	shop.queue_free()
	DirAccess.remove_absolute(SAVE)
