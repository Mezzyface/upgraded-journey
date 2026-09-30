extends TestSuite


func test_a_challenge_passes_if_any_member_meets_it() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	var dark := Fixtures.adult(st, "spider_albino", 100)  # Darksight, guard D
	var tough := Fixtures.adult(st, "spider", 300)  # guard C
	var events := Expedition.resolve(st, db, &"cave", [dark.id, tough.id], Fixtures.rng())
	check(events[0].contains("2 of 2"), "both challenges passed: %s" % events[0])
	eq(dark.injured_days + tough.injured_days, 0, "no injuries")


func test_failed_challenges_injure_and_nothing_is_found() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	var weak := Fixtures.adult(st, "spider", 50)  # no Darksight, guard E: fails both
	var events := Expedition.resolve(st, db, &"cave", [weak.id], Fixtures.rng())
	check(events[0].contains("0 of 2"), "none passed")
	eq(weak.injured_days, Expedition.INJURY_DAYS, "injured")
	eq(st.money, 500, "no loot without passes")
	eq(st.creatures.size(), 1, "no eggs")


func test_loot_is_eggs_or_money_and_albino_is_rare() -> void:
	var db := Fixtures.db()
	var eggs := 0
	var albinos := 0
	var money_finds := 0
	for seed_value in 200:
		var st := Fixtures.state(db)
		var a := Fixtures.adult(st, "spider_albino", 300)  # passes both challenges: two rolls
		Expedition.resolve(st, db, &"cave", [a.id], Fixtures.rng(seed_value))
		for c: CreatureData in st.creatures.values():
			if c.stage == "egg":
				eggs += 1
				if c.species == &"spider_albino":
					albinos += 1
		if st.money > 500:
			money_finds += 1
	check(eggs > 130 and eggs < 190, "about 40%% of 400 rolls are eggs (got %d)" % eggs)
	check(albinos > 0 and albinos * 4 < eggs, "Spider Albino is rare (%d of %d eggs)" % [albinos, eggs])
	check(money_finds > 0, "money rolls happen")


func test_full_pens_release_found_eggs() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	var a := Fixtures.adult(st, "spider_albino", 300)
	for i in 5:
		Fixtures.adult(st, "slime")
	var released := false
	for seed_value in 30:
		for e in Expedition.resolve(st, db, &"cave", [a.id], Fixtures.rng(seed_value)):
			if e.contains("released"):
				released = true
	check(released, "an egg was released")
	eq(Market.pen_used(st), 6, "the pens never overflow")


func test_members_gain_experience_and_babies_lean_bold() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	var baby := Fixtures.adult(st, "spider", 100, 500)
	baby.stage = "baby"
	var before := 0
	for s in Stats.NAMES:
		before += baby.stats[s]
	Expedition.resolve(st, db, &"cave", [baby.id], Fixtures.rng())
	var after := 0
	for s in Stats.NAMES:
		after += baby.stats[s]
	eq(after - before, Expedition.XP_GAIN, "+10 in one stat")
	eq(baby.leanings.get("bold", 0), 1, "leans Bold")


func test_unknown_location_or_missing_team_does_nothing() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	eq(Expedition.resolve(st, db, &"atlantis", [1], Fixtures.rng()).size(), 0, "unknown location")
	eq(Expedition.resolve(st, db, &"cave", [42], Fixtures.rng()).size(), 0, "no such creatures")


func test_challenges_met_is_the_count_resolve_reports() -> void:
	var db := Fixtures.db()
	for case in [["spider", 50, 0], ["spider_albino", 100, 1], ["spider", 300, 1]]:
		var st := Fixtures.state(db)
		var c := Fixtures.adult(st, case[0], case[1])
		eq(Expedition.challenges_met(st, db, &"cave", [c]), case[2], "%s at %d" % [case[0], case[1]])
		var events := Expedition.resolve(st, db, &"cave", [c.id], Fixtures.rng())
		check(events[0].contains("%d of 2" % case[2]), "resolve agrees: %s" % events[0])
	var st2 := Fixtures.state(db)
	var dark := Fixtures.adult(st2, "spider_albino", 100)
	var tough := Fixtures.adult(st2, "spider", 300)
	eq(Expedition.challenges_met(st2, db, &"cave", [dark, tough]), 2, "any member meets each")
	eq(Expedition.challenges_met(st2, db, &"cave", [null, dark]), 1, "nulls ignored")
	eq(Expedition.challenges_met(st2, db, &"cave", []), 0, "empty team")
	eq(Expedition.challenges_met(st2, db, &"atlantis", [dark]), 0, "unknown location")


func test_each_injured_creature_is_reported_once() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	var weak := Fixtures.adult(st, "spider", 50)  # fails both challenges: both injuries land on it
	var events := Expedition.resolve(st, db, &"cave", [weak.id], Fixtures.rng())
	var hurt := Array(events).filter(func(e: String) -> bool: return e.contains("was injured"))
	eq(hurt.size(), 1, "one line for one hurt creature: %s" % [events])
