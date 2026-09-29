# Farm map and hanging top bar — design

Status: approved in chat 2026-09-28 (sections 1–4). Mockup chosen: option C, "rope over a textured strip".

## Goal

The main screen is the farm: the owner's map (built in `testing.tscn`) with only interactable things on it. Everything
else — stats and actions — lives in a top bar that hangs from the top of the screen: a thin brown rope with a
translucent wood-grain strip behind it, both running off both screen edges. Actions open popup windows, each its own
scene, over the dimmed farm.

## Constraints

- Godot changes go through the open editor via the godot-ai MCP (CLAUDE.md). Scenes are laid out in the editor;
  nothing generated is saved into a `.tscn`.
- Viewport stays 640×360 (40 × 22.5 tiles of 16 px).
- `testing.tscn` stays the owner's construction sandbox: its nodes are copied, the file is not changed.
- Market and Expedition windows are shells in this project; their contents get their own specs later.

## 1. Scene structure — `shop/shop.tscn` rebuilt in place

- Stays the main scene: root `Shop` (Control) with `shop/shop.gd`.
- Removed: `Ranch` (old ground/paths/fences layers, house NinePatches, decor sprites), `Hud`, the station buttons
  `Counter`, `MarketStall`, `Door`, and the `Stable` SpawnArea.
- Added, copied from `testing.tscn` in the editor with the ground TileSet: `BaseMap` (`Dirt`, `Grass` layers),
  `ShopBuilding` (the building TileMapLayer, named `Shop` in testing.tscn — renamed so it does not clash with the root)
  and `Pen` (its three layers).
- `ShopDoor`: a transparent `Button` (flat, no text) over the shop building; opens the Orders window.
- `Pens` (existing SpawnArea, unique name kept): resized to the pen's inner dirt; `sprite_scale` stays 1.4; clicking a
  creature opens its card.
- `TopBar`: an instance of `ui/top_bar.tscn`, anchored top-wide.
- `Toast` and `PanelHost` stay, drawn last (above the farm and the bar).

## 2. Top bar — `ui/top_bar.tscn` + `ui/top_bar.gd`

Laid out in the editor, anchored top-wide, reaching 8 px past both screen edges.

- `Strip`: `Panel`, about 22 px tall, theme variation `RopeStrip` — a `StyleBoxTexture` tiling a plank region of
  `art/sprout/tiles/Wooden_House_Walls_Tilset.png` (already synced), about 70% opacity. `mouse_filter = IGNORE`.
- `Rope`: `Panel`, 3 px, along the strip's bottom edge, variation `Rope` — `StyleBoxFlat` `#8c7369` with a lighter
  top edge. `mouse_filter = IGNORE`.
- `Stats` (`HBoxContainer` on the strip, left to right): day number + weather icon; the six AP hearts (the
  `heart_full` / `heart_empty` exports move here from `shop.gd`, hearts placed in the editor as today); coin + money;
  feed icon + count; pen icon + used/capacity; "Rep N · TN". Labels use the outlined map-text style. `mouse_filter`
  of the container and its children = IGNORE.
- `Tags` (`HBoxContainer` below the rope, right-aligned): `Orders`, `Stable`, `Expedition`, `Market`, `EndDay` —
  `Button`s with variation `HangingTag` (a Sprout plate) and a 1 px string up to the rope; `EndDay` uses a warmer
  tint.
- Interface:
  - `func show_state(state: GameState, tier: int) -> void` — fills every stat.
  - signals `orders_pressed`, `stable_pressed`, `expedition_pressed`, `market_pressed`, `end_day_pressed`.
- The bar covers the top ~40 px of the map; only the tags take clicks.

## 3. Popup windows

Every popup is its own `.tscn` under `shop/panels/`, opened one at a time by `%PanelHost` over the main scene:

