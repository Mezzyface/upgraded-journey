# Upgraded Journey

Godot 4.7 project (root) + AI asset pipeline (`asset-pipeline/`, see its README).

## Godot MCP (Claude Code drives the editor)

`addons/godot_ai` + `addons/godot_omni` are [Godot-MCP v5.0.39](https://github.com/bebabinlarsson-blip/Godot-MCP)
(MIT). `.mcp.json` registers the `godot-ai` server for Claude Code in project scope; Claude Code asks once to
approve it on the next session start.

Order matters on this machine: start Claude Code (it spawns the server), then open the project in Godot:

```bash
"C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --editor --path .
```

The plugin attaches to the running server and the **Godot MCP** dock turns green. If Godot is opened first, the
plugin tries to spawn its own server, which fails the process-identity check on Windows; just restart Claude Code
or press the dock's reconnect button.

Notes:
- Server HTTP port is **8765** (Docker owns 8000). Set in `.mcp.json` and in Godot Editor Settings `godot_ai/http_port`.
- Telemetry is off (`GODOT_AI_DISABLE_TELEMETRY=1` in `.mcp.json`, `godot_ai/telemetry_enabled=false`).
- `godot_ai/auto_configure_clients=false` so the addon never rewrites `~/.claude.json` behind your back.
- Requires `uv` (`pip install uv`). The first launch downloads the pinned wheel + deps.

## UI theme (Isle of Lore 2 UI Pack)

`ui/theme/isle_of_lore.tres` is the project-wide theme (`gui/theme/custom`). Edit it in Godot's Theme editor
like any resource. The `addons/iol_theme` plugin adds two entries under **Project > Tools**:

- **Isle of Lore: Sync UI pack files** copies the ~45 PNGs and two fonts the theme uses from
  `asset-pipeline/ui-pack/` into `ui/theme/pack/` (git-ignored: licensed art, public repo) and composes the
  CheckButton switch images.
- **Isle of Lore: Rebuild theme from pack (overwrites edits)** regenerates the `.tres` from scratch with the
  nine-patch margins from the pack docs. Only use it to reset; it discards Theme-editor edits.

Fresh clone: drop the pack into `asset-pipeline/ui-pack/`, open the project, run Sync, wait for the import, and
the committed theme just works (Rebuild is not needed). Headless equivalent: `addons/iol_theme/rebuild_cli.gd`.

`ui/gallery.tscn` (the current main scene) shows every themed control. Type variations available via
`theme_type_variation`: `DecoratedButton`, `HeaderLabel`, `BannerLabel`, `OnDarkLabel`, `FlatPanel`, `BarPanel`,
`InsetPanel`, `InventorySlot`, `InventorySlotSelected`, `NamePlate`, `PackScrollBar`. Round buttons are not nine-patch art; use a
`TextureButton` with `button_round_*` as in the gallery.

Scrollbars: the pack draws a scrollbar as a thin bar with a fixed-size knob, which is a `VSlider` in Godot (a
`VScrollBar` stretches its grabber). For a scrolling page, hide the ScrollContainer's own bar (vertical scroll
mode "Show Never"), add a `VSlider` beside it with `theme_type_variation = PackScrollBar` and the
`ui/pack_scroll_bar.gd` script, and point its `scroll_path` at the container. The gallery does this.

Rule for all Godot work (see `CLAUDE.md`): changes go through the editor, and anything generated is an explicit
editor tool, never a script that silently overwrites editor-editable files.
