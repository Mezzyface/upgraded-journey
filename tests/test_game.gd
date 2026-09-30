extends TestSuite

const GameScript := preload("res://game/game.gd")
const SAVE := "user://test_game_save.json"


func _game() -> Node:
	var g: Node = GameScript.new()
	g.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"], db.species[&"slime"]])
	setup.start_pen = db.buildables[&"pen"]  # so loading has nothing to migrate
	g.start_new(setup, db, 1)
	return g


func _cleanup(g: Node) -> void:
	g.free()
	DirAccess.remove_absolute(SAVE)


func test_actions_emit_changed_only_when_they_succeed() -> void:
	var g := _game()
	var count := [0]
	g.changed.connect(func() -> void: count[0] += 1)
	var c: CreatureData = g.owned()[0]
	eq(g.train(c, "power"), "", "trained")
	eq(count[0], 1, "one change")
	g.state.ap = 0
	var before: Dictionary = g.state.to_dict()
	eq(g.care(c, "play"), "not enough action points", "refused")
	eq(count[0], 1, "no change signal on refusal")
	eq(g.state.to_dict(), before, "state untouched")
	_cleanup(g)


func test_end_day_autosaves_and_start_loads_it() -> void:
	var g := _game()
	var events: PackedStringArray = g.end_day()
	check(events is PackedStringArray, "returns the evening's events")
	eq(g.state.day, 2, "next day")
	check(FileAccess.file_exists(SAVE), "autosaved to save_path")
	var g2: Node = GameScript.new()
	g2.save_path = SAVE
	g2.start(Fixtures.db())
	eq(g2.state.to_dict(), g.state.to_dict(), "loaded the autosave")
	g2.free()
	_cleanup(g)


func test_start_without_a_save_begins_a_new_game() -> void:
	DirAccess.remove_absolute(SAVE)
	var g: Node = GameScript.new()
	g.save_path = SAVE
	g.start(Fixtures.db())  # data/new_game.tres: spider, slime, green_golem (not in the fixtures, so skipped)
	eq(g.state.day, 1, "day 1")
	eq(g.owned().size(), 2, "the setup's species that exist")
	check(not g.state.board.is_empty(), "offers posted")
	_cleanup(g)


func test_a_save_from_before_the_board_gets_offers() -> void:
	var g := _game()
	var d := g.state.to_dict()
	d.erase("board")  # the format before the order board existed
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var g2: Node = GameScript.new()
	g2.save_path = SAVE
	g2.start(Fixtures.db())
	check(not g2.state.board.is_empty(), "offers posted on load")
	g2.free()
	_cleanup(g)


func test_queries_and_orders() -> void:
	var g := _game()
	eq(g.owned().map(func(c: CreatureData) -> int: return c.id), [1, 2], "owned by id")
	eq(g.retire(g.owned()[0]), "", "retired")
	eq(g.retired().size(), 1, "in the stable")
	eq(g.accept(&"t0_slime"), "", "accepted (both tier-0 templates are on the board)")
	var slime: CreatureData = g.owned()[0]
	eq(g.best_match(0), slime, "the slime matches the slime order best")
	check(g.order_check(0, slime)["ok"], "and meets it")
	eq(g.offer_days(&"t0_power"), g.state.day + 4, "offer deadline preview")
	eq(g.sell_price(slime), Market.sell_price(slime), "sell price")
	eq(g.deliver(0, slime), "", "delivered")
	check(g.owned().is_empty(), "handed over")
	_cleanup(g)


func test_breed_lays_an_egg_and_logs_it() -> void:
	var g := _game()
	var a: CreatureData = Fixtures.adult(g.state, "spider")
	var b: CreatureData = Fixtures.adult(g.state, "spider")
	eq(g.retire(a), "", "retire a")
	eq(g.retire(b), "", "retire b")
	var count := [0]
	g.changed.connect(func() -> void: count[0] += 1)
	var ap: int = g.state.ap
	eq(g.breed_reason(a, b), "", "a valid pair")
	check(g.compat_mark(a, b) in Inheritance.COMPAT_MARKS, "a mark: %s" % g.compat_mark(a, b))
	eq(g.breed(a, b), "", "bred")
	eq(g.state.ap, ap - Day.COST_BREED, "2 AP")
	var eggs: Array = g.state.creatures.values().filter(func(c: CreatureData) -> bool: return c.parents.size() == 2)
	eq(eggs.size(), 1, "one child")
	eq(eggs[0].stage, "egg", "an egg")
	eq(eggs[0].parents, PackedInt32Array([a.id, b.id]), "both parents")
	eq(count[0], 1, "changed once")
	eq(g.day_log[-1], "Bred %s and %s — an egg" % [g.who(a), g.who(b)], "logged")
	eq(g.breed(a, b), g.breed_reason(a, b), "refused with the Stable's reason")
	eq(count[0], 1, "no change on refusal")
	_cleanup(g)


