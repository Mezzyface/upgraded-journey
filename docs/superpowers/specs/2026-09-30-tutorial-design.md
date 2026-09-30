# Tutorial — design

Status: approved by delegation 2026-09-30 (owner asked: "also add in tutorial"; owner asleep).

## Goal

A new player learns the loop by doing it: one short hint at a time in a corner box, each finished by doing the thing
it asks. It covers orders, the creature card, training, care, ending the day, retiring and breeding, expeditions,
the Market and delivering. It can be skipped, never blocks input, and remembers its place in the save.

## Decisions

- **Hint box** `ui/tutorial_hint.tscn` (`class_name TutorialHint`, PanelContainer, `TooltipPanel` variation): a
  `%Text` label (autowrap), a step counter `%Step` ("3/10"), and `%Skip` ("Skip tutorial"). Anchored bottom-left of
  the farm above the toast line, `mouse_filter` pass-through except the Skip button; drawn above popups (z 10) so it
  stays readable while a popup is open.
- **Steps** are data in code (`Tutorial.STEPS`, an Array of `{text, done}`), checked against the state and against
  what the player just did. Order:
  1. "Customers post requests on the Orders board. Open it from the shop door or the Orders tag." — opened Orders.
  2. "Accept a request: it shows what the customer wants and when." — an order accepted.
  3. "Click a creature in the pen to open its card." — a card opened.
  4. "Train raises a stat for 1 heart (action point). Hearts refill every morning." — trained.
  5. "Feed or Play keeps a creature happy; happy babies grow up well." — cared.
  6. "The Market sells feed, eggs, upgrades and pens." — opened the Market.
  7. "Out of hearts? Press End Day. Eggs hatch and babies grow overnight." — a day ended.
  8. "Send up to three creatures on an expedition to find eggs and gold — check the challenges first." — sent.
  9. "Retire two grown creatures to the Stable and breed them: the egg inherits their sparks." — bred.
  10. "When a creature meets a request, deliver it from the Orders board." — delivered.
  Done shows "You know the ranch now — have fun!" for one refresh, then hides.
- **Events**: `Game` gains `signal acted(what: StringName)`, emitted by `_did` on success with one of
  `&"train"`, `&"care"`, `&"retire"`, `&"sell"`, `&"build"`, `&"accept"`, `&"deliver"`, `&"breed"`,
  `&"expedition"`, `&"buy"`, `&"end_day"`. Opening popups is reported by the shop:
  `Tutorial.saw(what)` with `&"orders"`, `&"card"`, `&"market"`.
- **State**: `GameState.tutorial_step: int` (0-based; `STEPS.size()` = finished; `-1` = skipped), saved as
  `"tutorial_step"` (missing in old saves → finished, so existing players aren't shown it).
  New games start at 0.
- **Logic** `ui/tutorial.gd` (`class_name Tutorial`, RefCounted, static): `static func advance(step: int, what:
  StringName) -> int` (returns the next step when `what` completes `step`, else `step`), so it is testable without
  scenes. The hint node calls it on `Game.acted` and on `saw(...)` from the shop, writes `Game.state.tutorial_step`
  and saves through `Game`.
- Completing a later step early (e.g. breeding before training) does not skip ahead — only the current step's action
  advances; the hints are ordered to match a natural first day or two.

## Testing

- `test_tutorial.gd`: `advance` for every step's action and for wrong actions; skipped/finished stay put.
- `test_game.gd`: `acted` emitted with the right key for each action, not on refusals.
- `test_state.gd`: `tutorial_step` round-trips; a save without it loads as finished.
- `test_tutorial_hint.gd`: the hint shows step 1 on a new game, advances on the matching action, Skip hides it
  and saves `-1`, finished hides it.
- Screenshot of the farm with the hint.
