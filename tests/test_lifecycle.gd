extends TestSuite


func test_branching_evolution_picks_first_satisfied() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var dark := Fixtures.adult(st, "spider", 200)
	dark.traits.append(&"darksight")
	var strong := Fixtures.adult(st, "spider", 450)  # power B
	var both := Fixtures.adult(st, "spider", 450)
	both.traits.append(&"darksight")
	var plain := Fixtures.adult(st, "spider", 200)
	eq(Evolution.check(dark, db).id, &"spider_albino", "darksight branch")
	eq(Evolution.check(strong, db).id, &"spider_large", "power branch")
	eq(Evolution.check(both, db).id, &"spider_albino", "first listed wins")
	check(Evolution.check(plain, db) == null, "no branch met")


func test_personality_evolution_and_babies_never_evolve() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var slime := Fixtures.adult(st, "slime")
	slime.personality = &"cheerful"
	eq(Evolution.check(slime, db).id, &"slime_antenna", "cheerful slime")
	slime.stage = "baby"
	check(Evolution.check(slime, db) == null, "baby")


func test_min_age_condition() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 450)
	var e := Fixtures.evo(db.species[&"spider_large"], "power", Stats.Grade.B, null, null)
	e.min_age_days = 5
	c.age_days = 4
	check(not Evolution.met(c, e, db), "too young")
	c.age_days = 5
	check(Evolution.met(c, e, db), "old enough")


func test_egg_hatches_grows_and_is_inspired_three_times() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	c.stage = "egg"
	c.days_left = Inheritance.HATCH_DAYS
	var rng := Fixtures.rng()
	var stages: PackedStringArray = []
	for day in 6:
		Lifecycle.advance_day(c, db, rng)
		stages.append(c.stage)
	eq(stages, PackedStringArray(["egg", "baby", "baby", "baby", "baby", "adult"]), "timeline")
	eq(c.inspirations, 3, "hatch, mid-growth, adulthood")


func test_events_and_cooldowns() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	c.traits.append(&"darksight")
	c.breed_cooldown = 1
	var events := Lifecycle.advance_day(c, db, Fixtures.rng())
	eq(c.species, &"spider_albino", "evolved at end of day")
	check(events.size() == 1 and events[0].contains("evolved into Spider Albino"), "event: %s" % events)
	eq(c.breed_cooldown, 0, "cooldown ticks")
	Lifecycle.advance_day(c, db, Fixtures.rng())
	eq(c.breed_cooldown, 0, "never negative")


func test_gone_creatures_are_frozen() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	c.status = CreatureData.Status.GONE
	Lifecycle.advance_day(c, db, Fixtures.rng())
	eq(c.age_days, 0, "no ageing")
