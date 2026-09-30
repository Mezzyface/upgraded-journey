# Expeditions — design

Status: approved in chat 2026-09-29 (sections 1–2). Approach 1: one two-column Expedition panel in the Stable's
slots-and-rows pattern; creatures on an expedition leave their pen until evening. Training-location choice on the
card is a separate spec.

## Goal

The player sends expeditions from the UI. In the Expedition panel they pick a location, see its challenges turn
met/missing as they pick a team of 1–3, see what can be found there, and press Send (2 AP) or read why they can't.
The team leaves the farm for the day; the evening summary reports what happened (already built). Done when a wild
egg found at a location, and an injury from a failed challenge, can be played by hand.

## What already exists (not changed)

- `Day.send_expedition` (2 AP; 1–3 creatures; refuses eggs, retired, busy, injured) records
  `state.expeditions` and marks the team `state.busy` and cared-for.
- `Expedition.resolve` in the evening: each challenge passes if any member meets it; each pass rolls a wild egg
  (`EGG_CHANCE`, needs pen space) or gold; each failure injures a random member; every member gains a little XP
  and leans Bold. `Day.end_day` runs it and clears `busy`.
- The day summary lists those events. The card shows "Away today".
- Three locations in `data/locations/` (Meadow, Mine, Old Forest), two challenges each, a loot table, a gold range.
- `RequirementGroup.describe()`, `Game.group_met(c, g)`, and the `OrderNeed` line scene (met/missing colours).

## Decisions

- One screen, two columns: location, challenges, finds, Send on the left; team slots and the creature list on the
  right.
- Location buttons show the picked team's total (`Mine 1/2`); list rows show how many challenges each creature
  meets alone (`2/2`).
- Every owned creature except eggs is listed; one that can't go is disabled and says why.
- Creatures on an expedition are not drawn in their pen until the evening clears `busy`.
- `StableRow` is renamed `CreatureRow` (it serves both panels) and gains a `blocked` note.
- No new state, no save changes.

## Constraints

- Godot changes go through the open editor via the godot-ai MCP (CLAUDE.md); scenes are laid out in the editor and
  scripts fill them. If the MCP is unavailable, scenes are built by Godot itself (headless, `PackedScene.pack` +
  `ResourceSaver.save`), uid header lines are kept, and `--headless --import` must be clean.
- Viewport 640×360; PanelHost is 640×320. New scrolling lists use the `VSlider` + `PackScrollBar` +
  `ui/pack_scroll_bar.gd` pattern.
- Existing theme variations only (`DecoratedButton`, `NamePlate`, `HeaderLabel`, `PackScrollBar`).
- `Game` stays the one path from the UI to the rules.

## 1. Rules and `Game`

- `Day.travel_reason(state, c) -> String`: `""` or, in order, `"no such creature"` (null), `_owned(c)`
  (`"retired creatures only breed"`, `"no longer in the shop"`), `"eggs can't travel"`, `_available(state, c)`
  (`"busy on an expedition today"`, `"injured for N more days"`).
- `Day.expedition_reason(state, db, location_id, team: Array) -> String`: the checks now in `send_expedition`, same
  order and wording: `"unknown location"`, `"a team is 1 to 3 creatures"`, then per member
  `"a creature can only go once"` for a repeated id and `travel_reason` otherwise, then `_afford(state,
  COST_EXPEDITION)`. `send_expedition` calls it and keeps its side effects unchanged.
- `Expedition.challenges_met(state, db, location_id, team: Array) -> int`: challenges passed by the team (any member
  meets the group, via `Orders.group_met`). `resolve` uses it for its `passes` count, so the preview is the result.
  Unknown location or empty team → 0.
- `Game.send_expedition(location_id, team) -> String` through `_did`, log line
  `"Sent Spider #1 and Slime #2 to the Mine"` (names joined with ", " and a final " and ").
- `Game.expedition_reason(location_id, team)`, `Game.travel_reason(c)`, `Game.challenges_met(location_id, team)`:
  thin wrappers.
- `Game.expeditions_today() -> Array[Dictionary]`: `{location: Location, team: Array[CreatureData]}` per entry of
  `state.expeditions`, skipping unknown locations and missing creatures.
- `shop.gd _refresh`: a pen syncs `Game.owned()` filtered to its pen **and** `not Game.state.busy.has(c.id)`.

## 2. Expedition panel — `shop/panels/expedition_panel.tscn` / `.gd` (new script, `class_name ExpeditionPanel`)

```
┌ Expedition ───────────────────────────────────────────────── [Close] ┐
│ [Meadow 2/2] [Mine 1/2] [Old Forest 0/2] │ [Spider #1] [Slime #2] [ + ]  │
│ ● Speed C or better                      │ ───────────────────────────── │
│ ● Knows a Nature or Beast move           │ [portrait] Spider #1  Dark · Bug  2/2 [Card] │
│ Finds: Spider, Wolf, Mushroom eggs ·     │ [portrait] Slime #2   injured for 2 more days [Card] │
│        10–30 gold                        │                                              │
│        [ Send (2 AP) ]   %Reason         │                                              │
│ Out today: Mine (Wolf #6)                │                                              │
└──────────────────────────────────────────────────────────────────────┘
```

