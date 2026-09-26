# Creature Breeding Shop — design (working title TBD)

Status: approved design, 2026-09-26. Scope of the first vertical slice: sub-projects 1 + 2 below.

## Goal

A commercial creature-breeding shop game. The player runs a shop, customers post orders for creatures with
specific species, stats, traits, moves, personality or lineage, and the player breeds, raises and trains creatures
to fill them. Art comes from the 80 licensed monster packs (128x128 side-view sprites with Idle/Move/Attack sheets)
and the Isle of Lore UI theme already in the project.

## Pillars

- **Breed to order.** Every system feeds the order board: what a customer asks for is something you plan
  generations ahead to produce.
- **Raising matters.** How a creature is trained and cared for shapes its traits, personality, evolution and
  what it can pass on.
- **Readable luck.** Outcomes are uncertain but plannable: compatibility marks, a pedigree and a scanner tell the
  player where the odds are.
- **Cozy with goals.** No game over; reputation and upgrades give direction.

## Sub-projects

Each gets its own spec → plan → build cycle.

1. **Creature core** — species, stats, sparks/inheritance, traits, personality, evolution (data + rules).
2. **Shop & breeding loop** — day cycle, orders, breeding, eggs, raising/training, delivery, economy.
3. **Tactics** — turn-based tactics battles for exploring, training and finding creatures. Replaces the
   auto-resolved expeditions of the slice; auto-resolve may remain as a "skip battle" option.
4. **Content & meta** — more species, locations, upgrades, story.

First vertical slice = 1 + 2.

## 1. Creature model

### Species
Name, sprite set (`SpriteFrames` from a monster pack), element (Earth, Fire, Water, Air, Dark, Light, Nature,
Beast…), base stats, natural traits, learnable moves (with the stat grade that unlocks each), egg group, and a list
of evolutions. A pack's variants form an evolution line (Slime → Slime Antenna).

### Stats
Power, Guard, Speed, Wits, Heart. Range 0–999. Grades are the breakpoints orders use:

| grade | E   | D   | C   | B   | A   | S   |
|-------|-----|-----|-----|-----|-----|-----|
| from  | 0   | 100 | 250 | 400 | 600 | 800 |

Each stat has a hidden **potential** (cap). Training raises the stat toward the cap. A child's potential is the
parents' average ± variance, with a rare mutation, plus any boosts from inspiration.

### Traits
Three sources:
- **Natural** — fixed by species.
- **Learned** — earned by training at a location (e.g. mine drills → Tunnel-wise) or by care.
- **Inherited** — granted by a trait spark at inspiration (below). Natural and learned traits become heritable
  this way.

### Personality
Set by care (feeding, play, rest, overtraining): Cheerful, Stubborn, Gentle, Bold, Timid (slice set). Modifies
training gains and satisfies personality orders.

### Moves
Learned through training when a stat reaches the species' unlock grade. Each move has an element and a kind
(damaging / utility). Orders can ask for a move by element or kind.

### Inheritance: sparks (Uma Musume-style)
Chosen over Mendelian genes after comparing Pokémon, Monster Rancher, Dragon Quest Monsters, Palworld, Monster
Hunter Stories, Viva Piñata, Chao Garden, Digimon, Temtem and Uma Musume.

- **Retire to breeding.** Moving a creature into the breeding stable (0 AP) rolls and locks its sparks from its
  current state. A retired creature no longer trains. Sparks, each 1–3★:
  - one stat spark for its best stat (stars scale with grade),
  - one per natural and learned trait,
  - one move spark,
  - one personality spark.
- **Breeding.** Both parents must be retired and share an egg group. The child is one parent's species at random
  (small chance of the evolved form if both parents are evolved). Each parent has a breeding cooldown in days.
- **Spark pool.** The child carries its parents' sparks and its four grandparents' sparks. Grandparent sparks
  have lower weight.
- **Inspiration** happens twice: at hatch and at adulthood. Each spark in the pool procs with a chance from its
  stars × weight × compatibility. Effects:
  - stat spark → stat and potential boost,
  - trait spark → the trait is granted outright,
  - move spark → the move is learned early,
  - personality spark → personality nudged toward it.
- **Compatibility** ◎ / ○ / △ for a pair, from shared line, element, egg group and overlapping sparks. Shown before
  breeding; raises proc chance.
- **Mystery.** Grandparents' sparks are hidden unless the player raised that creature or owns the Gene Scanner
  upgrade. Which sparks proc is luck.

### Pedigree
Each creature records its parents. The creature card shows a 3-generation family tree. Delivered and retired
ancestors are kept as lightweight records so trees survive. Enables lineage orders ("3-generation Mine line") and
pure-line bonuses.

### Evolution
Per-species list of evolutions, each with conditions: minimum stat grade, has trait, personality, held item, age
in days. Checked at end of day. **Branching:** a species may list several evolutions, and how it was raised picks
the branch (first satisfied in list order).

