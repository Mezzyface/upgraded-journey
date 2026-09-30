# Expeditions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The player sends expeditions from a two-column Expedition panel (location, challenges met/missing for the chosen team, finds, 1–3 team slots, Send or the reason), and the team leaves its pen until the evening.

**Architecture:** `Day.travel_reason` / `Day.expedition_reason` pull the refusal checks out of `Day.send_expedition`; `Expedition.challenges_met` is the pass count `resolve` and the preview share. `Game` wraps them plus `send_expedition` and `expeditions_today`. The Stable's `StableRow` becomes `CreatureRow` with a `blocked` note, reused by the new `ExpeditionPanel`. `shop.gd` skips busy creatures when syncing pens.

**Tech Stack:** Godot 4.7 (GDScript). godot-ai MCP when the editor is connected; otherwise headless Godot builds the scenes.

**Spec:** `docs/superpowers/specs/2026-09-29-expeditions-design.md`

## Global Constraints

- Godot changes through the godot-ai MCP when an editor session is connected. Otherwise (owner asleep, editor
  closed): scripts written as text; scenes built or re-saved by Godot itself from a temporary `-s` script that runs
  in `_initialize()` after `await process_frame` (so autoload `Game` exists), `PackedScene.pack` +
  `ResourceSaver.save`; then restore any dropped `uid="…"` header / `ext_resource` lines by text; a TabContainer or
  toggled node saved outside the tree may gain `visible = false` — remove it where the editor wouldn't write it; then
  `"$GODOT" --headless --path . --import` with no errors naming changed files. Delete temporary scripts.
