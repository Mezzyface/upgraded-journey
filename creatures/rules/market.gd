class_name Market
extends RefCounted
## Buying feed, eggs and upgrades; selling creatures; pen space.

const FEED_PRICE := 10
const SELL_PER_GRADE := 20  ## sell price = this x the sum of the five stat grades (E=0 ... S=5)
const PEN_BASE := 6
const PEN_PER_UPGRADE := 3


static func pen_capacity(state: GameState) -> int:
	return PEN_BASE + (PEN_PER_UPGRADE if state.upgrades.has(&"extra_pen") else 0)


## Owned and retired creatures (eggs included) take a pen space; delivered or sold ones don't.
static func pen_used(state: GameState) -> int:
	return state.creatures.values().filter(
		func(c: CreatureData) -> bool: return c.status != CreatureData.Status.GONE).size()


static func has_pen_space(state: GameState) -> bool:
	return pen_used(state) < pen_capacity(state)


static func buy_feed(state: GameState, count := 1) -> String:
	if count < 1:
		return "buy at least one"
	if state.money < FEED_PRICE * count:
		return "not enough money"
	state.money -= FEED_PRICE * count
	state.inventory["feed"] = int(state.inventory.get("feed", 0)) + count
	return ""


## Eggs on sale: species with a market tier that the current reputation has unlocked.
static func egg_for_sale(state: GameState, db: Db, species_id: StringName) -> bool:
	var sp: Species = db.species.get(species_id)
	return sp != null and sp.market_tier >= 0 and sp.market_tier <= OrderBoard.tier(state.reputation)


static func buy_egg(state: GameState, db: Db, species_id: StringName, rng: RandomNumberGenerator) -> String:
	if not egg_for_sale(state, db, species_id):
		return "not sold here yet"
	var sp: Species = db.species[species_id]
	if state.money < sp.market_price:
		return "not enough money"
	if not has_pen_space(state):
		return "the pens are full"
	state.money -= sp.market_price
	state.add(CreatureData.wild_egg(sp, state.new_id(), rng))
	return ""


static func sell_price(c: CreatureData) -> int:
	var grades := 0
	for s in Stats.NAMES:
		grades += Stats.grade(c.stats[s])
	return grades * SELL_PER_GRADE


static func sell(state: GameState, c: CreatureData) -> String:
	if c == null:
		return "no such creature"
	if c.status == CreatureData.Status.RETIRED:
		return "retired creatures only breed"
	if c.status == CreatureData.Status.GONE:
		return "no longer in the shop"
	if state.busy.has(c.id):
		return "busy on an expedition today"
	state.money += sell_price(c)
	c.status = CreatureData.Status.GONE
	return ""


static func buy_upgrade(state: GameState, db: Db, upgrade_id: StringName) -> String:
	var u: UpgradeDef = db.upgrades.get(upgrade_id)
	if u == null:
		return "no such upgrade"
	if state.upgrades.has(upgrade_id):
		return "already bought"
	if OrderBoard.tier(state.reputation) < u.min_tier:
		return "needs reputation tier %d" % u.min_tier
	if state.money < u.cost:
		return "not enough money"
	state.money -= u.cost
	state.upgrades.append(upgrade_id)
	return ""
