# Bot playtest — design

Status: approved by delegation 2026-09-30 (owner asked: "have a bot playtest it if you end up finishing").

## Goal

A scripted player plays the real game — the farm scene and its panels, not just the rules — for many in-game days
from a fresh save, on several seeds, and writes a report: what it did each day, the economy over time, which slice
goals it reached, every script error, and where it got stuck. The report drives the balance/fix pass.

## Decisions

- **Runner** `tools/playtest/playtest.gd` (`extends SceneTree`, run with
  `godot --headless --path . -s res://tools/playtest/playtest.gd -- --days=30 --seeds=1,2,3 --out=<path>`). It is a
  tool, not a test: it never touches the player's save (`user://playtest_<seed>.json`), and it writes only its report
  (default `user://playtest_report.md`; the morning report copies it into `docs/playtest/`).
- **Bot** `tools/playtest/bot.gd` (`class_name PlaytestBot`, RefCounted): one `play_day(shop)` that acts through
  the farm's popups the way a player would — `shop.open_orders()` then the orders panel's buttons, the creature card's
  Train/Feed/Play/Retire/Sell buttons, the Stable's `pick` + Breed, the Expedition panel's `choose`/`pick` + Send,
  the Market's Buy buttons, the placer for pens, End Day. When a panel has no public way to do something the bot
  records it as a UI gap in the report instead of calling `Game` directly.
- **Policy** (simple, greedy, deterministic per seed):
  1. Accept offers while board slots are free (best reward per difficulty first).
  2. Deliver any owned creature that meets an accepted order.
  3. Keep feed ≥ 3; buy an egg when pens have room and money > 200; buy upgrades when money > cost + 200; build a pen
     when pens are full and money > pen cost + 100.
  4. Spend AP: care for babies below 60 mood; train toward the stat an accepted order needs (else the creature's best
     stat); send an expedition when a team of free adults passes ≥ 1 challenge (best location); retire and breed the
     two best same-egg-group adults once there are ≥ 4 owned adults.
  5. End the day.
- **Report** (Markdown): per seed a day table (day, gold, reputation, tier, owned/retired/eggs, orders active/filled/
  missed, AP used, actions), totals, slice goals reached (order of each kind filled, spark carried across two
  generations, pedigree of 3 generations, branching evolution, mid-day reload), every error with its day, stalls
  (a day with AP left and no action the bot could take; gold not growing for 5 days; an order kind never fillable),
  and UI gaps.
- Errors are caught with the same `Logger` technique as `tests/run_tests.gd`.

## Testing

- `tests/test_playtest_bot.gd`: one bot day on a fixture game completes without script errors and ends the day;
  the report writer produces the day table for a two-day run.
- Running the tool itself is the playtest; its report is committed under `docs/playtest/`.
