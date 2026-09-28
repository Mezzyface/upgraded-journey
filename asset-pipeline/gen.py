"""Game asset pipeline: jobs.json -> agy (Antigravity CLI, nano-banana generate_image) -> assets/<type>/<name>.png
Everything lives under asset-pipeline/ (its .gdignore keeps Godot from importing the packs and raw output).

    python asset-pipeline/gen.py                 # run every job in pipeline/jobs.json (skips ones already rendered)
    python asset-pipeline/gen.py hero_fox        # run one job by name
    python asset-pipeline/gen.py --force hero_fox        # regenerate even if it exists
    python asset-pipeline/gen.py --reprocess blue_slime  # re-run keying/resize on the saved .raw without regenerating
    python asset-pipeline/gen.py --review blue_slime     # just run the reviewer on an existing asset
    python asset-pipeline/gen.py --remap <png>[#x,y,w,h] [--out <png>]  # put an existing image on a palette, no API call

Job fields: name, type (portrait|splash|sprite|ui|prop|restyle), prompt, refs (optional, <=3 paths, accept a
"#x,y,w,h" crop suffix), aspect, size (sprite/ui px), colors (palette size for the Aseprite pass; 0 skips it),
palette (name from PALETTES; locks the Aseprite pass to that palette PNG instead of quantizing to `colors`).
Each type has a style prefix + default reference images pulled from art-example / the packs / sprout-lands.
"""
import glob, hashlib, json, os, re, shutil, subprocess, sys, tempfile, time
from collections import deque
from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "assets")
BRAIN = os.path.expanduser("~/.gemini/antigravity-cli/brain")
ASEPRITE = os.environ.get("ASEPRITE", "C:/Program Files/Aseprite/Aseprite.exe")
MAGENTA = (255, 0, 255)
REWORKS = 2
TRIM_PAD = 2  # px kept around the creature when a restyle source frame is trimmed
SIZES = {  # standard sprite sizes (px, square); portrait/splash match the art-example dimensions
    "tiny": 32, "small": 64, "large": 128, "boss": 256,
    "icon": 32, "button": 128,
    "portrait": (540, 720), "splash": (1280, 720),
}

SL = "sprout-lands/"
SL_PREM = SL + "Sprout Lands - Sprites - premium pack/"
SL_UI_BASIC = SL + "Sprout Lands - UI Pack - Basic pack/"
SL_UI_PREM = SL + "Sprout Lands - UI Pack - Premium pack/"
PALETTES = {"sprout": SL_PREM + "Sprout Lands color pallet/Sprout Lands defautlt palette.png"}

STYLES = {
    "portrait": dict(
        aspect="3:4", colors=32, size="portrait",
        prefix="Pixel art full-body character portrait matching the style of the reference images exactly: "
               "crisp 1px dark outlines, small limited palette, flat colors with hard-edged cel shading, "
               "no anti-aliasing, no gradients, centered on a plain solid white background, no text. Subject: ",
        refs=["art-example/portrait1.png", "art-example/portrait2.png"]),
    "splash": dict(
        aspect="16:9", key=False, colors=64, size="splash",
        prefix="16:9 pixel art splash screen background matching the style of the reference images exactly: "
               "limited pastel palette, flat cel-shaded clouds and surfaces, clean pixel edges, "
               "no dithering, no text, no characters, wide establishing shot. Scene: ",
        refs=["art-example/splashscreen1.gif", "art-example/splashscreen2.gif"]),
    "sprite": dict(
        aspect="1:1", size="small", colors=16,
        prefix="Tiny 16-bit pixel art game sprite matching the style of the reference monster exactly: "
               "chibi proportions, thick dark outline, 3-4 shades per color, one creature centered and facing right, "
               "idle pose, drop shadow, no text, on a solid flat magenta #FF00FF background. Creature: ",
        refs=["80_Monster_Packs/Monster Packs/Monster Pack 1 (Slimes)/Slime.gif"]),
    "ui": dict(
        aspect="1:1", size=32, colors=0, palette="sprout",
        prefix="Tiny pixel art game UI element matching the style of the reference (Sprout Lands UI pack) exactly: "
               "soft cream and wood-brown pastel palette, 1px dark outline, flat shading with a one-pixel highlight, "
               "no anti-aliasing, centered, no text, on a solid flat magenta #FF00FF background. Element: ",
        refs=[SL_UI_BASIC + "Sprite sheets/Sprite sheet for Basic Pack.png",
              SL_UI_PREM + "UI Sprites/Dialouge UI/dialog box.png"]),
    "prop": dict(
        aspect="1:1", size="small", colors=0, palette="sprout",
        prefix="Tiny top-down (3/4 view) pixel art farm game object matching the style of the reference sprite sheets "
               "exactly (Sprout Lands): soft pastel palette, 1px dark brown outline, simple flat shading, no "
               "anti-aliasing, sized for a 16x16 tile grid, one object centered, no text, on a solid flat magenta "
               "#FF00FF background. Object: ",
        refs=[SL_PREM + "Objects/Trees, stumps and bushes.png", SL_PREM + "Objects/work station.png",
              SL_PREM + "Tilesets/Building parts/Chest.png"]),
    "restyle": dict(  # job refs: [creature frame to redraw, style ref, style ref]
        aspect="1:1", size="small", colors=0, palette="sprout",
        prefix="Redraw the creature from the FIRST reference image as a 16-bit farm game sprite whose creature fills about half the image height in the exact "
               "style of the OTHER reference images (Sprout Lands): same creature, same pose and silhouette, colours "
               "moved to that soft pastel palette, 1px dark outline, simple flat shading, no anti-aliasing, one "
               "creature centered and facing right, no text, on a solid flat magenta #FF00FF background. Creature: ",
        refs=[SL_PREM + "Animals/Chicken/chicken default.png", SL_PREM + "Characters/Premium Charakter Spritesheet.png"]),
}