- Keeps Title/`%Close`; removes the `Text` label. `Margin/Rows` holds Title and a `Body` HBox with `Left` and
  `Right` VBoxes.
- **Left:** `%Places` (HBox; one `DecoratedButton` per `Game.db.locations`, sorted by id, toggle mode in one
  ButtonGroup, created by the script; text `display_name`, or `"%s %d/%d"` with a team), `%Needs` (VBox of
  `OrderNeed` lines: `describe()`, not bonus, `met` = `null` with no team else whether the team passes that
  challenge), `%Finds` (Label, autowrap: `"Finds: " + species names (loot order, no repeats) + " eggs · "` and
  `"%d–%d gold"`; just the gold part when the loot table is empty), `%Send` (`DecoratedButton`,
  `"Send (%d AP)" % Day.COST_EXPEDITION`), `%Reason` (Label, autowrap, hidden when empty), `%Out` (Label, autowrap,
  `"Out today: Mine (Wolf #6), Meadow (…)"`, hidden when none).
- **Right:** `%Team` (HBox of `%Slot1..3`, `DecoratedButton`, `"Pick a creature"` when empty), an `HSeparator`, and a
  `Page` HBox: `Scroll` (ScrollContainer, vertical bar "Show Never") → `%List` (VBox), plus a `VSlider` with
  `PackScrollBar` and `ui/pack_scroll_bar.gd`.
- `var place: StringName` (selected location), `var team: Array[CreatureData]` (size 3, null = empty).
- `%List`: a `CreatureRow` per `Game.owned()` creature whose stage is not `"egg"`:
  `show_row(c, "%d/%d" % [met alone, challenge count], team.has(c), Game.travel_reason(c))`. Row Pick fills the next
  empty slot; a filled slot's press empties it; row Card emits `creature_chosen` (shop.gd opens the card in place).
- `%Send` enabled when the team has at least one creature and `Game.expedition_reason(place, members)` is `""`;
  otherwise `%Reason` shows the reason (capitalised) when the team is not empty.
- On Send: `Game.send_expedition(place, members)`; on `""` the slots clear and `signal sent(location: Location)`
  is emitted; `shop.gd open_expedition()` connects it to `toast("Off to the %s — back this evening" % name)`.
  A refusal shows in `%Reason`. Pressing Send with an empty team does nothing.
- Refills on `Game.changed` (method callable); a slotted creature that can no longer travel stays in its slot and the
  reason says why.
- Minimum size keeps the list at least 4 rows tall inside PanelHost (≤ 640×320).

### `CreatureRow` — renamed from `StableRow`

- `shop/panels/stable_row.{gd,tscn}` → `shop/panels/creature_row.{gd,tscn}` (git mv, uids kept),
  `class_name CreatureRow`, root node `CreatureRow`. `StablePanel` and its tests use the new name.
- `show_row(c, mark, in_slot, blocked := "")`: when `blocked` is not empty, Pick is disabled and `%Note` shows
  `blocked`; otherwise as today. The Stable passes no `blocked`.
- `%Note` clips long text with an ellipsis (`text_overrun_behavior`) and has a tooltip with the full text.

## Testing

- `test_day.gd`: `travel_reason` for null / retired / gone / egg / busy / injured / ok; `expedition_reason` returns
  each refusal and matches what `send_expedition` returns; `send_expedition` side effects unchanged.
- `test_expedition.gd`: `challenges_met` for a team that passes 0, 1 and 2 of the fixture cave's challenges equals
  `resolve`'s "N of M challenges passed".
- `test_game.gd`: `send_expedition` costs 2 AP, logs the line, emits `changed`; `expeditions_today` lists it.
- `test_expedition_panel.gd` (new): location buttons per location and the team totals; challenge lines coloured by
  the team; finds text; picking fills slots; blocked rows disabled with their reason; Send enabled only for a valid
  team; sending clears the slots, emits `sent`, and lists it in `%Out`; `Game.changed` refreshes the reason.
- `test_stable_panel.gd` / `test_popups.gd` / `test_shop_scene.gd`: renamed row class; a blocked row.
- `test_shop_scene.gd`: a sent creature is not in its pen's sprites; after End Day it is back.
- `test_panel_fit.gd` keeps the Expedition panel inside 640×360.
- Screenshots: the panel with a team picked, and the farm with the team gone. `--headless --import` clean.

## Out of scope

Training-location choice on the card · expedition animations or a map · multi-day expeditions · Tactics battles
(sub-project 3) · changing expedition balance or location content.