### Later (not in slice)
- **Gene Lab** upgrade: consume a donor creature to transfer one chosen spark, at a cost. The deliberate,
  luck-free option (Monster Hunter Stories' Rite of Channeling as reference).
- Lifespan beyond baby → adult; egg moves.

## 2. Day loop, orders, economy

### A day
1. **Morning — orders board.** 2–4 new orders appear, each with a deadline in days and a reward (money +
   reputation). Accept up to the board's slot count (grows with reputation).
2. **Day — spend action points** (5 AP base):

   | action          | AP | effect                                                                                  |
   |-----------------|----|-----------------------------------------------------------------------------------------|
   | Train           | 1  | a creature does a drill: stat gain toward potential; the drill location may grant a learned trait |
   | Care            | 1  | feed / play: personality and mood                                                        |
   | Breed           | 2  | two retired, compatible creatures make an egg (hatches ~2 days, adult ~3 more)           |
   | Expedition      | 2  | up to 3 creatures go to a location; stats/traits vs its challenges; return in the evening with wild eggs/captures, materials, experience, possibly an injury |
   | Retire          | 0  | move a creature to the breeding stable; locks its sparks                                |
   | Market          | 0  | buy feed, items, eggs; sell surplus creatures cheaply                                   |
   | Deliver         | 0  | hand a creature to a customer at the counter                                            |

3. **Evening.** Eggs hatch (inspiration), babies reach adulthood (inspiration), evolution checks, expeditions
   return, deadlines tick, autosave.

### Orders
Requirements are composable pieces with AND / OR groups:
- species or evolution line,
- stat ≥ grade,
- has trait,
- has move of an element or kind,
- personality,
- lineage (N generations of a line).

Example, "help me mine": (Darksight OR Glowing) AND (Ground move OR damaging move).

Orders may carry **bonus** requirements (e.g. "Power B required, A for a bonus") that pay extra. Delivery needs
every required piece; the creature leaves permanently.

### Economy and progression
- Income: orders; selling surplus creatures.
- Spending: feed, items, eggs, upgrades — pens, nursery (faster hatching), Gene Scanner, +1 AP, board slots,
  training rooms.
- Reputation tiers unlock customer types, harder and better-paying orders, and new species in the market.
- **Soft fail:** a missed deadline costs reputation and can drop a tier; there is no game over.

### Stretch
Training rooms as an alternative to buying AP: a creature assigned to a room trains daily without AP. Rooms can
host mentoring (one creature teaches another a move or learned trait) and sparring (fight to gain a move; links
to Tactics).

## 3. Architecture (Godot 4.7)

Follows the repo rule: everything is editable in the Godot editor; generators are explicit editor tools.

- **Data** — `class_name` Resources with `@export` fields, one `.tres` each under `data/`, edited in the
  Inspector: `Species`, `TraitDef`, `Move`, `Personality`, `OrderTemplate`, `Location`. Evolutions and learnable
  moves are sub-resources or arrays on `Species`.
- **Pack importer** — `addons/creature_tools` EditorPlugin, menu `Project > Tools > Creatures: Import pack as
  species`. Copies the pack's PNGs into git-ignored `creatures/pack/`, creates a `SpriteFrames` and a starter
  `Species`. Create-only: never overwrites an existing file. Modeled on `addons/iol_theme`.
- **Rules** — plain GDScript, no scene dependencies; every roll takes a seeded `RandomNumberGenerator`:
  `Sparks.roll(creature, rng)`, `Inheritance.breed(a, b, rng)`, `Inheritance.inspire(child, rng)`,
  `Inheritance.compatibility(a, b)`, `Orders.check(creature, order)` (met / bonus / missing list),
  `Training.apply(...)`, `Evolution.check(creature)`, `Expedition.resolve(team, location, rng)`.
- **State** — `Game` autoload holding a `GameState` (day, AP, money, reputation, creatures, eggs, orders,
  upgrades, ancestor records). `CreatureData`: id, species, parent ids, potentials, stats, learned traits,
  personality, mood, cooldowns, retired flag, locked sparks `{kind, id, stars}`.
- **Save** — JSON in `user://` via `to_dict()` / `from_dict()`. Not `.tres`: loading a resource can run embedded
  scripts, and players share save files.
- **Scenes** — `shop/shop.tscn`: side-view shop with pens where creatures (`AnimatedSprite2D`) wander between
  idle and move. Stations open themed panels: Orders board, Creature card (with pedigree), Breeding (with
  compatibility), Training, Expedition, Market, Day summary. Reuse the theme variations (`NamePlate`,
  `InventorySlot`, `DecoratedButton`, `PackScrollBar` + `ui/pack_scroll_bar.gd`).
- **Tests** — one `tests/run_tests.gd` (SceneTree script with asserts), run with
  `--headless --script res://tests/run_tests.gd`. Covers spark rolls, inheritance and inspiration odds with fixed
  seeds, grade breakpoints, order matching, evolution branching, save/load round trip.

## 4. First slice

### Content
- ~10 species: 5 packs as 2-stage lines — Slimes, Mushrooms, Spiders, Golems, Canines.
- 8 traits (Darksight, Glowing, Thick Hide, Swift, Fireproof, …), natural on some species and learnable at
  locations; 6 further learned traits.
- 5 personalities, ~12 moves, ~15 order templates.
- 3 locations: Meadow, Mine, Old Forest.
- Upgrades: extra pen, Gene Scanner, +1 AP.

### Build order
Data classes → rules + tests → pack importer → state + save → shop scene + pens → panels → day loop → balance.

### Done when
- 10 in-game days play from a fresh save with no errors.
- At least one order of each kind is filled (species, stat, trait, move, personality, lineage); one of them
  requires carrying a trait spark across 2 generations.
- Retire → breed → inspiration visibly transfers a spark; the pedigree shows 3 generations; compatibility marks
  show.
- A branching evolution triggers: one species raised two ways reaches two different forms.
- Save and reload mid-day restores all state.
- `tests/run_tests.gd` passes headless; `--headless --import` is clean; `editor_screenshot` after each scene or
  panel change; a seeded 10-day scripted playthrough completes.
- Every data `.tres` opens and edits in the Inspector.
