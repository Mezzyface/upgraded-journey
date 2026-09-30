extends TestSuite

const SAVE := "user://test_day_report_save.json"


func _row(report: Dictionary, id: int) -> PackedStringArray:
	for r in report["creatures"]:
		if r["id"] == id:
			return r["changes"]
	return PackedStringArray()


func test_totals_and_creature_changes() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	var spider := Fixtures.adult(st, "spider", 200)
	var slime := Fixtures.adult(st, "slime", 200)
	slime.stage = "baby"
	var quiet := Fixtures.adult(st, "spider", 200)
	var morning := DayReport.snapshot(st)
	spider.stats["power"] += 24
	spider.mood += 10
	spider.moves.append(&"bite")
	st.money += 80
	st.reputation += 3
	var before_evening := DayReport.snapshot(st)
	slime.stage = "adult"
	for c in [spider, slime, quiet]:
		c.mood += 5  # resting overnight
	var egg := Fixtures.adult(st, "slime")
	egg.stage = "egg"
	var report := DayReport.compare(morning, before_evening, st, db)
	eq(report["totals"], {"gold": 80, "reputation": 3, "feed": 0}, "totals")
	eq(_row(report, spider.id), PackedStringArray(["Power +24", "Mood +10", "Learned Bite"]), "a trained creature")
	eq(_row(report, slime.id), PackedStringArray(["Grew up!"]), "overnight rest isn't a mood change")
	eq(_row(report, egg.id), PackedStringArray(["New"]), "a new egg")
	check(report["creatures"].all(func(r: Dictionary) -> bool: return r["id"] != quiet.id), "no row when nothing changed")


func test_hatching_evolving_injury_and_leaving() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	var egg := Fixtures.adult(st, "spider")
	egg.stage = "egg"
	var evolver := Fixtures.adult(st, "spider")
	var hurt := Fixtures.adult(st, "spider")
	var sold := Fixtures.adult(st, "spider")
	var morning := DayReport.snapshot(st)
	sold.status = CreatureData.Status.GONE
	var before_evening := DayReport.snapshot(st)
	egg.stage = "baby"
	evolver.species = &"spider_large"
	hurt.injured_days = 2
	var report := DayReport.compare(morning, before_evening, st, db)
	eq(_row(report, egg.id), PackedStringArray(["Hatched!"]), "hatched")
	check(_row(report, evolver.id)[0].begins_with("Evolved into"), "evolved: %s" % _row(report, evolver.id))
	eq(_row(report, hurt.id), PackedStringArray(["Injured"]), "injured")
	eq(_row(report, sold.id), PackedStringArray(["Left the shop"]), "sold or delivered")


func test_game_logs_the_days_actions_and_reports_the_evening() -> void:
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"], db.species[&"slime"]])
	setup.start_pen = db.buildables[&"pen"]
	Game.start_new(setup, db, 2)
	eq(Game.day_log.size(), 0, "a new day starts with an empty log")
	eq(Game.accept(&"t0_slime"), "", "accepted")
	var slime: CreatureData = Game.owned().filter(func(c: CreatureData) -> bool: return c.species == &"slime")[0]
	eq(Game.deliver(0, slime), "", "delivered")
	check(Game.day_log[0].begins_with("Accepted") and Game.day_log[1].begins_with("Delivered Slime"),
		"logged in order: %s" % Game.day_log)
	check(Game.day_log[1].contains("+80 gold"), "the reward is in the log")
	var day := Game.state.day
	Game.end_day()
	eq(Game.report["day"], day, "the report names the day that ended")
	eq(Game.report["totals"]["gold"], 80, "gold earned today")
	var customer := (Game.db.orders[&"t0_slime"] as OrderTemplate).customer
	eq(Game.report["events"][0], "Accepted %s's request" % customer, "the day log comes first")
	eq(_row(Game.report, slime.id), PackedStringArray(["Left the shop"]), "the delivered slime")
	eq(Game.day_log.size(), 0, "the next morning's log is empty")
	DirAccess.remove_absolute(SAVE)
