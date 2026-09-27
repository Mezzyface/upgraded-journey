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
