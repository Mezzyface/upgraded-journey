# Buildable pens — design

Status: approved in chat 2026-09-29 (sections 1–3). Approach A: every buildable is an editor-laid-out scene plus a
`.tres` definition, placed on the 16 px grid and saved.

## Goal

The player buys pens in the Market and places them anywhere buildable on the farm. Each placed pen holds creatures
that walk around inside its fences. Pens are the first *buildable*; other areas (fields, coops, decor) come later
through the same definition, placement mode and save format.

## Decisions

- Free placement on the 16 px grid, footprint snapped, anywhere the owner has painted as buildable.
- One pen type for now: 6×5 tiles including the fence, holds 3 creatures, price 300 (editable in its `.tres`).
- Bought from the Market's new Pens list; payment happens on confirming the spot, not on Buy.
- A ghost of the pen follows the mouse, green/red by the rules; click, then Place / Cancel. Esc or right-click cancels.
- Placed pens are permanent (no move or demolish yet).
- New creatures go to the first pen with room and stay there (saved). No moving between pens yet.
- The Market builds only its Pens section in this project; feed, eggs and upgrades get their own spec.

## Constraints

- Godot changes go through the open editor via the godot-ai MCP (CLAUDE.md). Scenes and the buildable layer are laid
  out in the editor; nothing generated is saved into a `.tscn`.
- `testing.tscn` stays the owner's sandbox and is not changed.
- Viewport 640×360; the top ~40 px are under the top bar.

## 1. Data and rules

### `BuildableDef` — `creatures/defs/buildable_def.gd` (`@tool`, `class_name BuildableDef`, Resource)

| Export | Type | Meaning |
|---|---|---|
| `id` | StringName | key in saves and `Db.buildables` |
| `display_name` | String | shown in the Market |
| `description` | String | shown in the Market |
| `cost` | int | paid on Place |
| `capacity` | int | creatures it holds; 0 for areas that are not pens |
| `footprint` | Vector2i | size in tiles, fence included |
| `scene` | PackedScene | what the farm and the ghost instantiate |

- `data/buildables/pen.tres`: `id = &"pen"`, "Pen", "Room for 3 creatures.", cost 300, capacity 3, footprint (6, 5),
  scene `res://ranch/pen.tscn`.
- `Db` gains `buildables: Dictionary[StringName, BuildableDef]`, loaded from `data/buildables/` by `load_dir()` like
  the other kinds.

### Save data

- `GameState.placed: Array[Dictionary]`, each `{id: int, def: StringName, cell: Vector2i}`. `id` comes from a
  `next_placed_id` counter on `GameState`. Saved as `"placed": [{"id", "def", "x", "y"}]`; entries whose `def` is not
  in `db.buildables` are dropped on load (same as unknown upgrades).
- `CreatureData.pen := -1`: the placed id of the pen the creature lives in. Saved in `to_dict` / read in `from_dict`,
  default -1.

### Rules — `creatures/rules/build.gd` (`class_name Build`, RefCounted, static, like `Market`)

