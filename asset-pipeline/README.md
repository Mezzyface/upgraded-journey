# Asset pipeline

Generates pixel-art game assets with nano-banana through the local Antigravity CLI (`agy`, your Gemini account),
using the art in `art-example/`, `80_Monster_Packs/` and `sprout-lands/` as style references.

```bash
python asset-pipeline/gen.py              # every job in jobs.json (skips already-rendered)
python asset-pipeline/gen.py hero_fox     # one job
python asset-pipeline/gen.py --force x    # regenerate
python asset-pipeline/gen.py --reprocess  # redo keying/resize from the saved .raw, no API call
python asset-pipeline/gen.py --review x   # just run the reviewer on an existing asset
```

Flow per job: nano-banana generate -> key/resize -> Aseprite quantize -> Gemini vision review -> pass, or
regenerate with the reviewer's fix notes appended (up to `REWORKS`, default 2). The verdicts are written to
`asset-pipeline/assets/<type>/<name>.review.json`; the last attempt is kept even if it never passed (a `WARN` line says so).

Output: `asset-pipeline/assets/<type>/<name>.png` (+ `.raw.jpg`, the untouched model output, git-ignored).

## Aseprite refine pass

After keying/resizing, `refine.lua` runs in Aseprite batch mode (`Aseprite.exe -b --script`): it quantizes the
image to `colors` (per-type default, override per job, `0` to skip), rewrites the PNG, and saves a
`<name>.aseprite` next to it so you can hand-edit in Aseprite. Re-run `--reprocess` after changing `colors`.

Any further Aseprite work (outlines, sprite sheets, tags, tilemaps) is a few lines of Lua against
https://www.aseprite.org/api/ invoked the same way; see `refine.lua` as the template. Set `ASEPRITE` in the
environment if it is not at `C:/Program Files/Aseprite/Aseprite.exe`.

## jobs.json

```json
{"name": "blue_slime", "type": "sprite", "prompt": "a blue slime with a tiny crown",
 "refs": ["optional/up/to/3.png"], "aspect": "1:1", "size": "small", "colors": 16}
```

`"key_shadow_fix": true` (keyed types only): swaps despill's default narrow, fixed-brightness key-colour test for a wider hue-based one that also catches dark shadow-tinted purples, then recolours any key-coloured pixels still left anywhere in the image (e.g. a shadow band fully enclosed by opaque art, which an edge-connected despill can't reach) into a plain dark shadow. Opt in per job only -- the wide test also matches this style's legitimate dark-purple outline/shading colour, so it must never run by default.

## Standard sizes

| name     | px        | use                          |
|----------|-----------|------------------------------|
| tiny     | 32x32     | FX, projectiles, pickups     |
| small    | 64x64     | regular monsters (default)   |
| large    | 128x128   | elites, large beasts         |
| boss     | 256x256   | bosses                       |
| icon     | 32x32     | inventory / HUD icons        |
| button   | 128x128   | UI buttons (default for ui)  |
| portrait | 540x720   | matches art-example portraits|
| splash   | 1280x720  | matches art-example splashes |

`size` also accepts an int (square) or `[w, h]`.

| type     | aspect | size     | colors | post-processing                            | default refs               |
|----------|--------|----------|--------|--------------------------------------------|----------------------------|
| portrait | 3:4    | portrait | 32     | white bg keyed to transparent, nearest     | art-example portraits      |
| splash   | 16:9   | splash   | 64     | nearest resize only                        | art-example splash screens |
| sprite   | 1:1    | small    | 16     | magenta bg keyed, nearest resize           | Monster Pack 1 slime       |
| ui       | 1:1    | 32       | —      | magenta keyed, nearest, Sprout palette     | Sprout UI sheet + dialog box |
| prop     | 1:1    | small    | —      | magenta keyed, nearest, Sprout palette     | Sprout trees, work station, chest |
| restyle  | 1:1    | small    | —      | magenta keyed, nearest, Sprout palette     | job ref: the creature frame; gen.py adds `STYLE_EXAMPLE` + a palette card |

Style prefixes live in `STYLES` in `gen.py`; edit them there to steer the look.
Needs `agy` on PATH (logged in), Pillow, and Aseprite (optional; skipped if not found).

## Palette lock

`"palette": "sprout"` (default for `ui`, `prop`, `restyle`) makes `refine.lua` remap the image to the Sprout Lands
palette PNG instead of quantizing to `colors`. After the pass `gen.py` prints a `WARN` if any opaque pixel is off the
palette or the remap made pixels transparent. `python asset-pipeline/gen.py --remap <png>[#x,y,w,h] [--out <png>]`
puts any existing image (or one cell of a sheet) on the palette without a model call. Refs accept the same
`#x,y,w,h` suffix to use one frame of a sprite sheet. Checks: `python asset-pipeline/test_gen.py`.

Props used in the game are copied by hand from assets/prop/ into ranch/art/ (committed; they are our own art, not pack art).

## Restyle experiment result

Palette-remap (not full model restyle) is the recommended default -- it kept each creature's identity; full
restyle lost the golem's features; creatures read well at about 32 px against 16 px tiles (a rough midpoint of the
15-30 px measured); sub-project 2 uses this for `sprite_scale`.

## Creature variants review

Every creature has a `restyle_<species>` job (one idle frame facing right, redrawn in Sprout style) writing
`assets/restyle/restyle_<species>.png` (git-ignored). `python asset-pipeline/gen.py restyle_wolf` makes one;
`python asset-pipeline/gen.py` makes any missing; `--force restyle_wolf` redoes one. Each restyle gets three single-subject
refs (the tool takes at most 3): the trimmed creature frame, the owner's chosen conversion
(`assets/restyle/favourites/restyle_yellow_golem.png`, `STYLE_EXAMPLE` in gen.py) and a palette card; the prompt also lists
the Sprout palette ramps as hex, and the Aseprite pass still snaps the result to the palette.

Images made elsewhere (e.g. the Gemini web app, which takes more refs and has a separate quota from `agy`) go
through the same key/resize/palette pass with `python asset-pipeline/gen.py --ingest restyle_wolf <image>`; the
source is kept as `restyle_wolf.raw.<ext>`. No review runs on ingested images. Review them in Godot in
`creatures/variants_review.tscn` (original | Sprout palette swap | still, on ranch grass); from the command line:
`godot --path . res://creatures/variants_review.tscn -- --screenshot=out.png --scroll=0`.
