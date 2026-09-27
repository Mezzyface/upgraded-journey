extends TestSuite


func _order(required: Array, extra := 0) -> OrderTemplate:
	var o := Fixtures.order("x", 0, required, [], 100, 1, extra)
	return o


func test_fixture_orders() -> void:
	var db := Fixtures.db()
	eq(OrderDifficulty.days(db.orders[&"t0_slime"], db), 9, "line: 3 + 6")
	eq(OrderDifficulty.days(db.orders[&"t0_power"], db), 4, "Power D: 3 + 1")
	eq(OrderDifficulty.days(db.orders[&"t1_dark"], db), 6, "trait no base species has: 3 + 3")


func test_each_requirement_kind() -> void:
	var db := Fixtures.db()
	eq(OrderDifficulty.days(_order([Fixtures.group([Fixtures.req("species", "spider_albino")])]), db), 13, "evolved species: 3 + 6 + 4")
	eq(OrderDifficulty.days(_order([Fixtures.group([Fixtures.req("species", "spider")])]), db), 9, "base species: 3 + 6")
	eq(OrderDifficulty.days(_order([Fixtures.group([Fixtures.req("lineage", "spider", 0, 2)])]), db), 19, "lineage 2: 3 + 16")
	eq(OrderDifficulty.days(_order([Fixtures.group([Fixtures.req("stat", "power", Stats.Grade.S)])]), db), 11, "Power S: 3 + 8")
	eq(OrderDifficulty.days(_order([Fixtures.group([Fixtures.req("move_kind", "damaging")])]), db), 4, "move: 3 + 1")
	eq(OrderDifficulty.days(_order([Fixtures.group([Fixtures.req("personality", "gentle")])]), db), 5, "personality: 3 + 2")


func test_groups_cost_their_cheapest_option_and_extra_days_add() -> void:
	var db := Fixtures.db()
	var either := Fixtures.group([Fixtures.req("species", "slime"), Fixtures.req("stat", "power", Stats.Grade.D)])
	eq(OrderDifficulty.days(_order([either]), db), 4, "cheapest option: Power D")
	eq(OrderDifficulty.days(_order([either], 2), db), 6, "extra_days added")
	var o := _order([either])
	o.bonus.assign([Fixtures.group([Fixtures.req("lineage", "spider", 0, 3)])])
	eq(OrderDifficulty.days(o, db), 4, "bonus groups don't count")