- `footprint_cells(def, cell) -> Array[Vector2i]`.
- `can_place(state, db, def_id, cell, buildable: Dictionary) -> String` — `buildable` is a set of Vector2i cells
  (keys) supplied by the farm. Returns `""` or, checked in this order: `"not enough money"`, `"can't build there"`
  (any footprint cell not in `buildable`), `"overlaps the <display_name>"` (any footprint cell inside a placed
  buildable's footprint).
- `place(state, db, def_id, cell, buildable) -> String` — `can_place`, then pay `cost` and append to `placed`.
- `place_free(state, def, cell)` — appends without checks or payment (the starting pen).
- `pen_used(state, placed_id) -> int` — creatures with `pen == placed_id` and status not GONE.
- `first_pen_with_room(state, db) -> int` — placed id in `placed` order, or -1.

### Capacity and assignment

- `Market.pen_capacity(state)` becomes the sum of `capacity` over `placed` (needs `db`: signature gains `db`; callers
  updated). `PEN_BASE`, `PEN_PER_UPGRADE`, the `extra_pen` check and `data/upgrades/extra_pen.tres` are removed. Old
  saves listing `extra_pen` lose it silently (`_known_ids` already drops unknown ids).
- `Market.pen_used(state)` is unchanged (owned + retired, eggs included). Retired creatures keep their pen slot, so a
  pen can look emptier than it counts.
- `GameState.add(c)` assigns `c.pen = first_pen_with_room` when `c.pen < 0`. It is the only place creatures are added
  (market eggs, expedition finds, breeding, new game), so every new creature gets a pen. `add` needs the capacities,
  so `GameState` gains `var db: Db` (not saved), set by `Day.new_game` and `GameState.from_dict`. With `db == null`
  (bare `GameState.new()` in tests) `add` leaves `pen` at -1.

### Starting pen and old saves

- `NewGameSetup` gains `@export var start_pen: BuildableDef` and `@export var start_pen_cell := Vector2i(11, 14)`
  (today's pen). `data/new_game.tres` sets `start_pen = pen.tres`.
- `Day.new_game` calls `Build.place_free(state, setup.start_pen, setup.start_pen_cell)` before adding the starting
  creatures.
- `Game.start` after loading a save: if `state.placed` is empty, place the start pen free and assign every creature
  with `pen < 0` (status not GONE) to the first pen with room — even past capacity, so nobody is lost. Migration is
  idempotent: a save that already has `placed` is untouched.

## 2. Buying and placement mode

### Market — `shop/panels/market_panel.tscn` + new `market_panel.gd`

- The "opens soon" text is replaced by a **Pens** heading and one row per `BuildableDef` with `capacity > 0`:
  name, "holds N", price, **Buy**. Rows are built from `Game.db.buildables` (a row scene laid out in the editor,
  `shop/panels/buildable_row.tscn`, instanced per def).
- Buy is disabled with the tooltip/label "not enough money" when `Game.state.money < cost`.
- Buy emits `build_requested(def_id)`; `shop.gd` closes the Market and starts placement. Nothing is charged here.

### Placer — `shop/placer.tscn` + `shop/placer.gd`

- A full-rect `Control` in `shop.tscn` after `TopBar` and before `Toast` / `PanelHost`, hidden unless placing; while placing its
  `mouse_filter = STOP` so creatures, `ShopDoor` and top-bar tags don't take clicks.
- `start(def_id, buildable: Dictionary)`: instantiates `def.scene` as the ghost (`process_mode = DISABLED`, no
  creatures, `collision_enabled = false` on its TileMapLayers so creatures don't bump a ghost), shows `%Buildable` faintly, shows the hint "Click to place · Esc to cancel" in its own
  label at the bottom.
- Mouse motion: `cell = ((mouse - footprint * 8) / 16).floor()` so the footprint centres on the cursor; ghost at
  `cell * 16`; `modulate` = `ok_tint` (default `Color(0.6, 1, 0.6, 0.75)`) when `Build.can_place` is `""`, else
  `bad_tint` (default `Color(1, 0.45, 0.45, 0.75)`) with the reason in a label under the ghost. Tints are exports,
  editable on the placer.
- Left-click on a green cell: the ghost stays there and `%Place` / `%Cancel` buttons (laid out in `placer.tscn`)
  appear above it; left-click elsewhere moves it again.
- Place: `Game.place(def_id, cell, buildable)`; on `""` placement ends and `shop.gd` toasts "Pen built"; otherwise
  the reason is toasted and placement stays open.
- Cancel, Esc (`ui_cancel`) or right-click: placement ends, nothing charged.
- Signal `finished(built: bool)`.

### Game — `game/game.gd`

- `place(def_id: StringName, cell: Vector2i, buildable: Dictionary) -> String` — `Build.place`, emits `changed` on
  success, like every other action.

## 3. The farm scene

### `ranch/pen.tscn` (built in the editor from today's pen)

- Root `Pen` (Node2D). Children: today's three pen `TileMapLayer`s, their cells shifted by (-11, -14) so the fence's
  top-left is cell (0, 0); and `%Creatures`, the `Pens` SpawnArea moved in, offsets (16, 16)–(80, 64) (the inner dirt),
  same exports (`wander_speed`, `baby_scale`, `max_shown`, `preview_frames`, `preview_count`).
- The fence TileSet (embedded in `shop.tscn`, with the collision boxes) is saved as `ranch/fence_tileset.tres` and
  used by the fence layer.
- This scene is where the pen's look is changed; the ghost and every placed pen use it.

### `shop.tscn`

- Removed: `Pen` and `Pens`.
- Added `%Buildings` (Node2D, after `ShopBuilding`): placed buildables are instanced here, each at `cell * 16`,
  named `Placed<id>`.
- Added `%Buildable` (TileMapLayer, `ground_tileset.tres`, any tile, `modulate` faint green): the cells where
  building is allowed. Visible in the editor, hidden at runtime by `shop.gd`, shown faintly by the placer. First pass
  painted via MCP: open grass, excluding the shop building, paths and rows 0–2 (under the top bar); the owner trims
  it in the editor.
- Added `%Placer` (instance of `shop/placer.tscn`), after `TopBar` and before `Toast` / `PanelHost`, so it is
  drawn over the top-bar tags (blocking them) and under popups and toasts.

### `shop.gd`

- `_refresh()`: for each `placed` entry without a node under `%Buildings`, instance its scene; then for each placed
  pen, `pen.get_node("%Creatures").sync(owned creatures with c.pen == id, Game.db, _rng)`. Each pen's
  `creature_clicked` opens the card.
- `buildable_cells() -> Dictionary`: `%Buildable.get_used_cells()` as a set.
- `open_market()` connects `build_requested` → close Market, `%Placer.start(def_id, buildable_cells())`;
  `%Placer.finished` → toast "Pen built" when built.

### Other

- `creatures/species_preview.gd` uses the starting pen's `%Creatures` instead of `%Pens`.
- `CLAUDE.md` Layout: `ranch/pen.tscn`, `data/buildables/`, the `%Buildable` layer and placement mode.
- New theme variations for the Market rows (if any) are added to `ui/gallery.tscn`.
- `testing.tscn` unchanged.

## Testing

Rules (`tests/test_build.gd`):
- `can_place`: each refusal (money, unbuildable cell, overlap) and the order they are checked in; a valid spot.
- `place` pays and appends with increasing ids; `place_free` doesn't pay.
- `Market.pen_capacity` sums over placed pens; 0 with none.
- `GameState.add` puts creatures in the first pen with room, then the next; -1 when all are full.
- Save round-trip keeps `placed` and `CreatureData.pen`; unknown `def` dropped.
- Migration: a save with no `placed` gets the start pen and every creature assigned; running it twice changes nothing.

Scenes:
- `test_shop_scene`: a placed pen appears under `%Buildings` at `cell * 16`; a creature shows in its own pen's area
  only; the starting pen exists in a new game.
- `tests/test_placer.gd`: tint follows `can_place` for a valid and an invalid cell; Place charges and adds a pen;
  Cancel and Esc charge nothing.
- `test_species_preview` still shows one creature beside its card.
- Existing market/day/expedition tests updated for the new `pen_capacity` signature and the removed upgrade.

Visual (`editor_screenshot` / game capture): the Market Pens list; a green ghost; a red ghost with its reason; the farm
with a second pen and a creature in it.

## Out of scope

- Moving, demolishing or refunding buildables; moving creatures between pens.
- Other buildable kinds (the definition and placer support them; no content yet).
- Market feed, eggs and upgrades UI.
- Pathing between pens or creatures leaving pens.
