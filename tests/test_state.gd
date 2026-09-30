extends TestSuite

const PATH := "user://test_save.json"


func _sample() -> GameState:
	var st := GameState.new()
	st.day = 4
	st.money = 1234
	var a := Fixtures.adult(st, "spider", 210, 480)
	a.traits.append(&"tunnel_wise")
	a.moves.append(&"bite")
	a.personality = &"timid"
	a.status = CreatureData.Status.RETIRED
	a.sparks.append({"kind": "trait", "id": "tunnel_wise", "stars": 2})
	var b := Fixtures.adult(st, "slime")
	b.parents = PackedInt32Array([a.id, 99])
	b.pool.append({"kind": "stat", "id": "power", "stars": 3, "weight": 0.5})
	return st


func test_wild_creature_rolls_near_species_potential() -> void:
	var sp: Species = Fixtures.db().species[&"spider"]
	var c := CreatureData.wild(sp, 7, Fixtures.rng())
	eq(c.id, 7, "id")
	for s in Stats.NAMES:
		check(c.potential[s] >= 270 and c.potential[s] <= 330, "%s potential within ±10%%" % s)
		eq(c.stats[s], roundi(c.potential[s] * CreatureData.START_FRACTION), "%s starts at 20%%" % s)


func test_all_traits_merges_natural_without_duplicates() -> void:
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider_albino")
	c.traits.append(&"darksight")
	c.traits.append(&"tunnel_wise")
	eq(c.all_traits(Fixtures.db()), [&"darksight", &"tunnel_wise"], "merged")


func test_json_round_trip_restores_everything() -> void:
	var st := _sample()
	var d := st.to_dict()
	var back := GameState.from_dict(JSON.parse_string(JSON.stringify(d)), Fixtures.db())
	eq(back.to_dict(), d, "round trip")
	eq(typeof(back.creatures[1].stats["power"]), TYPE_INT, "ints stay ints")
	eq(typeof(back.creatures[2].pool[0]["stars"]), TYPE_INT, "stars stay ints")


func test_save_and_load_file_twice() -> void:
	var db := Fixtures.db()
	var st := _sample()
	eq(st.save(PATH), OK, "first save")
	st.money = 50
	eq(st.save(PATH), OK, "second save overwrites")
	var back := GameState.load_file(db, PATH)
	check(back != null, "loads")
	eq(back.money, 50, "latest save wins")
	check(not FileAccess.file_exists(PATH + ".tmp"), "temp file cleaned up")


func test_missing_corrupt_or_newer_save_returns_null() -> void:
	var db := Fixtures.db()
	check(GameState.load_file(db, "user://does_not_exist.json") == null, "missing")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	check(GameState.load_file(db, PATH) == null, "corrupt")
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": GameState.SAVE_VERSION + 1}))
	f.close()
	check(GameState.load_file(db, PATH) == null, "newer version")


func test_unknown_species_is_skipped_not_fatal() -> void:
	var d := _sample().to_dict()
	d["creatures"][0]["species"] = "removed_species"
	var back := GameState.from_dict(d, Fixtures.db())
	eq(back.creatures.size(), 1, "only the valid creature loads")
	check(back.creatures.has(2), "slime kept")


func test_unloadable_creatures_are_kept_as_orphans_and_survive_a_resave() -> void:
	var db := Fixtures.db()
	var d := _sample().to_dict()
	d["creatures"][0]["species"] = "removed_species"
	var loaded := GameState.from_dict(d, db)
	eq(loaded.orphans.size(), 1, "the unknown-species record is kept, not lost")
	eq(loaded.creatures.size(), 1, "still only the valid creature loads")

	# A content fix restores the species; the orphan comes back on the next load.
	var resaved := loaded.to_dict()
	var reloaded := GameState.from_dict(resaved, db)
	eq(reloaded.orphans.size(), 1, "orphan preserved through a resave")
	check(not reloaded.creatures.has(1), "and still not loaded without its species")

	var full_db: Db = Fixtures.db()
	full_db.add(Fixtures.species("removed_species", "spider", 1, "dark", "bug", []))
	var recovered := GameState.from_dict(resaved, full_db)
	check(recovered.creatures.has(1), "creature is back once its species exists again")
	eq(recovered.orphans.size(), 0, "no longer an orphan")


func test_malformed_creature_fields_are_skipped_not_fatal() -> void:
	var d := _sample().to_dict()
	var base: Dictionary = d["creatures"][0].duplicate(true)
	var bad_potential := base.duplicate(true)
	bad_potential["id"] = 101
	bad_potential["potential"] = 5
	var bad_stats := base.duplicate(true)
	bad_stats["id"] = 102
	bad_stats["stats"] = "x"
	var bad_id := base.duplicate(true)
	bad_id["id"] = null
	var bad_parents := base.duplicate(true)
	bad_parents["id"] = 103
	bad_parents["parents"] = 7
	d["creatures"].append(bad_potential)
	d["creatures"].append(bad_stats)
	d["creatures"].append(bad_id)
	d["creatures"].append(bad_parents)
	var back := GameState.from_dict(d, Fixtures.db())
	eq(back.creatures.size(), 2, "only the two well-formed creatures load")


