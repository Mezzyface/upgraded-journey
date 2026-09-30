extends TestSuite


func _state() -> GameState:
	var st := Fixtures.state()
	st.ap = Day.BASE_AP
	return st


func test_new_game() -> void:
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"], db.species[&"slime"]])
	var st := Day.new_game(setup, db, Fixtures.rng())
	eq(st.money, 500, "money")
	eq(st.inventory["feed"], 5, "feed")
	eq(st.creatures.size(), 2, "starting creatures")
	for c: CreatureData in st.creatures.values():
		eq(c.stage, "adult", "adults")
		check(db.personalities.has(c.personality), "a random personality")
	eq(st.ap, Day.BASE_AP, "AP")
	eq(st.board.size(), 2, "day 1 offers posted")


func test_refused_actions_change_nothing() -> void:
	var db := Fixtures.db()
	var st := _state()
	var c := Fixtures.adult(st, "spider")
	st.ap = 0
	var before := st.to_dict()
	eq(Day.train(st, db, c, "power", null, Fixtures.rng()), "not enough action points", "no AP to train")
	eq(Day.care(st, c, "play"), "not enough action points", "no AP to care")
	eq(Day.train(st, db, c, "charisma", null, Fixtures.rng()), "unknown stat", "bad stat")
	eq(Day.care(st, c, "sing"), "unknown care", "bad care")
	eq(Day.send_expedition(st, db, &"cave", [c]), "not enough action points", "no AP to travel")
	eq(Day.train(st, db, null, "power", null, Fixtures.rng()), "no such creature", "null creature")
	eq(st.to_dict(), before, "nothing changed")


func test_train_and_care() -> void:
	var db := Fixtures.db()
	var st := _state()
	var c := Fixtures.adult(st, "spider")
	eq(Day.train(st, db, c, "power", null, Fixtures.rng()), "", "trained")
	eq(st.ap, 4, "1 AP")
	check(c.stats["power"] > 200, "stat up")
	st.inventory["feed"] = 1
	c.mood = 50
	eq(Day.care(st, c, "feed"), "", "fed")
	eq(c.mood, 70, "+20 mood")
	eq(st.inventory["feed"], 0, "feed used")
	eq(Day.care(st, c, "feed"), "no feed left", "out of feed")
	eq(Day.care(st, c, "play"), "", "played")
	eq(c.mood, 85, "+15 mood")
	eq(st.ap, 2, "care costs 1 AP each")
	check(st.cared.has(c.id), "marked as cared for")


func test_baby_care_and_tired_training_shape_leanings() -> void:
	var db := Fixtures.db()
	var st := _state()
	st.ap = 10
	var b := Fixtures.adult(st, "spider")
	b.stage = "baby"
	st.inventory["feed"] = 1
	Day.care(st, b, "feed")
	Day.care(st, b, "play")
	b.mood = 20
	Day.train(st, db, b, "power", null, Fixtures.rng())
	eq(b.leanings, {"gentle": 1, "cheerful": 1, "stubborn": 1}, "leanings")


func test_away_injured_retired_and_eggs_are_refused() -> void:
	var db := Fixtures.db()
	var st := _state()
	var a := Fixtures.adult(st, "spider")
	var b := Fixtures.adult(st, "spider")
	eq(Day.send_expedition(st, db, &"cave", [a]), "", "sent")
	eq(st.ap, 3, "2 AP")
	check(st.busy.has(a.id), "away")
	eq(Day.train(st, db, a, "power", null, Fixtures.rng()), "busy on an expedition today", "away: no training")
	eq(Day.care(st, a, "play"), "busy on an expedition today", "away: no care")
	eq(Day.sell(st, a), "busy on an expedition today", "away: no selling")
	eq(Day.deliver(st, db, 0, a), "busy on an expedition today", "away: no delivery")
	eq(Day.retire(st, db, a, Fixtures.rng()), "busy on an expedition today", "away: no retiring")
	eq(Day.send_expedition(st, db, &"cave", [a]), "busy on an expedition today", "away: not twice")
	b.injured_days = 2
	eq(Day.train(st, db, b, "power", null, Fixtures.rng()), "injured for 2 more days", "injured: no training")
	eq(Day.care(st, b, "play"), "", "injured: care is fine")
	var egg := Fixtures.adult(st, "slime")
	egg.stage = "egg"
	eq(Day.care(st, egg, "play"), "eggs don't need care yet", "eggs")
	var r := Fixtures.adult(st, "slime")
	r.status = CreatureData.Status.RETIRED
	eq(Day.care(st, r, "play"), "retired creatures only breed", "pickled: no care")
	eq(Day.send_expedition(st, db, &"cave", [r]), "retired creatures only breed", "pickled: no expeditions")
	eq(Day.send_expedition(st, db, &"cave", []), "a team is 1 to 3 creatures", "empty team")
	eq(Day.send_expedition(st, db, &"atlantis", [b]), "unknown location", "unknown location")


func test_expedition_counts_as_care() -> void:
	var db := Fixtures.db()
	var st := _state()
	var baby := Fixtures.adult(st, "spider")
	baby.stage = "baby"
	Day.send_expedition(st, db, &"cave", [baby])
	Day.end_day(st, db, Fixtures.rng())
	eq(baby.leanings.get("bold", 0), 1, "leans Bold from the expedition")
	eq(baby.leanings.get("timid", 0), 0, "not also marked Timid for being uncared-for")


