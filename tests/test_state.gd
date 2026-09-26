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