def as_png(ref, trim=False):
    """generate_image only takes still images: GIF refs become a PNG of their first frame, and 'path#x,y,w,h'
    refs become a PNG of that region (e.g. one frame of a sprite sheet). trim=True also crops to the opaque
    pixels plus TRIM_PAD, so a small creature in a big cell fills the ref. Cached in the temp dir."""
    path, _, crop = ref.partition("#")
    path = os.path.join(ROOT, path)
    if not crop and not trim and not path.lower().endswith(".gif"):
        return path
    tag = (("_" + crop.replace(",", "_")) if crop else "") + ("_trim" if trim else "")
    # ponytail: basename alone collides when refs share a filename (e.g. creatures/pack/*/idle.png) --
    # prefix a hash of the full path so distinct sources never share a cache entry.
    h = hashlib.sha1(path.encode()).hexdigest()[:8]
    cached = os.path.join(tempfile.gettempdir(), "agy_refs", h + "_" + os.path.basename(path) + tag + ".png")
    if not os.path.exists(cached):
        os.makedirs(os.path.dirname(cached), exist_ok=True)
        im = Image.open(path)
        if crop:
            x, y, w, h = map(int, crop.split(","))
            im = im.convert("RGBA").crop((x, y, x + w, y + h))
        else:
            im = im.convert("RGB")
        if trim:
            im = im.convert("RGBA")
            box = im.getbbox()
            if box:
                im = im.crop((box[0] - TRIM_PAD, box[1] - TRIM_PAD, box[2] + TRIM_PAD, box[3] + TRIM_PAD))
        im.save(cached)
    return cached


def _rgba(png):
    b = Image.open(png).convert("RGBA").tobytes()
    return (tuple(b[i:i + 4]) for i in range(0, len(b), 4))


def palette_colors(png):
    return {c[:3] for c in _rgba(png) if c[3]}


def opaque_count(png):
    return sum(1 for c in _rgba(png) if c[3])


def off_palette(png, pal_png):
    pal = palette_colors(pal_png)
    return sum(1 for c in _rgba(png) if c[3] and c[:3] not in pal)


def palette_of(job):
    name = job.get("palette", STYLES[job["type"]].get("palette"))
    return os.path.join(ROOT, PALETTES[name]) if name else None


def agy(instruction, schema=None, tries=3):
    cmd = ["agy", "-p", instruction, "--output-format", "json", "--print-timeout", "240s"] + (
        ["--json-schema", json.dumps(schema)] if schema else [])
    for i in range(tries):  # ponytail: backend 404s/5xx happen; blind retry with backoff
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
        info = json.loads(next(l for l in r.stdout.splitlines() if l.startswith("{")))
        if info.get("status") == "SUCCESS":
            return info
        print(f"      agy error ({info.get('error', '')[:80]}), retry {i + 1}/{tries}", flush=True)
        time.sleep(5 * (i + 1))
    raise RuntimeError(f"agy failed: {info}")


