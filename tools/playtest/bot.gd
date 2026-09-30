class_name PlaytestBot
extends RefCounted
## A scripted player for tools/playtest (docs/superpowers/specs/2026-09-30-bot-playtest-design.md). play_day() plays one
## day through the farm's popups like a player: the Orders board (deliver, then accept), the Market (feed, upgrades,
## eggs, a pen through the placer), the Stable (retire two adults on their cards, breed), the Expedition panel, the
## creature cards (care for babies, train), then End Day and Continue. It decides from the game state the way a player
## reads the screen; every change goes through a popup's button or method. What the UI can't do lands in `gaps`.

const FEED_MIN := 3
const MONEY_BUFFER := 200
const MAX_STEPS := 30  ## per day, against loops on a refused action

var shop: Control
var gaps: PackedStringArray = []
var reload_on_day := -1  ## on this day, after sending an expedition, save-and-reload through Game.start and compare
var _reload_result := "not run"
var _did: PackedStringArray = []
var _kinds_filled := {}  ## requirement kind -> true, from delivered orders
var _evolved := {}  ## line -> {species id: true}


func _init(farm: Control) -> void:
	shop = farm


func play_day() -> Dictionary:
	_did.clear()
	var day := Game.state.day
	var gold := Game.state.money
	await _orders()
	await _market()
	await _breed()
	await _expedition()
	if day == reload_on_day:
		_reload_mid_day()
	await _care_and_train()
	var ap_left := Game.state.ap
	var orders := Game.state.orders.size()
	var before := species_now()
	var events := await _end_day()
	note_evolutions(before)
	return {"day": day, "gold": Game.state.money, "gold_delta": Game.state.money - gold, "rep": Game.state.reputation,
		"tier": Game.tier(), "owned": Game.owned().size(), "retired": Game.retired().size(),
		"eggs": Game.owned().filter(func(c: CreatureData) -> bool: return c.stage == "egg").size(),
		"orders": orders, "delivered": Array(_did).filter(func(a: String) -> bool: return a.begins_with("delivered")).size(),
		"missed": Array(events).filter(func(e: String) -> bool: return e.begins_with("Missed")).size(),
		"ap_left": ap_left, "actions": _did.duplicate(), "events": events}


func goals() -> Dictionary:
	var kinds: Array = _kinds_filled.keys()
	kinds.sort()
	var three_gen := Game.state.creatures.values().any(func(c: CreatureData) -> bool:
		var f := Game.family(c)
		return (f["grandparents"] as Array).any(func(g: Array) -> bool: return g.any(func(x) -> bool: return x != null)))
	var branching: PackedStringArray = []
	for line in _evolved:
		if (_evolved[line] as Dictionary).size() >= 2:
			branching.append("%s (%s)" % [line, ", ".join(PackedStringArray((_evolved[line] as Dictionary).keys()))])
	var never: Array = []
	for t: OrderTemplate in Game.db.orders.values():
		for g in t.required:
			for r in g.any_of:
				if r and not _kinds_filled.has(r.kind) and not never.has(r.kind):
					never.append(r.kind)
	never.sort()
	return {"order kinds filled": ", ".join(PackedStringArray(kinds)) if not kinds.is_empty() else "none",
		"order kinds never filled": ", ".join(PackedStringArray(never)) if not never.is_empty() else "none",
		"spark carried across two generations": "not measured",
		"mid-day reload": _reload_result,
		"3-generation pedigree": "yes" if three_gen else "no",
		"evolutions": ", ".join(PackedStringArray(_evolved.keys())) if not _evolved.is_empty() else "none",
		"branching evolution": ", ".join(branching) if not branching.is_empty() else "no"}


## Species of every creature now, to see evolutions after the evening.
func species_now() -> Dictionary:
	var out := {}
	for c: CreatureData in Game.state.creatures.values():
		out[c.id] = c.species
	return out


func note_evolutions(before: Dictionary) -> void:
	for c: CreatureData in Game.state.creatures.values():
		if before.has(c.id) and before[c.id] != c.species:
			var sp := Game.species_of(c)
			if sp:
				_evolved.get_or_add(String(sp.line), {})[String(sp.id)] = true


