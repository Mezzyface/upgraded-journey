# Sprout Lands: ranch scene — design (sub-project 2)

Status: design for review, 2026-09-27. Second of the Sprout Lands sub-projects
(see `2026-09-27-sprout-lands-pack-theme-design.md`): the main screen becomes a **top-down ranch** on one
640×360 screen, still click-driven. Sub-project 1 (packs, sync tool, theme, 640×360 grid, pipeline palette lock)
is done; the owner's shop HUD (`Hud/TopLeft`, End Day, reputation) is done and stays.

## Decisions (from the brainstorm)

- **Layout ownership:** Claude builds the TileSet, the terrain tool and a first-pass layout; the owner repaints and
  moves anything freely in the editor afterwards. The first pass is a starting point, not a design lock.
- **The shop is a small roofless house** (dollhouse cutaway, seen from above) built from the pack's wooden house
  walls. Both counters stand inside it and are clickable.
- **Counters are generated** with the asset pipeline's `prop` type (palette-locked to Sprout).
- **Creatures: rescale only.** Original colours stay; palette-remapping them is a separate follow-up.
- **Terrains now:** grass, soil (paths), fences. Water, hills, stone, bushes later.
- **TileSet set-up:** an editor tool applies the pack's bitmask reference once (approach 1); the TileSet is
  editor-owned afterwards.
- **Scene structure:** `shop.tscn` keeps its `Control` root, HUD and `PanelHost`; the map is a `Node2D` underneath;
  stations stay `TextureButton`s so `shop.gd`'s wiring barely changes.

## Screen layout (first pass)

640×360 = 40×22.5 tiles of 16 px. HUD top-left and End Day/reputation top-right stay clear of props.

```
 ┌────────────────────────────────────────────────────────────┐
 │[HUD]                                           [End day]    │
 │                  ┌──────── shop house ─────┐   reputation   │
 │                  │ orders    rug   market   │                │
 │                  │ counter          counter │                │
 │                  │  plant   table   clock   │                │
 │                  └──────────┐ door ┌───────┘                │
 │  ╔═════════ pen ═════════╗  │path│        ╔══ stable ══╗     │
 │  ║   creatures wander    ║══╪════╪════════║ coop  hay  ║     │
 │  ║                       gate    ╚══path══gate retired  ║ ──▶ sign
 │  ╚═══════════════════════╝                ╚════════════╝  (road off-screen = expeditions)
 └────────────────────────────────────────────────────────────┘
```

## Scene tree (`shop/shop.tscn`)

```
Shop (Control, shop.gd)
├─ Ranch (Node2D)                 drawn first
│  ├─ Ground   (TileMapLayer)     grass terrain everywhere
│  ├─ Paths    (TileMapLayer)     soil terrain, blends onto the grass below
│  ├─ House    (TileMapLayer)     wall + floor tiles, no roof
│  ├─ Fences   (TileMapLayer)     fence terrain: pen + stable yard
│  └─ Decor    (Node2D, y_sort_enabled)  furniture, coop, hay, closed gates as Sprite2D
├─ Counter      (TextureButton)   orders_counter.png, inside the house → open_orders()
├─ MarketStall  (TextureButton)   market_counter.png, inside the house → "The market opens soon"
├─ Door         (TextureButton)   signpost where the road leaves the screen → "Expeditions start soon"
├─ PenArea → Pens (SpawnArea, %Pens)        inside the pen fence
├─ StableArea → Stable (SpawnArea, %Stable) inside the stable-yard fence
├─ Hud (unchanged), Toast, PanelHost
```

Node names `%Counter`, `%MarketStall`, `%Door`, `%Pens`, `%Stable` are unchanged. Everything is placed on whole
pixels at 1× scale (one pixel grid). Removed: `Floor`, `PenFrame`, `StableFrame`.

## Art and sync

Added to `SproutSync.FILES` (pack art stays git-ignored; `.import` files committed):

| Destination (`art/sprout/`) | Source (premium sprites pack) |
|---|---|
| `tiles/Grass_tiles_v2.png` | `Tilesets/ground tiles/New tiles/Grass_tiles_v2.png` |
| `tiles/Soil_Ground_Tiles.png` | `Tilesets/ground tiles/New tiles/Soil_Ground_Tiles.png` |
| `tiles/Fences.png` | `Tilesets/Building parts/Fences.png` |
| `tiles/Wooden_House_Walls_Tilset.png` | `Tilesets/Building parts/Wooden_House_Walls_Tilset.png` |
| `objects/Basic_Furniture.png` | `Tilesets/Building parts/Basic_Furniture.png` |
| `objects/Chikcen_Houses.png` | `Tilesets/Building parts/Animal Structures/Chikcen_Houses.png` |
| `objects/Barn structures.png` | `Tilesets/Building parts/Animal Structures/Barn structures.png` (hay, crates) |
| `objects/Fence gates animation sprites .png` | `Tilesets/Building parts/Fence gates animation sprites .png` |
| `objects/signs.png` | `Objects/signs.png` |
| `objects/Egg_Spritesheet.png` | `Animals/Chicken_Egg/Egg_Spritesheet.png` |

Exact source paths are checked against the extracted pack during planning (file names in the pack have typos and
trailing spaces; keep them verbatim).

**Generated counters** (our own art, committed): two `prop` jobs in `asset-pipeline/jobs.json`, palette-locked:

- `orders_counter` — a wooden shop counter with a ledger and pinned order slips, top-down ¾ view, 48×32.
- `market_counter` — the same counter with a produce crate and a small price sign, 48×32.

