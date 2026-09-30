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
	bot.reload_on_day = 2
	for n in 3:
		var day: Dictionary = await bot.play_day()
		eq(day["day"], n + 1, "day %d played" % (n + 1))
		check(not (day["actions"] as PackedStringArray).is_empty(), "day %d: the bot did something: %s" % [n + 1, day])
	eq(Game.state.day, 4, "three days ended")
	check(shop.get_node("%PanelHost").current() == null, "no popup left open")
	check(bot.goals().has("order kinds filled"), "goals reported")
	check(bot.gaps.is_empty(), "every action worked: %s" % [bot.gaps])
	check(String(bot.goals()["mid-day reload"]).begins_with("yes"), "a real mid-day reload: %s" % bot.goals()["mid-day reload"])
	check(bot.goals().has("order kinds never filled"), "and what was never filled")
	shop.queue_free()
	DirAccess.remove_absolute(SAVE)


func test_a_disabled_button_is_a_gap_not_a_press() -> void:
	var bot := PlaytestBot.new(Control.new())
	var b := Button.new()
	b.disabled = true
	var pressed := [0]
	b.pressed.connect(func() -> void: pressed[0] += 1)
	check(not bot.press(b, "Breed"), "not pressed")
	eq(pressed[0], 0, "no signal")
	eq(bot.gaps.size(), 1, "a gap: %s" % [bot.gaps])
	b.free()


func test_evolutions_come_from_species_changes_not_names() -> void:
	await tree.process_frame
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 11)
	var bot := PlaytestBot.new(Control.new())
	var c := CreatureData.wild(Game.db.species[&"mushroom"], Game.state.new_id(), Fixtures.rng())
	Game.state.add(c)
	var before: Dictionary = bot.species_now()
	c.species = &"party_mushroom"
	bot.note_evolutions(before)
	eq(bot.goals()["branching evolution"], "no", "one mushroom evolution is not a branch")
	check(String(bot.goals()["evolutions"]).contains("mushroom"), "but it is an evolution")
	DirAccess.remove_absolute(SAVE)


func test_only_the_requirements_a_creature_meets_count_as_filled() -> void:
	await tree.process_frame
	Game.save_path = SAVE
	var db := Fixtures.db()
	Game.start_new(NewGameSetup.new(), db, 3)
	var c := Fixtures.adult(Game.state, "spider", 200)  # power D, no Darksight
	var t := Fixtures.order("either", 0, [Fixtures.group([Fixtures.req("stat", "power", Stats.Grade.D),
		Fixtures.req("trait", "darksight")])], [], 50, 1, 0)
	eq(PlaytestBot.new(Control.new()).kinds_met(c, t), ["stat"], "only the alternative it meets")
	DirAccess.remove_absolute(SAVE)
