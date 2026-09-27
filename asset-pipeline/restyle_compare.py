"""Spike (throwaway): how close can the pipeline bring our creatures to Sprout Lands?
Per creature: original idle frame | palette remap only | full restyle, each on Sprout grass at the same pixel scale.
    python asset-pipeline/restyle_compare.py      -> asset-pipeline/assets/restyle/comparison.png
"""
import json, os
from PIL import Image
import gen

CREATURES = ["slime", "mushroom", "blue_golem"]
FRAME = "#0,256,128,128"  # idle sheet, row 2 (facing right), column 0
GRASS = gen.SL_PREM + ("Tilesets/ground tiles/New tiles/simpel versions/Grass tiles v2 simple cutout/"
                       "Grass_tiles_v2_Mid.png")
S = 2  # display scale; every image and the 16px grass tile get the same factor
OUT = os.path.join(gen.OUT, "restyle")


def cell(path):
    grass = Image.open(os.path.join(gen.ROOT, GRASS)).convert("RGBA")
    grass = grass.resize((grass.width * S, grass.height * S), Image.NEAREST)
    c = Image.new("RGBA", (128 * S, 128 * S))
    for y in range(0, c.height, grass.height):
        for x in range(0, c.width, grass.width):
            c.paste(grass, (x, y))
    if path and os.path.exists(path):
        im = Image.open(path).convert("RGBA")
        im = im.resize((im.width * S, im.height * S), Image.NEAREST)
        c.alpha_composite(im, ((c.width - im.width) // 2, (c.height - im.height) // 2))
    return c


if __name__ == "__main__":
    jobs = {j["name"]: j for j in json.load(open(os.path.join(gen.ROOT, "jobs.json")))}
    rows = []
    for name in CREATURES:
        ref = f"../creatures/pack/{name}/idle.png{FRAME}"
        gen.remap(ref, os.path.join(OUT, name + "_palette.png"))
        gen.run(jobs["restyle_" + name])
        rows.append([gen.as_png(ref), os.path.join(OUT, name + "_palette.png"),
                     os.path.join(gen.OUT, "restyle", "restyle_" + name + ".png")])
    sheet = Image.new("RGBA", (3 * 128 * S, len(rows) * 128 * S))
    for r, paths in enumerate(rows):
        for c, p in enumerate(paths):
            sheet.paste(cell(p), (c * 128 * S, r * 128 * S))
    sheet.save(os.path.join(OUT, "comparison.png"))
    print("wrote", os.path.join(OUT, "comparison.png"))
