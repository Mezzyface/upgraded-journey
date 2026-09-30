# Market Goods Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Market sells feed, eggs and upgrades (plus the existing pens), each refusal shown before Buy.

**Architecture:** `Market.feed_reason` / `egg_reason` / `upgrade_reason` pull the checks out of the `buy_*` rules;
`Game` wraps buys (logged) and the offer lists; the Market panel becomes one scrolling list of four sections built
from `buildable_row.tscn` rows.

**Tech Stack:** Godot 4.7 GDScript; headless Godot builds scenes while the editor is closed.

**Spec:** `docs/superpowers/specs/2026-09-30-market-goods-design.md`

## Global Constraints

- As in `docs/superpowers/plans/2026-09-29-expeditions.md` Global Constraints (headless scene builds in
  `_initialize()` after a frame, uid lines restored, `--import` clean then `git checkout -- art` to drop LF-only
  `.import` rewrites; suite baseline now `223 tests, 1 failed` — only `test_nothing_references_isle_of_lore`; scene
  tests await a frame first; no co-author trailer; never push). Branch `market`.
- Wording is copied from the rules: "not enough money", "the pens are full", "already bought",
  "needs reputation tier N", "not sold here yet", "no such upgrade", "buy at least one".

## Review Focus

1. Money changes while the Market is open (a purchase): every row's Buy state follows `Game.changed`.
   → Task 2 `test_rows_follow_the_money`.
2. A tier-locked egg is visible but disabled with "needs reputation tier 1". → Task 2 `test_sections_and_rows`.
3. A bought upgrade can't be bought twice and reads "Owned". → Task 2 `test_buying_an_upgrade_marks_it_owned`.
4. Pens full: egg rows disabled with "the pens are full". → Task 1 `test_reasons_match_what_buy_refuses`.
5. Many offers (5 eggs + 2 upgrades + 2 feed + pens) still fit 640×360 and scroll. → `test_panel_fit.gd`.

---

### Task 1: Market reasons, Game buys and offers

**Files:** Modify `creatures/rules/market.gd`, `game/game.gd`; Test `tests/test_market.gd`, `tests/test_game.gd`.

**Produces:** `Market.feed_reason(state, count: int) -> String`, `Market.egg_reason(state, db, species_id) -> String`,
`Market.upgrade_reason(state, db, upgrade_id) -> String`; `Game.buy_feed(count: int) -> String`,
`Game.buy_egg(species_id: StringName) -> String`, `Game.buy_upgrade(upgrade_id: StringName) -> String`,
`Game.feed_reason(count)`, `Game.egg_reason(species_id)`, `Game.upgrade_reason(upgrade_id)`,
`Game.eggs_on_offer() -> Array[Species]` (market_tier >= 0; price, then display name),
`Game.upgrades_on_offer() -> Array[UpgradeDef]` (cost, then display name).

- [ ] **Step 1: Failing tests.** In `tests/test_market.gd` change the line
  `eq(Market.buy_egg(st, db, &"spider", Fixtures.rng()), "not sold here yet", "spider needs tier 1")` to expect
  `"needs reputation tier 1"`, and append:

```gdscript
func test_reasons_match_what_buy_refuses() -> void:
	var db := Fixtures.db()
	var st := Fixtures.state(db)
	st.money = 25
	eq(Market.feed_reason(st, 0), "buy at least one", "count")
	eq(Market.feed_reason(st, 2), "", "affordable")
	eq(Market.feed_reason(st, 3), "not enough money", "30 > 25")
	eq(Market.buy_feed(st, 3), Market.feed_reason(st, 3), "buy_feed agrees")
	st.money = 1000
	eq(Market.egg_reason(st, db, &"slime"), "", "tier 0 egg")
	eq(Market.egg_reason(st, db, &"spider"), "needs reputation tier 1", "locked")
	eq(Market.egg_reason(st, db, &"spider_large"), "not sold here yet", "never sold")
	eq(Market.egg_reason(st, db, &"nope"), "not sold here yet", "unknown")
	for i in 6:
		Fixtures.adult(st, "spider")
	eq(Market.egg_reason(st, db, &"slime"), "the pens are full", "full")
	eq(Market.buy_egg(st, db, &"slime", Fixtures.rng()), Market.egg_reason(st, db, &"slime"), "buy_egg agrees")
	eq(Market.upgrade_reason(st, db, &"extra_pen"), "", "affordable tier 0")
	eq(Market.upgrade_reason(st, db, &"extra_ap"), "needs reputation tier 1", "tier")
	eq(Market.upgrade_reason(st, db, &"nope"), "no such upgrade", "unknown")
	Market.buy_upgrade(st, db, &"extra_pen")
	eq(Market.upgrade_reason(st, db, &"extra_pen"), "already bought", "once")
	eq(Market.buy_upgrade(st, db, &"extra_pen"), "already bought", "buy_upgrade agrees")
```

