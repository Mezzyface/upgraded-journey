extends Node
## The one path from the UI to the rules (autoload "Game"). Holds the content, the game state and the RNG. Every
## action returns "" or the reason it was refused and emits `changed` only when it did something. Autosaves after
## each evening. start() is called by the shop scene, not _ready, so tests and tools never touch the player's save.

signal changed

const NEW_GAME := "res://data/new_game.tres"
const TRAINING_LOCATION := &"mine"  ## where the creature card trains (2b-2 adds a location choice)

var db: Db
var state: GameState
var rng := RandomNumberGenerator.new()
var save_path := GameState.SAVE_PATH
var day_start := {}  ## DayReport.snapshot this morning (not saved: saves happen in the evening, a load is a morning)
var day_log: PackedStringArray = []  ## today's actions, for the end-of-day summary
var report := {}  ## the last end_day: DayReport.compare plus "day" and "events" (the day log, then the evening)


## Loads the save at save_path, or starts a new game from NEW_GAME when there is none or it can't be read.
func start(content: Db = null) -> void:
	db = content if content else Db.load_dir()
	rng.randomize()
	state = GameState.load_file(db, save_path)
	if state == null:
		state = Day.new_game(load(NEW_GAME), db, rng)
	elif state.board.is_empty():
		OrderBoard.post_offers(state, db, rng)  # saves from before the order board had none
	Build.migrate(state, db, load(NEW_GAME))  # saves from before pens were placed
	_new_day()
	changed.emit()


func start_new(setup: NewGameSetup, content: Db, seed_value: int) -> void:
	db = content
	rng.seed = seed_value
	state = Day.new_game(setup, db, rng)
	_new_day()
	changed.emit()


func train(c: CreatureData, stat: String) -> String:
	return _did(Day.train(state, db, c, stat, db.locations.get(TRAINING_LOCATION), rng))


func care(c: CreatureData, kind: String) -> String:
	return _did(Day.care(state, c, kind))


func retire(c: CreatureData) -> String:
	var who := who(c)
	return _did(Day.retire(state, db, c, rng), "Retired %s to the stable" % who)


func sell(c: CreatureData) -> String:
	var who := who(c)
	var money := state.money
	var reason := Day.sell(state, c)
	return _did(reason, "Sold %s (%+d gold)" % [who, state.money - money])


func breed(a: CreatureData, b: CreatureData) -> String:
	var line := "Bred %s and %s — an egg" % [who(a), who(b)]
	return _did(Day.breed(state, db, a, b, rng), line)


func breed_reason(a: CreatureData, b: CreatureData) -> String:
	return Day.breed_reason(state, db, a, b)


## ◎, ○ or △ for the pair (Inheritance.COMPAT_MARKS).
func compat_mark(a: CreatureData, b: CreatureData) -> String:
	return Inheritance.COMPAT_MARKS[Inheritance.compatibility(a, b, db)]

func send_expedition(location_id: StringName, team: Array) -> String:
	var loc: Location = db.locations.get(location_id)
	var names := PackedStringArray(team.map(func(c: CreatureData) -> String: return who(c)))
	var line := "Sent %s to the %s" % [_and_list(names), loc.display_name if loc else String(location_id)]
	return _did(Day.send_expedition(state, db, location_id, team), line)


func expedition_reason(location_id: StringName, team: Array) -> String:
	return Day.expedition_reason(state, db, location_id, team)


func travel_reason(c: CreatureData) -> String:
	return Day.travel_reason(state, c)


func challenges_met(location_id: StringName, team: Array) -> int:
	return Expedition.challenges_met(state, db, location_id, team)


## Today's expeditions for the Expedition panel: {location: Location, team: Array[CreatureData]}; unknown locations
## and missing creatures are skipped.
func expeditions_today() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ex in state.expeditions:
		var loc: Location = db.locations.get(StringName(ex["location"]))
		if loc == null:
			continue
		var team: Array[CreatureData] = []
		for id in ex["team"]:
			var c := state.get_creature(int(id))
			if c:
				team.append(c)
		out.append({"location": loc, "team": team})
	return out

func buy_feed(count: int) -> String:
	var money := state.money
	var reason := Market.buy_feed(state, count)
	return _did(reason, "Bought %d feed (%+d gold)" % [count, state.money - money])


func buy_egg(species_id: StringName) -> String:
	var money := state.money
	var sp: Species = db.species.get(species_id)
	var reason := Market.buy_egg(state, db, species_id, rng)
	return _did(reason, "Bought a %s egg (%+d gold)" % [sp.display_name if sp else String(species_id), state.money - money])


func buy_upgrade(upgrade_id: StringName) -> String:
	var money := state.money
	var u: UpgradeDef = db.upgrades.get(upgrade_id)
	var reason := Market.buy_upgrade(state, db, upgrade_id)
	return _did(reason, "Bought %s (%+d gold)" % [u.display_name if u else String(upgrade_id), state.money - money])


func feed_reason(count: int) -> String:
	return Market.feed_reason(state, count)


func egg_reason(species_id: StringName) -> String:
	return Market.egg_reason(state, db, species_id)


func upgrade_reason(upgrade_id: StringName) -> String:
	return Market.upgrade_reason(state, db, upgrade_id)