func test_spark_rows_hide_grandparents_until_the_gene_scanner() -> void:
	var g := _game()
	Build.place_free(g.state, g.db.buildables[&"pen"], Vector2i(6, 0))  # room for everyone
	var gp1: CreatureData = Fixtures.adult(g.state, "spider")
	var gp2: CreatureData = Fixtures.adult(g.state, "spider")
	var p1: CreatureData = Fixtures.adult(g.state, "spider")
	var p2: CreatureData = Fixtures.adult(g.state, "spider")
	p1.parents = PackedInt32Array([gp1.id, gp2.id])
	for c: CreatureData in [gp1, gp2, p1, p2]:
		eq(g.retire(c), "", "retire #%d" % c.id)
	var child: CreatureData = Fixtures.adult(g.state, "spider")
	child.parents = PackedInt32Array([p1.id, p2.id])
	var rows: Array[Dictionary] = g.spark_rows(child)
	eq(rows.map(func(r: Dictionary) -> String: return r["who"]),
		[g.who(p1), g.who(gp1), g.who(gp2), g.who(p2)], "parent, its parents, then the other parent")
	eq(rows.map(func(r: Dictionary) -> bool: return r["hidden"]), [false, true, true, false], "grandparents hidden")
	eq(rows[0]["sparks"], p1.sparks, "a parent's own sparks")
	eq(g.spark_rows(p1)[0]["who"], "Own", "a retired creature's own sparks come first")
	g.state.upgrades.append(&"gene_scanner")
	eq(g.spark_rows(child).map(func(r: Dictionary) -> bool: return r["hidden"]), [false, false, false, false],
		"the Gene Scanner shows them")
	check(g.spark_rows(g.owned()[0]).is_empty(), "a starter has no sparks")
	_cleanup(g)


func test_spark_rows_skip_missing_ancestors() -> void:
	var g := _game()
	var p: CreatureData = Fixtures.adult(g.state, "spider")
	p.parents = PackedInt32Array([998])  # a grandparent the save lost
	eq(g.retire(p), "", "retire the parent")
	var child: CreatureData = Fixtures.adult(g.state, "spider")
	child.parents = PackedInt32Array([p.id, 999])  # a parent the save lost
	var rows: Array[Dictionary] = g.spark_rows(child)
	eq(rows.map(func(r: Dictionary) -> String: return r["who"]), [g.who(p)], "only the known parent")
	_cleanup(g)


func test_send_expedition_costs_ap_logs_and_lists_it() -> void:
	var g := _game()
	var a: CreatureData = g.owned()[0]
	var b: CreatureData = g.owned()[1]
	var count := [0]
	g.changed.connect(func() -> void: count[0] += 1)
	var ap: int = g.state.ap
	eq(g.expedition_reason(&"cave", [a, b]), "", "valid")
	eq(g.travel_reason(a), "", "a can travel")
	check(g.challenges_met(&"cave", [a, b]) >= 0, "a count")
	eq(g.send_expedition(&"cave", [a, b]), "", "sent")
	eq(g.state.ap, ap - Day.COST_EXPEDITION, "2 AP")
	eq(count[0], 1, "changed once")
	eq(g.day_log[-1], "Sent %s and %s to the Cave" % [g.who(a), g.who(b)], "logged")
	var today: Array[Dictionary] = g.expeditions_today()
	eq(today.size(), 1, "one expedition")
	eq(today[0]["location"].id, &"cave", "to the cave")
	eq(today[0]["team"], [a, b] as Array[CreatureData], "with both")
	eq(g.send_expedition(&"cave", [a]), g.expedition_reason(&"cave", [a]), "refused with the panel's reason")
	eq(count[0], 1, "no change on refusal")
	g.state.expeditions.append({"location": "atlantis", "team": [a.id]})
	eq(g.expeditions_today().size(), 1, "unknown locations skipped")
	_cleanup(g)


func test_market_buys_cost_money_and_log() -> void:
	var g := _game()
	var count := [0]
	g.changed.connect(func() -> void: count[0] += 1)
	g.state.money = 1000
	var feed: int = g.state.inventory.get("feed", 0)
	eq(g.buy_feed(5), "", "feed")
	eq(g.state.inventory["feed"], feed + 5, "stocked")
	eq(g.day_log[-1], "Bought 5 feed (-50 gold)", "logged feed")
	eq(g.buy_egg(&"slime"), "", "egg")
	eq(g.day_log[-1], "Bought a Slime egg (-60 gold)", "logged egg")
	eq(g.buy_upgrade(&"extra_pen"), "", "upgrade")
	eq(g.day_log[-1], "Bought Extra Pen (-300 gold)", "logged upgrade")
	eq(g.state.money, 1000 - 50 - 60 - 300, "paid")
	eq(count[0], 3, "changed per purchase")
	eq(g.buy_upgrade(&"extra_pen"), g.upgrade_reason(&"extra_pen"), "refused with the panel's reason")
	eq(count[0], 3, "no change on refusal")
	eq(g.eggs_on_offer().map(func(s: Species) -> StringName: return s.id), [&"slime", &"spider"], "price order")
	eq(g.upgrades_on_offer().map(func(u: UpgradeDef) -> StringName: return u.id),
		[&"extra_pen", &"extra_ap", &"gene_scanner"], "cost order")
	check(g.feed_reason(1) == "" and g.egg_reason(&"spider") != "", "reason wrappers")
	_cleanup(g)


