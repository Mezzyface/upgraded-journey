# Bot Playtest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A scripted player plays the real farm and its popups for many days on several seeds and writes a Markdown
report (days, economy, goals reached, errors, stalls, UI gaps).

**Architecture:** `tools/playtest/report.gd` (`PlaytestReport`, static, scene-free) turns run records into Markdown and
finds stalls; `tools/playtest/bot.gd` (`PlaytestBot`) plays one day through `shop.gd`'s popup openers and the panels'
buttons; `tools/playtest/playtest.gd` (`-s` SceneTree) runs seeds × days, catches script errors with a `Logger`, and
writes the report.

**Tech Stack:** Godot 4.7 GDScript.

**Spec:** `docs/superpowers/specs/2026-09-30-bot-playtest-design.md`

## Global Constraints

As in `docs/superpowers/plans/2026-09-29-expeditions.md` (no co-author trailer, never push, `git checkout -- art` after
imports). Branch `playtest` (stacked on `tutorial`). The runner never touches `user://save.json`
(`user://playtest_<seed>.json`). Scripts run by `-s` compile before autoloads: they must not name autoload-dependent
classes as types (load them with `load(...).new()`).

## Review Focus

1. A panel method the bot relies on is missing or renamed → a script error in the report, not a silent skip.
   → Task 2 test runs a full day with the error catcher.
2. The bot loops forever on a refused action (e.g. Train refused every time). → guard counters + refusal → gap.
3. The report must show errors per day and seed. → Task 1 test.
4. A run that never delivers or never earns → flagged as a stall. → Task 1 test.
5. The reload check compares a real `Game.start()` reload with the pre-reload state. → Task 3 runner.

---

### Task 1: `PlaytestReport`

**Files:** create `tools/playtest/report.gd`; test `tests/test_playtest_report.gd`.
**Produces:** `class_name PlaytestReport`: `static func markdown(runs: Array) -> String`,
`static func stalls(days: Array) -> PackedStringArray`. A run is `{"seed": int, "days": Array[Dictionary], "errors":
PackedStringArray, "gaps": PackedStringArray, "goals": Dictionary}`; a day is `{"day", "gold", "gold_delta", "rep",
"tier", "owned", "retired", "eggs", "orders", "delivered", "missed", "ap_left", "actions": PackedStringArray,
"events": PackedStringArray}`.

- [ ] **Step 1: Test** `tests/test_playtest_report.gd`:

```gdscript
extends TestSuite
## PlaytestReport: the Markdown the bot playtest writes, and the stalls it flags.


func _day(n: int, gold: int, actions: Array, delivered := 0, ap_left := 0) -> Dictionary:
	return {"day": n, "gold": gold, "gold_delta": 0, "rep": 0, "tier": 0, "owned": 3, "retired": 0, "eggs": 0,
		"orders": 1, "delivered": delivered, "missed": 0, "ap_left": ap_left,
		"actions": PackedStringArray(actions), "events": PackedStringArray()}


func test_markdown_has_a_day_table_errors_gaps_and_goals() -> void:
	var run := {"seed": 7, "days": [_day(1, 500, ["trained Spider #1's power"]), _day(2, 480, [])],
		"errors": PackedStringArray(["day 2: boom"]), "gaps": PackedStringArray(["no spot to build a pen"]),
		"goals": {"order kinds filled": "stat, trait"}}
	var md := PlaytestReport.markdown([run])
	check(md.contains("## Seed 7"), "a section per seed")
	check(md.contains("| Day | Gold |"), "a day table")
	check(md.contains("| 1 | 500 |"), "a row per day")
	check(md.contains("day 2: boom"), "errors listed")
	check(md.contains("no spot to build a pen"), "gaps listed")
	check(md.contains("order kinds filled: stat, trait"), "goals listed")


func test_stalls_flag_idle_days_flat_gold_and_no_deliveries() -> void:
	var days := [_day(1, 500, [], 0, 3)]
	for n in range(2, 8):
		days.append(_day(n, 500, ["x"]))
	var found := PlaytestReport.stalls(days)
	check(found.has("day 1: did nothing with 3 AP left"), "idle day: %s" % [found])
	check(found.has("days 2-7: gold did not grow"), "flat gold: %s" % [found])
	check(found.has("never delivered an order"), "no deliveries: %s" % [found])
	eq(PlaytestReport.stalls([_day(1, 500, ["x"], 1), _day(2, 600, ["x"])]).size(), 0, "a healthy run has none")
```