def job_refs(job):
    refs = job.get("refs", STYLES[job["type"]]["refs"])[:3]
    # restyle: the first ref is the creature to redraw; trim it so the model sees the creature, not an empty cell
    return [as_png(r, trim=job["type"] == "restyle" and i == 0) for i, r in enumerate(refs)]


def step_errors(conv_dir):
    """agy's reply can be "done" even when generate_image failed (e.g. a 429 quota error); the real error is in
    the conversation's step outputs. Returns their first lines joined, or "" if there are none."""
    errors = []
    for f in sorted(glob.glob(os.path.join(conv_dir, ".system_generated", "steps", "*", "output.txt"))):
        text = open(f, encoding="utf-8", errors="replace").read()
        if text.startswith("Encountered error"):
            errors.append(text.splitlines()[0][:200])
    return "; ".join(errors)


def generate(job, notes=""):
    style = STYLES[job["type"]]
    refs = job_refs(job)
    prompt = style["prefix"] + job["prompt"]
    if notes:
        prompt += " IMPORTANT, a reviewer rejected the previous attempt, fix these issues: " + notes
    instruction = (
        f"Call generate_image exactly once with Prompt={json.dumps(prompt)}, ImageName='{job['name']}', "
        f"AspectRatio='{job.get('aspect', style['aspect'])}', ImagePaths={json.dumps(refs)}. "
        "Do not edit the prompt. Then reply with only the word done."
    )
    info = agy(instruction)
    files = glob.glob(os.path.join(BRAIN, info["conversation_id"], "*.*"))
    files = [f for f in files if f.lower().endswith((".jpg", ".png", ".jpeg"))]
    if not files:
        conv = os.path.join(BRAIN, info["conversation_id"])
        raise RuntimeError(f"no image in brain dir for {info['conversation_id']}: "
                           f"{step_errors(conv) or info.get('response')}")
    return max(files, key=os.path.getmtime)


def is_key_narrow(r, g, b):
    """Fixed-brightness key-colour test (the default): matches the bright #FF00FF key and close
    variants. Safe to run on every keyed job -- doesn't match this style's dark-purple outline/
    shading colour (verified against asset-pipeline/assets/sprite/blue_slime.png, see task report)."""
    return r > 140 and b > 130 and g < 90


def is_key_hue(r, g, b):
    """Wide hue-based key-colour test: also catches dark shadow-tinted purples (e.g.
    (127,41,128)) that fall under is_key_narrow's brightness cutoff. NOT safe as a default --
    it also matches this style's legitimate dark-purple outline/cel-shading colour (removes 89 of
    blue_slime.png's 306 opaque pixels, incl. art beside the crown, vs 2 for is_key_narrow). Only
    ever run behind the opt-in "key_shadow_fix" job flag."""
    return r > 100 and b > 100 and g < min(r, b) - 60


