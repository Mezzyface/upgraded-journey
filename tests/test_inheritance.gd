extends TestSuite


func _retired(st: GameState, db: Db, species_id: String, seed_value := 1) -> CreatureData:
	var c := Fixtures.adult(st, species_id)
	Sparks.retire(c, db, Fixtures.rng(seed_value))
	return c


func test_roll_one_spark_per_source() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider_albino", 200, 900)
	c.stats["power"] = 650
	c.traits.append(&"tunnel_wise")
	c.moves.append(&"bite")
	c.personality = &"timid"
	var sparks := Sparks.roll(c, db, Fixtures.rng())
	eq(sparks.size(), 5, "stat + 2 traits + move + personality")
	eq(sparks[0], {"kind": "stat", "id": "power", "stars": 2}, "best stat is power at A")
	# learned traits first, then natural ones (CreatureData.all_traits order)
	eq(sparks.map(func(s: Dictionary) -> String: return s["id"]), ["power", "tunnel_wise", "darksight", "bite", "timid"], "ids")
	for s in sparks:
		check(s["stars"] >= 1 and s["stars"] <= 3, "stars in 1..3")


func test_stat_spark_stars_follow_grade() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	for pair in [[300, 1], [450, 2], [650, 2], [850, 3]]:
		var c := Fixtures.adult(st, "spider", pair[0], 999)
		eq(Sparks.roll(c, db, Fixtures.rng())[0]["stars"], pair[1], "stat %d" % pair[0])


func test_retire_locks_sparks() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := _retired(st, db, "spider")
	eq(c.status, CreatureData.Status.RETIRED, "retired")
	check(not c.sparks.is_empty(), "sparks locked")


func test_compatibility_marks() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var spider := _retired(st, db, "spider")
	var albino := _retired(st, db, "spider_albino")
	var slime := _retired(st, db, "slime")
	var antenna := Fixtures.adult(st, "slime_antenna")
	antenna.stats["heart"] = 300  # best stat differs from slime's, so no shared stat spark
	Sparks.retire(antenna, db, Fixtures.rng())
	eq(Inheritance.compatibility(spider, albino, db), 2, "same line+element+group = ◎")
	eq(Inheritance.compatibility(slime, antenna, db), 1, "same line+group, different element = ○")
	eq(Inheritance.compatibility(spider, slime, db), 0, "only a shared stat spark (score 1) = △")


func test_can_breed_reasons() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var a := _retired(st, db, "spider")
	var b := Fixtures.adult(st, "spider")
	check(Inheritance.can_breed(a, b, db) != "", "b not retired")
	Sparks.retire(b, db, Fixtures.rng())
	eq(Inheritance.can_breed(a, b, db), "", "ok")
	check(Inheritance.can_breed(a, a, db) != "", "same creature")
	var s := _retired(st, db, "slime")
	check(Inheritance.can_breed(a, s, db) != "", "egg groups differ")
	b.breed_cooldown = 1
	check(Inheritance.can_breed(a, b, db) != "", "cooldown")


func test_breed_makes_base_form_egg_with_pool_and_cooldowns() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var a := _retired(st, db, "spider")
	var b := _retired(st, db, "spider")
	var child := Inheritance.breed(a, b, st, db, Fixtures.rng())
	eq(child.species, &"spider", "base form")
	eq(child.stage, "egg", "egg")
	eq(child.days_left, Inheritance.HATCH_DAYS, "hatch timer")
	eq(child.parents, PackedInt32Array([a.id, b.id]), "parents recorded")
	check(st.get_creature(child.id) == child, "added to state")
	eq(child.pool.size(), a.sparks.size() + b.sparks.size(), "parents' sparks, no grandparents")
	for p in child.pool:
		eq(p["weight"], 1.5, "◎ multiplier on parent sparks")
	eq(a.breed_cooldown, Inheritance.COOLDOWN_DAYS, "cooldown a")
	eq(b.breed_cooldown, Inheritance.COOLDOWN_DAYS, "cooldown b")


func test_potential_is_average_plus_variance_and_capped() -> void:
	var db := Fixtures.db()
	for seed_value in 50:
		var st := GameState.new()
		var a := _retired(st, db, "spider")
		var b := _retired(st, db, "spider")
		a.potential["power"] = 400
		b.potential["power"] = 600
		a.potential["heart"] = 999
		b.potential["heart"] = 999
		var c := Inheritance.breed(a, b, st, db, Fixtures.rng(seed_value))
		var p: int = c.potential["power"]
		check(p >= 470 and p <= 650, "power %d within 500-30 .. 500+30+120" % p)
		check(c.potential["heart"] <= Stats.MAX, "heart capped at 999")


func test_evolved_child_only_when_both_parents_evolved() -> void:
	var db := Fixtures.db()
	var evolved := 0
	for seed_value in 400:
		var st := GameState.new()
		var a := _retired(st, db, "spider_albino")
		var b := _retired(st, db, "spider_large")
		if db.species[Inheritance.breed(a, b, st, db, Fixtures.rng(seed_value)).species].stage > 1:
			evolved += 1
		var c := _retired(st, db, "spider")
		var d := _retired(st, db, "spider")
		eq(Inheritance.breed(c, d, st, db, Fixtures.rng(seed_value)).species, &"spider", "base parents -> base child")
	check(evolved >= 20 and evolved <= 70, "about 10%% evolved children (got %d/400)" % evolved)