Append to `tests/test_game.gd`:

```gdscript
func test_market_buys_cost_money_and_log() -> void:
	var g := _game()
	var count := [0]
	g.changed.connect(func() -> void: count[0] += 1)
	g.state.money = 1000
	var feed: int = g.state.inventory.get("feed", 0)
	eq(g.buy_feed(5), "", "feed")
	eq(g.state.inventory["feed"], feed + 5, "stocked")
	eq(g.day_log[-1], "Bought 5 feed (-50 gold)", "logged feed")
	eq(g.buy_egg(&"slime"), "", "egg")
	eq(g.day_log[-1], "Bought a Slime egg (-60 gold)", "logged egg")
	eq(g.buy_upgrade(&"extra_pen"), "", "upgrade")
	eq(g.day_log[-1], "Bought Extra Pen (-300 gold)", "logged upgrade")
	eq(g.state.money, 1000 - 50 - 60 - 300, "paid")
	eq(count[0], 3, "changed per purchase")
	eq(g.buy_upgrade(&"extra_pen"), g.upgrade_reason(&"extra_pen"), "refused with the panel's reason")
	eq(count[0], 3, "no change on refusal")
	eq(g.eggs_on_offer().map(func(s: Species) -> StringName: return s.id), [&"slime", &"spider"], "price order")
	eq(g.upgrades_on_offer().map(func(u: UpgradeDef) -> StringName: return u.id),
		[&"extra_pen", &"extra_ap", &"gene_scanner"], "cost order")
	check(g.feed_reason(1) == "" and g.egg_reason(&"spider") != "", "reason wrappers")
	_cleanup(g)
```

- [ ] **Step 2: Run** `test_market.gd`, `test_game.gd` → FAIL (compile / nonexistent functions).
- [ ] **Step 3: Implement.** In `creatures/rules/market.gd` replace `buy_feed`, `buy_egg`, `buy_upgrade` with:

```gdscript
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
```

In `game/game.gd` after `func expeditions_today()` add:

```gdscript
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
```

- [ ] **Step 4: Run** both files and the suite → PASS; suite `225 tests, 1 failed` (known only).
- [ ] **Step 5: Commit** `creatures/rules/market.gd game/game.gd tests/test_market.gd tests/test_game.gd`:
  "Add Market reasons and Game purchases for feed, eggs and upgrades".

### Task 2: The Market panel's four sections

**Files:** Modify `shop/panels/market_panel.gd`, `shop/panels/market_panel.tscn` (Godot-built), `shop/shop.gd`
(`open_market`); Test `tests/test_market_panel.gd` (new).

**Produces:** `market_panel.gd` (`class_name MarketPanel`, still `extends "res://shop/panels/closable_panel.gd"`) with
`signal build_requested(def_id: StringName)` (unchanged), `signal bought(text: String)`, `func refresh()`; unique
nodes `%Feed`, `%Eggs`, `%Upgrades`, `%Pens` (VBoxes of `buildable_row.tscn` rows named after their item:
`feed_1`, `feed_5`, species id, upgrade id, buildable id).

- [ ] **Step 1: Failing tests** — `tests/test_market_panel.gd`:

