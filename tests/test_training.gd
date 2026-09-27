extends TestSuite


func test_gain_uses_personality_and_mood() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 200, 500)
	c.personality = &"timid"  # favours speed, dislikes power
	var r := Training.train(c, "speed", null, db, Fixtures.rng())
	eq(r["gain"], 50, "40 * 1.25 at mood 50")
	eq(c.stats["speed"], 250, "speed raised")
	eq(c.mood, 40, "mood cost")
	var p := Training.train(c, "power", null, db, Fixtures.rng())
	eq(p["gain"], 27, "40 * 0.75 * (0.5 + 0.40)")


func test_mood_multiplier_is_clamped_even_if_set_externally() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 200, 500)
	c.mood = 150  # e.g. from a hand-edited save; must not inflate the gain multiplier past 1.5
	var r := Training.train(c, "guard", null, db, Fixtures.rng())
	eq(r["gain"], 60, "40 * 1.5 (mood clamped to 100), no favored/disfavored stat")


func test_gain_never_exceeds_potential() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 490, 500)
	var r := Training.train(c, "guard", null, db, Fixtures.rng())
	eq(r["gain"], 10, "capped gain")
	eq(c.stats["guard"], 500, "at potential")
	Training.train(c, "guard", null, db, Fixtures.rng())
	eq(c.stats["guard"], 500, "still at potential")


func test_moves_unlock_at_stat_grades() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 200, 500)  # power 200 = D, speed 200 = D
	var r := Training.train(c, "speed", null, db, Fixtures.rng())  # speed -> 240, still D
	eq(r["moves"], [&"bite"], "bite unlocks at power D")
	r = Training.train(c, "speed", null, db, Fixtures.rng())  # speed crosses 250 = C
	eq(r["moves"], [&"web"], "web unlocks at speed C")
	eq(c.moves, [&"bite", &"web"], "both known, no duplicates")


func test_location_teaches_its_trait_once() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	var mine: Location = db.locations[&"mine"]  # trait_chance 1.0 in fixtures
	var r := Training.train(c, "power", mine, db, Fixtures.rng())
	eq(r["trait"], "tunnel_wise", "learned at the mine")
	r = Training.train(c, "power", mine, db, Fixtures.rng())
	eq(r["trait"], "", "not learned twice")
	eq(c.traits.count(&"tunnel_wise"), 1, "one copy")


func test_only_active_creatures_can_train() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	eq(Training.can_train(c), "", "owned adult")
	c.stage = "baby"
	eq(Training.can_train(c), "", "babies can train")
	c.stage = "egg"
	check(Training.can_train(c) != "", "eggs cannot")
	c.stage = "adult"
	Sparks.retire(c, db, Fixtures.rng())
	check(Training.can_train(c) != "", "retired creatures cannot")
	var r := Training.train(c, "power", null, db, Fixtures.rng())  # logs an error by design
	eq(r["gain"], 0, "no gain")
	eq(c.stats["power"], 200, "stat unchanged")
	eq(c.mood, 50, "mood untouched")