Style references: `Basic_Furniture.png` and `Wooden_House_Walls_Tilset.png` (job-level `refs`). The prop style is
1:1; the plan checks that a 48×32 job size works with it (job-level `aspect` override if needed). If the model's
reviewer fails a counter three times the last output is kept for the owner to judge; the fallback is a counter
assembled from the pack's table tiles. Outputs are copied from `asset-pipeline/assets/prop/` to `ranch/art/`
(committed), the same manual step today's `shop/art/` used; the pipeline README gets one line saying so.

**Egg:** eggs switch from `shop/art/egg.png` to `creatures/egg.tres`, an `AtlasTexture` on one frame of
`Egg_Spritesheet.png` (editor-authored). Its users follow: `shop/creature_sprite.tscn`, `shop/panels/creature_card.gd`
(`EGG_TEXTURE`), `tests/test_creature_card.gd`.

## TileSet: `ranch/ranch_tileset.tres`

Created in the editor; 16 px tiles; four atlas sources: grass, soil, fences, house walls.

- **Terrain set 0 — Match Corners and Sides:** terrains **Grass** and **Soil**. `Grass_tiles_v2.png` and
  `Soil_Ground_Tiles.png` share the same 11×7 layout (documented by `Bitmask references 2.png`), so one table
  serves both. Plain fill tiles and their flower/tuft variants get probabilities so painted areas don't repeat.
- **Terrain set 1 — Match Sides:** terrain **Fence** over the 8×4 `Fences.png`.
- House walls are placed as plain tiles (no terrain).
- Layering: `Ground` is painted all grass; `Paths` paints soil on top and the soil's own edge tiles blend onto the
  grass (as the pack's `TILE LAYER EXAMPLE.png` shows); `Fences` paints fence.

## Editor tool: set up ranch terrains

`addons/sprout_tools/ranch_terrains.gd`, menu **Project > Tools > "Sprout Lands: Set up ranch terrains (overwrites
terrain bits)"**, registered by the existing `sprout_tools` plugin.

- Holds two readable GDScript tables: the **blob table** (atlas cell → which of its 8 neighbours match) and the
  **fence table** (atlas cell → which of its 4 sides connect).
- Writes only terrain sets, terrains, peering bits and fill probabilities on `ranch/ranch_tileset.tres`.
  Collision, custom data, animation and anything else set in the TileSet editor are left alone.
- Runs only when the menu item is chosen; it is how the terrain bits get set the first time and the named way to
  reset them. It never runs on import or on project open.
- A missing atlas texture (packs not synced) stops with one error naming the file and pointing at
  **Sprout Lands: Sync pack files**, before anything is written.

## Creatures and pens

- `%Pens` and `%Stable` stay `SpawnArea`s, each sized to its fence's inside minus a one-tile margin so creatures
  never overlap fence art; the editor ghosts still show where they wander.
- One `sprite_scale` for both areas, picked by measuring each species' idle frame so a typical adult reads about
  32 px tall (two tiles), per the restyle experiment. Babies keep the existing `baby_scale` ratio.
- `wander_speed` retuned to about one tile per second (≈16 px/s).
- Creature colours unchanged (remap is a follow-up).

## Removed

- Nodes `Floor`, `PenFrame`, `StableFrame`.
- `shop/art/` entirely: `shop_floor`, `shop_counter`, `market_stall`, `shop_door`, `pen_grass`, `stable_hay`, `egg`
  (`.png` + `.import`).
- The matching side-view jobs in `asset-pipeline/jobs.json` (`shop_floor`, `shop_counter`, `market_stall`,
  `shop_door`, `pen_grass`, `stable_hay`, `egg`) and their outputs under `asset-pipeline/assets/`.

The owner's uncommitted line-ending-only changes to `shop/art/*.import` go with those files; nothing else is lost.

## Unchanged

The HUD (`Hud/TopLeft`, End Day, reputation), `Toast`, `PanelHost`, all panels, `test_panel_fit.gd`, and
`shop.gd`'s logic (it loses only art references).

## Testing

In the existing GDScript suite (`tests/run_tests.gd`), no new framework:

- `tests/test_ranch_terrains.gd`
  - the blob table is complete and free of duplicates: every distinct 8-neighbour pattern the sheet provides
    appears exactly once; the fence table likewise for 4-side patterns.
  - functional: run the tool on a scratch copy of the TileSet, paint a 4×3 grass rectangle with a one-tile notch
    via `TileMapLayer.set_cells_terrain_connect`, and check each cell got the expected corner / edge /
    inner-corner atlas coords.
- `tests/test_shop_scene.gd` (kept, extended): stations still open their panel or toast; creatures spawn in
  `%Pens` / `%Stable` and every creature's position stays inside its area; the scene has no `shop/art/`
  references.
- `tests/test_sprout_art.gd` (new): every `res://art/sprout/` path referenced by any `.tscn`, `.tres` or
  `project.godot` is listed in `SproutSync.FILES` (the deferred fresh-clone check from sub-project 1).
- `tests/test_panel_fit.gd` still passes over the new map. `python asset-pipeline/test_gen.py` stays green.

## Done when

1. Running the game shows the top-down ranch: grass, soil paths, the roofless house with both counters, the fenced
   pen with owned creatures, the stable yard with retired ones, the owner's HUD on top.
2. Orders counter opens orders; market counter and signpost toast; clicking a creature opens its card.
3. The owner can repaint grass, soil and fences with the terrain brush in the editor and edges/corners resolve
   themselves.
4. All suites `0 failed`, `--import` clean, and a screenshot set (ranch, card, orders, summary) has been read.

## Out of scope (later)

Farmer walking to stations (sub-project 3) · fence collisions (only the farmer needs them) · gate-open animation ·
mailbox "new order" animation · water, hills, stone, bushes · palette-remapping creatures · roof / interior view
switch · audio (sub-project 4).
