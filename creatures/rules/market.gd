class_name Market
extends RefCounted
## Buying feed, eggs and upgrades; selling creatures; pen space.

const FEED_PRICE := 10
const SELL_BASE := 10  ## every creature sells for at least this
const SELL_PER_GRADE := 20  ## sell price = SELL_BASE + this x the sum of the five stat grades


## The creatures all placed pens hold together (Build, data/buildables/); 0 without content or pens.
static func pen_capacity(state: GameState) -> int:
	var total := 0
	if state.content == null:
		return total
	for p in state.placed:
		var def: BuildableDef = state.content.buildables.get(p["def"])
		if def:
			total += def.capacity
	return total


## Owned and retired creatures (eggs included) take a pen space; delivered or sold ones don't.
static func pen_used(state: GameState) -> int:
	return state.creatures.values().filter(
		func(c: CreatureData) -> bool: return c.status != CreatureData.Status.GONE).size()


static func has_pen_space(state: GameState) -> bool:
	return pen_used(state) < pen_capacity(state)


## Eggs on sale: species with a market tier that the current reputation has unlocked.
static func egg_for_sale(state: GameState, db: Db, species_id: StringName) -> bool:
	var sp: Species = db.species.get(species_id)
	return sp != null and sp.market_tier >= 0 and sp.market_tier <= OrderBoard.tier(state.reputation)


static func sell_price(c: CreatureData) -> int:
	var grades := 0
	for s in Stats.NAMES:
		grades += Stats.grade(c.stats[s])
	return SELL_BASE + grades * SELL_PER_GRADE


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


## "" when `count` feed can be bought now, otherwise why not.
static func feed_reason(state: GameState, count: int) -> String:
	if count < 1:
		return "buy at least one"
	if state.money < FEED_PRICE * count:
		return "not enough money"
	return ""


static func buy_feed(state: GameState, count := 1) -> String:
	var reason := feed_reason(state, count)
	if reason != "":
		return reason
	state.money -= FEED_PRICE * count
	state.inventory["feed"] = int(state.inventory.get("feed", 0)) + count
	return ""


## "" when an egg of `species_id` can be bought now, otherwise why not. A species the market sells at a higher
## reputation tier says which tier.
static func egg_reason(state: GameState, db: Db, species_id: StringName) -> String:
	var sp: Species = db.species.get(species_id)
	if sp == null or sp.market_tier < 0:
		return "not sold here yet"
	if not egg_for_sale(state, db, species_id):
		return "needs reputation tier %d" % sp.market_tier
	if state.money < sp.market_price:
		return "not enough money"
	if not has_pen_space(state):
		return "the pens are full"
	return ""


static func buy_egg(state: GameState, db: Db, species_id: StringName, rng: RandomNumberGenerator) -> String:
	var reason := egg_reason(state, db, species_id)
	if reason != "":
		return reason
	var sp: Species = db.species[species_id]
	state.money -= sp.market_price
	state.add(CreatureData.wild_egg(sp, state.new_id(), rng))
	return ""


## "" when `upgrade_id` can be bought now, otherwise why not.
static func upgrade_reason(state: GameState, db: Db, upgrade_id: StringName) -> String:
	var u: UpgradeDef = db.upgrades.get(upgrade_id)
	if u == null:
		return "no such upgrade"
	if state.upgrades.has(upgrade_id):
		return "already bought"
	if OrderBoard.tier(state.reputation) < u.min_tier:
		return "needs reputation tier %d" % u.min_tier
	if state.money < u.cost:
		return "not enough money"
	return ""


static func buy_upgrade(state: GameState, db: Db, upgrade_id: StringName) -> String:
	var reason := upgrade_reason(state, db, upgrade_id)
	if reason != "":
		return reason
	state.money -= db.upgrades[upgrade_id].cost
	state.upgrades.append(upgrade_id)
	return ""
