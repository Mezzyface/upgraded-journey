extends TestSuite
## A scripted player plays 10 days on the real content with a fixed seed: buys two slime eggs on day 1 and
## raises them without ever selling or delivering them, accepts orders, delivers matches with any other owned
## adult, keeps feed stocked, cares for babies, breeds the two raised slimes once they're grown, sends Mine
## expeditions and trains with the AP left.
## Guards the loop end to end: no script errors (the runner catches them), sane money and reputation, at least
## one delivery, a bred pair, and a mid-day save that reloads to an identical state.

const SEED := 7
const DAYS := 10


func test_ten_scripted_days() -> void:
	var db := Db.load_dir()
	var rng := Fixtures.rng(SEED)
	var st := Day.new_game(load("res://data/new_game.tres"), db, rng)
	var keep: Array[int] = []
	var id_a := st.next_id
	eq(Market.buy_egg(st, db, &"slime", rng), "", "day 1: buy a slime egg to raise")
	keep.append(id_a)
	var id_b := st.next_id
	eq(Market.buy_egg(st, db, &"slime", rng), "", "day 1: buy a second slime egg to raise")
	keep.append(id_b)
	var delivered := 0
	var bred := false
	for day in DAYS:
		for id in st.board.duplicate():
			OrderBoard.accept(st, db, id)
		delivered += _deliver_matches(st, db, keep)
		if int(st.inventory.get("feed", 0)) < 2 and st.money >= 40:
			Market.buy_feed(st, 2)
		for c: CreatureData in _owned(st):
			if c.stage == "baby":
				Day.care(st, c, "play")
		if not bred:
			bred = _try_breed(st, db, rng, keep)
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
	check(bred, "bred once during the 10 days")


static func _owned(st: GameState) -> Array:
	return st.creatures.values().filter(func(c: CreatureData) -> bool: return c.status == CreatureData.Status.OWNED)


## Delivers matching orders with any owned adult except the two creatures in `keep`, which the scripted
## player is raising to breed and never sells or delivers.
static func _deliver_matches(st: GameState, db: Db, keep: Array[int]) -> int:
	var n := 0
	for i in range(st.orders.size() - 1, -1, -1):
		var tmpl: OrderTemplate = db.orders[StringName(st.orders[i]["template"])]
		for c: CreatureData in _owned(st):
			if keep.has(c.id):
				continue
			if Orders.check(c, tmpl, db, st)["ok"] and Day.deliver(st, db, i, c) == "":
				n += 1
				break
	return n


## Retires and breeds the two kept creatures once both are grown, owned, idle, uninjured, same-egg-group
## adults and AP/pen space allow it. If they aren't ready yet, does nothing this day; the caller retries on a
## later day rather than giving up for good.
static func _try_breed(st: GameState, db: Db, rng: RandomNumberGenerator, keep: Array[int]) -> bool:
	var a := st.get_creature(keep[0])
	var b := st.get_creature(keep[1])
	if a == null or b == null:
		return false
	if a.status != CreatureData.Status.OWNED or b.status != CreatureData.Status.OWNED:
		return false
	if a.stage != "adult" or b.stage != "adult":
		return false
	if st.busy.has(a.id) or st.busy.has(b.id) or a.injured_days > 0 or b.injured_days > 0:
		return false
	if db.species[a.species].egg_group != db.species[b.species].egg_group:
		return false
	if st.ap < Day.COST_BREED or not Market.has_pen_space(st):
		return false
	Day.retire(st, db, a, rng)
	Day.retire(st, db, b, rng)
	return Day.breed(st, db, a, b, rng) == ""
