# Sprout Lands: packs, theme and pipeline — design (sub-project 1)

Status: design for review, 2026-09-27. First of several sub-projects that move the game to the Sprout Lands art
(Cup Nooble) while keeping our creatures.

## Goal and roadmap

Switch environment, UI and characters to Sprout Lands. The main screen becomes a **top-down ranch** on one
640×360 screen, still **click-driven** (stations and creatures open panels as today); a Sprout Lands farmer walks
to whatever you click. Sub-projects, each with its own spec, plan and PR:

1. **Packs, theme, pipeline (this spec)** — pack layout + sync tool, Sprout Lands theme at 640×360, pipeline
   references and palette lock, creature-restyle experiment.
2. **Ranch scene** — TileSet (terrains, fences with collisions) from Maaack's Sprout-Lands-Tilemap as reference,
   `shop.tscn` rebuilt top-down, pens/stable as fenced `SpawnArea`s, stations as props, creatures rescaled,
   old side-view shop art and jobs removed.
3. **Farmer** — SpriteFrames from the premium character sheet, walks to the clicked station.
4. **Audio** — pack SFX on clicks, sales, end of day.
5. **Aseprite source of truth** (noted, see end).

Later, separately: expeditions (reuse the TileSet; Sorry pack Dungeon/Ocean sets).

## Constraints

- **License** (premium read_me): use and modify in any project; no redistribution of the pack, even modified; no
  NFTs. All pack art stays git-ignored (public repo), like the monster and Isle of Lore packs. The pack also bans
  "AI training"; the owner's decision is that using it as generation *reference input* is not training. Keep the
  image provider's "train on my data" setting off.
- **Editor first** (`CLAUDE.md`): Maaack's addons are never enabled — their installers copy/rewrite files and set
  `gui/theme/custom` and `main_scene`. Their resources are reference and a one-time starting point only.
- The addons target Godot 4.3 and the deprecated `TileMap`; sub-project 2 uses `TileMapLayer`s.

## 1. Pack layout and sync

- `sprout-lands/` (repo root, untracked) moves to `asset-pipeline/sprout-lands/`, git-ignored. Each zip is
  extracted next to itself into a folder of the same name (`Sprout Lands - Sprites - premium pack/`, …). The zips
  stay (fresh clone: drop zips, extract, sync). `Fonts.zip` and the loose `free_character_spritesheet_by-cupnooble.png`
  move too.
- Maaack's `Sprout-Lands-Tilemap-0.2.0` and `Sprout-Lands-UI-0.2.0` are extracted there as **reference only**.
- The Basic packs contain exactly the files Maaack's resources reference (`Sprite sheet for Basic Pack.png`,
  `Grass.png`, `Hills.png`, `Tilled Dirt.png`, `Water.png`, `Fences.png`, `Wooden House.png`, the `Objects/` sheets),
  so their regions, terrains and collision polygons stay valid after a path rewrite.
- **`addons/sprout_tools/`** (GDScript `EditorPlugin`) adds **Project > Tools > Sprout Lands: Sync pack files**. A
  const list maps each destination under `art/sprout/{ui,tiles,objects,characters,fonts,audio}/` to its source
  under `asset-pipeline/sprout-lands/`; the tool copies them and triggers an import. It only writes pack art
  (PNG/TTF/WAV), never a `.tres`/`.tscn`. Missing sources are listed in one error, not silently skipped. Only files
  a resource actually uses are listed; add entries as later sub-projects need them.
- `art/sprout/` art is git-ignored; its `.import` files are committed so UIDs and import settings (the pixel font
  without antialiasing) survive a fresh clone. `sprout-lands/` at the root is removed once moved.
- **One-time starting resources:** Maaack's `sprout_lands_theme.tres` is copied to `ui/theme/sprout_lands.tres`
  with its texture path rewritten to `art/sprout/ui/…`, UIDs stripped, and opened/re-saved in the editor. From then
  on the Theme editor owns it. (The TileSet gets the same treatment in sub-project 2.)

## 2. Theme and resolution

- **Resolution:** `display/window/size/viewport_width/height = 640×360`, `window_width/height_override = 1280×720`,
  stretch mode `canvas_items`, `default_texture_filter` stays nearest, `rendering/2d/snap/snap_2d_transforms_to_pixel = true`.
  One pixel grid for tiles, UI and fonts: ×2 at 720p, ×3 at 1080p.
- **Theme:** `ui/theme/sprout_lands.tres` becomes `gui/theme/custom`. Default font: `pixelFont-7-8x14-sproutLands.ttf`
  at the size that renders crisp (confirmed by screenshot), with antialiasing off.