func test_creatures_not_a_list_returns_null() -> void:
	var db := Fixtures.db()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": GameState.SAVE_VERSION, "creatures": null}))
	f.close()
	check(GameState.load_file(db, PATH) == null, "creatures: null")
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": GameState.SAVE_VERSION, "creatures": "nope"}))
	f.close()
	check(GameState.load_file(db, PATH) == null, "creatures: not a list")


func test_non_numeric_version_returns_null() -> void:
	var db := Fixtures.db()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": []}))
	f.close()
	check(GameState.load_file(db, PATH) == null, "version is an array")


func test_invalid_spark_and_pool_entries_are_dropped_pool_weight_defaults() -> void:
	var d := _sample().to_dict()
	var cd: Dictionary = d["creatures"][1]  # slime (id 2): pool already has one stat spark, weight 0.5
	cd["pool"].append({"kind": "bogus", "id": "power", "stars": 2, "weight": 1.0})
	cd["pool"].append({"kind": "stat", "id": "not_a_stat", "stars": 2, "weight": 1.0})
	cd["pool"].append({"kind": "trait", "id": "tunnel_wise", "stars": 2})  # no weight -> defaults to 1.0
	var back := GameState.from_dict(d, Fixtures.db())
	var pool: Array[Dictionary] = back.creatures[2].pool
	eq(pool.size(), 2, "bad kind and bad stat id dropped; valid entries kept")
	eq(pool[0]["weight"], 0.5, "original weight preserved")
	eq(pool[1]["weight"], 1.0, "missing weight defaults to 1.0")


func test_numeric_fields_are_clamped_on_load() -> void:
	var d := _sample().to_dict()
	var cd: Dictionary = d["creatures"][0]
	cd["potential"]["power"] = -5
	cd["potential"]["guard"] = 5000
	cd["stats"]["power"] = 999
	cd["mood"] = 500
	cd["breed_cooldown"] = -3
	cd["days_left"] = -1
	cd["age_days"] = -1
	cd["inspirations"] = -1
	var back := GameState.from_dict(d, Fixtures.db())
	var c: CreatureData = back.creatures[1]
	eq(c.potential["power"], 0, "potential clamped to 0")
	eq(c.potential["guard"], Stats.MAX, "potential clamped to max")
	eq(c.stats["power"], 0, "stat clamped to (clamped) potential")
	eq(c.mood, 100, "mood clamped to 100")
	eq(c.breed_cooldown, 0, "breed_cooldown >= 0")
	eq(c.days_left, 0, "days_left >= 0")
	eq(c.age_days, 0, "age_days >= 0")
	eq(c.inspirations, 0, "inspirations >= 0")


func test_invalid_status_or_stage_skips_creature() -> void:
	var d := _sample().to_dict()
	d["creatures"][0]["status"] = 99
	var back := GameState.from_dict(d, Fixtures.db())
	eq(back.creatures.size(), 1, "invalid status creature skipped")

	d = _sample().to_dict()
	d["creatures"][0]["stage"] = "cocoon"
	back = GameState.from_dict(d, Fixtures.db())
	eq(back.creatures.size(), 1, "invalid stage creature skipped")


func test_parents_capped_at_two() -> void:
	var d := _sample().to_dict()
	d["creatures"][0]["parents"] = [10, 20, 30, 40]
	var back := GameState.from_dict(d, Fixtures.db())
	eq(back.creatures[1].parents.size(), 2, "at most 2 parents kept")


func test_next_id_never_reuses_an_id() -> void:
	var d := _sample().to_dict()
	d["next_id"] = 1  # lower than the highest loaded creature id
	var back := GameState.from_dict(d, Fixtures.db())
	eq(back.next_id, 3, "next_id advances past the highest loaded id (2)")


func test_orphan_ids_are_never_reused() -> void:
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	c.id = 5
	var rec := c.to_dict()
	rec["species"] = "removed_species"
	var g := GameState.from_dict({"version": 1, "next_id": 1, "creatures": [rec]}, Fixtures.db())
	eq(g.orphans.size(), 1, "orphaned")
	check(g.new_id() > 5, "new ids skip past the orphan's id")


func test_wild_egg() -> void:
	var c := CreatureData.wild_egg(Fixtures.db().species[&"slime"], 3, Fixtures.rng())
	eq(c.stage, "egg", "an egg")
	eq(c.days_left, Inheritance.HATCH_DAYS, "hatch timer")
	check(c.pool.is_empty() and c.parents.is_empty(), "wild: no parents, no sparks")