- [ ] **Step 2: Run** → FAIL (`PlaytestReport` unknown).
- [ ] **Step 3: Implement** `tools/playtest/report.gd`:

```gdscript
class_name PlaytestReport
extends RefCounted
## Markdown for the bot playtest (tools/playtest/playtest.gd) and the stalls it flags. Scene-free and Game-free.

const FLAT_DAYS := 5  ## gold not growing this many days in a row is a stall


static func markdown(runs: Array) -> String:
	var out: PackedStringArray = ["# Bot playtest", ""]
	for run: Dictionary in runs:
		var days: Array = run["days"]
		out.append("## Seed %d" % run["seed"])
		out.append("")
		out.append("| Day | Gold | Δ | Rep | Tier | Owned | Retired | Eggs | Orders | Delivered | Missed | AP left | Actions |")
		out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
		for d: Dictionary in days:
			out.append("| %d | %d | %+d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %s |" % [d["day"], d["gold"],
				d["gold_delta"], d["rep"], d["tier"], d["owned"], d["retired"], d["eggs"], d["orders"], d["delivered"],
				d["missed"], d["ap_left"], "; ".join(d["actions"])])
		out.append("")
		out.append("**Goals**")
		for goal in run["goals"]:
			out.append("- %s: %s" % [goal, run["goals"][goal]])
		out.append("")
		for section in [["Errors", run["errors"]], ["Stalls", stalls(days)], ["UI gaps", run["gaps"]]]:
			out.append("**%s**" % section[0])
			var items: PackedStringArray = section[1]
			if items.is_empty():
				out.append("- none")
			for item in items:
				out.append("- " + item)
			out.append("")
	return "\n".join(out)


static func stalls(days: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for d: Dictionary in days:
		if (d["actions"] as PackedStringArray).is_empty() and int(d["ap_left"]) > 0:
			out.append("day %d: did nothing with %d AP left" % [d["day"], d["ap_left"]])
	var streak_start := -1  ## index of the first day of a stretch whose gold didn't rise over the day before
	for i in range(1, days.size() + 1):
		var flat: bool = i < days.size() and int(days[i]["gold"]) <= int(days[i - 1]["gold"])
		if flat and streak_start < 0:
			streak_start = i
		elif not flat and streak_start >= 0:
			if i - streak_start >= FLAT_DAYS:
				out.append("days %d-%d: gold did not grow" % [days[streak_start]["day"], days[i - 1]["day"]])
			streak_start = -1
	if not days.is_empty() and days.all(func(d: Dictionary) -> bool: return int(d["delivered"]) == 0):
		out.append("never delivered an order")
	return out
```

- [ ] **Step 4: Run** → PASS. Suite `+2`.
- [ ] **Step 5: Commit** `tools/playtest/report.gd(.uid) tests/test_playtest_report.gd(.uid)`: "Add the playtest report".

### Task 2: `PlaytestBot`

**Files:** create `tools/playtest/bot.gd`; test `tests/test_playtest_bot.gd`.
**Produces:** `class_name PlaytestBot`: `func _init(farm: Control)`, `func play_day() -> Dictionary` (a coroutine; the
day record above), `var gaps: PackedStringArray`, `func goals() -> Dictionary`.

- [ ] **Step 1: Test** `tests/test_playtest_bot.gd`:

