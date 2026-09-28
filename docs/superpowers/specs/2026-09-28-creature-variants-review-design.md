# Creature variants review — design

Status: approved in chat 2026-09-28. Item 1 of the session after the ranch (sub-project 2): an experiment, not a
game change.

## Goal

Let the owner review two Sprout Lands takes on every creature, side by side with the original, before anything
changes in the game:

1. **Palette swap** — the pack art, every frame, recoloured to the Sprout Lands palette.
2. **Sprout-style still** — the asset pipeline redraws each creature (one idle frame, facing right) in Sprout Lands
   style.

Nothing in the pens, shop or game SpriteFrames changes. Adopting a variant later is its own decision.

## Constraints

- Everything Godot goes through the editor (CLAUDE.md). Nothing generated is saved into a `.tscn`/`.tres`.
- Pack art and anything derived from it stays git-ignored. The palette swap produces no files at all; stills live in
  the already-ignored `asset-pipeline/assets/restyle/`.
- Model generation runs from Python (`gen.py`), not an editor menu: calls take minutes and would block the editor.

## 1. Palette swap shader

- **Palette PNG:** `sprout_sync.gd` `FILES` gains
  `"palette/Sprout Lands default palette.png": SPRITES_PREM + "Sprout Lands color pallet/Sprout Lands defautlt palette.png"`
  (16×7, 98 opaque colours). Git-ignored like the rest of `art/sprout/`; its `.import` (filter off) is committed.
- **`creatures/sprout_palette.gdshader`** (`canvas_item`), uniform `palette : sampler2D` (filter nearest).
  `fragment()`: `COLOR` with alpha 0 passes through; otherwise loop every palette texel with `texelFetch`, skip
  transparent texels, keep the nearest by RGB distance, output it with the source alpha.
  `// ponytail: plain RGB distance; switch to OKLab in this loop if colours land badly.`
- **`creatures/sprout_palette.tres`**: ShaderMaterial with the palette texture set. Created in the editor. It is the
  single thing a pen sprite would use if the swap is adopted.

## 2. Sprout-style stills (pipeline)

### Baseline

- `jobs.json` gains `restyle_<species>` for the 10 species without one (slime, mushroom, blue_golem exist):
  `refs` = `../creatures/pack/<species>/idle.png#0,256,128,128` (idle, row 2 = facing right, column 0) then the two
  Sprout refs; `prompt` = a short description of the creature written from that frame (owner may edit).
- Output `asset-pipeline/assets/restyle/restyle_<species>.png` (64×64, Sprout palette, `.aseprite` beside it).
- Run: `python asset-pipeline/gen.py restyle_<species>`, or `python asset-pipeline/gen.py` for all (skips rendered).
- Review all 13 in the review scene; screenshot to the owner.

### Improvement round (only for failures the baseline shows)

Each change is small and judged before/after in the review scene:

1. **Reviewer checks identity.** For `restyle`, the reviewer instruction says the first ref is the source creature
   and fails outputs that lose its distinctive features (e.g. the golem's glowing eye and crystal spikes), in
   addition to the existing style checks.
2. **Size.** The `restyle` prefix asks for a creature about 32 px tall on the 64 px canvas instead of "tiny".
3. **Single-sprite style refs.** Replace the whole chicken and character sheets with one-frame `#x,y,w,h` crops.
4. **Trimmed source.** Crop the source frame to its opaque bounds before sending it.

Changes the baseline does not call for are not made. `test_gen.py` gains a check for each change with logic (restyle
reviewer instruction names the source ref; trim crops a padded frame to its opaque bounds).

### Cleanup

`restyle_compare.py` is deleted (the review scene replaces it). README: keep the recorded experiment result; add a
short "Creature variants review" section (how to regenerate stills, how to open the review scene).

## 3. Review scene

- **`creatures/variants_review.tscn`**: `Node2D` root and `Camera2D`. Script **`creatures/variants_review.gd`**
  (`@tool`) builds the content in `_ready()` as unowned nodes, including the grass `TileMapLayer` (ranch TileSet;
  painting a saved layer would write cells into the scene), so it shows (animated) in the editor's 2D view and is
  never saved into the scene.
- One group per `creatures/frames/*.tres`, 3 groups per row:
  - original: `AnimatedSprite2D`, `idle_right`, scale 1.4 (the pens' `sprite_scale`);
  - palette swap: the same with `material = sprout_palette.tres`;
  - Sprout still: `Sprite2D` at 1× from `Image.load_from_file` on `asset-pipeline/assets/restyle/restyle_<species>.png`
    (no `.import` for ignored outputs); if missing, a `Label` reading `gen.py restyle_<species>`;
  - a `Label` with the species id under the group (project theme font).
- The grass centre tile fills the used area.
- Mouse wheel scrolls the camera. After `--`: `--scroll=<px>` and `--screenshot=<png>`, as in `ui/gallery.gd`:
  `Godot_v4.7.2-stable_win64_console.exe --path . res://creatures/variants_review.tscn -- --screenshot=out.png --scroll=0`
- New species appear automatically; they only need a restyle job for their still.

## 4. Testing and errors

- `tests/run_tests.gd`:
  - shader: render an opaque and a transparent pixel through `sprout_palette.tres` in a `SubViewport`; the opaque one
    comes out as a palette colour, the transparent one stays transparent;
  - review scene: instancing it yields one group per `creatures/frames/*.tres`, each with an original, a swapped
    sprite and a still or the missing-still label.
- `python asset-pipeline/test_gen.py`: the improvement-round checks above.
- Errors: palette PNG not synced → the swap renders unchanged and the scene `push_warning`s to run
  "Sprout Lands: Sync pack files"; missing still → the label; missing pack sheet → SpriteFrames' own error.
- Verification: standalone screenshot of the review scene and an `editor_screenshot` with it open; full test suite
  green; `git status` shows no licensed or derived art.

## Out of scope

Pens, shop and game SpriteFrames; baked palette-swap sheets; animated restyles (follow-up, starting with a
single-strip probe on one species). Item 2 (further restyles) gets its own brainstorm and adds a column to this
review scene.