- **Variations keep their names** so scenes keep their `theme_type_variation`: `DecoratedButton`, `HeaderLabel`,
  `BannerLabel`, `OnDarkLabel`, `FlatPanel`, `BarPanel`, `InsetPanel`, `InventorySlot`, `InventorySlotSelected`,
  `NamePlate`, `PackScrollBar`, `TooltipLabel`, `TooltipPanel`. Each is redefined with Sprout art in the Theme editor — the Basic sheet first,
  premium sprites (dialog boxes, inventory slots, slider) added to the sync list where the Basic sheet has nothing.
  `PackScrollBar` stays a `VSlider` + `ui/pack_scroll_bar.gd` beside a ScrollContainer.
- **Relayout in the editor (godot-ai MCP):** `creature_card.tscn`, `orders_panel.tscn`, `day_summary.tscn` and
  `ui/gallery.tscn` resized for 640×360 (mostly font sizes and margins; they are container-based). The gallery's
  round `TextureButton`s switch to Sprout square buttons. `shop.tscn` is only kept working and legible here;
  sub-project 2 rebuilds it.
- **Cursor:** `display/mouse_cursor/custom_image` = the Sprout cat-paw sprite.
- **Isle of Lore removal:** when nothing references it, delete `ui/theme/isle_of_lore.tres` and `addons/iol_theme/`,
  drop `ui/theme/pack/` from `.gitignore`, and update `README.md` and `CLAUDE.md` (theme, sync tool, resolution).
  The local `asset-pipeline/ui-pack/` folder is left on disk.
- **Done when:** `godot --headless --path . -s res://tests/run_tests.gd` passes; `--headless --import` has no
  errors; editor screenshots of the gallery, the shop and each panel are legible and pixel-crisp.

## 3. Asset pipeline

- Style references come from `asset-pipeline/sprout-lands/<pack>/…` (`as_png` already converts GIFs).
- **`ui` type** switches to Sprout pixel UI: pixel-art prefix, refs = Basic UI sheet + a premium dialog box,
  nearest resize.
- **New `prop` type:** a top-down object in Sprout style on the magenta key; refs = premium
  `Objects/Trees, stumps and bushes.png`, `Objects/work station.png`, `Tilesets/Building parts/Chest.png`. For things
  the pack lacks (order board, market stall, counter, creature feed).
- **Palette lock:** new `palette` field (per type default, per job override): `"sprout"` for `ui`, `prop` and
  `restyle`; absent means the current "quantize to `colors`" behaviour. `refine.lua` gets a `palette=<png>` param:
  load that palette and remap the image to it (indexed, no dithering) instead of `ColorQuantization`. The palette
  PNG is `Sprout Lands color pallet/Sprout Lands defautlt palette.png`.
- **Palette check:** after refine, `gen.py` counts opaque pixels whose colour is not in the palette and prints a
  `WARN` with the count. This is the pipeline's one runnable check for the feature.
- `sprite` (creatures keep the monster-pack style), `portrait` and `splash` are unchanged.
- One example job `order_board` (`prop`) proves the style end to end. README updated (types table, palette field,
  `restyle`, `--remap`).
- Skipped: a `tile` type — image models are poor at autotile sheets and the pack's tilesets cover the ranch. Add it
  if expeditions need terrain the pack lacks.

## 4. Creature restyle experiment (spike, throwaway)

Question: how close can the pipeline bring our creatures to Sprout Lands' style and palette?

- **Palette only:** `gen.py --remap <png> [--out <png>]` runs `refine.lua` with the Sprout palette on an existing
  image, no model call. Applied to frame 0 of `idle.png` (128×128 region) for `slime`, `mushroom`, `blue_golem`.
- **Full restyle:** new `restyle` type — the job's first ref is the creature frame to redraw; the prefix asks for
  the same creature, pose and silhouette redrawn in the style of the remaining refs (Sprout premium
  `Animals/Chicken/chicken default.png`, `Characters/Premium Charakter Spritesheet.png`), magenta key, palette
  `sprout`, size `small`. Jobs `restyle_slime`, `restyle_mushroom`, `restyle_blue_golem`.
- **Output:** `asset-pipeline/assets/restyle/comparison.png` — one row per creature: original | palette-only |
  restyled, each shown next to a 16px Sprout grass tile at the same scale. Reported with a recommendation
  (keep originals / palette-remap / restyle) that feeds sub-project 2's creature scale decision.
- Nothing is wired into the game. Single idle frame only; restyling whole animation sheets is a separate
  decision after seeing the results.

## Noted follow-up: Aseprite as the editing format

Owner wants all art editable as `.aseprite` going forward. Recorded here, not built in this sub-project:

- The pipeline already writes a `.aseprite` next to every generated PNG.
- For pack art: a batch `refine.lua`-style script that saves each used pack PNG as `.aseprite` (16px grid set;
  frames and tags for animated sheets), under a git-ignored folder. Some premium sheets already ship `.aseprite`.
- Open question for that spec: does Godot import `.aseprite` directly (e.g. an Aseprite importer addon) or do we
  keep exporting PNGs from Aseprite and have the sync tool copy those? Decide before building.