def despill(im, is_key=is_key_narrow):
    """Flood-fill from the already-transparent background into any adjoining key-coloured
    (magenta/purple) pixels, clearing them too -- catches a keyed shadow/halo the corner
    flood-fill and the global halo-strip above miss (e.g. drop shadows dark enough to fall
    outside the halo-strip's threshold). Only pixels *connected* to transparent background
    are cleared, so key-coloured art fully enclosed by opaque pixels is left alone. Uses the
    narrow (safe-by-default) key test unless a job opts into the wide one via is_key."""
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    q = deque()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                seen[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                r, g, b, a = px[nx, ny]
                if a > 0 and is_key(r, g, b):
                    px[nx, ny] = (r, g, b, 0)
                    seen[ny * w + nx] = 1
                    q.append((nx, ny))
    return im


def neutral_shadow(im, is_key=is_key_hue):
    """Part of the opt-in "key_shadow_fix" path only (never called by default): recolour any
    key-coloured pixels the edge-connected wide despill couldn't reach (fully enclosed by opaque
    art, e.g. a shadow band under a fence) into a plain dark shadow, same shape/alpha-ish. Runs
    over the whole image, so it must stay opt-in -- on any job with legitimately purple art it
    would repaint that art too."""
    w, h = im.size
    px = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and is_key(r, g, b):
                px[x, y] = (35, 30, 28, 140)
    return im


def postprocess(src, job):
    style = STYLES[job["type"]]
    im = Image.open(src).convert("RGBA")
    if job.get("key", style.get("key", True)):
        # ponytail: flood-fill the flat background from each corner (tolerant of JPG noise). rembg if edges get ugly.
        for xy in [(0, 0), (im.width - 1, 0), (0, im.height - 1), (im.width - 1, im.height - 1)]:
            ImageDraw.floodfill(im, xy, (0, 0, 0, 0), thresh=90)
        if "#FF00FF" in style["prefix"]:  # strip the magenta halo the flood fill leaves around edges
            r, g, b, a = im.split()
            halo = ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v > 150 else 0),
                                                           b.point(lambda v: 255 if v > 150 else 0)),
                                       g.point(lambda v: 255 if v < 120 else 0))
            im.putalpha(ImageChops.subtract(a, halo))
            if job.get("key_shadow_fix"):  # opt-in: wide hue despill + neutral-shadow the rest
                im = despill(im, is_key_hue)
                im = neutral_shadow(im, is_key_hue)
            else:
                im = despill(im)  # default: narrow test, safe for every keyed job
    size = job.get("size", style.get("size"))
    size = SIZES.get(size, size) if isinstance(size, (str, int)) else size  # ponytail: [w, h] sizes aren't hashable
    if size:
        size = (size, size) if isinstance(size, int) else tuple(size)
        im = im.resize(size, style.get("resample", Image.NEAREST))  # ponytail: nearest; a pixel-grid detector is better
    return im


REVIEW_SCHEMA = {"type": "object", "required": ["pass", "issues"],
                 "properties": {"pass": {"type": "boolean"}, "issues": {"type": "string"}}}


def review_instruction(view, job, refs):
    """The reviewer prompt. For restyle jobs the first ref is the creature being redrawn, so identity is checked
    against it and only the remaining refs are style references."""
    if job["type"] == "restyle":
        look = f"the source creature {json.dumps(refs[0])} and then the style references {json.dumps(refs[1:])}"
        identity = ("it is not recognisably the same creature as the source creature (lost distinctive features such "
                    "as its eyes, spikes, crystals, cap, antenna, legs or markings, or a different body shape), "
                    "it does not face right, ")
    else:
        look, identity = f"the style references {json.dumps(refs)}", ""
    return (
        f"You are an art director QA-ing a game asset. Use view_file ONLY (never run_command) to look at the "
        f"candidate {view} and then {look}. The candidate was generated for: "
        f"{json.dumps(job['prompt'])} as a {job['type']} in the reference style. Fail it if: it does not depict the "
        f"prompt, {identity}it is not pixel art in the reference style, it contains text, watermarks or extra subjects, or "
        f"(for portrait/sprite/ui) any background other than the flat magenta remains (magenta #FF00FF in the candidate "
        f"means transparent and is correct; a small drop shadow under the subject is part of the sprite, not background). "
        f"Be strict but not pedantic. "
        f"Reply with JSON: pass (bool) and issues (short concrete fix instructions, empty if pass)."
    )


def review(dest, job):
    """Gemini vision looks at the finished asset next to the references and judges it. Returns the verdict dict."""
    im = Image.open(dest).convert("RGBA")
    if im.width < 256:  # small sprites are hard to judge at 1x
        im = im.resize((im.width * 8, im.height * 8), Image.NEAREST)
    view = dest[:-4] + ".review.png"  # must live inside the workspace or view_file stalls on permissions
    bg = Image.new("RGBA", im.size, MAGENTA + (255,))  # the model cannot see alpha; show it as magenta
    bg.alpha_composite(im)
    bg.convert("RGB").save(view)
    refs = job_refs(job)
    instruction = review_instruction(view, job, refs)
    info = agy(instruction, REVIEW_SCHEMA)
    for m in reversed(re.findall(r"\{[^{}]*\}", info.get("response", ""))):  # response may wrap the JSON in prose/fences
        try:
            v = json.loads(m)
            if "pass" in v:
                return {"pass": bool(v["pass"]), "issues": str(v.get("issues", ""))}
        except ValueError:
            pass
    return {"pass": False, "issues": f"reviewer gave no verdict: {info.get('response')}"}