```gdscript
extends TestSuite
## The Market panel (market_panel.tscn): feed, eggs, upgrades and pens, each Buy enabled only when it would work.

const SAVE := "user://test_market_panel_save.json"


## Fixture content with the starter pen; money 1000, reputation tier 0. Returns [host, panel]; await it.
func _market() -> Array:
	await tree.process_frame
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.start_pen = db.buildables[&"pen"]
	Game.start_new(setup, db, 3)
	Game.state.money = 1000
	var host := PanelHost.new()
	host.size = Vector2(640, 320)
	tree.root.add_child(host)
	var panel: MarketPanel = load("res://shop/panels/market_panel.tscn").instantiate()
	host.open(panel)
	await tree.process_frame
	return [host, panel]


func _done(host: Node) -> void:
	host.queue_free()
	DirAccess.remove_absolute(SAVE)


func _buy(panel: Node, list: String, item: String) -> Button:
	return panel.get_node("%" + list).get_node(item).get_node("%Buy")


func test_sections_and_rows() -> void:
	var parts: Array = await _market()
	var panel: MarketPanel = parts[1]
	eq(panel.get_node("%Feed").get_children().map(func(r: Node) -> String: return r.name), ["feed_1", "feed_5"], "feed rows")
	eq(panel.get_node("%Feed/feed_5/%Name").text, "Feed ×5", "feed name")
	eq(panel.get_node("%Feed/feed_1/%Holds").text, "%d in stock" % Game.state.inventory["feed"], "stock")
	eq(panel.get_node("%Feed/feed_5/%Price").text, "50", "price")
	eq(panel.get_node("%Eggs").get_children().map(func(r: Node) -> String: return r.name), ["slime", "spider"], "eggs by price")
	check(_buy(panel, "Eggs", "spider").disabled, "locked egg disabled")
	eq(_buy(panel, "Eggs", "spider").tooltip_text, "Needs reputation tier 1", "and says why")
	check(not _buy(panel, "Eggs", "slime").disabled, "tier-0 egg on sale")
	eq(panel.get_node("%Upgrades").get_child_count(), 3, "every upgrade")
	eq(panel.get_node("%Pens").get_child_count(), 1, "pens kept")
	_done(parts[0])


func test_buying_feed_and_eggs() -> void:
	var parts: Array = await _market()
	var panel: MarketPanel = parts[1]
	var said: Array = []
	panel.bought.connect(func(t: String) -> void: said.append(t))
	var feed: int = Game.state.inventory["feed"]
	_buy(panel, "Feed", "feed_5").pressed.emit()
	eq(Game.state.inventory["feed"], feed + 5, "five feed")
	eq(panel.get_node("%Feed/feed_1/%Holds").text, "%d in stock" % (feed + 5), "stock refreshed")
	_buy(panel, "Eggs", "slime").pressed.emit()
	eq(Game.owned().filter(func(c: CreatureData) -> bool: return c.stage == "egg").size(), 1, "an egg")
	eq(said, ["Bought 5 feed", "Bought a Slime egg"], "bought emitted")
	_done(parts[0])


func test_buying_an_upgrade_marks_it_owned() -> void:
	var parts: Array = await _market()
	var panel: MarketPanel = parts[1]
	_buy(panel, "Upgrades", "extra_pen").pressed.emit()
	check(Game.state.upgrades.has(&"extra_pen"), "bought")
	check(_buy(panel, "Upgrades", "extra_pen").disabled, "can't buy twice")
	eq(_buy(panel, "Upgrades", "extra_pen").text, "Owned", "reads Owned")
	_done(parts[0])


func test_rows_follow_the_money() -> void:
	var parts: Array = await _market()
	var panel: MarketPanel = parts[1]
	check(not _buy(panel, "Feed", "feed_5").disabled, "affordable")
	Game.state.money = 20
	Game.changed.emit()
	check(_buy(panel, "Feed", "feed_5").disabled, "50 > 20: disabled")
	eq(_buy(panel, "Feed", "feed_5").tooltip_text, "Not enough money", "says why")
	check(not _buy(panel, "Feed", "feed_1").disabled, "one still affordable")
	_done(parts[0])


func test_pens_still_ask_the_farm_to_build() -> void:
	var parts: Array = await _market()
	var panel: MarketPanel = parts[1]
	var asked: Array = []
	panel.build_requested.connect(func(id: StringName) -> void: asked.append(id))
	_buy(panel, "Pens", "pen").pressed.emit()
	eq(asked, [&"pen"], "build_requested")
	_done(parts[0])
```

- [ ] **Step 2: Run** → FAIL (`MarketPanel` unknown).
- [ ] **Step 3: Script** `shop/panels/market_panel.gd`:

```gdscript
class_name MarketPanel
extends "res://shop/panels/closable_panel.gd"
## The Market: one scrolling list of Feed, Eggs, Upgrades and Pens (docs/superpowers/specs/2026-09-30-market-goods-design.md),
## a buildable_row.tscn per item (%Name, %Holds as the detail, %Price, %Buy), named after the item. A Buy that would
## be refused is disabled with the reason as its tooltip. Feed, eggs and upgrades are bought at once (bought is
## emitted for the shop's toast); a pen's Buy asks the farm to start placement (paid when placed). Refreshes on
## Game.changed.

signal build_requested(def_id: StringName)
signal bought(text: String)

const ROW := preload("res://shop/panels/buildable_row.tscn")
const FEED_PACKS: PackedInt32Array = [1, 5]


func _ready() -> void:
	super()
	Game.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for list in [%Feed, %Eggs, %Upgrades, %Pens]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	for n in FEED_PACKS:
		var row := _row(%Feed, "feed_%d" % n, "Feed ×%d" % n, "%d in stock" % int(Game.state.inventory.get("feed", 0)),
				Market.FEED_PRICE * n, Game.feed_reason(n))
		row.get_node("%Buy").pressed.connect(_buy.bind(func() -> String: return Game.buy_feed(n), "Bought %d feed" % n))
	for sp in Game.eggs_on_offer():
		var row := _row(%Eggs, String(sp.id), "%s egg" % sp.display_name, "", sp.market_price, Game.egg_reason(sp.id))
		row.get_node("%Buy").pressed.connect(_buy.bind(func() -> String: return Game.buy_egg(sp.id), "Bought a %s egg" % sp.display_name))
	for u in Game.upgrades_on_offer():
		var reason := Game.upgrade_reason(u.id)
		var row := _row(%Upgrades, String(u.id), u.display_name, u.description, u.cost, reason)
		if reason == "already bought":
			row.get_node("%Buy").text = "Owned"
		row.get_node("%Buy").pressed.connect(_buy.bind(func() -> String: return Game.buy_upgrade(u.id), "Bought %s" % u.display_name))
	var defs: Array = Game.db.buildables.values().filter(func(d: BuildableDef) -> bool: return d.capacity > 0)
	defs.sort_custom(func(a: BuildableDef, b: BuildableDef) -> bool: return a.cost < b.cost)
	for def: BuildableDef in defs:
		var money := "" if Game.state.money >= def.cost else "not enough money"
		var row := _row(%Pens, String(def.id), def.display_name, "holds %d" % def.capacity, def.cost, money)
		if money == "":
			row.get_node("%Buy").tooltip_text = def.description
		row.get_node("%Buy").pressed.connect(func() -> void: build_requested.emit(def.id))


func _row(list: Node, id: String, title: String, detail: String, price: int, reason: String) -> Control:
	var row: Control = ROW.instantiate()
	row.name = id
	list.add_child(row)
	row.get_node("%Name").text = title
	row.get_node("%Holds").text = detail
	row.get_node("%Price").text = str(price)
	var buy: Button = row.get_node("%Buy")
	buy.disabled = reason != ""
	buy.tooltip_text = reason.left(1).to_upper() + reason.substr(1)
	return row


func _buy(action: Callable, text: String) -> void:
	if action.call() == "":
		bought.emit(text)
```

In `shop/shop.gd` `open_market()` add after the `build_requested` connect: `	market.bought.connect(toast)`.

- [ ] **Step 4: Scene.** Headless build: load `market_panel.tscn` (`GEN_EDIT_STATE_MAIN`), set
  `custom_minimum_size = Vector2(380, 280)`; under `Margin/Rows` add `Page` HBox (`size_flags_vertical = 3`) with
  `Scroll` (ScrollContainer, `size_flags_horizontal/vertical = 3`, horizontal disabled, vertical "Show Never") →
  `Sections` VBox (`size_flags_horizontal = 3`), and `Bar` VSlider (`PackScrollBar`, `ui/pack_scroll_bar.gd`). In
  `Sections`: `FeedTitle` Label (`HeaderLabel`, "Feed") + `%Feed` VBox, `EggsTitle` ("Eggs") + `%Eggs`,
  `UpgradesTitle` ("Upgrades") + `%Upgrades`, then move the existing `PensTitle` and `%Pens` in (reparent keeps
  their `unique_id`s; set owner again). Save; restore uid lines; `--import`; `git checkout -- art`. The detail label
  `%Holds` in `buildable_row.tscn` gets `size_flags_horizontal = 3`, `text_overrun_behavior = 3`,
  `mouse_filter = 1` (text edit) and the row script-sets `tooltip_text` = detail — add
  `row.get_node("%Holds").tooltip_text = detail` in `_row`.
- [ ] **Step 5: Run** `test_market_panel.gd`, `test_popups.gd`, `test_panel_fit.gd`, `test_shop_scene.gd`, suite →
  PASS; suite `230 tests, 1 failed` (known only).
- [ ] **Step 6: Commit** the panel script/scene, `buildable_row.tscn`, `shop.gd`, test (+ uids): "Sell feed, eggs and
  upgrades in the Market".

### Task 3: Verify

- [ ] Render the Market (fresh game, real content) and after buying feed; read the PNGs (fits, readable, sections,
  locked eggs visibly disabled). Fix what they show, test-first where expressible. Suite + `--import` clean.
