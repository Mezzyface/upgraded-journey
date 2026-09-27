extends TestSuite


func _baby(st: GameState) -> CreatureData:
	var c := Fixtures.adult(st, "spider")
	c.stage = "baby"
	return c


func test_add_only_counts_for_babies() -> void:
	var st := GameState.new()
	var c := _baby(st)
	Leanings.add(c, &"cheerful")
	Leanings.add(c, &"cheerful", 2)
	eq(c.leanings, {"cheerful": 3}, "baby leans")
	c.stage = "adult"
	Leanings.add(c, &"bold")
	eq(c.leanings, {"cheerful": 3}, "adults don't")


func test_settle_picks_the_strongest_leaning() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := _baby(st)
	c.personality = &"timid"
	c.leanings = {"cheerful": 3, "gentle": 1}
	Leanings.settle(c, db, Fixtures.rng())
	eq(c.personality, &"cheerful", "strongest wins")


func test_settle_ties_and_empty_keep_current_or_pick_random() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := _baby(st)
	c.personality = &"timid"
	c.leanings = {"cheerful": 2, "gentle": 2}
	Leanings.settle(c, db, Fixtures.rng())
	eq(c.personality, &"timid", "a tie keeps the current personality")
	c.leanings = {}
	Leanings.settle(c, db, Fixtures.rng())
	eq(c.personality, &"timid", "no leanings keeps the current personality")
	c.personality = &""
	Leanings.settle(c, db, Fixtures.rng())
	check(db.personalities.has(c.personality), "none -> a random known personality (%s)" % c.personality)


func test_settle_ignores_unknown_personalities() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := _baby(st)
	c.personality = &"timid"
	c.leanings = {"evil_overlord": 9, "cheerful": 1}
	Leanings.settle(c, db, Fixtures.rng())
	eq(c.personality, &"cheerful", "the unknown leaning is skipped")


func test_personality_spark_adds_a_leaning_and_settles_at_adulthood() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := _baby(st)
	c.days_left = 1
	c.personality = &"timid"
	c.pool.assign([{"kind": "personality", "id": "cheerful", "stars": 3, "weight": 2.0}])  # always procs
	var events := Lifecycle.advance_day(c, db, Fixtures.rng())
	eq(c.stage, "adult", "grew up")
	eq(c.leanings.get("cheerful", 0), Leanings.SPARK_LEANING, "the spark became a leaning")
	eq(c.personality, &"cheerful", "settled at adulthood")
	check(events.size() == 1 and events[0].contains("grew up"), "event")