## The requirement kinds of `t` that `c` actually meets (not every alternative of an any-of group).
func kinds_met(c: CreatureData, t: OrderTemplate) -> Array:
	var out: Array = []
	for g in t.required:
		for r in g.any_of:
			if r and Orders.met(c, r, Game.db, Game.state) and not out.has(r.kind):
				out.append(r.kind)
	return out


## Presses `b` like a player: a disabled or hidden button is a UI gap, not a press.
func press(b: BaseButton, what: String) -> bool:
	if b.disabled or not b.is_visible_in_tree():
		gaps.append("day %d: %s was %s" % [Game.state.day if Game.state else 0, what, "disabled" if b.disabled else "hidden"])
		return false
	b.pressed.emit()
	return true


func _reload_mid_day() -> void:
	var before: Dictionary = Game.state.to_dict()
	Game.start(Game.db)  # a real load of the save the last action wrote
	_reload_result = ("yes (day %d, after sending an expedition)" if Game.state.to_dict() == before
		else "NO (day %d: the reloaded state differs)") % Game.state.day


# --- popups -----------------------------------------------------------------------------------------------------

func _frame() -> void:
	await shop.get_tree().process_frame


func _open(method: StringName, args: Array = []) -> Control:
	shop.callv(method, args)
	await _frame()
	return shop.get_node("%PanelHost").current()


func _close() -> void:
	shop.get_node("%PanelHost").close()
	await _frame()


func _orders() -> void:
	var panel: Control = await _open(&"open_orders")
	var i := 0
	while i < Game.state.orders.size():
		var c := _deliverable(i)
		if c == null:
			i += 1
			continue
		var t := Game.order_template(i)
		var kinds := kinds_met(c, t)
		panel.open_active(i)
		var menu: PopupMenu = panel.get_node("%Details").get_node("%Deliver").get_popup()
		var item := menu.get_item_index(c.id)
		if item < 0 or menu.is_item_disabled(item):
			gaps.append("day %d: Deliver menu for %s lacks %s" % [Game.state.day, t.customer, Game.who(c)])
			i += 1
			panel = await _open(&"open_orders")
			continue
		menu.id_pressed.emit(c.id)
		if c.status == CreatureData.Status.GONE:
			_did.append("delivered %s to %s" % [Game.who(c), t.customer])
			for k in kinds:
				_kinds_filled[k] = true
		else:
			gaps.append("day %d: Deliver of %s to %s did nothing" % [Game.state.day, Game.who(c), t.customer])
			i += 1
		panel = await _open(&"open_orders")
	var offers: Array = Game.state.board.duplicate()
	offers.sort_custom(func(a: StringName, b: StringName) -> bool: return _fit(a) > _fit(b))
	for id: StringName in offers:
		if Game.state.orders.size() >= OrderBoard.slots(Game.state):
			break
		panel.open_offer(id)
		if press(panel.get_node("%Details").get_node("%Accept"), "Accept"):
			if not Game.state.board.has(id):
				_did.append("accepted %s" % Game.db.orders[id].customer)
			else:
				gaps.append("day %d: Accept of %s did nothing" % [Game.state.day, Game.db.orders[id].customer])
		panel = await _open(&"open_orders")
	await _close()


func _deliverable(i: int) -> CreatureData:
	for c in Game.owned():
		if Game.order_check(i, c)["ok"]:
			return c
	return null


## How many required groups of offer `id` the best owned creature already meets.
func _fit(id: StringName) -> int:
	var t: OrderTemplate = Game.db.orders[id]
	var best := 0
	for c in Game.owned():
		best = maxi(best, t.required.filter(func(g: RequirementGroup) -> bool: return Game.group_met(c, g)).size())
	return best


func _market() -> void:
	var panel: Control = await _open(&"open_market")
	if int(Game.state.inventory.get("feed", 0)) < FEED_MIN and Game.feed_reason(5) == "":
		await _buy(panel, "Feed/feed_5", "bought 5 feed")
	for u in Game.upgrades_on_offer():
		if Game.upgrade_reason(u.id) == "" and Game.state.money >= u.cost + MONEY_BUFFER:
			await _buy(panel, "Upgrades/" + String(u.id), "bought " + u.display_name)
	var eggs := Game.eggs_on_offer().filter(func(sp: Species) -> bool: return Game.egg_reason(sp.id) == "")
	if not eggs.is_empty() and Game.state.money >= eggs[0].market_price + MONEY_BUFFER and Game.owned().size() < 6:
		await _buy(panel, "Eggs/" + String(eggs[0].id), "bought a %s egg" % eggs[0].display_name)
	var pen: BuildableDef = Game.db.buildables.get(&"pen")
	if pen and not Market.has_pen_space(Game.state) and Game.state.money >= pen.cost + 100:
		if press(panel.get_node("%Pens/pen/%Buy"), "Pen Buy"):  # the farm closes the Market and starts placing
			await _frame()
			await _place_pen(pen)
			return
	await _close()