func test_breed_needs_pen_space_and_ap() -> void:
	var db := Fixtures.db()
	var st := _state()
	var a := Fixtures.adult(st, "spider")
	var b := Fixtures.adult(st, "spider")
	Sparks.retire(a, db, Fixtures.rng())
	Sparks.retire(b, db, Fixtures.rng())
	for i in 4:
		Fixtures.adult(st, "slime")
	eq(Day.breed(st, db, a, b, Fixtures.rng()), "the pens are full", "6 of 6")
	Build.place_free(st, st.content.buildables[&"pen"], Vector2i(6, 0))  # room for the egg
	st.ap = 1
	eq(Day.breed(st, db, a, b, Fixtures.rng()), "not enough action points", "needs 2 AP")
	st.ap = 5
	eq(Day.breed(st, db, a, b, Fixtures.rng()), "", "bred")
	eq(st.ap, 3, "2 AP spent")
	eq(Market.pen_used(st), 7, "the egg takes a pen")


func test_end_day_runs_the_evening() -> void:
	var db := Fixtures.db()
	var st := _state()
	st.day = 3
	st.reputation = 5
	var explorer := Fixtures.adult(st, "spider_albino", 300)
	Day.send_expedition(st, db, &"cave", [explorer])
	var baby := Fixtures.adult(st, "slime")
	baby.stage = "baby"
	baby.days_left = 4
	var hurt := Fixtures.adult(st, "spider")
	hurt.injured_days = 1
	hurt.mood = 95
	st.cared.append(hurt.id)
	st.orders.assign([{"template": "t0_slime", "deadline_day": 3}])
	var events := Day.end_day(st, db, Fixtures.rng())
	check(events[0].begins_with("Cave:"), "the expedition resolves first: %s" % events[0])
	eq(baby.leanings.get("timid", 0), 1, "an uncared-for baby leans Timid")
	eq(baby.days_left, 3, "growth ran")
	eq(hurt.mood, 100, "overnight rest, capped at 100")
	eq(hurt.injured_days, 0, "injury ticked")
	eq(st.reputation, 2, "the missed order cost 3")
	check(st.orders.is_empty(), "missed order removed")
	check(st.busy.is_empty() and st.cared.is_empty() and st.expeditions.is_empty(), "day lists cleared")
	eq(st.day, 4, "next day")
	eq(st.ap, Day.BASE_AP, "AP refilled")
	check(not st.board.is_empty(), "new offers posted")


func test_fresh_injuries_last_two_full_days() -> void:
	var db := Fixtures.db()
	var st := _state()
	var weak := Fixtures.adult(st, "spider", 50)  # fails both cave challenges
	Day.send_expedition(st, db, &"cave", [weak])
	Day.end_day(st, db, Fixtures.rng())
	check(Day.train(st, db, weak, "power", null, Fixtures.rng()) != "", "injured the next day")
	Day.end_day(st, db, Fixtures.rng())
	check(Day.train(st, db, weak, "power", null, Fixtures.rng()) != "", "still injured the day after")
	Day.end_day(st, db, Fixtures.rng())
	eq(Day.train(st, db, weak, "power", null, Fixtures.rng()), "", "healed on the third day")


func test_retire_refuses_while_injured() -> void:
	var db := Fixtures.db()
	var st := _state()
	var c := Fixtures.adult(st, "spider")
	c.injured_days = 2
	var before := st.to_dict()
	eq(Day.retire(st, db, c, Fixtures.rng()), "injured for 2 more days", "refused")
	eq(st.to_dict(), before, "nothing changed")


func test_breed_refuses_an_injured_parent() -> void:
	var db := Fixtures.db()
	var st := _state()
	var a := Fixtures.adult(st, "spider")
	var b := Fixtures.adult(st, "spider")
	Sparks.retire(a, db, Fixtures.rng())
	Sparks.retire(b, db, Fixtures.rng())
	a.injured_days = 1
	eq(Day.breed(st, db, a, b, Fixtures.rng()), "an injured creature needs rest", "refused")


func test_extra_ap_upgrade() -> void:
	var st := _state()
	st.upgrades.append(&"extra_ap")
	eq(Day.max_ap(st), 6, "6 AP a day")


func test_breed_reason_matches_what_breed_refuses() -> void:
	var db := Fixtures.db()
	var st := _state()
	var a := Fixtures.adult(st, "spider")
	var b := Fixtures.adult(st, "spider")
	var slime := Fixtures.adult(st, "slime")
	eq(Day.breed_reason(st, db, a, null), "no such creature", "missing")
	eq(Day.breed_reason(st, db, a, a), "needs two different creatures", "same creature")
	check(Day.breed_reason(st, db, a, b).ends_with("is not in the breeding stable"), "not retired")
	for c in [a, b, slime]:
		Sparks.retire(c, db, Fixtures.rng())
	eq(Day.breed_reason(st, db, a, slime), "their egg groups differ", "egg groups")
	b.injured_days = 1
	eq(Day.breed_reason(st, db, a, b), "an injured creature needs rest", "injured")
	b.injured_days = 0
	st.ap = 1
	eq(Day.breed_reason(st, db, a, b), "not enough action points", "AP")
	st.ap = 5
	eq(Day.breed_reason(st, db, a, b), "", "valid pair")
	eq(Day.breed(st, db, a, b, Fixtures.rng()), "", "breeds")
	check(Day.breed_reason(st, db, a, b).ends_with("more days of rest"), "cooldown after breeding")
	eq(Day.breed(st, db, a, b, Fixtures.rng()), Day.breed_reason(st, db, a, b), "breed refuses with the same reason")
