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


func test_a_loaded_save_without_offers_gets_them() -> void:
	var g := _game()
	g.state.board.clear()
	g.state.save(SAVE)
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