## Buys a row the rules say is on sale: a disabled Buy is a gap, and so is a Buy that changes no money.
func _buy(panel: Control, row: String, said: String) -> void:
	var money := Game.state.money
	if not press(panel.get_node("%" + row + "/%Buy"), row + " Buy"):
		return
	await _frame()
	if Game.state.money < money:
		_did.append(said)
	else:
		gaps.append("day %d: %s Buy did nothing" % [Game.state.day, row])


func _place_pen(def: BuildableDef) -> void:
	var placer: Control = shop.get_node("%Placer")
	var cells: Dictionary = shop.buildable_cells()
	var spots: Array = cells.keys()
	spots.sort()
	for cell: Vector2i in spots:
		if Build.can_place(Game.state, Game.db, def.id, cell, cells) != "":
			continue
		var centre := Vector2(cell * Placer.TILE) + Vector2(def.footprint * Placer.TILE) / 2.0
		if placer.move_to(centre) != "":
			continue
		placer.pin(true)
		var pens := Game.state.placed.size()
		press(placer.get_node("%Place"), "Place")
		await _frame()
		if Game.state.placed.size() > pens:
			_did.append("built a pen")
			return
		gaps.append("day %d: Place did nothing at %s" % [Game.state.day, cell])
		break
	gaps.append("day %d: no spot to build a pen" % Game.state.day)
	placer.get_node("%Cancel").pressed.emit()
	await _frame()


func _breed() -> void:
	if Game.state.ap < Day.COST_BREED or not Market.has_pen_space(Game.state):
		return
	var pair := _retired_pair()
	if pair.is_empty():
		var adults := Game.owned().filter(func(c: CreatureData) -> bool: return c.stage == "adult" and Game.travel_reason(c) == "")
		if adults.size() < 4:
			return
		pair = _best_pair(adults)
		if pair.is_empty():
			return
		for c: CreatureData in pair:
			var card: Control = await _open(&"open_card", [c])
			press(card.get_node("%Retire"), "Retire")  # arms
			press(card.get_node("%Retire"), "Retire")  # retires
			await _frame()
			if c.status == CreatureData.Status.RETIRED:
				_did.append("retired %s" % Game.who(c))
			else:
				gaps.append("day %d: Retire of %s did nothing" % [Game.state.day, Game.who(c)])
		await _close()
		if Game.breed_reason(pair[0], pair[1]) != "":
			return
	var stable: Control = await _open(&"open_stable")
	var before := Game.state.creatures.size()
	stable.pick(pair[0])
	stable.pick(pair[1])
	press(stable.get_node("%Breed"), "Breed")
	await _frame()
	if Game.state.creatures.size() > before:
		_did.append("bred %s and %s" % [Game.who(pair[0]), Game.who(pair[1])])
	else:
		gaps.append("day %d: Breed of %s and %s did nothing: %s" % [Game.state.day, Game.who(pair[0]), Game.who(pair[1]),
			stable.get_node("%Reason").text])
	await _close()


func _retired_pair() -> Array:
	var free := Game.retired()
	for a in free:
		for b in free:
			if a.id < b.id and Game.breed_reason(a, b) == "":
				return [a, b]
	return []


## The two strongest adults sharing an egg group, or [] when none do.
func _best_pair(adults: Array) -> Array:
	var sorted := adults.duplicate()
	sorted.sort_custom(func(a: CreatureData, b: CreatureData) -> bool: return Stats.score(a.stats) > Stats.score(b.stats))
	for a: CreatureData in sorted:
		for b: CreatureData in sorted:
			if a != b and Game.species_of(a).egg_group == Game.species_of(b).egg_group:
				return [a, b]
	return []