func test_family_looks_up_parents_and_grandparents() -> void:
	var g := _game()
	var wild: CreatureData = g.owned()[0]
	eq(g.family(wild), {"parents": [], "grandparents": []}, "a wild creature")
	var gp := Fixtures.adult(g.state, "spider")
	var p1 := Fixtures.adult(g.state, "spider")
	p1.parents = PackedInt32Array([gp.id, 999])
	var p2 := Fixtures.adult(g.state, "spider")
	p2.status = CreatureData.Status.GONE  # sold: still in the pedigree
	var child := Fixtures.adult(g.state, "spider")
	child.parents = PackedInt32Array([p1.id, p2.id])
	var f: Dictionary = g.family(child)
	eq(f["parents"], [p1, p2], "both parents, the sold one too")
	eq(f["grandparents"], [[gp, null], []], "p1's parents (one lost), p2 wild")
	child.parents = PackedInt32Array([998, p1.id])
	eq(g.family(child)["parents"], [null, p1], "a lost parent is null")
	eq(g.family(child)["grandparents"], [[], [gp, null]], "and has no grandparents")
	_cleanup(g)


func test_every_action_saves() -> void:
	var g := _game()
	DirAccess.remove_absolute(SAVE)
	check(not g.has_save(), "no save yet")
	var c: CreatureData = g.owned()[0]
	eq(g.care(c, "play"), "", "played")
	check(g.has_save(), "saved after the action")
	eq(g.send_expedition(&"cave", [c]), "", "sent")
	var loaded := GameState.load_file(g.db, SAVE)
	eq(loaded.to_dict(), g.state.to_dict(), "the save is this moment: AP, cared, busy, expeditions")
	g.state.ap = 0
	var before := FileAccess.get_file_as_string(SAVE)
	eq(g.care(g.owned()[1], "feed"), "not enough action points", "refused")
	eq(FileAccess.get_file_as_string(SAVE), before, "a refusal doesn't save")
	_cleanup(g)


func test_new_game_replaces_the_save() -> void:
	var g := _game()
	g.end_day()
	eq(g.state.day, 2, "day 2 saved")
	g.new_game(Fixtures.db())
	eq(g.state.day, 1, "a fresh game")
	eq(GameState.load_file(g.db, SAVE).day, 1, "and it's the save now")
	_cleanup(g)


func test_a_failed_save_warns_but_the_action_stands() -> void:
	var g := _game()
	g.save_path = "user://no_such_dir/deeper/save.json"
	var c: CreatureData = g.owned()[0]
	eq(g.care(c, "play"), "", "the action still happens")
	_cleanup(g)


func test_the_runner_never_uses_the_players_save() -> void:
	check(Game.save_path != GameState.SAVE_PATH, "tests default to %s" % Game.save_path)


func test_continue_keeps_an_emptied_board() -> void:
	var g := _game()
	g.state.board.assign([g.state.board[0]])  # one offer left today
	eq(g.accept(g.state.board[0]), "", "accepted: the board is empty and saved")
	check(g.state.board.is_empty(), "empty")
	var left: Array = g.state.board.duplicate()
	var g2: Node = GameScript.new()
	g2.save_path = SAVE
	g2.start(Fixtures.db())
	eq(g2.state.board, left, "no fresh offers on the same day after a reload")
	g2.free()
	_cleanup(g)


func test_an_unreadable_save_is_kept_aside_not_overwritten() -> void:
	var g := _game()
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	check(g.has_save() and not g.can_continue(), "a file, but not a loadable one")
	g.start(Fixtures.db())
	eq(g.state.day, 1, "a fresh game")
	check(FileAccess.file_exists(SAVE + ".bad"), "the unreadable save was moved aside")
	eq(FileAccess.get_file_as_string(SAVE + ".bad"), "{ not json", "untouched")
	DirAccess.remove_absolute(SAVE + ".bad")
	_cleanup(g)


func test_new_game_keeps_a_backup_of_the_old_ranch() -> void:
	var g := _game()
	g.end_day()
	var old := FileAccess.get_file_as_string(SAVE)
	g.new_game(Fixtures.db())
	eq(FileAccess.get_file_as_string(SAVE + ".bak"), old, "the old ranch is kept as .bak")
	eq(g.state.day, 1, "fresh")
	DirAccess.remove_absolute(SAVE + ".bak")
	_cleanup(g)
