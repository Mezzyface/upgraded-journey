# Upgraded Journey

Godot 4.7 project (root) + AI asset pipeline (`asset-pipeline/`, see its README).

## Godot MCP (Claude Code drives the editor)

`addons/godot_ai` + `addons/godot_omni` are [Godot-MCP v5.0.39](https://github.com/bebabinlarsson-blip/Godot-MCP)
(MIT). `.mcp.json` registers the `godot-ai` server for Claude Code in project scope; Claude Code asks once to
approve it on the next session start.

Order matters on this machine: the Claude session starts the server first (any `godot-ai` tool call), then the
editor opens and *adopts* it. The plugin cannot use a server it launches itself on Windows: its launch never passes
the identity proof, and it binds `0.0.0.0`, which the plugin's own port check then reads as "free" and never
adopts. The two sides authenticate through a record in `%LOCALAPPDATA%\godot-ai\capabilities\http-<port>.json`.

- **Claude Code CLI in a normal terminal:** open the editor normally:

  ```bash
  "C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --editor --path .
  ```

- **Claude desktop app:** the app is MSIX-packaged, so its `%LOCALAPPDATA%` writes are redirected to
  `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Local\` and the editor would never see the record.
  Open the editor with `LOCALAPPDATA` pointed there (a `.cmd` launcher kept outside the repo):

  ```bat
  set "LOCALAPPDATA=%USERPROFILE%\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Local"
  start "" "C:\Users\ozark\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --editor --path "C:\upgraded-journey"
  ```

  Junctions/symlinks don't work: godot-ai refuses record paths through a reparse point.

The **Godot MCP** dock turns green once it adopts the server. If it shows "WebSocket port 9500 is already in use" or
"status probe failed: http_401", a stale server or record is in the way: quit Godot, end the leftover godot-ai
`python.exe` (its command line has `--pid-file …godot_ai_server.pid`), make a `godot-ai` call from Claude, then open
the editor again. Keep `godot_ai/keep_server_on_exit` off so editor-launched servers don't linger.

Notes:
- Server HTTP port is **8765** (Docker owns 8000). Set in `.mcp.json` and in Godot Editor Settings `godot_ai/http_port`.
- Telemetry is off (`GODOT_AI_DISABLE_TELEMETRY=1` in `.mcp.json`, `godot_ai/telemetry_enabled=false`).
- `godot_ai/auto_configure_clients=false` so the addon never rewrites `~/.claude.json` behind your back.
- Requires `uv` (`pip install uv`). The first launch downloads the pinned wheel + deps.

## UI theme (Sprout Lands)

`ui/theme/sprout_lands.tres` is the project theme (`gui/theme/custom`); edit it in the Theme editor. The game renders
on a 640×360 pixel grid (`canvas_items` stretch, window 1280×720). Pack art is licensed and git-ignored:

1. Put the Sprout Lands zips in `asset-pipeline/sprout-lands/` and extract each one with "Extract Here" — each zip
   already contains its own top-level folder, so a plain "Extract All…" nests that folder twice.
2. **Project > Tools > Sprout Lands: Sync pack files** copies the files the project uses into `art/sprout/`
   (headless: `godot --headless --path . -s res://addons/sprout_tools/sync_cli.gd`, then `--import`). Reopen the
   project after the first sync — the editor caches the theme with missing textures until then.

The `.import` files under `art/sprout/` are committed so UIDs and the pixel-font import settings survive a clone. Add a
line to `FILES` in `addons/sprout_tools/sprout_sync.gd` whenever a scene or resource starts using another pack file.
Maaack's Sprout-Lands-Tilemap/UI addons in the pack folder are reference only; never enable them.

Type variations: `DecoratedButton`, `HeaderLabel`, `BannerLabel`, `OnDarkLabel`, `OnMapLabel`, `FlatPanel`, `BarPanel`,
`InsetPanel`, `InventorySlot`, `InventorySlotSelected`, `NamePlate`, `PackScrollBar`, `TooltipLabel`, `TooltipPanel`.
`OnDarkLabel` is for text on a dark panel; `OnMapLabel` is for text drawn straight over the ranch map (Toast,
`Hud/RepLabel`) — same near-white font color, plus a dark outline so it reads on grass.

Scrollbars: the pack draws a scrollbar as a thin bar with a fixed-size knob, which is a `VSlider` in Godot (a
`VScrollBar` stretches its grabber). For a scrolling page, hide the ScrollContainer's own bar (vertical scroll
mode "Show Never"), add a `VSlider` beside it with `theme_type_variation = PackScrollBar` and the
`ui/pack_scroll_bar.gd` script, and point its `scroll_path` at the container. The gallery does this.

## Ranch map

The ranch lives in `shop/shop.tscn` under the `Ranch` node, using the `ranch/ranch_tileset.tres` TileSet. Paint
grass on `Ranch/Ground` and soil on `Ranch/Paths` with the terrain brush — never paint soil on `Ground`, since the
soil edge tiles are transparent outside the soil area and would show the ground beneath instead of blending.
Fences go on `Ranch/Fences`, also with the terrain brush.

**Project > Tools > Sprout Lands: Set up ranch terrains (overwrites terrain bits)** rebuilds terrain sets 0
(Grass/Soil) and 1 (Fence) on the TileSet from the Sprout Lands bitmask reference. It removes ALL terrain sets on
the TileSet first, so if you've added any other terrain sets, re-add them after running it. Collision and custom
data on existing tiles are left alone.

If `ranch/ranch_tileset.tres` is ever lost, `RanchTerrains.new_tileset()` (`addons/sprout_tools/ranch_terrains.gd`)
recreates it from scratch.

## Creatures

Content lives in `data/` as Resources (Species, TraitDef, MoveDef, Personality, Location, OrderTemplate); edit
them in the Inspector. **Project > Tools > Creatures: Import monster pack…** copies a pack from
`asset-pipeline/80_Monster_Packs/` into `creatures/pack/` (git-ignored, licensed) and creates a SpriteFrames in
`creatures/frames/` and a starter Species in `data/species/` for each variant. It never overwrites an existing
file; delete a file first to regenerate it. Tests: `godot --headless --path . -s res://tests/run_tests.gd`.

The tests and the Db need the licensed pack art, which is git-ignored: on a fresh clone, drop the monster packs
into `asset-pipeline/80_Monster_Packs/` and run the Creatures import (and the Sprout Lands sync, above) before running
tests, otherwise `test_content` fails and SpriteFrames report missing textures.

Rule for all Godot work (see `CLAUDE.md`): changes go through the editor, and anything generated is an explicit
editor tool, never a script that silently overwrites editor-editable files.

## Playing

`shop/shop.tscn` is the main scene. The `Game` autoload (`game/game.gd`) is the only path from the UI to the rules.
Pens and the stable are `SpawnArea` nodes and panels open in the `PanelHost` node: move or resize them in the editor
(they draw placeholders there). Screenshots: `godot --path . -- --save=user://shot_save.json --open=card --screenshot=out.png`.
