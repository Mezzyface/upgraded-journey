# Day Loop & Systems — design (Plan 2a)

Status: approved design, 2026-09-26. Builds on the creature core (`docs/superpowers/specs/2026-09-26-creature-shop-design.md`,
plan `docs/superpowers/plans/2026-09-26-creature-core.md`). Scope: the playable game loop with no screens; 2b adds the
shop scene, panels and menus on top of it.

## Goal

A full day cycle that runs headless: orders in the morning, action points spent during the day, growth, expedition
returns and deadlines in the evening. Around it: order generation, care, market, expeditions, reputation, money and
upgrades. Proven by rule tests and a seeded 10-day scripted playthrough.

## Decisions

- **Darksight source:** Mine expeditions can bring back a rare wild Spider Albino egg; breeding spreads the trait.
- **Personality:** babies collect leanings from care; the strongest leaning becomes the personality at adulthood.
- **Orders:** authored `OrderTemplate`s only, filtered by reputation tier, recent ones skipped.
- **Expeditions:** challenge checks built from the same requirement pieces as orders.
- **No items yet:** the spec's `held_item` evolution condition waits.
- **RNG state is not saved:** reloading re-rolls pending outcomes (revisit if reload-to-reroll becomes a problem).
- **Retired creatures stay pickled:** no care, training or expeditions; they only breed.

## 1. Loop and actions

Rules stay scene-free static classes taking `(state, db, rng)`. A new `Day` class holds every action; each returns
`""` on success or the reason it was refused (same pattern as `Inheritance.can_breed`), and never changes state when
refused. No `Game` autoload or `Events` bus in 2a — they arrive with the UI in 2b.

| action | AP | rule |
|---|---|---|
| Train | 1 | `Training.train` (existing); refused for eggs, retired, injured, busy |
| Care: feed | 1 | uses 1 Feed; mood +20; baby leans Gentle |
| Care: play | 1 | mood +15; baby leans Cheerful |
| Breed | 2 | `Inheritance.breed` (existing); needs a free pen space; refused if either parent is injured |
| Expedition | 2 | team of 1–3 owned, non-injured adults or babies at a location; they are busy for the rest of the day |
| Retire | 0 | `Sparks.retire` (existing) |
| Buy / sell | 0 | market (section 2) |
| Accept / deliver order | 0 | section 2 |

Care is refused for retired creatures and eggs; injured creatures can be cared for.

**`Day.end_day()`** (the evening), in order:
1. Expeditions resolve (section 3).
2. Babies that received no care today lean Timid.
3. `Lifecycle.advance_day` for every creature (growth, three inspirations, evolution; retired creatures only tick
   their breeding cooldown).
4. Every non-retired creature gets mood +10 (overnight rest), capped at 100; `injured_days` tick down.
5. Active orders past their deadline are removed and cost their `reward_rep` (reputation floor 0).
6. Unaccepted board offers expire; busy flags clear.
7. Day +1, AP refills (5, +1 with the upgrade), new morning offers are posted.
8. Returns the day's events (strings) for the day summary.

**Pens:** capacity 6 creatures that are owned or retired (eggs count); the Extra Pen upgrade adds 3. Buying an egg and
breeding are refused when full; a wild egg found on an expedition when full is released, with an event line.

**New game:** `data/new_game.tres` (`NewGameSetup`, edited in the Inspector): money 500, Feed 5, starting species
spider, slime, green_golem as wild adults with random personalities; `Day.new_game(setup, db, rng)` builds the state and
posts day 1's offers.

**State additions** (save version 2; version-1 saves load with the new fields empty):
- `GameState`: `board` (offered template ids), `orders` (active: `{template, deadline_day}`), `recent_templates` (last 5),
  `inventory` (item id → count; only `feed` in 2a), `upgrades` (ids bought), `expeditions` (pending:
  `{location, team}`), `busy` (creature ids busy today), `cared` (creature ids cared for today).
- `CreatureData`: `injured_days`, `leanings` (personality id → count).

## 2. Orders, market, reputation, upgrades

