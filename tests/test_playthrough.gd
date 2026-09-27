extends TestSuite
## A scripted player plays 10 days on the real content with a fixed seed: accepts orders, delivers matches,
## keeps feed stocked, cares for babies, breeds once, sends Mine expeditions and trains with the AP left.
## Guards the loop end to end: no script errors (the runner catches them), sane money and reputation, at least
## one delivery, and a mid-day save that reloads to an identical state.

const SEED := 7
const DAYS := 10


func test_ten_scripted_days() -> void:
	var db := Db.load_dir()
	var rng := Fixtures.rng(SEED)
	var st := Day.new_game(load("res://data/new_game.tres"), db, rng)
	eq(Market.buy_egg(st, db, &"slime", rng), "", "day 1: buy a slime egg")
	var delivered := 0
	var bred := false
	for day in DAYS:
		for id in st.board.duplicate():
			OrderBoard.accept(st, db, id)
		delivered += _deliver_matches(st, db)
		if int(st.inventory.get("feed", 0)) < 2 and st.money >= 40:
			Market.buy_feed(st, 2)
		for c: CreatureData in _owned(st):
			if c.stage == "baby":
				Day.care(st, c, "play")
		if not bred:
			bred = _try_breed(st, db, rng)
		if day % 2 == 0:
			var team := _owned(st).filter(func(c: CreatureData) -> bool: return c.stage == "adult" and c.injured_days == 0)
			if not team.is_empty():
				Day.send_expedition(st, db, &"mine", team.slice(0, 2))
		for c: CreatureData in _owned(st):
			while st.ap > 0 and Day.train(st, db, c, "power", db.locations[&"mine"], rng) == "":
				pass
		if day == 4:
			var d := st.to_dict()
			var back := GameState.from_dict(JSON.parse_string(JSON.stringify(d)), db)
			eq(back.to_dict(), d, "a mid-day save reloads identically")
		Day.end_day(st, db, rng)
		check(st.money >= 0 and st.reputation >= 0, "day %d: money and reputation valid" % st.day)
	eq(st.day, DAYS + 1, "played %d days" % DAYS)
	check(delivered >= 1, "delivered at least one order (got %d)" % delivered)


static func _owned(st: GameState) -> Array:
	return st.creatures.values().filter(func(c: CreatureData) -> bool: return c.status == CreatureData.Status.OWNED)


static func _deliver_matches(st: GameState, db: Db) -> int:
	var n := 0
	for i in range(st.orders.size() - 1, -1, -1):
		var tmpl: OrderTemplate = db.orders[StringName(st.orders[i]["template"])]
		for c: CreatureData in _owned(st):
			if Orders.check(c, tmpl, db, st)["ok"] and Day.deliver(st, db, i, c) == "":
				n += 1
				break
	return n


## Retires and breeds the first two same-egg-group adults, once, when AP and pen space allow.
static func _try_breed(st: GameState, db: Db, rng: RandomNumberGenerator) -> bool:
	var adults := _owned(st).filter(func(c: CreatureData) -> bool:
		return c.stage == "adult" and not st.busy.has(c.id) and c.injured_days == 0)
	for i in adults.size():
		for j in range(i + 1, adults.size()):
			var a: CreatureData = adults[i]
			var b: CreatureData = adults[j]
			if db.species[a.species].egg_group != db.species[b.species].egg_group:
				continue
			if st.ap < Day.COST_BREED or not Market.has_pen_space(st):
				return false
			Day.retire(st, db, a, rng)
			Day.retire(st, db, b, rng)
			return Day.breed(st, db, a, b, rng) == ""
	return false
