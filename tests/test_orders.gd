extends TestSuite


func _group(reqs: Array) -> RequirementGroup:
	var g := RequirementGroup.new()
	g.any_of.assign(reqs)
	return g


func _order(required: Array, bonus: Array = []) -> OrderTemplate:
	var o := OrderTemplate.new()
	o.id = &"test"
	o.required.assign(required)
	o.bonus.assign(bonus)
	return o


func _mining_order() -> OrderTemplate:
	return _order([
		_group([Fixtures.req("trait", "darksight"), Fixtures.req("trait", "glowing")]),
		_group([Fixtures.req("move_element", "earth"), Fixtures.req("move_kind", "damaging")]),
	])


func test_and_of_or_groups() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider_albino")  # natural darksight
	var r := Orders.check(c, _mining_order(), db, st)
	check(not r["ok"], "no moves yet")
	eq(r["missing"], PackedStringArray(["Earth move or damaging move"]), "missing list")
	c.moves.append(&"bite")  # beast, damaging
	check(Orders.check(c, _mining_order(), db, st)["ok"], "damaging move satisfies the second group")


func test_stat_species_line_personality() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider_large", 399)
	c.personality = &"timid"
	var power_b := _order([_group([Fixtures.req("stat", "power", Stats.Grade.B)])])
	check(not Orders.check(c, power_b, db, st)["ok"], "399 is C")
	c.stats["power"] = 400
	check(Orders.check(c, power_b, db, st)["ok"], "400 is B")
	check(Orders.check(c, _order([_group([Fixtures.req("species", "spider_large")])]), db, st)["ok"], "species")
	check(Orders.check(c, _order([_group([Fixtures.req("line", "spider")])]), db, st)["ok"], "line")
	check(not Orders.check(c, _order([_group([Fixtures.req("species", "spider")])]), db, st)["ok"], "other species")
	check(Orders.check(c, _order([_group([Fixtures.req("personality", "timid")])]), db, st)["ok"], "personality")


func test_bonus_needs_required_too() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 650)  # power A
	var o := _order(
		[_group([Fixtures.req("stat", "power", Stats.Grade.B)])],
		[_group([Fixtures.req("stat", "power", Stats.Grade.A)])])
	var r := Orders.check(c, o, db, st)
	check(r["ok"] and r["bonus"], "A power meets required and bonus")
	c.stats["power"] = 450
	r = Orders.check(c, o, db, st)
	check(r["ok"] and not r["bonus"], "B power: required only")
	var no_bonus := Orders.check(c, _order([_group([Fixtures.req("line", "spider")])]), db, st)
	check(not no_bonus["bonus"], "orders without bonus groups never report a bonus")


func test_only_owned_adults_can_be_delivered() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var o := _order([_group([Fixtures.req("line", "spider")])])
	var c := Fixtures.adult(st, "spider")
	c.stage = "baby"
	eq(Orders.check(c, o, db, st)["missing"], PackedStringArray(["must be grown up"]), "baby")
	c.stage = "adult"
	c.status = CreatureData.Status.RETIRED
	eq(Orders.check(c, o, db, st)["missing"], PackedStringArray(["retired creatures stay in the breeding stable"]), "retired")


func test_lineage() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var gps: Array[CreatureData] = []
	for i in 4:
		gps.append(Fixtures.adult(st, "spider"))
	var p1 := Fixtures.adult(st, "spider")
	p1.parents = PackedInt32Array([gps[0].id, gps[1].id])
	var p2 := Fixtures.adult(st, "spider_albino")
	p2.parents = PackedInt32Array([gps[2].id, gps[3].id])
	var c := Fixtures.adult(st, "spider")
	c.parents = PackedInt32Array([p1.id, p2.id])
	check(Orders.lineage(c, &"spider", 3, db, st), "3 generations of spider line")
	gps[3].species = &"slime"
	check(not Orders.lineage(c, &"spider", 3, db, st), "a slime grandparent breaks it")
	check(Orders.lineage(c, &"spider", 2, db, st), "2 generations still hold")
	var wild := Fixtures.adult(st, "spider")
	check(not Orders.lineage(wild, &"spider", 2, db, st), "no recorded parents")
	var lost := Fixtures.adult(st, "spider")
	lost.parents = PackedInt32Array([999999, 999998])
	check(not Orders.lineage(lost, &"spider", 2, db, st), "parent records missing")