```gdscript
extends TestSuite
## The playtest bot plays whole days through the farm's popups without script errors (the runner fails any test that
## triggers one).

const SAVE := "user://test_playtest_bot_save.json"


func test_the_bot_plays_three_days() -> void:
	await tree.process_frame
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 11)
	var shop: Control = load("res://shop/shop.tscn").instantiate()
	tree.root.add_child(shop)
	await tree.process_frame
	var bot := PlaytestBot.new(shop)
	for n in 3:
		var day: Dictionary = await bot.play_day()
		eq(day["day"], n + 1, "day %d played" % (n + 1))
		check(not (day["actions"] as PackedStringArray).is_empty(), "day %d: the bot did something: %s" % [n + 1, day])
	eq(Game.state.day, 4, "three days ended")
	check(shop.get_node("%PanelHost").current() == null, "no popup left open")
	check(bot.goals().has("order kinds filled"), "goals reported")
	shop.queue_free()
	DirAccess.remove_absolute(SAVE)
```

- [ ] **Step 2: Run** → FAIL (`PlaytestBot` unknown).
- [ ] **Step 3: Implement** `tools/playtest/bot.gd`:

```gdscript
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
	await _care_and_train()
	var ap_left := Game.state.ap
	var orders := Game.state.orders.size()
	var events := await _end_day()
	for e in events:
		if e.contains(" evolved into "):
			for sp: Species in Game.db.species.values():
				if e.ends_with(" " + sp.display_name):
					_evolved.get_or_add(String(sp.line), {})[String(sp.id)] = true
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
	return {"order kinds filled": ", ".join(PackedStringArray(kinds)) if not kinds.is_empty() else "none",
		"3-generation pedigree": "yes" if three_gen else "no",
		"evolutions": ", ".join(PackedStringArray(_evolved.keys())) if not _evolved.is_empty() else "none",
		"branching evolution": ", ".join(branching) if not branching.is_empty() else "no"}


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
		panel.open_active(i)
		panel.get_node("%Details").get_node("%Deliver").get_popup().id_pressed.emit(c.id)
		if c.status == CreatureData.Status.GONE:
			_did.append("delivered %s to %s" % [Game.who(c), t.customer])
			for g in t.required:
				for r in g.any_of:
					_kinds_filled[r.kind] = true
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
		panel.get_node("%Details").get_node("%Accept").pressed.emit()
		if not Game.state.board.has(id):
			_did.append("accepted %s" % Game.db.orders[id].customer)
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
	if int(Game.state.inventory.get("feed", 0)) < FEED_MIN:
		await _buy(panel, "Feed/feed_5", "bought 5 feed")
	for u in Game.upgrades_on_offer():
		if Game.upgrade_reason(u.id) == "" and Game.state.money >= u.cost + MONEY_BUFFER:
			await _buy(panel, "Upgrades/" + String(u.id), "bought " + u.display_name)
	var eggs := Game.eggs_on_offer().filter(func(sp: Species) -> bool: return Game.egg_reason(sp.id) == "")
	if not eggs.is_empty() and Game.state.money >= eggs[0].market_price + MONEY_BUFFER and Game.owned().size() < 6:
		await _buy(panel, "Eggs/" + String(eggs[0].id), "bought a %s egg" % eggs[0].display_name)
	var pen: BuildableDef = Game.db.buildables.get(&"pen")
	if pen and not Market.has_pen_space(Game.state) and Game.state.money >= pen.cost + 100:
		panel.get_node("%Pens/pen/%Buy").pressed.emit()  # the farm closes the Market and starts placing
		await _frame()
		await _place_pen(pen)
		return
	await _close()


func _buy(panel: Control, row: String, said: String) -> void:
	var buy: Button = panel.get_node("%" + row + "/%Buy")
	if buy.disabled:
		return
	buy.pressed.emit()
	await _frame()
	_did.append(said)


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
		placer.get_node("%Place").pressed.emit()
		await _frame()
		_did.append("built a pen")
		return
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
			card.get_node("%Retire").pressed.emit()  # arms
			card.get_node("%Retire").pressed.emit()  # retires
			await _frame()
			_did.append("retired %s" % Game.who(c))
		await _close()
		if Game.breed_reason(pair[0], pair[1]) != "":
			return
	var stable: Control = await _open(&"open_stable")
	var before := Game.state.creatures.size()
	stable.pick(pair[0])
	stable.pick(pair[1])
	stable.get_node("%Breed").pressed.emit()
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
	panel.get_node("%Send").pressed.emit()
	await _frame()
	if not Game.state.expeditions.is_empty():
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
```