func _expedition() -> void:
	if Game.state.ap < Day.COST_EXPEDITION + 1:
		return
	var free := Game.owned().filter(func(c: CreatureData) -> bool: return Game.travel_reason(c) == "" and c.stage == "adult")
	var best_id := &""
	var best_team: Array = []
	var best := 0
	for id: StringName in Game.db.locations:
		var team: Array = []
		for _slot in Expedition.MAX_TEAM:
			var gain := Game.challenges_met(id, team)
			var add: CreatureData = null
			for c: CreatureData in free:
				if not team.has(c) and Game.challenges_met(id, team + [c]) > gain:
					gain = Game.challenges_met(id, team + [c])
					add = c
			if add == null:
				break
			team.append(add)
		var n := Game.challenges_met(id, team)
		if n > best:
			best = n
			best_id = id
			best_team = team
	if best == 0:
		return
	var panel: Control = await _open(&"open_expedition")
	panel.choose(best_id)
	for c in best_team:
		panel.pick(c)
	var sent := Game.state.expeditions.size()
	press(panel.get_node("%Send"), "Send")
	await _frame()
	if Game.state.expeditions.size() <= sent:
		gaps.append("day %d: Send to the %s did nothing" % [Game.state.day, Game.db.locations[best_id].display_name])
	else:
		_did.append("sent %d to the %s (%d/%d)" % [best_team.size(), Game.db.locations[best_id].display_name, best,
			Game.db.locations[best_id].challenges.size()])
	await _close()


func _care_and_train() -> void:
	var tended := {}
	var steps := 0
	while Game.state.ap > 0 and steps < MAX_STEPS:
		steps += 1
		var c := _next_to_tend(tended)
		if c == null:
			break
		tended[c.id] = int(tended.get(c.id, 0)) + 1
		var card: Control = await _open(&"open_card", [c])
		var ap := Game.state.ap
		if c.stage == "baby" and c.mood < 60:
			card.get_node("%Feed" if int(Game.state.inventory.get("feed", 0)) > 0 else "%Play").pressed.emit()
			await _frame()
			if Game.state.ap < ap:
				_did.append("cared for %s" % Game.who(c))
		else:
			var stat := _stat_for(c)
			card.get_node("%Train").get_popup().id_pressed.emit(Stats.NAMES.find(stat))
			await _frame()
			if Game.state.ap < ap:
				_did.append("trained %s's %s" % [Game.who(c), stat])
		if Game.state.ap == ap:
			tended[c.id] = 99  # refused: leave it for today
			var msg: String = card.get_node("%Message").text
			if msg != "":
				gaps.append("day %d: %s refused: %s" % [Game.state.day, Game.who(c), msg])
	if shop.get_node("%PanelHost").current():
		await _close()


func _next_to_tend(tended: Dictionary) -> CreatureData:
	var ready := Game.owned().filter(func(c: CreatureData) -> bool:
		return c.stage != "egg" and Game.travel_reason(c) == "" and int(tended.get(c.id, 0)) < 3)
	if ready.is_empty():
		return null
	ready.sort_custom(func(a: CreatureData, b: CreatureData) -> bool:
		var na := int(tended.get(a.id, 0)) - (5 if a.stage == "baby" and a.mood < 60 else 0)
		var nb := int(tended.get(b.id, 0)) - (5 if b.stage == "baby" and b.mood < 60 else 0)
		return na < nb)
	return ready[0]


## A stat an accepted order asks of `c` that it doesn't meet yet, else its best stat still below potential.
func _stat_for(c: CreatureData) -> String:
	for i in Game.state.orders.size():
		for g in Game.order_template(i).required:
			if Game.group_met(c, g):
				continue
			for r in g.any_of:
				if r.kind == "stat":
					return String(r.id)
	var best: String = Stats.NAMES[0]
	for s in Stats.NAMES:
		if int(c.stats[s]) < int(c.potential[s]) and (int(c.stats[best]) >= int(c.potential[best]) or int(c.stats[s]) > int(c.stats[best])):
			best = s
	return best


func _end_day() -> PackedStringArray:
	shop.end_day()
	await _frame()
	var events: PackedStringArray = Game.report.get("events", PackedStringArray())
	var summary: Control = shop.get_node("%PanelHost").current()
	if summary:
		summary.get_node("%Continue").pressed.emit()
		await _frame()
	return events