| Popup | Scene | Opened by |
|---|---|---|
| Orders | `orders_panel.tscn` (exists, unchanged) | Orders tag, `ShopDoor` |
| Stable | `stable_panel.tscn` + `stable_panel.gd` (new) | Stable tag |
| Market | `market_panel.tscn` (new) | Market tag |
| Expedition | `expedition_panel.tscn` (new) | Expedition tag |
| Creature card | `creature_card.tscn` (exists) | a creature in the pen or the Stable list |
| Day summary | `day_summary.tscn` (exists) | End Day tag |

- New windows follow the existing panel pattern: `PanelContainer` → `Margin` → `Rows` → title row (`HeaderLabel` +
  `%Close` button) → content.
- `stable_panel.gd`: `func show_creatures(retired: Array) -> void` builds one `DecoratedButton` row per creature
  (name and species); pressing one emits `creature_chosen(c: CreatureData)`; `shop.gd` opens that creature's card
  (which replaces the Stable window). Empty list → a label "No retired creatures yet".
- `market_panel.tscn` / `expedition_panel.tscn`: title "Market" / "Expedition", a text label "The market opens soon."
  / "Expeditions start soon.", a close button. Their script is a shared `shop/panels/closable_panel.gd` (Close →
  the parent `PanelHost` closes the window). Everything else is laid out in each scene, editable on its own.
- `PanelHost`: covers the area below the bar (so windows centre on the farm) and draws a translucent dark backdrop
  while a window is open. Esc and Close work as now.
- The toast stays for short messages; Market and Expedition no longer use it.

## 4. Supporting changes

- `ground_tileset.tres` moves from the repo root to `ranch/ground_tileset.tres` (moved in the editor's FileSystem
  dock so references follow) and is committed.
- `addons/sprout_tools/sprout_sync.gd` `FILES` gains every sheet the ground TileSet uses (grass, darker grass,
  grass hills and layers, soil, darker soil, soil hills, stone, stone hills, `Bush_Tiles.png`,
  `Bitmask references 2.png`); their `.import` files are committed.
- `ui/theme/sprout_lands.tres` gains `RopeStrip`, `Rope`, `HangingTag` (made in the Theme editor via MCP);
  `ui/gallery.tscn` shows them.
- `shop.gd`: `--open=orders|stable|market|expedition|card|summary`; `_refresh` calls `%TopBar.show_state`;
  connects the five tag signals, `ShopDoor.pressed`, `Pens.creature_clicked`.
- Removed once a grep shows nothing else references them: `ranch/ranch_tileset.tres`, the "Sprout Lands: Set up
  ranch terrains" tool (`addons/sprout_tools/ranch_terrains.gd` and its menu item), `tests/test_ranch_map.gd`,
  `tests/test_ranch_tileset.gd`, `tests/test_ranch_terrains.gd`, and `ranch/art/` props only the old decor used.
  README / CLAUDE.md lines about them are updated.

## 5. Tests and checks

- `tests/test_shop_scene.gd` (rewritten):
  - the bar shows day, hearts, money, feed, pens and rep from the state, and refreshes after actions;
  - each tag signal opens its scene (OrdersPanel, StablePanel, MarketPanel, ExpeditionPanel, DaySummary);
    `ShopDoor` opens OrdersPanel;
  - creatures spawn inside the pen's rect at `sprite_scale` 1.4; `creature_clicked` opens the card;
  - no `Ranch`, `Hud`, `Counter`, `MarketStall`, `Door`, `Stable` nodes remain;
  - no later sibling blocks a tag or `ShopDoor`; the strip, rope and stats ignore the mouse.
- `tests/test_top_bar.gd`: `show_state` fills every stat; each tag emits its signal.
- `tests/test_stable_panel.gd`: one row per retired creature; pressing a row emits `creature_chosen`; empty state.
- `tests/test_panel_host.gd` (or extend an existing test): backdrop only while open; every new popup's Close closes it.
- `test_sprout_art` covers the new Sync entries.
- Checks: full suite green; standalone screenshots of the farm and each `--open=` popup; `editor_screenshot` of
  `shop.tscn` and `top_bar.tscn`; `git status` clean apart from the owner's own files.

## Out of scope

Market and Expedition contents; a stable object on the map; changes to `testing.tscn`; animation of the rope.