def refine(dest, job):
    """Aseprite pass: remap to the job's palette PNG (or quantize to `colors`), save a .aseprite for hand edits."""
    colors = job.get("colors", STYLES[job["type"]]["colors"])
    pal = palette_of(job)
    if pal and not os.path.exists(pal):
        raise RuntimeError(f"{dest}: palette not found at {pal} -- "
                            f"extract the Sprout Lands zips into asset-pipeline/sprout-lands/")
    if pal and not os.path.exists(ASEPRITE):
        print(f"WARN  {dest}: Aseprite not found at {ASEPRITE}, palette lock skipped")
        off = off_palette(dest, pal)
        if off:
            print(f"WARN  {dest}: {off} pixels off the palette")
        return
    if not (colors or pal) or not os.path.exists(ASEPRITE):
        return
    before = opaque_count(dest)
    param = f"palette={pal}" if pal else f"colors={colors}"
    r = subprocess.run([ASEPRITE, "-b", "--script-param", f"in={dest}", "--script-param", param,
                        "--script", os.path.join(ROOT, "refine.lua")], capture_output=True, text=True)
    print("     ", (r.stdout.strip() or r.stderr.strip()).splitlines()[-1])
    if pal:
        off, lost = off_palette(dest, pal), before - opaque_count(dest)
        if off or lost:
            print(f"WARN  {dest}: {off} pixels off the palette, {lost} opaque pixels lost in the remap")


def remap(ref, out):
    """Put an existing image on the Sprout palette (no model call): `gen.py --remap <path[#x,y,w,h]> [--out <png>]`."""
    os.makedirs(os.path.dirname(out), exist_ok=True)
    Image.open(as_png(ref)).convert("RGBA").save(out)
    refine(out, {"type": "prop", "palette": "sprout"})


def check_inputs(job):
    """Fail clearly before any model call when a job's palette or reference files are missing -- otherwise the
    un-remapped `dest` from generate() gets saved anyway and the next run just prints `skip`."""
    pal = palette_of(job)
    if pal and not os.path.exists(pal):
        raise RuntimeError(f"{job['name']}: palette not found at {pal} -- "
                            f"extract the Sprout Lands zips into asset-pipeline/sprout-lands/")
    for ref in job.get("refs", STYLES[job["type"]]["refs"]):
        path = os.path.join(ROOT, ref.partition("#")[0])
        if not os.path.exists(path):
            raise RuntimeError(f"{job['name']}: ref not found at {path} -- "
                                f"extract the Sprout Lands zips into asset-pipeline/sprout-lands/")


def run(job, force=False, reprocess=False):
    dest = os.path.join(OUT, job["type"], job["name"] + ".png")
    raw = glob.glob(dest[:-4] + ".raw.*")
    if reprocess == "review" and os.path.exists(dest):
        print(f"review {job['type']}/{job['name']}: {review(dest, job)}")
        return
    if reprocess and raw:
        postprocess(raw[0], job).save(dest)
        refine(dest, job)
        print(f"redid {dest}")
        return
    if os.path.exists(dest) and not force:
        print(f"skip  {dest}")
        return
    check_inputs(job)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    notes, log = "", []
    for attempt in range(1 + REWORKS):
        print(f"gen   {job['type']}/{job['name']} attempt {attempt + 1} ...", flush=True)
        src = generate(job, notes)
        postprocess(src, job).save(dest)
        refine(dest, job)
        shutil.copy(src, dest[:-4] + ".raw" + os.path.splitext(src)[1])  # keep the untouched original
        verdict = review(dest, job)
        log.append(verdict)
        json.dump({"attempts": log}, open(dest[:-4] + ".review.json", "w"), indent=1)
        if verdict["pass"]:
            print(f"wrote {dest}")
            return
        notes = verdict["issues"]
        print(f"      rework: {notes}")
    print(f"WARN  {dest} failed review after {1 + REWORKS} attempts, last output kept")


if __name__ == "__main__":
    if "--remap" in sys.argv:
        ref = sys.argv[sys.argv.index("--remap") + 1]
        name = os.path.basename(os.path.dirname(ref.partition("#")[0]))
        out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else os.path.join(OUT, "restyle", name + "_palette.png")
        remap(ref, out)
        print(f"wrote {out}")
        sys.exit()
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    jobs = json.load(open(os.path.join(ROOT, "jobs.json")))
    for job in jobs:
        if not args or job["name"] in args:
            run(job, force="--force" in sys.argv,
                reprocess="review" if "--review" in sys.argv else "--reprocess" in sys.argv)