**Morning offers:** pick 2–4 templates with `min_rep_tier ≤ tier`, excluding the last 5 seen (fall back to allowing
them if too few remain). Order slots = 2 + reputation tier; accepting beyond the slots is refused.
**Accept:** deadline = day + `deadline_days`. **Deliver:** `Orders.check` must pass; pays `reward_money`
(+`bonus_money` when the bonus passes) and `reward_rep`; the creature becomes `GONE` (kept for pedigrees).
**Missed deadline:** −`reward_rep`, floor 0.

**Reputation tiers:** thresholds 0 / 20 / 50 / 100 / 200 → tiers 0–4.

**Market:**
- Feed: 10 money.
- Eggs of base species: new `Species.market_price` and `Species.market_tier` (−1 = not sold). Slice: slime, mushroom,
  dog 60 at tier 0; spider, green_golem 90 at tier 1. Bought eggs are wild eggs (hatch in 2 days, no spark pool).
- Sell a creature (owned, not retired): 20 × the sum of its five stat grades (E=0 … S=5); it becomes `GONE`.

**Upgrades:** `UpgradeDef` resources in `data/upgrades/` (id, display name, cost, min tier), bought once each:
Extra Pen 300 (tier 0), +1 AP 400 (tier 1), Gene Scanner 500 (tier 1; stored flag, used by the 2b UI).

**Content:** ~15 order templates across tiers 0–2 covering every requirement kind (species, line, stat, trait, move
element, move kind, personality, lineage), including "help me mine" ((Darksight or Glowing) and (Earth move or
damaging move)) and one 2-generation lineage order.

## 3. Expeditions, personality, injuries

**Location additions:** `challenges: Array[RequirementGroup]`, `loot: Array[LootEntry]` (`LootEntry`: species, weight),
`money_min`, `money_max`.

**Resolution (evening):** a challenge passes if any team member meets it (`Orders.met`). Each pass is one loot roll:
40% a wild egg (species by loot weight), otherwise money in [money_min, money_max]. Each failed challenge injures one
random team member for 2 days. Every member gains +10 in a random stat (capped at potential) and, if a baby, leans Bold.

| location | challenges | loot |
|---|---|---|
| Meadow | Speed ≥ D; a Nature or Beast move | slime, mushroom, dog |
| Mine | Darksight or Glowing; Guard ≥ C | green_golem, spider, spider_albino (weight 1 of ~10) |
| Old Forest | Wits ≥ D; Power ≥ C | spider, mushroom, dog |

**Personality leanings** (babies only): play → Cheerful, feed → Gentle, expedition → Bold, training while mood < 30 →
Stubborn, a day without care → Timid. A personality spark adds +3 to its leaning instead of setting the personality.
At adulthood, after the adulthood inspiration, the strongest leaning becomes the personality (ties keep the current
personality); with no leanings the inherited personality stays; a creature with none gets a random one.

**Injuries:** `injured_days > 0` blocks training, expeditions and breeding; care is allowed.

## 4. Architecture

- `creatures/rules/day.gd` (`Day`): new_game, actions, end_day.
- `creatures/rules/market.gd`, `creatures/rules/expedition.gd`, `creatures/rules/order_board.gd`: focused rule classes
  used by `Day`.
- `creatures/rules/leanings.gd` (`Leanings`): add a leaning, settle personality at adulthood (called by `Lifecycle`).
- Data classes: `NewGameSetup`, `UpgradeDef`, `LootEntry` (`@tool`, like the other defs); `Location` and `Species`
  gain the fields above; `Db` gains `upgrades`.
- Save: `SAVE_VERSION` 2; `from_dict` accepts 1 and 2 and keeps the Plan 1 hardening (clamps, skips, orphans).

## 5. Testing and done

- Headless tests per rule: every action's refusals and effects, end_day ordering, order board picking and slots,
  delivery and deadline penalties, market buy/sell and pen limits, expedition passes/loot/injury, leanings and
  settling, upgrades, save v1 → v2.
- `tests/test_playthrough.gd`: a scripted player on the real `data/` with a fixed seed plays 10 days (accept orders,
  train, care, breed, a Mine expedition, deliver any match). Asserts: reaches day 11, no script errors, at least one
  order delivered, money and reputation valid, and a mid-day save → load gives identical `to_dict()`.
- Filling one order of every kind is a human playtest check after 2b.
