extends TestSuite
## The playtest bot plays whole days through the farm's popups without script errors (the runner fails any test that
## triggers one).

const SAVE := "user://test_playtest_bot_save.json"


func test_the_bot_plays_three_days() -> void:
	await tree.process_frame
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 11)
	var shop: Control = load("res://shop/shop.tscn").instantiate()
	tree.root.add_child(shop)
	await tree.process_frame
	var bot := PlaytestBot.new(shop)
	for n in 3:
		var day: Dictionary = await bot.play_day()
		eq(day["day"], n + 1, "day %d played" % (n + 1))
		check(not (day["actions"] as PackedStringArray).is_empty(), "day %d: the bot did something: %s" % [n + 1, day])
	eq(Game.state.day, 4, "three days ended")
	check(shop.get_node("%PanelHost").current() == null, "no popup left open")
	check(bot.goals().has("order kinds filled"), "goals reported")
	shop.queue_free()
	DirAccess.remove_absolute(SAVE)
