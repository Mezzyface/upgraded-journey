"""Game asset pipeline: jobs.json -> agy (Antigravity CLI, nano-banana generate_image) -> assets/<type>/<name>.png
Everything lives under asset-pipeline/ (its .gdignore keeps Godot from importing the packs and raw output).

    python asset-pipeline/gen.py                 # run every job in pipeline/jobs.json (skips ones already rendered)
    python asset-pipeline/gen.py hero_fox        # run one job by name
    python asset-pipeline/gen.py --force hero_fox        # regenerate even if it exists
    python asset-pipeline/gen.py --reprocess blue_slime  # re-run keying/resize on the saved .raw without regenerating
    python asset-pipeline/gen.py --review blue_slime     # just run the reviewer on an existing asset

Job fields: name, type (portrait|splash|sprite|ui), prompt, refs (optional, <=3 paths), aspect, size (sprite/ui px),
colors (palette size for the Aseprite pass; 0 skips it).
Each type has a style prefix + default reference images pulled from art-example / the packs.
"""
import glob, json, os, re, shutil, subprocess, sys, tempfile, time
from collections import deque
from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "assets")
BRAIN = os.path.expanduser("~/.gemini/antigravity-cli/brain")
ASEPRITE = os.environ.get("ASEPRITE", "C:/Program Files/Aseprite/Aseprite.exe")
MAGENTA = (255, 0, 255)
REWORKS = 2
SIZES = {  # standard sprite sizes (px, square); portrait/splash match the art-example dimensions
    "tiny": 32, "small": 64, "large": 128, "boss": 256,
    "icon": 32, "button": 128,
    "portrait": (540, 720), "splash": (1280, 720),
}

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
    "ui": dict(  # the ui-pack is smooth vector-style art, not pixel art, so no palette quantization here
        aspect="1:1", size="button", colors=0, resample=Image.LANCZOS,
        prefix="Clean 2D game UI element matching the style of the reference (Isle of Lore 2 UI pack) exactly: "
               "smooth anti-aliased dark outline, soft gradient shading, rounded beveled edges, glossy highlight, "
               "centered, no text, on a solid flat magenta #FF00FF background. Element: ",
        refs=["ui-pack/Documentation/files/examples/buttons/2_button_square_decorated_0.png",
              "ui-pack/Documentation/files/examples/buttons/6_button_round_big_0.png"]),
}


def as_png(path):
    """generate_image only takes still images; cache a PNG of GIF refs' first frame."""
    path = os.path.join(ROOT, path)
    if not path.lower().endswith(".gif"):
        return path
    cached = os.path.join(tempfile.gettempdir(), "agy_refs", os.path.basename(path) + ".png")
    if not os.path.exists(cached):
        os.makedirs(os.path.dirname(cached), exist_ok=True)
        Image.open(path).convert("RGB").save(cached)
    return cached


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
    return [as_png(r) for r in job.get("refs", STYLES[job["type"]]["refs"])][:3]


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
        raise RuntimeError(f"no image in brain dir for {info['conversation_id']}: {info.get('response')}")
    return max(files, key=os.path.getmtime)


def is_key_hue(r, g, b):
    """True for magenta/purple key-colour tones by hue, not fixed brightness: catches dark
    shadow-tinted purples (e.g. (127,41,128)) as well as the bright #FF00FF key itself."""
    return r > 100 and b > 100 and g < min(r, b) - 60


def despill(im):
    """Flood-fill from the already-transparent background into any adjoining key-coloured
    (magenta/purple) pixels, clearing them too -- catches a keyed shadow/halo the corner
    flood-fill and the global halo-strip above miss (e.g. drop shadows dark enough to fall
    outside the halo-strip's threshold). Only pixels *connected* to transparent background
    are cleared, so key-coloured art fully enclosed by opaque pixels is left alone."""
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
                if a > 0 and is_key_hue(r, g, b):
                    px[nx, ny] = (r, g, b, 0)
                    seen[ny * w + nx] = 1
                    q.append((nx, ny))
    return im


def neutral_shadow(im):
    """Opt-in (job "neutral_shadow": true): recolour any key-coloured pixels the edge-connected
    despill couldn't reach (fully enclosed by opaque art, e.g. a shadow band under a fence) into
    a plain dark shadow, same shape/alpha-ish. Runs over the whole image, so it's only wired in
    per job -- never on a type/job where a purple creature or prop is legitimate art."""
    w, h = im.size
    px = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and is_key_hue(r, g, b):
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
            im = despill(im)
            if job.get("neutral_shadow"):
                im = neutral_shadow(im)
    size = job.get("size", style.get("size"))
    size = SIZES.get(size, size) if isinstance(size, (str, int)) else size  # ponytail: [w, h] sizes aren't hashable
    if size:
        size = (size, size) if isinstance(size, int) else tuple(size)
        im = im.resize(size, style.get("resample", Image.NEAREST))  # ponytail: nearest; a pixel-grid detector is better
    return im


REVIEW_SCHEMA = {"type": "object", "required": ["pass", "issues"],
                 "properties": {"pass": {"type": "boolean"}, "issues": {"type": "string"}}}


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
    instruction = (
        f"You are an art director QA-ing a game asset. Use view_file ONLY (never run_command) to look at the "
        f"candidate {view} and then the style references {json.dumps(refs)}. The candidate was generated for: "
        f"{json.dumps(job['prompt'])} as a {job['type']} in the reference style. Fail it if: it does not depict the "
        f"prompt, it is not pixel art in the reference style, it contains text, watermarks or extra subjects, or "
        f"(for portrait/sprite/ui) any background other than the flat magenta remains (magenta #FF00FF in the candidate "
        f"means transparent and is correct; a small drop shadow under the subject is part of the sprite, not background). "
        f"Be strict but not pedantic. "
        f"Reply with JSON: pass (bool) and issues (short concrete fix instructions, empty if pass)."
    )
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
    """Aseprite pass: quantize palette, save a .aseprite next to the PNG for hand edits."""
    colors = job.get("colors", STYLES[job["type"]]["colors"])
    if not colors or not os.path.exists(ASEPRITE):
        return
    r = subprocess.run([ASEPRITE, "-b", "--script-param", f"in={dest}", "--script-param", f"colors={colors}",
                        "--script", os.path.join(ROOT, "refine.lua")], capture_output=True, text=True)
    print("     ", (r.stdout.strip() or r.stderr.strip()).splitlines()[-1])


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
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    jobs = json.load(open(os.path.join(ROOT, "jobs.json")))
    for job in jobs:
        if not args or job["name"] in args:
            run(job, force="--force" in sys.argv,
                reprocess="review" if "--review" in sys.argv else "--reprocess" in sys.argv)
