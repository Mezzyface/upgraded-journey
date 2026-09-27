# Asset pipeline

Generates pixel-art game assets with nano-banana through the local Antigravity CLI (`agy`, your Gemini account),
using the art in `art-example/`, `80_Monster_Packs/` and `ui-pack/` as style references.

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
| ui       | 1:1    | button   | 0      | magenta bg keyed, smooth (Lanczos) resize  | ui-pack decorated buttons  |

`ui` is smooth vector-style art because the Isle of Lore pack is; set `colors` and swap the prefix in `STYLES`
if you want pixel-art UI instead.

Style prefixes live in `STYLES` in `gen.py`; edit them there to steer the look.
Needs `agy` on PATH (logged in), Pillow, and Aseprite (optional; skipped if not found).
