extends TestSuite

const OPEN := Rect2i(0, 0, 20, 10)  ## the buildable ground in these tests


func _ground(r := OPEN) -> Dictionary:
	var cells := {}
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			cells[Vector2i(x, y)] = true
	return cells


func test_can_place_checks_money_then_ground_then_overlap() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db, 0)
	st.money = 299
	eq(Build.can_place(st, db, &"pen", Vector2i(-1, 0), _ground()), "not enough money", "money first")
	st.money = 300
	eq(Build.can_place(st, db, &"pen", Vector2i(-1, 0), _ground()), "can't build there", "a cell off the ground")
	eq(Build.can_place(st, db, &"pen", Vector2i(15, 5), _ground()), "can't build there", "sticks out bottom-right")
	eq(Build.can_place(st, db, &"pen", Vector2i(0, 0), _ground()), "", "fits")
	Build.place_free(st, db.buildables[&"pen"], Vector2i(0, 0))
	eq(Build.can_place(st, db, &"pen", Vector2i(5, 4), _ground()), "overlaps the pen", "shares a corner tile")
	eq(Build.can_place(st, db, &"pen", Vector2i(6, 0), _ground()), "", "right next to it is fine")
	eq(Build.can_place(st, db, &"nope", Vector2i(6, 0), _ground()), "nothing like that to build", "unknown id")


func test_place_pays_and_numbers_each_pen() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db, 0)
	st.money = 700
	eq(Build.place(st, db, &"pen", Vector2i(0, 0), _ground()), "", "first")
	eq(Build.place(st, db, &"pen", Vector2i(6, 0), _ground()), "", "second")
	eq(st.money, 100, "paid 300 each")
	eq(st.placed.map(func(p: Dictionary) -> int: return p["id"]), [1, 2], "ids count up")
	eq(st.placed[1]["cell"], Vector2i(6, 0), "at its cell")
	eq(Build.place(st, db, &"pen", Vector2i(12, 0), _ground()), "not enough money", "refused")
	eq(st.money, 100, "a refusal costs nothing")
	Build.place_free(st, db.buildables[&"pen"], Vector2i(12, 0))
	eq(st.money, 100, "place_free doesn't pay")
	eq(Market.pen_capacity(st), 18, "capacity adds up over pens")


func test_new_creatures_fill_the_first_pen_with_room() -> void:
	var st := Fixtures.state(null, 2)
	var first: int = st.placed[0]["id"]
	var second: int = st.placed[1]["id"]
	var made: Array[CreatureData] = []
	for i in 7:
		made.append(Fixtures.adult(st, "spider"))
	eq(made.slice(0, 6).map(func(c: CreatureData) -> int: return c.pen), [first, first, first, first, first, first],
		"six in the first")
	eq(made[6].pen, second, "the seventh in the second")
	made[0].status = CreatureData.Status.GONE
	eq(Fixtures.adult(st, "slime").pen, first, "a sold creature's space is reused")
	var full := Fixtures.state(null, 0)
	eq(Fixtures.adult(full, "spider").pen, -1, "no pens: no pen")


func test_placed_pens_and_creature_pens_survive_a_save() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db, 2)
	var c := Fixtures.adult(st, "spider")
	var d := st.to_dict()
	d["placed"].append({"id": 9, "def": "gone_building", "x": 0, "y": 0})
	var back := GameState.from_dict(JSON.parse_string(JSON.stringify(d)), db)
	eq(back.placed.size(), 2, "unknown buildables dropped")
	eq(back.placed[1]["cell"], Vector2i(6, 0), "cells kept")
	eq(back.placed[1]["def"], &"pen", "def kept")
	eq(back.next_placed_id, 3, "next id kept")
	eq(back.get_creature(c.id).pen, c.pen, "the creature's pen kept")
	eq(Market.pen_capacity(back), 12, "a loaded state knows its content")


func test_old_saves_get_the_starting_pen_once() -> void:
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.start_pen = db.buildables[&"pen"]
	var st := GameState.new()  # an old save: creatures, no pens
	for i in 7:
		Fixtures.adult(st, "spider")
	Build.migrate(st, db, setup)
	eq(st.placed.size(), 1, "the starting pen")
	eq(st.placed[0]["cell"], setup.start_pen_cell, "where the old pen was")
	check(st.creatures.values().all(func(c: CreatureData) -> bool: return c.pen == st.placed[0]["id"]),
		"everyone moved in, even past capacity")
	Build.migrate(st, db, setup)
	eq(st.placed.size(), 1, "running it again changes nothing")


func test_a_new_game_starts_with_its_pen_and_creatures_in_it() -> void:
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.start_pen = db.buildables[&"pen"]
	setup.species.assign([db.species[&"spider"], db.species[&"slime"]])
	var st := Day.new_game(setup, db, Fixtures.rng())
	eq(st.placed.size(), 1, "one pen")
	check(st.creatures.values().all(func(c: CreatureData) -> bool: return c.pen == st.placed[0]["id"]), "they live in it")