- [ ] **Step 4: Run** `test_playtest_bot.gd` → PASS. Fix bot/API mismatches the run shows (ledger each). Suite `+1`.
- [ ] **Step 5: Commit**: "Add the playtest bot".

### Task 3: Runner and the report

**Files:** create `tools/playtest/playtest.gd`; `docs/playtest/2026-09-30-report.md` (the run's output).

- [ ] **Step 1: Runner** `tools/playtest/playtest.gd`:

```gdscript
extends SceneTree
## Bot playtest (docs/superpowers/specs/2026-09-30-bot-playtest-design.md):
##   godot --headless --path . -s res://tools/playtest/playtest.gd -- --days=30 --seeds=1,2,3 --out=user://playtest_report.md
## Plays each seed from a fresh game for --days days with tools/playtest/bot.gd, then checks a mid-run reload, and writes
## the Markdown report (tools/playtest/report.gd). Never touches the player's save.


class ErrorCatcher extends Logger:
	var script_errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool,
			error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			script_errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file, line])


func _initialize() -> void:
	await process_frame
	var days := 30
	var seeds: PackedInt32Array = [1, 2, 3]
	var out := "user://playtest_report.md"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			days = int(arg.trim_prefix("--days="))
		elif arg.begins_with("--seeds="):
			seeds = PackedInt32Array(Array(arg.trim_prefix("--seeds=").split(",")).map(func(s: String) -> int: return int(s)))
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var game: Node = root.get_node("Game")
	var runs: Array = []
	for seed_value in seeds:
		game.save_path = "user://playtest_%d.json" % seed_value
		DirAccess.remove_absolute(game.save_path)
		game.start_new(load("res://data/new_game.tres"), Db.load_dir(), seed_value)
		var shop: Control = load("res://shop/shop.tscn").instantiate()
		root.add_child(shop)
		await process_frame
		var bot = load("res://tools/playtest/bot.gd").new(shop)
		var records: Array = []
		var errors: PackedStringArray = []
		for n in days:
			catcher.script_errors.clear()
			var record: Dictionary = await bot.play_day()
			for e in catcher.script_errors:
				errors.append("day %d: %s" % [record["day"], e])
			records.append(record)
			print("seed %d day %d: gold %d, rep %d, %d actions" % [seed_value, record["day"], record["gold"], record["rep"],
				(record["actions"] as PackedStringArray).size()])
		var goals: Dictionary = bot.goals()
		var before: Dictionary = game.state.to_dict()
		game.start(game.db)  # a real reload from the save written by the last action / evening
		goals["mid-run reload restores the state"] = "yes" if game.state.to_dict() == before else "NO"
		runs.append({"seed": seed_value, "days": records, "errors": errors, "gaps": bot.gaps, "goals": goals})
		shop.queue_free()
		await process_frame
	var md: String = load("res://tools/playtest/report.gd").markdown(runs)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(md)
	f.close()
	print("report: ", ProjectSettings.globalize_path(out))
	quit()
```

  (Check `Logger._log_error`'s exact signature against `tests/run_tests.gd`'s `ErrorCatcher` and copy it.)
- [ ] **Step 2: Run** `"$GODOT" --headless --path . -s res://tools/playtest/playtest.gd -- --days=30 --seeds=1,2,3
  --out=user://playtest_report.md`, copy the report to `docs/playtest/2026-09-30-report.md`, read it.
- [ ] **Step 3: Commit** runner + report: "Add the playtest runner and the first report".
