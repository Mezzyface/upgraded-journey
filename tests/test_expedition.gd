extends TestSuite


func test_a_challenge_passes_if_any_member_meets_it() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var dark := Fixtures.adult(st, "spider_albino", 100)  # Darksight, guard D
	var tough := Fixtures.adult(st, "spider", 300)  # guard C
	var events := Expedition.resolve(st, db, &"cave", [dark.id, tough.id], Fixtures.rng())
	check(events[0].contains("2 of 2"), "both challenges passed: %s" % events[0])
	eq(dark.injured_days + tough.injured_days, 0, "no injuries")


func test_failed_challenges_injure_and_nothing_is_found() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
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
		var st := GameState.new()
		var a := Fixtures.adult(st, "spider_albino", 300)  # passes both challenges: two rolls
		Expedition.resolve(st, db, &"cave", [a.id], Fixtures.rng(seed_value))
		for c: CreatureData in st.creatures.values():
			if c.stage == "egg":
				eggs += 1
				if c.species == &"spider_albino":
					albinos += 1
		if st.money > 500:
			money_finds += 1
	check(eggs > 100 and eggs < 220, "about 40%% of 400 rolls are eggs (got %d)" % eggs)
	check(albinos > 0 and albinos * 4 < eggs, "Spider Albino is rare (%d of %d eggs)" % [albinos, eggs])
	check(money_finds > 0, "money rolls happen")


func test_full_pens_release_found_eggs() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
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
	var st := GameState.new()
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
	var st := GameState.new()
	eq(Expedition.resolve(st, db, &"atlantis", [1], Fixtures.rng()).size(), 0, "unknown location")
	eq(Expedition.resolve(st, db, &"cave", [42], Fixtures.rng()).size(), 0, "no such creatures")