- Test suite: `"$GODOT" --headless --path . -s res://tests/run_tests.gd` (`-- --only=test_x.gd` for one file),
  `GODOT="C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`.
  Baseline `211 tests, 1 failed` — only `test_theme.gd::test_nothing_references_isle_of_lore` (known). Scene tests
  start with `await tree.process_frame` (earlier tests' queued frees must land before `Game.start_new`) and await a
  frame after adding nodes to `tree.root` before using signals.
- Commits: plain subject, **no `Co-Authored-By`**, stage files by name, never push. Branch `expeditions` (exists).
- Existing theme variations only: `DecoratedButton`, `NamePlate`, `HeaderLabel`, `PackScrollBar`. New scrolling lists:
  ScrollContainer with vertical bar "Show Never" + `VSlider` (`PackScrollBar`, `ui/pack_scroll_bar.gd`).
- Viewport 640×360; PanelHost 640×320. `Game` is the one path from the UI to the rules.

## Review Focus

1. A location with no challenges (the fixture `mine`): buttons read `Mine 0/0`, no challenge lines, sending works.
   → Task 4 `test_locations_challenges_and_finds`.
2. The game changes while the panel is open (AP spent elsewhere): Send and the reason follow `Game.changed`.
   → Task 4 `test_send_state_follows_game_changes`.
3. Send pressed again after a success (slots cleared): nothing happens, no AP spent. → Task 4
   `test_send_costs_ap_clears_slots_and_lists_it`.
4. Long row notes ("busy on an expedition today") in the narrow right column: clipped with "…", full text in the
   tooltip. → Task 3 `test_blocked_row_is_disabled_and_says_why` + Task 5 screenshot.
5. Eggs and retired creatures never appear in the Expedition list; injured and away ones appear disabled.
   → Task 4 `test_picking_fills_slots_and_totals_update`.

---

### Task 1: `Day.travel_reason`, `Day.expedition_reason`, `Expedition.challenges_met`

**Files:**
- Modify: `creatures/rules/day.gd` (`send_expedition`), `creatures/rules/expedition.gd` (`resolve`)
- Test: `tests/test_day.gd`, `tests/test_expedition.gd`

**Interfaces:**
- Produces: `Day.travel_reason(state: GameState, c: CreatureData) -> String`;
  `Day.expedition_reason(state: GameState, db: Db, location_id: StringName, team: Array) -> String`;
  `Expedition.challenges_met(state: GameState, db: Db, location_id: StringName, team: Array) -> int` (team of
  CreatureData, nulls ignored).

- [ ] **Step 1: Failing tests** — append to `tests/test_day.gd`:

```gdscript
func test_travel_and_expedition_reasons_match_what_send_refuses() -> void:
	var db := Fixtures.db()
	var st := _state()
	var a := Fixtures.adult(st, "spider")
	var b := Fixtures.adult(st, "spider")
	eq(Day.travel_reason(st, null), "no such creature", "null")
	eq(Day.travel_reason(st, a), "", "free")
	var retired := Fixtures.adult(st, "spider")
	retired.status = CreatureData.Status.RETIRED
	eq(Day.travel_reason(st, retired), "retired creatures only breed", "retired")
	var gone := Fixtures.adult(st, "spider")
	gone.status = CreatureData.Status.GONE
	eq(Day.travel_reason(st, gone), "no longer in the shop", "gone")
	var egg := Fixtures.adult(st, "slime")
	egg.stage = "egg"
	eq(Day.travel_reason(st, egg), "eggs can't travel", "egg")
	b.injured_days = 2
	eq(Day.travel_reason(st, b), "injured for 2 more days", "injured")
	b.injured_days = 0
	eq(Day.expedition_reason(st, db, &"atlantis", [a]), "unknown location", "location")
	eq(Day.expedition_reason(st, db, &"cave", []), "a team is 1 to 3 creatures", "empty")
	eq(Day.expedition_reason(st, db, &"cave", [a, a]), "a creature can only go once", "twice")
	eq(Day.expedition_reason(st, db, &"cave", [a, egg]), "eggs can't travel", "a member's reason")
	st.ap = 1
	eq(Day.expedition_reason(st, db, &"cave", [a]), "not enough action points", "AP")
	st.ap = 5
	eq(Day.expedition_reason(st, db, &"cave", [a, b]), "", "valid")
	eq(Day.send_expedition(st, db, &"cave", [a, b]), "", "sent")
	eq(st.ap, 5 - Day.COST_EXPEDITION, "2 AP")
	check(st.busy.has(a.id) and st.busy.has(b.id), "both busy")
	eq(Day.travel_reason(st, a), "busy on an expedition today", "busy now")
	eq(Day.send_expedition(st, db, &"cave", [a]), Day.expedition_reason(st, db, &"cave", [a]), "same refusal")
```

Append to `tests/test_expedition.gd`:

```gdscript
func test_challenges_met_is_the_count_resolve_reports() -> void:
	var db := Fixtures.db()
	for case in [["spider", 50, 0], ["spider_albino", 100, 1], ["spider", 300, 1]]:
		var st := Fixtures.state(db)
		var c := Fixtures.adult(st, case[0], case[1])
		eq(Expedition.challenges_met(st, db, &"cave", [c]), case[2], "%s at %d" % [case[0], case[1]])
		var events := Expedition.resolve(st, db, &"cave", [c.id], Fixtures.rng())
		check(events[0].contains("%d of 2" % case[2]), "resolve agrees: %s" % events[0])
	var st2 := Fixtures.state(db)
	var dark := Fixtures.adult(st2, "spider_albino", 100)
	var tough := Fixtures.adult(st2, "spider", 300)
	eq(Expedition.challenges_met(st2, db, &"cave", [dark, tough]), 2, "any member meets each")
	eq(Expedition.challenges_met(st2, db, &"cave", [null, dark]), 1, "nulls ignored")
	eq(Expedition.challenges_met(st2, db, &"cave", []), 0, "empty team")
	eq(Expedition.challenges_met(st2, db, &"atlantis", [dark]), 0, "unknown location")
```

- [ ] **Step 2: Run** `test_day.gd` and `test_expedition.gd`. Expected: FAIL (both files fail to compile:
  `travel_reason` / `challenges_met` not found).

- [ ] **Step 3: Implement.** In `creatures/rules/day.gd` replace the whole `static func send_expedition(...)` with:

```gdscript
## "" when `c` could join an expedition today, otherwise why not. expedition_reason uses it per member.
static func travel_reason(state: GameState, c: CreatureData) -> String:
	if c == null:
		return "no such creature"
	var reason := _owned(c)
	if reason == "" and c.stage == "egg":
		reason = "eggs can't travel"
	if reason == "":
		reason = _available(state, c)
	return reason


## "" when `team` can go to `location_id` now, otherwise the reason. The Expedition panel shows it before Send, and
## send_expedition refuses with the same text.
static func expedition_reason(state: GameState, db: Db, location_id: StringName, team: Array) -> String:
	if not db.locations.has(location_id):
		return "unknown location"
	if team.is_empty() or team.size() > Expedition.MAX_TEAM:
		return "a team is 1 to 3 creatures"
	var ids: Array = []
	for member in team:
		var c: CreatureData = member
		if c != null and ids.has(c.id):
			return "a creature can only go once"
		var reason := travel_reason(state, c)
		if reason != "":
			return reason
		ids.append(c.id)
	return _afford(state, COST_EXPEDITION)


static func send_expedition(state: GameState, db: Db, location_id: StringName, team: Array) -> String:
	var reason := expedition_reason(state, db, location_id, team)
	if reason != "":
		return reason
	var ids: Array = team.map(func(c: CreatureData) -> int: return c.id)
	state.expeditions.append({"location": String(location_id), "team": ids})
	for id in ids:
		state.busy.append(id)
		if not state.cared.has(id):
			state.cared.append(id)
	state.ap -= COST_EXPEDITION
	return ""
```

In `creatures/rules/expedition.gd` add after `resolve`:

```gdscript
## How many of the location's challenges `team` (CreatureData; nulls ignored) passes: a challenge passes if any
## member meets it. resolve counts passes with this, so the Expedition panel's preview is the evening's result.
static func challenges_met(state: GameState, db: Db, location_id: StringName, team: Array) -> int:
	var loc: Location = db.locations.get(location_id)
	if loc == null:
		return 0
	var n := 0
	for g in loc.challenges:
		if g and team.any(func(c: CreatureData) -> bool: return c != null and Orders.group_met(c, g, db, state)):
			n += 1
	return n
```

and in `resolve` replace

```gdscript
	var passes := 0
	for g in loc.challenges:
		if g and team.any(func(c: CreatureData) -> bool: return Orders.group_met(c, g, db, state)):
			passes += 1
```

with `	var passes := challenges_met(state, db, location_id, team)`.

- [ ] **Step 4: Run** both files, then the suite. Expected: both PASS; suite `213 tests, 1 failed` (known only).
- [ ] **Step 5: Commit** `creatures/rules/day.gd creatures/rules/expedition.gd tests/test_day.gd tests/test_expedition.gd`:
  "Add Day.travel_reason, Day.expedition_reason and Expedition.challenges_met".

---

### Task 2: `Game` expedition actions, and away creatures leave their pen

**Files:**
- Modify: `game/game.gd`, `shop/shop.gd` (`_refresh`)
- Test: `tests/test_game.gd`, `tests/test_shop_scene.gd`

**Interfaces:**
- Consumes: Task 1.
- Produces: `Game.send_expedition(location_id: StringName, team: Array) -> String`;
  `Game.expedition_reason(location_id: StringName, team: Array) -> String`; `Game.travel_reason(c) -> String`;
  `Game.challenges_met(location_id: StringName, team: Array) -> int`;
  `Game.expeditions_today() -> Array[Dictionary]` of `{"location": Location, "team": Array[CreatureData]}`.

- [ ] **Step 1: Failing tests** — append to `tests/test_game.gd`:

```gdscript
func test_send_expedition_costs_ap_logs_and_lists_it() -> void:
	var g := _game()
	var a: CreatureData = g.owned()[0]
	var b: CreatureData = g.owned()[1]
	var count := [0]
	g.changed.connect(func() -> void: count[0] += 1)
	var ap: int = g.state.ap
	eq(g.expedition_reason(&"cave", [a, b]), "", "valid")
	eq(g.travel_reason(a), "", "a can travel")
	check(g.challenges_met(&"cave", [a, b]) >= 0, "a count")
	eq(g.send_expedition(&"cave", [a, b]), "", "sent")
	eq(g.state.ap, ap - Day.COST_EXPEDITION, "2 AP")
	eq(count[0], 1, "changed once")
	eq(g.day_log[-1], "Sent %s and %s to the Cave" % [g.who(a), g.who(b)], "logged")
	var today: Array[Dictionary] = g.expeditions_today()
	eq(today.size(), 1, "one expedition")
	eq(today[0]["location"].id, &"cave", "to the cave")
	eq(today[0]["team"], [a, b], "with both")
	eq(g.send_expedition(&"cave", [a]), g.expedition_reason(&"cave", [a]), "refused with the panel's reason")
	eq(count[0], 1, "no change on refusal")
	g.state.expeditions.append({"location": "atlantis", "team": [a.id]})
	eq(g.expeditions_today().size(), 1, "unknown locations skipped")
	_cleanup(g)
```

Append to `tests/test_shop_scene.gd`:

```gdscript
func test_a_creature_on_an_expedition_leaves_its_pen_until_evening() -> void:
	await tree.process_frame
	var shop := _shop()
	await tree.process_frame
	var c: CreatureData = Game.owned()[0]
	var pen: SpawnArea = shop.call("pen_area", c.pen)
	var shown := func() -> Array: return pen.sprites().map(func(s: CreatureSprite) -> int: return s.creature.id)
	check(shown.call().has(c.id), "in its pen")
	eq(Game.send_expedition(&"meadow", [c]), "", "sent")
	await tree.process_frame
	check(not shown.call().has(c.id), "gone for the day")
	Game.end_day()
	await tree.process_frame
	check(shown.call().has(c.id), "back after the evening")
	_done(shop)
```

- [ ] **Step 2: Run** `test_game.gd`, `test_shop_scene.gd`. Expected: FAIL (`expedition_reason` nonexistent;
  "gone for the day" fails).

- [ ] **Step 3: Implement.** In `game/game.gd` after `func compat_mark(...)` add:

```gdscript
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
```

and before `func who(`:

```gdscript
## "A", "A and B", "A, B and C".
static func _and_list(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]
```

In `shop/shop.gd` `_refresh()` replace the `pen.sync(...)` filter with:

```gdscript
			pen.sync(Game.owned().filter(func(c: CreatureData) -> bool:
				return c.pen == p["id"] and not Game.state.busy.has(c.id)), Game.db, _rng)  # away on an expedition: gone until evening
```

and add to the header comment: "Creatures away on an expedition are not drawn until the evening."

- [ ] **Step 4: Run** both files, then the suite. Expected: PASS; suite `215 tests, 1 failed` (known only).
- [ ] **Step 5: Commit** `game/game.gd shop/shop.gd tests/test_game.gd tests/test_shop_scene.gd`: "Add Game
  expedition actions and keep away creatures out of their pens".

---

### Task 3: `StableRow` → `CreatureRow` with a `blocked` note

**Files:**
- Rename: `shop/panels/stable_row.gd` → `creature_row.gd` (+ `.gd.uid`), `stable_row.tscn` → `creature_row.tscn`
- Modify: `shop/panels/stable_panel.gd`, `tests/test_stable_panel.gd`, `tests/test_popups.gd`, `tests/test_shop_scene.gd`
- Test: `tests/test_stable_panel.gd`

**Interfaces:**
- Produces: `class_name CreatureRow` (root node `CreatureRow`), `signal picked(c)`, `signal card_pressed(c)`,
  `func show_row(c: CreatureData, mark: String, in_slot: bool, blocked := "") -> void`; scene
  `res://shop/panels/creature_row.tscn`.

- [ ] **Step 1: Rename and failing test.** `git mv` the three files; in all `.gd`/`.tscn` files replace
  `StableRow` → `CreatureRow` and `stable_row.` → `creature_row.` (the tscn's root `[node name="StableRow"` and its
  ext_resource path). Append to `tests/test_stable_panel.gd`:

```gdscript
func test_blocked_row_is_disabled_and_says_why() -> void:
	await tree.process_frame
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"]])
	Game.start_new(setup, db, 4)
	var spider: CreatureData = Game.owned()[0]
	var row: CreatureRow = load("res://shop/panels/creature_row.tscn").instantiate()
	tree.root.add_child(row)
	await tree.process_frame
	row.show_row(spider, "1/2", false, "busy on an expedition today")
	check(row.get_node("%Pick").disabled, "blocked: not pickable")
	eq(row.get_node("%Note").text, "busy on an expedition today", "says why")
	eq(row.get_node("%Note").tooltip_text, "busy on an expedition today", "full text on hover")
	eq(row.get_node("%Note").text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "long notes clip with …")
	row.show_row(spider, "", false)
	check(not row.get_node("%Pick").disabled, "not blocked: pickable again")
	eq(row.get_node("%Note").text, "Dark · Bug", "back to element and egg group")
	row.queue_free()
	DirAccess.remove_absolute(SAVE)
```

- [ ] **Step 2: Run** `test_stable_panel.gd`. Expected: FAIL (`show_row` takes 3 arguments / overrun behaviour 0).
- [ ] **Step 3: Implement.** `shop/panels/creature_row.gd`:

```gdscript
class_name CreatureRow
extends HBoxContainer
## One creature in a list (creature_row.tscn), used by the Stable and the Expedition panel: Pick (portrait and name)
## puts it in the panel's next empty slot, the note gives its element and egg group, how long it still rests, or
## `blocked` (why it can't be picked), the mark is the panel's score for it, and Card opens its card.

signal picked(c: CreatureData)
signal card_pressed(c: CreatureData)

var creature: CreatureData


func _ready() -> void:
	%Pick.pressed.connect(func() -> void: picked.emit(creature))
	%Card.pressed.connect(func() -> void: card_pressed.emit(creature))


## `mark`: the panel's score for this creature ("" for none). `in_slot` or a non-empty `blocked` disables Pick;
## `blocked` also replaces the note.
func show_row(c: CreatureData, mark: String, in_slot: bool, blocked := "") -> void:
	creature = c
	var sp := Game.species_of(c)
	%Pick.icon = CreatureAnim.portrait(sp.sprite_frames) if sp else null
	%Pick.text = Game.who(c)
	%Pick.disabled = in_slot or blocked != ""
	if blocked != "":
		%Note.text = blocked
	elif c.breed_cooldown > 0:
		%Note.text = "rests %d day%s" % [c.breed_cooldown, "" if c.breed_cooldown == 1 else "s"]
	else:
		%Note.text = "%s · %s" % [String(sp.element).capitalize(), String(sp.egg_group).capitalize()] if sp else ""
	%Note.tooltip_text = %Note.text
	%Mark.text = mark
```

In `creature_row.tscn`, on the `Note` node add: `size_flags_horizontal = 3`, `mouse_filter = 1`,
`text_overrun_behavior = 3` (text edit; the node already exists). `stable_panel.gd`: `ROW` path and
`var row: CreatureRow`.

- [ ] **Step 4: Run** `test_stable_panel.gd`, `test_popups.gd`, `test_shop_scene.gd`, `--import`, then the suite.
  Expected: PASS; suite `216 tests, 1 failed` (known only).
- [ ] **Step 5: Commit** the renamed files, `stable_panel.gd`, and the three tests: "Rename StableRow to CreatureRow and
  let a row be blocked with a reason".

---

### Task 4: The Expedition panel

**Files:**
- Create: `shop/panels/expedition_panel.gd`
- Modify: `shop/panels/expedition_panel.tscn` (Godot-built), `shop/shop.gd` (`open_expedition`)
- Test: `tests/test_expedition_panel.gd` (new)

**Interfaces:**
- Consumes: Tasks 2–3; `OrderNeed.show_need(description: String, bonus: bool, met: Variant)`,
  `RequirementGroup.describe()`, `Game.group_met(c, g)`.
- Produces: `class_name ExpeditionPanel` with `signal creature_chosen(c: CreatureData)`,
  `signal sent(location: Location)`, `const EMPTY_SLOT := "Pick a creature"`, `var place: StringName`,
  `var team: Array[CreatureData]` (size 3), `func choose(id: StringName)`, `func pick(c: CreatureData)`,
  `func members() -> Array[CreatureData]`, `func refresh()`. Unique nodes: `%Close`, `%Places`, `%Needs`, `%Finds`,
  `%Send`, `%Reason`, `%Out`, `%Slot1`, `%Slot2`, `%Slot3`, `%List`.

- [ ] **Step 1: Failing tests** — create `tests/test_expedition_panel.gd`:

```gdscript
extends TestSuite
## The Expedition panel (expedition_panel.tscn): locations, challenges, finds, team slots and Send.

const SAVE := "user://test_expedition_panel_save.json"


## Fixture content, no starters: dark = Spider Albino (Darksight, guard D: passes the cave's first challenge),
## tough = Spider with guard C (passes the second), hurt = an injured Spider, and an egg that must not be listed.
## Returns [host, panel, dark, tough, hurt]; await it.
func _panel() -> Array:
	await tree.process_frame
	Game.save_path = SAVE
	var db := Fixtures.db()
	db.locations[&"mine"].display_name = "Mine"
	var setup := NewGameSetup.new()
	setup.start_pen = db.buildables[&"pen"]
	Game.start_new(setup, db, 7)
	var dark := Fixtures.adult(Game.state, "spider_albino", 100)
	var tough := Fixtures.adult(Game.state, "spider", 300)
	var hurt := Fixtures.adult(Game.state, "spider", 300)
	hurt.injured_days = 2
	Fixtures.adult(Game.state, "slime").stage = "egg"
	var host := PanelHost.new()
	host.size = Vector2(640, 320)
	tree.root.add_child(host)
	var panel: ExpeditionPanel = load("res://shop/panels/expedition_panel.tscn").instantiate()
	host.open(panel)
	await tree.process_frame
	return [host, panel, dark, tough, hurt]


func _done(host: Node) -> void:
	host.queue_free()
	DirAccess.remove_absolute(SAVE)


func _texts(parent: Node) -> Array:
	return parent.get_children().map(func(b: Button) -> String: return b.text)


func _row(panel: ExpeditionPanel, c: CreatureData) -> CreatureRow:
	for row: CreatureRow in panel.get_node("%List").get_children():
		if row.creature == c:
			return row
	return null


func test_locations_challenges_and_finds() -> void:
	var parts: Array = await _panel()
	var panel: ExpeditionPanel = parts[1]
	eq(_texts(panel.get_node("%Places")), ["Cave", "Mine"], "a button per location, sorted by id")
	eq(panel.place, &"cave", "the first is chosen")
	var cave: Location = Game.db.locations[&"cave"]
	eq(panel.get_node("%Needs").get_child_count(), 2, "a line per challenge")
	eq(panel.get_node("%Needs").get_child(0).get_node("%Text").text, cave.challenges[0].describe(), "its text")
	eq(panel.get_node("%Finds").text, "Finds: Spider Albino, Spider eggs · 10–20 gold", "eggs and gold")
	panel.choose(&"mine")
	eq(panel.get_node("%Needs").get_child_count(), 0, "the mine has no challenges")
	eq(panel.get_node("%Finds").text, "Finds: 10–40 gold", "gold only without loot")
	panel.pick(parts[2])
	eq(_texts(panel.get_node("%Places")), ["Cave 1/2", "Mine 0/0"], "totals for the team")
	check(not panel.get_node("%Send").disabled, "a location without challenges can still be sent to")
	_done(parts[0])


func test_picking_fills_slots_and_totals_update() -> void:
	var parts: Array = await _panel()
	var panel: ExpeditionPanel = parts[1]
	var dark: CreatureData = parts[2]
	var tough: CreatureData = parts[3]
	var hurt: CreatureData = parts[4]
	eq(panel.get_node("%List").get_child_count(), 3, "every owned non-egg creature")
	eq(panel.get_node("%Slot1").text, ExpeditionPanel.EMPTY_SLOT, "empty slot")
	check(panel.get_node("%Send").disabled, "no team, no Send")
	check(not panel.get_node("%Reason").visible, "no reason without a team")
	eq(_row(panel, tough).get_node("%Mark").text, "1/2", "a row's mark: challenges it meets alone")
	check(_row(panel, hurt).get_node("%Pick").disabled, "injured: disabled")
	eq(_row(panel, hurt).get_node("%Note").text, "injured for 2 more days", "and says why")
	panel.pick(dark)
	eq(panel.get_node("%Slot1").text, Game.who(dark), "slot 1 filled")
	check(_row(panel, dark).get_node("%Pick").disabled, "a slotted creature can't be picked twice")
	var need: OrderNeed = panel.get_node("%Needs").get_child(1)
	eq(_color(need), need.missing_color, "guard challenge missing with only dark")
	panel.pick(tough)
	eq(_texts(panel.get_node("%Places"))[0], "Cave 2/2", "both challenges with both")
	need = panel.get_node("%Needs").get_child(1)
	eq(_color(need), need.met_color, "guard challenge met with tough")
	panel.pick(hurt)
	eq(panel.team[2], null, "an injured creature can't be picked")
	panel.get_node("%Slot1").pressed.emit()
	eq(panel.team[0], null, "pressing a filled slot empties it")
	eq(panel.members(), [tough] as Array[CreatureData], "members skips empty slots")
	_done(parts[0])


func _color(need: OrderNeed) -> Color:
	var text: Label = need.get_node("%Text")
	return text.label_settings.font_color if text.label_settings else text.get_theme_color("font_color")


func test_send_costs_ap_clears_slots_and_lists_it() -> void:
	var parts: Array = await _panel()
	var panel: ExpeditionPanel = parts[1]
	var dark: CreatureData = parts[2]
	var tough: CreatureData = parts[3]
	var sent: Array = []
	panel.sent.connect(func(l: Location) -> void: sent.append(l.id))
	check(not panel.get_node("%Out").visible, "nothing out yet")
	panel.pick(dark)
	panel.pick(tough)
	var ap := Game.state.ap
	panel.get_node("%Send").pressed.emit()
	eq(Game.state.ap, ap - Day.COST_EXPEDITION, "2 AP")
	eq(sent, [&"cave"], "sent emitted")
	check(panel.members().is_empty(), "slots cleared")
	eq(panel.get_node("%Out").text, "Out today: Cave (%s, %s)" % [Game.who(dark), Game.who(tough)], "listed")
	check(panel.get_node("%Out").visible, "shown")
	eq(_row(panel, dark).get_node("%Note").text, "busy on an expedition today", "away now")
	panel.get_node("%Send").pressed.emit()  # a second click with the slots empty
	eq(Game.state.ap, ap - Day.COST_EXPEDITION, "nothing more spent")
	_done(parts[0])


func test_send_state_follows_game_changes() -> void:
	var parts: Array = await _panel()
	var panel: ExpeditionPanel = parts[1]
	panel.pick(parts[3])
	check(not panel.get_node("%Send").disabled, "can send")
	Game.state.ap = 0
	Game.changed.emit()
	check(panel.get_node("%Send").disabled, "AP gone: Send disabled")
	eq(panel.get_node("%Reason").text, "Not enough action points", "and says why")
	check(panel.get_node("%Reason").visible, "shown")
	eq(panel.team[0], parts[3], "the team is kept")
	_done(parts[0])


func test_card_button_emits_creature_chosen() -> void:
	var parts: Array = await _panel()
	var panel: ExpeditionPanel = parts[1]
	var chosen: Array = []
	panel.creature_chosen.connect(func(c: CreatureData) -> void: chosen.append(c))
	_row(panel, parts[3]).get_node("%Card").pressed.emit()
	eq(chosen, [parts[3]], "Card opens that creature")
	_done(parts[0])
```

- [ ] **Step 2: Run** `test_expedition_panel.gd`. Expected: FAIL (does not compile: `ExpeditionPanel` unknown).
- [ ] **Step 3: Script.** Create `shop/panels/expedition_panel.gd`:

```gdscript
class_name ExpeditionPanel
extends PanelContainer
## Send an expedition (docs/superpowers/specs/2026-09-29-expeditions-design.md). Left: pick a location in %Places
## (with a team, each button shows how many challenges it passes there, "Mine 1/2"), its challenges in %Needs
## (met/missing for the team), what can be found in %Finds, Send or %Reason, and today's expeditions in %Out.
## Right: three team slots and a CreatureRow per owned creature (eggs left out); one that can't go is disabled and
## says why, and its mark is how many challenges it meets alone. Refreshes on Game.changed.

signal creature_chosen(c: CreatureData)
signal sent(location: Location)

const ROW := preload("res://shop/panels/creature_row.tscn")
const NEED := preload("res://shop/panels/order_need.tscn")
const EMPTY_SLOT := "Pick a creature"

var place: StringName
var team: Array[CreatureData] = [null, null, null]
var _group := ButtonGroup.new()


func _ready() -> void:
	%Close.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close())
	for i in team.size():
		_slot(i).pressed.connect(_empty_slot.bind(i))
	%Send.text = "Send (%d AP)" % Day.COST_EXPEDITION
	%Send.pressed.connect(_send)
	var ids: Array = Game.db.locations.keys()
	ids.sort()
	for id: StringName in ids:
		var b := Button.new()
		b.name = String(id)
		b.theme_type_variation = &"DecoratedButton"
		b.toggle_mode = true
		b.button_group = _group
		b.pressed.connect(choose.bind(id))
		%Places.add_child(b)
	if not ids.is_empty():
		place = ids[0]
	Game.changed.connect(refresh)
	refresh()


func choose(id: StringName) -> void:
	place = id
	refresh()


## Puts `c` in the next empty slot; ignored when the team is full, `c` is already in it, or `c` can't travel.
func pick(c: CreatureData) -> void:
	var i := team.find(null)
	if i < 0 or team.has(c) or Game.travel_reason(c) != "":
		return
	team[i] = c
	refresh()


func members() -> Array[CreatureData]:
	var out: Array[CreatureData] = []
	for c in team:
		if c:
			out.append(c)
	return out


func refresh() -> void:
	var loc: Location = Game.db.locations.get(place)
	var picked := members()
	for b: Button in %Places.get_children():
		var l: Location = Game.db.locations.get(StringName(b.name))
		if l == null:
			continue
		b.text = l.display_name if picked.is_empty() else \
				"%s %d/%d" % [l.display_name, Game.challenges_met(l.id, picked), l.challenges.size()]
		b.set_pressed_no_signal(l.id == place)
	_clear(%Needs)
	if loc:
		for g in loc.challenges:
			if g == null:
				continue
			var line: OrderNeed = NEED.instantiate()
			%Needs.add_child(line)
			var met: Variant = null if picked.is_empty() else picked.any(func(c: CreatureData) -> bool: return Game.group_met(c, g))
			line.show_need(g.describe(), false, met)
	%Finds.text = _finds(loc) if loc else ""
	for i in team.size():
		var c := team[i]
		var sp: Species = Game.species_of(c) if c else null
		_slot(i).text = Game.who(c) if c else EMPTY_SLOT
		_slot(i).icon = CreatureAnim.portrait(sp.sprite_frames) if sp else null
	var reason := Game.expedition_reason(place, picked) if not picked.is_empty() else ""
	%Send.disabled = picked.is_empty() or reason != ""
	_show(%Reason, _sentence(reason))
	var outs: PackedStringArray = []
	for ex in Game.expeditions_today():
		var names := PackedStringArray(ex["team"].map(func(c: CreatureData) -> String: return Game.who(c)))
		outs.append("%s (%s)" % [ex["location"].display_name, ", ".join(names)])
	_show(%Out, "Out today: " + ", ".join(outs) if not outs.is_empty() else "")
	_clear(%List)
	var total := loc.challenges.size() if loc else 0
	for c: CreatureData in Game.owned():
		if c.stage == "egg":
			continue
		var row: CreatureRow = ROW.instantiate()
		%List.add_child(row)
		var alone := "%d/%d" % [Game.challenges_met(place, [c]), total] if total > 0 else ""
		row.show_row(c, alone, team.has(c), Game.travel_reason(c))
		row.picked.connect(pick)
		row.card_pressed.connect(creature_chosen.emit)


func _slot(i: int) -> Button:
	return get_node("%%Slot%d" % (i + 1))


func _empty_slot(i: int) -> void:
	team[i] = null
	refresh()


func _send() -> void:
	var picked := members()
	if picked.is_empty():
		return  # e.g. a second click after the slots cleared
	var reason := Game.send_expedition(place, picked)
	if reason != "":
		_show(%Reason, _sentence(reason))
		return
	team.fill(null)
	refresh()
	sent.emit(Game.db.locations[place])


## "Finds: Spider, Wolf eggs · 10–30 gold" (species in loot order, no repeats); just the gold without loot.
static func _finds(loc: Location) -> String:
	var names: PackedStringArray = []
	for e in loc.loot:
		if e and e.species and not names.has(e.species.display_name):
			names.append(e.species.display_name)
	var eggs := ", ".join(names) + " eggs · " if not names.is_empty() else ""
	return "Finds: %s%d–%d gold" % [eggs, loc.money_min, loc.money_max]


## Empty text hides the line so the column keeps its room.
static func _show(label: Label, text: String) -> void:
	label.text = text
	label.visible = text != ""


static func _sentence(reason: String) -> String:
	return reason.left(1).to_upper() + reason.substr(1)


static func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
```

In `shop/shop.gd` replace `open_expedition()` with:

```gdscript
func open_expedition() -> void:
	var panel: ExpeditionPanel = EXPEDITION.instantiate()
	%PanelHost.open(panel)
	panel.creature_chosen.connect(open_card)
	panel.sent.connect(func(loc: Location) -> void: toast("Off to the %s — back this evening" % loc.display_name))
```

- [ ] **Step 4: Scene.** Build with a temporary `-s` script (Global Constraints): load
  `expedition_panel.tscn` with `GEN_EDIT_STATE_MAIN`; set the root script to `expedition_panel.gd`,
  `custom_minimum_size = Vector2(600, 280)`; free `Margin/Rows/Text`; add under `Margin/Rows` a `Body` HBox
  (`size_flags_vertical = 3`, separation 8) with:
  - `Left` VBox (`custom_minimum_size.x = 280`, `size_flags_horizontal = 3`): `%Places` HFlowContainer (h/v separation
    4); `%Needs` VBox; `%Finds` Label (autowrap word-smart); `%Send` Button (`DecoratedButton`,
    `size_flags_horizontal = 4`, text "Send (2 AP)", disabled); `%Reason` Label (autowrap, centered, hidden);
    `%Out` Label (autowrap, hidden).
  - a `VSeparator`.
  - `Right` VBox (`size_flags_horizontal = 3`): `%Team` HBox with `%Slot1..3` (`DecoratedButton`,
    `custom_minimum_size = Vector2(0, 28)`, `size_flags_horizontal = 3`, `expand_icon = true`, `clip_text = true`,
    text "Pick a creature"); an `HSeparator`; `Page` HBox (`size_flags_vertical = 3`): `Scroll` ScrollContainer
    (`size_flags_horizontal/vertical = 3`, horizontal disabled, vertical "Show Never") → `%List` VBox
    (`size_flags_horizontal = 3`); `Bar` VSlider (`PackScrollBar`, script `ui/pack_scroll_bar.gd`).
  Set `owner` and `unique_name_in_owner` for each `%` node. Save; restore uid lines; remove any stray
  `visible = false`; `--import`.
- [ ] **Step 5: Run** `test_expedition_panel.gd`, `test_popups.gd`, `test_panel_fit.gd`, `test_shop_scene.gd`, then
  the suite. Expected: PASS; suite `221 tests, 1 failed` (known only).
- [ ] **Step 6: Commit** `shop/panels/expedition_panel.gd shop/panels/expedition_panel.gd.uid
  shop/panels/expedition_panel.tscn shop/shop.gd tests/test_expedition_panel.gd tests/test_expedition_panel.gd.uid`:
  "Send expeditions from a two-column Expedition panel".

---

### Task 5: Verify in the running game

- [ ] A temporary `-s` script (not committed, typed only with built-in/rule classes so it compiles before
  autoloads) starts a scratch game (`Game.save_path = "user://expedition_shot.json"`, `new_game.tres`, seed 5),
  opens the shop, opens the Expedition panel, picks two creatures, screenshots it, sends, screenshots the farm and
  the panel, ends the day, screenshots the summary. Read every PNG: fits 640×360, text legible, notes clip, the team
  is gone from the pen, the summary lists the expedition.
- [ ] Fix anything the screenshots show (test-first where a test can express it); ledger rulings.
- [ ] Suite + `--import` clean; `git status` clean.
