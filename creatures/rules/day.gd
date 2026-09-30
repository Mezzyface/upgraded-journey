class_name Day
extends RefCounted
## One shop day. new_game() builds a fresh state; each action costs action points (AP) and returns "" or the
## reason it was refused -- a refused action never changes state; end_day() runs the evening and the next morning.

const BASE_AP := 5
const COST_TRAIN := 1
const COST_CARE := 1
const COST_BREED := 2
const COST_EXPEDITION := 2
const FEED_MOOD := 20
const PLAY_MOOD := 15
const REST_MOOD := 10
const STUBBORN_MOOD := 30  ## training a baby below this mood leans it Stubborn
const CARE_KINDS: PackedStringArray = ["feed", "play"]


static func max_ap(state: GameState) -> int:
	return BASE_AP + (1 if state.upgrades.has(&"extra_ap") else 0)


static func new_game(setup: NewGameSetup, db: Db, rng: RandomNumberGenerator) -> GameState:
	var state := GameState.new()
	state.content = db
	if setup.start_pen:
		Build.place_free(state, setup.start_pen, setup.start_pen_cell)
	state.money = setup.money
	state.inventory["feed"] = setup.feed
	for sp in setup.species:
		if sp == null or not db.species.has(sp.id):
			continue
		var c := CreatureData.wild(db.species[sp.id], state.new_id(), rng)
		c.personality = Leanings.random_personality(db, rng)
		state.add(c)
	state.ap = max_ap(state)
	OrderBoard.post_offers(state, db, rng)
	return state


static func train(state: GameState, db: Db, c: CreatureData, stat: String, location: Location, rng: RandomNumberGenerator) -> String:
	if c == null:
		return "no such creature"
	if not Stats.NAMES.has(stat):
		return "unknown stat"
	var reason := Training.can_train(c)
	if reason == "":
		reason = _available(state, c)
	if reason == "":
		reason = _afford(state, COST_TRAIN)
	if reason != "":
		return reason
	var tired := c.mood < STUBBORN_MOOD
	Training.train(c, stat, location, db, rng)
	if tired:
		Leanings.add(c, &"stubborn")
	state.ap -= COST_TRAIN
	return ""


static func care(state: GameState, c: CreatureData, kind: String) -> String:
	if c == null:
		return "no such creature"
	if not CARE_KINDS.has(kind):
		return "unknown care"
	var reason := _owned(c)
	if reason == "" and c.stage == "egg":
		reason = "eggs don't need care yet"
	if reason == "" and state.busy.has(c.id):
		reason = "busy on an expedition today"
	if reason == "":
		reason = _afford(state, COST_CARE)
	if reason == "" and kind == "feed" and int(state.inventory.get("feed", 0)) <= 0:
		reason = "no feed left"
	if reason != "":
		return reason
	if kind == "feed":
		state.inventory["feed"] = int(state.inventory["feed"]) - 1
		c.mood = mini(c.mood + FEED_MOOD, 100)
		Leanings.add(c, &"gentle")
	else:
		c.mood = mini(c.mood + PLAY_MOOD, 100)
		Leanings.add(c, &"cheerful")
	if not state.cared.has(c.id):
		state.cared.append(c.id)
	state.ap -= COST_CARE
	return ""


## "" when a and b can breed right now, otherwise the reason. The Stable shows it before Breed is pressed, and
## breed() refuses with the same text.
static func breed_reason(state: GameState, db: Db, a: CreatureData, b: CreatureData) -> String:
	if a == null or b == null:
		return "no such creature"
	var reason := Inheritance.can_breed(a, b, db)
	if reason == "" and (a.injured_days > 0 or b.injured_days > 0):
		reason = "an injured creature needs rest"
	if reason == "" and not Market.has_pen_space(state):
		reason = "the pens are full"
	if reason == "":
		reason = _afford(state, COST_BREED)
	return reason


static func breed(state: GameState, db: Db, a: CreatureData, b: CreatureData, rng: RandomNumberGenerator) -> String:
	var reason := breed_reason(state, db, a, b)
	if reason != "":
		return reason
	Inheritance.breed(a, b, state, db, rng)
	state.ap -= COST_BREED
	return ""


static func send_expedition(state: GameState, db: Db, location_id: StringName, team: Array) -> String:
	if not db.locations.has(location_id):
		return "unknown location"
	if team.is_empty() or team.size() > Expedition.MAX_TEAM:
		return "a team is 1 to 3 creatures"
	var ids: Array = []
	for member in team:
		var c: CreatureData = member
		if c == null:
			return "no such creature"
		if ids.has(c.id):
			return "a creature can only go once"
		var reason := _owned(c)
		if reason == "" and c.stage == "egg":
			reason = "eggs can't travel"
		if reason == "":
			reason = _available(state, c)
		if reason != "":
			return reason
		ids.append(c.id)
	var cost_reason := _afford(state, COST_EXPEDITION)
	if cost_reason != "":
		return cost_reason
	state.expeditions.append({"location": String(location_id), "team": ids})
	for id in ids:
		state.busy.append(id)
		if not state.cared.has(id):
			state.cared.append(id)
	state.ap -= COST_EXPEDITION
	return ""


static func retire(state: GameState, db: Db, c: CreatureData, rng: RandomNumberGenerator) -> String:
	if c == null:
		return "no such creature"
	var reason := _available(state, c)
	if reason == "":
		reason = Sparks.can_retire(c)
	if reason != "":
		return reason
	Sparks.retire(c, db, rng)
	return ""


static func sell(state: GameState, c: CreatureData) -> String:
	return Market.sell(state, c)


static func deliver(state: GameState, db: Db, index: int, c: CreatureData) -> String:
	return OrderBoard.deliver(state, db, index, c)


## The evening, then the next morning. Returns the day summary's event lines.
static func end_day(state: GameState, db: Db, rng: RandomNumberGenerator) -> PackedStringArray:
	var events: PackedStringArray = []
	for c: CreatureData in state.creatures.values():  # first, so a fresh injury lasts two full days
		if c.status == CreatureData.Status.OWNED:
			c.injured_days = maxi(c.injured_days - 1, 0)
	for ex in state.expeditions:
		events.append_array(Expedition.resolve(state, db, StringName(ex["location"]), ex["team"], rng))
	state.expeditions.clear()
	for c: CreatureData in state.creatures.values():
		if c.status == CreatureData.Status.OWNED and c.stage == "baby" and not state.cared.has(c.id):
			Leanings.add(c, &"timid")
	for c: CreatureData in state.creatures.values():
		events.append_array(Lifecycle.advance_day(c, db, rng))
		if c.status == CreatureData.Status.OWNED:
			c.mood = mini(c.mood + REST_MOOD, 100)
	events.append_array(OrderBoard.expire(state, db))
	state.busy.clear()
	state.cared.clear()
	state.day += 1
	state.ap = max_ap(state)
	OrderBoard.post_offers(state, db, rng)
	return events


static func _owned(c: CreatureData) -> String:
	if c.status == CreatureData.Status.RETIRED:
		return "retired creatures only breed"
	if c.status == CreatureData.Status.GONE:
		return "no longer in the shop"
	return ""


static func _available(state: GameState, c: CreatureData) -> String:
	if state.busy.has(c.id):
		return "busy on an expedition today"
	if c.injured_days > 0:
		return "injured for %d more days" % c.injured_days
	return ""


static func _afford(state: GameState, cost: int) -> String:
	return "" if state.ap >= cost else "not enough action points"
