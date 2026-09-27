extends TestSuite


func test_pens_count_owned_retired_and_eggs() -> void:
	var st := GameState.new()
	for i in 5:
		Fixtures.adult(st, "spider")
	var gone := Fixtures.adult(st, "spider")
	gone.status = CreatureData.Status.GONE
	eq(Market.pen_used(st), 5, "delivered/sold creatures free their space")
	check(Market.has_pen_space(st), "5 of 6")
	Fixtures.adult(st, "slime").stage = "egg"
	check(not Market.has_pen_space(st), "6 of 6")
	st.upgrades.append(&"extra_pen")
	eq(Market.pen_capacity(st), 9, "extra pen")


func test_buy_feed() -> void:
	var st := GameState.new()
	st.money = 25
	eq(Market.buy_feed(st, 2), "", "bought")
	eq(st.money, 5, "paid")
	eq(st.inventory["feed"], 2, "stocked")
	eq(Market.buy_feed(st), "not enough money", "broke")
	eq(st.inventory["feed"], 2, "unchanged")


func test_buy_egg_rules() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	eq(Market.buy_egg(st, db, &"spider", Fixtures.rng()), "not sold here yet", "spider needs tier 1")
	eq(Market.buy_egg(st, db, &"spider_large", Fixtures.rng()), "not sold here yet", "never sold")
	eq(Market.buy_egg(st, db, &"slime", Fixtures.rng()), "", "slime egg")
	eq(st.money, 440, "paid 60")
	var egg: CreatureData = st.creatures.values()[-1]
	eq(egg.stage, "egg", "an egg")
	eq(egg.species, &"slime", "a slime")
	st.money = 10
	eq(Market.buy_egg(st, db, &"slime", Fixtures.rng()), "not enough money", "broke")
	st.money = 1000
	for i in 5:
		Fixtures.adult(st, "spider")
	eq(Market.buy_egg(st, db, &"slime", Fixtures.rng()), "the pens are full", "full")
	eq(st.money, 1000, "refusals cost nothing")


func test_sell() -> void:
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 200)  # five D grades
	eq(Market.sell_price(c), 5 * 1 * 20, "20 per grade level")
	eq(Market.sell(st, c), "", "sold")
	eq(st.money, 600, "paid")
	eq(c.status, CreatureData.Status.GONE, "gone")
	var r := Fixtures.adult(st, "spider")
	r.status = CreatureData.Status.RETIRED
	eq(Market.sell(st, r), "retired creatures only breed", "pickled")


func test_upgrades() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	eq(Market.buy_upgrade(st, db, &"extra_ap"), "needs reputation tier 1", "tier gate")
	eq(Market.buy_upgrade(st, db, &"extra_pen"), "", "bought")
	eq(st.money, 200, "paid 300")
	eq(Market.buy_upgrade(st, db, &"extra_pen"), "already bought", "once")
	st.reputation = 20
	eq(Market.buy_upgrade(st, db, &"extra_ap"), "not enough money", "400 > 200")
	eq(Market.buy_upgrade(st, db, &"nope"), "no such upgrade", "unknown")
