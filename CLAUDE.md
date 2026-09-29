# Upgraded Journey

Godot 4.7 project at the repo root; AI asset pipeline in `asset-pipeline/` (see its README).

## Standing rule: everything Godot goes through the Godot editor

The owner edits scenes, themes, scripts and settings in the Godot editor. Nothing may exist in a form the
editor cannot open and change, and nothing may silently overwrite what was changed there.

- Make Godot changes with the `godot-ai` MCP tools (scene, node, script, resource, project, editor_screenshot)
  while the editor is open, so the editor is the source of truth and shows the change immediately.
  Fall back to writing `.tscn` / `.tres` / `.gd` text only when the MCP is unavailable, and then confirm the
  file opens cleanly in the editor (`--headless --import` with no errors is the minimum check).
- No generated Godot files. If something must be produced from external data (art packs, spreadsheets), make it
  an editor tool: an `EditorPlugin` with a `Tools` menu item or dock, or an `EditorScript`, written in GDScript
  under `addons/`. It runs on demand, and any overwrite of an editor-editable resource is explicit and named
  in the menu item ("... (overwrites edits)").
- If an edit would be tedious to make by hand in the editor, build the editor tool that makes it easy rather
  than scripting around the editor.
- Verify visually: take an `editor_screenshot` (or run the scene with the gallery's `--screenshot` flag) after
  UI or scene changes.

## Layout

- `ui/theme/sprout_lands.tres` is the project theme (`gui/theme/custom`), on a 640×360 pixel grid. Edit it in the
  Theme editor. `Project > Tools > Sprout Lands: Sync pack files` copies the pack art it uses from
  `asset-pipeline/sprout-lands/` (git-ignored, licensed) into `art/sprout/` (art ignored, `.import` files committed).
- `ui/gallery.tscn` shows every themed control; keep it updated when adding theme types.
- `ranch/ranch_tileset.tres` is the ranch TileSet; its terrain bits come from
  `Project > Tools > Sprout Lands: Set up ranch terrains (overwrites terrain bits)`.
- Buildables (docs/superpowers/specs/2026-09-29-buildable-pens-design.md): one `BuildableDef` `.tres` per kind in
  `data/buildables/` (price, capacity, footprint, scene); the scene is laid out in the editor from cell (0, 0) —
  `ranch/pen.tscn` (fences use `ranch/fence_tileset.tres`, creatures live in its `%Creatures` SpawnArea). The Market
  sells them; `shop/placer.tscn` places them; the farm instances `Game.state.placed` under `%Buildings`. Paint where
  the player may build on the farm's `%Buildable` layer (visible in the editor, hidden in game except while placing).
- Page scrollbars: `VSlider` + `PackScrollBar` variation + `ui/pack_scroll_bar.gd` beside a ScrollContainer
  whose own bar is hidden (see README). Do not restyle `VScrollBar` to fake it; its grabber always stretches.
- `addons/godot_ai`, `addons/godot_omni`: Godot-MCP. Server port 8765 (Docker owns 8000). Start Claude Code
  before opening the editor so the plugin attaches to the server Claude Code owns.
- Asset packs and installers are git-ignored; do not commit licensed art.