## Species the Market sells at some tier (market_tier >= 0), cheapest first, then by name.
func eggs_on_offer() -> Array[Species]:
	var out: Array[Species] = []
	for sp: Species in db.species.values():
		if sp.market_tier >= 0:
			out.append(sp)
	out.sort_custom(func(a: Species, b: Species) -> bool:
		return a.market_price < b.market_price or (a.market_price == b.market_price and a.display_name < b.display_name))
	return out


## Every upgrade, cheapest first, then by name.
func upgrades_on_offer() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	out.assign(db.upgrades.values())
	out.sort_custom(func(a: UpgradeDef, b: UpgradeDef) -> bool:
		return a.cost < b.cost or (a.cost == b.cost and a.display_name < b.display_name))
	return out

func place(def_id: StringName, cell: Vector2i, buildable: Dictionary) -> String:
	var money := state.money
	var reason := Build.place(state, db, def_id, cell, buildable)
	var def: BuildableDef = db.buildables.get(def_id)
	return _did(reason, "Built a %s (%+d gold)" % [def.display_name.to_lower() if def else String(def_id), state.money - money])


func accept(template_id: StringName) -> String:
	var t: OrderTemplate = db.orders.get(template_id)
	return _did(OrderBoard.accept(state, db, template_id), "Accepted %s's request" % (t.customer if t else String(template_id)))


func deliver(index: int, c: CreatureData) -> String:
	var t := order_template(index) if index >= 0 and index < state.orders.size() else null
	var who := who(c)
	var money := state.money
	var rep := state.reputation
	var reason := Day.deliver(state, db, index, c)
	return _did(reason, "Delivered %s to %s (%+d gold, %+d reputation)" % [who, t.customer if t else "?",
		state.money - money, state.reputation - rep])


func end_day() -> PackedStringArray:
	var day := state.day
	var before_evening := DayReport.snapshot(state)
	var events := Day.end_day(state, db, rng)
	var err := state.save(save_path)
	if err != OK:
		events.append("Couldn't save the game (%s)" % error_string(err))
	report = DayReport.compare(day_start, before_evening, state, db)
	report["day"] = day
	report["events"] = day_log + events
	_new_day()
	changed.emit()
	return events


func owned() -> Array[CreatureData]:
	return _with_status(CreatureData.Status.OWNED)


func retired() -> Array[CreatureData]:
	return _with_status(CreatureData.Status.RETIRED)


func tier() -> int:
	return OrderBoard.tier(state.reputation)


func sell_price(c: CreatureData) -> int:
	return Market.sell_price(c)


## The card's Sparks tab: {who, sparks, hidden} for this creature's own sparks (once retired), then per parent the
## parent's sparks and its parents'. Grandparents are hidden until the Gene Scanner is owned. Ancestors missing from
## the state or without sparks are skipped.
func spark_rows(c: CreatureData) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not c.sparks.is_empty():
		rows.append({"who": "Own", "sparks": c.sparks, "hidden": false})
	var scanner := state.upgrades.has(&"gene_scanner")
	for pid in c.parents:
		var p := state.get_creature(pid)
		if p == null:
			continue
		if not p.sparks.is_empty():
			rows.append({"who": who(p), "sparks": p.sparks, "hidden": false})
		for gid in p.parents:
			var gp := state.get_creature(gid)
			if gp and not gp.sparks.is_empty():
				rows.append({"who": who(gp), "sparks": gp.sparks, "hidden": not scanner})
	return rows

func species_of(c: CreatureData) -> Species:
	return db.species.get(c.species)


func order_template(index: int) -> OrderTemplate:
	return db.orders.get(StringName(state.orders[index]["template"]))


func order_check(index: int, c: CreatureData) -> Dictionary:
	return Orders.check(c, order_template(index), db, state)


func group_met(c: CreatureData, g: RequirementGroup) -> bool:
	return c != null and Orders.group_met(c, g, db, state)


## The owned creature meeting the most required groups of order `index` (ties: lowest id); null when none owned.
func best_match(index: int) -> CreatureData:
	var best: CreatureData = null
	var best_n := -1
	for c in owned():
		var n := order_template(index).required.filter(func(g: RequirementGroup) -> bool: return group_met(c, g)).size()
		if n > best_n:
			best = c
			best_n = n
	return best


## The deadline day an offer would get if accepted today.
func offer_days(template_id: StringName) -> int:
	return state.day + OrderDifficulty.days(db.orders[template_id], db)


func _with_status(status: CreatureData.Status) -> Array[CreatureData]:
	var out: Array[CreatureData] = []
	for c: CreatureData in state.creatures.values():
		if c.status == status:
			out.append(c)
	out.sort_custom(func(a: CreatureData, b: CreatureData) -> bool: return a.id < b.id)
	return out


## Emits `changed` when the action happened (reason ""), noting `log_line` in today's log.
func _did(reason: String, log_line := "") -> String:
	if reason == "":
		if log_line != "":
			day_log.append(log_line)
		changed.emit()
	return reason


func _new_day() -> void:
	day_start = DayReport.snapshot(state)
	day_log.clear()


## "A", "A and B", "A, B and C".
static func _and_list(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


## "Spider #3", or "?" for null. Used by panels for creature names.
func who(c: CreatureData) -> String:
	if c == null:
		return "?"
	var sp := species_of(c)
	return "%s #%d" % [sp.display_name if sp else String(c.species), c.id]