func test_grandparents_join_pool_at_half_weight_and_missing_ones_are_skipped() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var gp1 := _retired(st, db, "spider")
	var gp2 := _retired(st, db, "spider")
	var parent := _retired(st, db, "spider")
	parent.parents = PackedInt32Array([gp1.id, gp2.id])
	var other := _retired(st, db, "spider")
	other.parents = PackedInt32Array([424242, 434343])  # records no longer exist
	var child := Inheritance.breed(parent, other, st, db, Fixtures.rng())
	var expected := parent.sparks.size() + other.sparks.size() + gp1.sparks.size() + gp2.sparks.size()
	eq(child.pool.size(), expected, "parents + known grandparents only")
	# pool order: parent's sparks, then parent's grandparents, then other's sparks
	eq(child.pool[0]["weight"], 1.5, "parent weight = ◎ multiplier")
	eq(child.pool[parent.sparks.size()]["weight"], 0.75, "grandparent weight = 1.5 * 0.5")


func test_inspire_applies_every_kind_and_respects_caps() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 980, 990)
	c.stage = "baby"
	c.pool.assign([
		{"kind": "stat", "id": "power", "stars": 3, "weight": 2.0},
		{"kind": "trait", "id": "darksight", "stars": 3, "weight": 2.0},
		{"kind": "move", "id": "dig", "stars": 3, "weight": 2.0},
		{"kind": "personality", "id": "cheerful", "stars": 3, "weight": 2.0},
	])  # 0.5 x 2.0 = always procs
	var procs := Inheritance.inspire(c, db, Fixtures.rng())
	eq(procs.size(), 4, "all proc")
	eq(c.potential["power"], 999, "potential capped at 999")
	eq(c.stats["power"], 999, "stat capped at potential")
	eq(c.traits, [&"darksight"], "trait granted")
	check(c.moves.has(&"dig"), "move granted")
	eq(c.leanings.get("cheerful", 0), Leanings.SPARK_LEANING, "personality spark becomes a leaning")
	eq(c.inspirations, 1, "counted")
	Inheritance.inspire(c, db, Fixtures.rng())
	eq(c.traits.count(&"darksight"), 1, "trait not duplicated")


func test_inspire_after_json_round_trip() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var a := _retired(st, db, "spider_albino", 3)
	var b := _retired(st, db, "spider", 4)
	var child := Inheritance.breed(a, b, st, db, Fixtures.rng(5))
	var back := CreatureData.from_dict(JSON.parse_string(JSON.stringify(child.to_dict())))
	var n1 := Inheritance.inspire(child, db, Fixtures.rng(9)).size()
	var n2 := Inheritance.inspire(back, db, Fixtures.rng(9)).size()
	eq(n2, n1, "same procs from reloaded pool")


func test_darksight_can_pass_two_generations() -> void:
	# An Albino's natural Darksight reaches a grandchild that has no Albino parent.
	var db := Fixtures.db()
	var got_child := 0
	var got_grandchild := 0
	for seed_value in 60:
		var rng := Fixtures.rng(seed_value)
		var st := GameState.new()
		var albino := _retired(st, db, "spider_albino", seed_value)
		var mate := _retired(st, db, "spider", seed_value + 1000)
		var child := Inheritance.breed(albino, mate, st, db, rng)
		for i in 3:
			Inheritance.inspire(child, db, rng)
		if not child.traits.has(&"darksight"):
			continue
		got_child += 1
		child.stage = "adult"
		Sparks.retire(child, db, rng)
		var mate2 := _retired(st, db, "spider", seed_value + 2000)
		var grandchild := Inheritance.breed(child, mate2, st, db, rng)
		for i in 3:
			Inheritance.inspire(grandchild, db, rng)
		if grandchild.traits.has(&"darksight"):
			got_grandchild += 1
	check(got_child > 0, "some children inherit Darksight (%d/60)" % got_child)
	check(got_grandchild > 0, "some grandchildren inherit Darksight (%d)" % got_grandchild)


func test_only_owned_adults_can_retire() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	for stage in ["egg", "baby"]:
		c.stage = stage
		check(Sparks.can_retire(c) != "", "%s cannot retire" % stage)
		Sparks.retire(c, db, Fixtures.rng())  # logs an error by design
		eq(c.status, CreatureData.Status.OWNED, "%s stays owned" % stage)
		check(c.sparks.is_empty(), "%s gets no sparks" % stage)
	c.stage = "adult"
	eq(Sparks.can_retire(c), "", "adult can retire")
	Sparks.retire(c, db, Fixtures.rng())
	eq(c.status, CreatureData.Status.RETIRED, "retired")
	check(Sparks.can_retire(c) != "", "cannot retire twice")


func test_the_rest_reason_counts_days_properly() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	var a := Fixtures.adult(st, "spider")
	var b := Fixtures.adult(st, "spider")
	for c in [a, b]:
		Sparks.retire(c, db, Fixtures.rng())
	a.breed_cooldown = 1
	check(Inheritance.can_breed(a, b, db).ends_with("needs 1 more day of rest"), Inheritance.can_breed(a, b, db))
	a.breed_cooldown = 2
	check(Inheritance.can_breed(a, b, db).ends_with("needs 2 more days of rest"), Inheritance.can_breed(a, b, db))
