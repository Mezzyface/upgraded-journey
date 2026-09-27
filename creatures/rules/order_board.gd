class_name OrderBoard
extends RefCounted
## Morning offers, accepting, delivering and missed deadlines. Reputation tiers gate templates and order slots.

const TIER_THRESHOLDS: PackedInt32Array = [0, 20, 50, 100, 200]
const RECENT_LIMIT := 5
const OFFERS_MIN := 2
const OFFERS_MAX := 4


static func tier(reputation: int) -> int:
	for t in range(TIER_THRESHOLDS.size() - 1, -1, -1):
		if reputation >= TIER_THRESHOLDS[t]:
			return t
	return 0


static func slots(state: GameState) -> int:
	return 2 + tier(state.reputation)


## Replaces the board with 2-4 offers from templates at or below the current tier, preferring ones not among
## the last RECENT_LIMIT offered. Never offers the same template twice.
static func post_offers(state: GameState, db: Db, rng: RandomNumberGenerator) -> void:
	var t := tier(state.reputation)
	var names: PackedStringArray = []
	for id: StringName in db.orders:
		if db.orders[id].min_rep_tier <= t:
			names.append(String(id))
	names.sort()  # independent of load order
	var eligible: Array = Array(names).map(func(n: String) -> StringName: return StringName(n))
	var want := rng.randi_range(OFFERS_MIN, OFFERS_MAX)
	state.board.clear()
	_take(state.board, eligible.filter(func(id: StringName) -> bool: return not state.recent_templates.has(id)), want, rng)
	_take(state.board, eligible.filter(func(id: StringName) -> bool: return not state.board.has(id)), want - state.board.size(), rng)
	for id in state.board:
		state.recent_templates.append(id)
	while state.recent_templates.size() > RECENT_LIMIT:
		state.recent_templates.remove_at(0)


static func accept(state: GameState, db: Db, template_id: StringName) -> String:
	if not state.board.has(template_id):
		return "not on the board"
	if state.orders.size() >= slots(state):
		return "no free order slots"
	state.board.erase(template_id)
	state.orders.append({"template": String(template_id), "deadline_day": state.day + db.orders[template_id].deadline_days})
	return ""


static func deliver(state: GameState, db: Db, index: int, c: CreatureData) -> String:
	if c == null:
		return "no such creature"
	if state.busy.has(c.id):
		return "busy on an expedition today"
	if index < 0 or index >= state.orders.size():
		return "no such order"
	var tmpl: OrderTemplate = db.orders[StringName(state.orders[index]["template"])]
	var r := Orders.check(c, tmpl, db, state)
	if not r["ok"]:
		return "missing: " + ", ".join(r["missing"])
	state.money += tmpl.reward_money + (tmpl.bonus_money if r["bonus"] else 0)
	state.reputation += tmpl.reward_rep
	c.status = CreatureData.Status.GONE
	state.orders.remove_at(index)
	return ""


## Evening: an order whose deadline day is today or earlier had its last chance today; it is removed and costs
## its reward_rep (reputation never goes below 0). Returns event lines.
static func expire(state: GameState, db: Db) -> PackedStringArray:
	var events: PackedStringArray = []
	for i in range(state.orders.size() - 1, -1, -1):
		if int(state.orders[i]["deadline_day"]) > state.day:
			continue
		var tmpl: OrderTemplate = db.orders[StringName(state.orders[i]["template"])]
		state.reputation = maxi(state.reputation - tmpl.reward_rep, 0)
		state.orders.remove_at(i)
		events.append("Missed %s's order (-%d reputation)" % [tmpl.customer, tmpl.reward_rep])
	return events


## Moves `count` random distinct items from `from` into `into`.
static func _take(into: Array[StringName], from: Array, count: int, rng: RandomNumberGenerator) -> void:
	var pool := from.duplicate()
	while count > 0 and not pool.is_empty():
		into.append(pool.pop_at(rng.randi() % pool.size()))
		count -= 1
