# Shop UI — design (Plan 2b-1)

Status: approved design, 2026-09-27. Builds on the day loop (`docs/superpowers/specs/2026-09-26-day-loop-design.md`)
and the creature core (`docs/superpowers/specs/2026-09-26-creature-shop-design.md`). Scope: the first playable UI —
the shop screen, the creature card, the orders counter, training/care/retire/sell, the end of day, and two rule
changes. Plan 2b-2 adds breeding, market and upgrades, expeditions and the menus.

## Decisions

- **Layout:** full-screen shop (1280×720, Isle of Lore theme) with clickable stations and creatures that open themed
  panels over the scene (layout A).
- **One façade:** a `Game` autoload is the only path from UI to rules; one `changed` signal refreshes the UI.
- **Editor-visible spawning:** everything spawned at runtime (creatures, panels) appears at a scene node you can see,
  move and resize in the editor, with placeholders drawn in the editor.
- **Selling pays a small, quality-scaled amount** instead of 0.
- **Order deadlines are computed from difficulty**, with a per-template hand-tuning offset.

## 1. Game autoload (`game/game.gd`, autoload name `Game`)

- Holds `db: Db`, `state: GameState`, `rng: RandomNumberGenerator`.
- Startup: load `user://save.json` (`GameState.load_file`); if missing or unloadable, `Day.new_game(load("res://data/new_game.tres"), ...)`.
  A loaded save with an empty board posts the day's offers (version-1 saves).
- Action wrappers, each returning `""` or the refusal reason and emitting `changed` on success:
  `train(c, stat)` (at the Mine), `care(c, kind)`, `retire(c)`, `sell(c)`, `accept(template_id)`, `deliver(index, c)`,
  `end_day() -> PackedStringArray` (events; autosaves after the evening).
- Query helpers for the UI: `owned()`, `retired()`, `sell_price(c)`, `order_check(index, c)`, `best_match(index)`.
- No other autoload and no signal bus in 2b-1.

## 2. Shop scene (`shop/shop.tscn`, the run scene)

Built in the editor (godot-ai scene/node tools). Nodes the owner can move and resize:

- **HUD** (top): banner bar with day, AP, money, reputation + tier, and an **End day** button.
- **Stations** (hotspot buttons): **Counter** → orders panel; **Market stall** and **Door** → "coming soon" until 2b-2.
- **Pens** and **Stable**: each contains a `SpawnArea`.
- **PanelHost**: where panels open and how large they may be.

### SpawnArea (`shop/spawn_area.gd`, `@tool`, extends `Control`)

- In the editor: draws a dashed outline and up to `preview_count` ghost creatures using `preview_frames`
  (a SpriteFrames), at `sprite_scale`, so size, scale and spacing are visible while editing.
- At runtime: hides the preview; `populate(creatures)` spawns one `CreatureSprite` per creature at random points
  inside its rect; creatures wander only inside it.
- `@export`: `preview_frames`, `preview_count` (default 4), `sprite_scale` (default 3.0), `baby_scale` (0.7 of adult),
  `max_shown` (default 12), `wander_speed`.

### CreatureSprite (`shop/creature_sprite.tscn` + `.gd`)

- `AnimatedSprite2D`, nearest filter, scaled by its area. Wanders: idle for a random 1–3 s, then walks to a random
  point in the area, facing left/right. Eggs show a placeholder egg sprite; babies are smaller. Clicking opens the
  creature card.
- **Fallback animations** (issue #1): `CreatureAnim.pick(frames, wanted, facing) -> StringName` tries
  `move → idle`, `attack → melee → ability → idle`, keeping the facing; a creature always animates.

### PanelHost (`shop/panel_host.gd`, `@tool`)

- Shows a placeholder frame in the editor; at runtime hosts one panel at a time over the scene (Esc / ✕ closes).

## 3. Panels (themed: DialogBox, NamePlate, InventorySlot, DecoratedButton)

- **Creature card:** portrait (current animation), name + id, stage, element, egg group, personality, mood; five stat
  bars with the potential cap marked and the grade letter; traits and moves as chips; parents and grandparents line.
  Buttons: Train (choose stat), Feed, Play, Retire, Sell (shows the price). Buttons stay enabled; a refused action
  shows its reason in the card.
- **Orders panel (counter):** active orders (customer, request text, deadline day, reward + bonus; requirement groups
  colored met/missing for the best-matching owned creature; **Deliver…** lists eligible creatures) and today's board
  offers (customer, summary, reward, computed deadline, **Accept**). Slots used/total shown.
- **Day summary:** after End day, lists the evening's events; missed orders and injuries highlighted; closing it shows
  the new morning.

## 4. Rule changes

- **Sell price:** `Market.sell_price(c) = 10 + 20 × (sum of the five stat grades)` (E=0 … S=5). Eggs and fresh wild
  creatures sell for 10. Refusals unchanged (retired, gone, away).
- **Computed deadlines:** `OrderDifficulty.days(template, db) = 3 + Σ required groups + template.extra_days`, where a
  group costs its cheapest requirement:
  - species / line: +6 (needs raising); +4 more if the species is an evolved form (stage > 1)
  - lineage: +8 per generation
  - stat grade D/C/B/A/S: +1/+2/+4/+6/+8
  - trait: +1 if some stage-1 species has it naturally, else +3
  - move element / move kind: +1
  - personality: +2
  Bonus groups don't count. `OrderTemplate.deadline_days` is replaced by `extra_days` (default 0); `OrderBoard.accept`
  sets `deadline_day = day + OrderDifficulty.days(...)`. Existing saves keep their stored `deadline_day`.
  Weights are constants in `OrderDifficulty` for now.

## 5. Testing and done

- Headless unit tests: `Game` actions/refusals/`changed`/autosave round trip; `OrderDifficulty` (including the worked
  examples: sticky_helper 4, first_pet 9, help_me_mine 7, spider_family 19, albino_request 13); sell price;
  `CreatureAnim.pick` fallbacks; `SpawnArea` keeps spawned points inside its rect.
- Scene smoke tests (headless, in the runner): instance `shop.tscn` → no script errors; pens hold one sprite per owned
  creature and the stable one per retired creature; opening the card and orders panel works; End day updates the HUD.
- Screenshots: `shop.tscn` accepts `--screenshot=<path>` (and `--open=card|orders|summary`) like the gallery; capture
  the shop, card, orders panel and summary at 1280×720 for visual review.
- Editor check: the SpawnArea and PanelHost placeholders are visible in the editor (editor_screenshot of the 2D view).