func test_v2_fields_round_trip() -> void:
	var db := Fixtures.db()
	var st := _sample()
	st.board.assign([&"t0_slime", &"t0_power"])
	st.orders.append({"template": "t1_dark", "deadline_day": 9})
	st.recent_templates.assign([&"t0_slime"])
	st.inventory["feed"] = 3
	st.upgrades.append(&"extra_pen")
	st.expeditions.append({"location": "cave", "team": [2]})
	st.busy.append(2)
	st.cared.append(2)
	var b: CreatureData = st.creatures[2]
	b.injured_days = 2
	b.leanings["cheerful"] = 3
	var d := st.to_dict()
	var back := GameState.from_dict(JSON.parse_string(JSON.stringify(d)), db)
	eq(back.to_dict(), d, "round trip")


func test_version_1_save_loads_with_empty_v2_fields() -> void:
	var d := _sample().to_dict()
	d["version"] = 1
	for k in ["board", "orders", "recent_templates", "inventory", "upgrades", "expeditions", "busy", "cared"]:
		d.erase(k)
	for cd in d["creatures"]:
		cd.erase("injured_days")
		cd.erase("leanings")
	var path := "user://test_v1.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var g := GameState.load_file(Fixtures.db(), path)
	check(g != null, "version 1 loads")
	eq(g.creatures.size(), 2, "creatures")
	check(g.board.is_empty() and g.orders.is_empty() and g.inventory.is_empty(), "new fields empty")
	eq(g.creatures[2].injured_days, 0, "injured default")


func test_untrusted_save_values_are_clamped_and_deduped() -> void:
	var db := Fixtures.db()
	var d := _sample().to_dict()
	d["ap"] = 999
	d["money"] = -5
	d["reputation"] = -10
	d["day"] = -2
	d["expeditions"] = [{"location": "cave", "team": [2, 2, 2]}]
	d["busy"] = [2, 2]
	d["cared"] = [2, 2]
	d["board"] = ["t0_slime", "t0_slime"]
	d["upgrades"] = ["extra_pen", "extra_pen"]
	var back := GameState.from_dict(d, db)
	eq(back.ap, Day.BASE_AP + 1, "ap clamped to max")
	eq(back.money, 0, "money clamped to >= 0")
	eq(back.reputation, 0, "reputation clamped to >= 0")
	eq(back.day, 1, "day clamped to >= 1")
	eq(back.expeditions[0]["team"], [2], "expedition team de-duplicated")
	eq(back.busy, [2], "busy de-duplicated")
	eq(back.cared, [2], "cared de-duplicated")
	eq(back.board, [&"t0_slime"], "board de-duplicated")
	eq(back.upgrades, [&"extra_pen"], "upgrades de-duplicated")


func test_v2_fields_with_unknown_ids_or_bad_types_are_dropped() -> void:
	var d := _sample().to_dict()
	d["board"] = ["t0_slime", "gone_template", 5]
	d["orders"] = [{"template": "gone", "deadline_day": 3}, {"template": "t0_power", "deadline_day": "x"},
		"junk", {"template": "t0_slime", "deadline_day": 4}]
	d["inventory"] = {"feed": -4, "gold": "lots"}
	d["upgrades"] = ["extra_pen", "nope"]
	d["expeditions"] = [{"location": "atlantis", "team": [2]}, {"location": "cave", "team": [999, 2]}]
	d["busy"] = [2, 777, "x"]
	d["creatures"][1]["leanings"] = {"cheerful": 2, "bold": "many"}
	d["creatures"][1]["injured_days"] = -3
	var g := GameState.from_dict(d, Fixtures.db())
	eq(g.board, [&"t0_slime"], "board keeps known templates")
	eq(g.orders, [{"template": "t0_slime", "deadline_day": 4}], "orders keep valid entries")
	eq(g.inventory, {"feed": 0}, "inventory clamped, bad values dropped")
	eq(g.upgrades, [&"extra_pen"], "upgrades keep known ids")
	eq(g.expeditions, [{"location": "cave", "team": [2]}], "unknown location and creatures dropped")
	eq(g.busy, [2], "busy keeps known creatures")
	eq(g.creatures[2].leanings, {"cheerful": 2}, "leanings keep numbers")
	eq(g.creatures[2].injured_days, 0, "injured clamped")


func test_tutorial_step_is_saved_and_old_saves_skip_it() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	st.tutorial_step = 4
	eq(GameState.from_dict(st.to_dict(), db).tutorial_step, 4, "round trip")
	var old := st.to_dict()
	old.erase("tutorial_step")
	eq(GameState.from_dict(old, db).tutorial_step, Tutorial.STEPS.size(), "a save from before the tutorial: finished")
	var fresh := Day.new_game(load("res://data/new_game.tres"), db, Fixtures.rng())
	eq(fresh.tutorial_step, 0, "a new game starts it")
