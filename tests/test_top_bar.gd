extends TestSuite
## ui/top_bar.tscn: shows the state and turns tag presses into signals.

const SAVE := "user://test_top_bar_save.json"


func _bar() -> TopBar:
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)
	var bar: TopBar = load("res://ui/top_bar.tscn").instantiate()
	tree.root.add_child(bar)
	return bar


func _done(bar: Node) -> void:
	bar.queue_free()
	DirAccess.remove_absolute(SAVE)


func test_show_state_fills_every_stat() -> void:
	var bar := _bar()
	await tree.process_frame  # _ready (tag connections) runs on the first frame
	var s := Game.state
	bar.show_state(s, 2)
	eq(bar.get_node("%DayLabel").text, "Day %d" % s.day, "day")
	eq(bar.get_node("%Money").text, str(s.money), "money")
	eq(bar.get_node("%Feed").text, str(s.inventory.get("feed", 0)), "feed")
	eq(bar.get_node("%PenSpace").text, "%d/%d" % [Market.pen_used(s), Market.pen_capacity(s)], "pens")
	eq(bar.get_node("%Rep").text, "Rep %d · T2" % s.reputation, "reputation and tier")
	var full := 0
	for h: TextureRect in bar.get_node("%Hearts").get_children():
		if h.visible and h.texture == bar.heart_full:
			full += 1
	eq(full, s.ap, "one full heart per AP left")
	_done(bar)


func test_each_tag_emits_its_signal() -> void:
	var bar := _bar()
	await tree.process_frame  # _ready (tag connections) runs on the first frame
	var got: Array[String] = []
	for sig in ["orders_pressed", "stable_pressed", "expedition_pressed", "market_pressed", "end_day_pressed"]:
		bar.connect(sig, func() -> void: got.append(sig))
	for tag in ["%Orders", "%Stable", "%Expedition", "%Market", "%EndDay"]:
		bar.get_node(tag).pressed.emit()
	eq(got, ["orders_pressed", "stable_pressed", "expedition_pressed", "market_pressed", "end_day_pressed"], "signals in order")
	_done(bar)


func test_only_the_tags_take_clicks() -> void:
	var bar := _bar()
	await tree.process_frame  # _ready (tag connections) runs on the first frame
	for path in [".", "Strip", "Rope", "%Stats"]:
		eq(bar.get_node(path).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % path)
	for n in bar.get_node("%Stats").get_children():
		eq(n.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % n.name)
	_done(bar)


func test_big_numbers_stay_clear_of_the_tags() -> void:
	var bar := _bar()
	await tree.process_frame  # _ready (tag connections) runs on the first frame
	bar.size = Vector2(656, 40)
	Game.state.money = 123456
	Game.state.reputation = 999
	bar.show_state(Game.state, 9)
	await tree.process_frame
	await tree.process_frame
	var stats: Rect2 = bar.get_node("%Stats").get_global_rect()
	var tags: Rect2 = bar.get_node("%Tags").get_global_rect()
	check(stats.end.x <= tags.position.x or stats.end.y <= tags.position.y, "stats %s clear of tags %s" % [stats, tags])
	check(stats.end.x <= 640 + 8, "stats fit on screen: %s" % stats)
	_done(bar)
