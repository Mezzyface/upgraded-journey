"""Checks for gen.py helpers (no framework). python asset-pipeline/test_gen.py"""
import os, shutil, tempfile
from PIL import Image
import gen

TMP = tempfile.mkdtemp()


def save(name, size, pixels):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    for xy, c in pixels.items():
        im.putpixel(xy, c)
    path = os.path.join(TMP, name)
    im.save(path)
    return path


def test_off_palette_counts_only_opaque_strangers():
    pal = save("pal.png", (2, 1), {(0, 0): (10, 20, 30, 255), (1, 0): (40, 50, 60, 255)})
    img = save("img.png", (3, 1), {(0, 0): (10, 20, 30, 255), (1, 0): (99, 99, 99, 255)})  # (2,0) transparent
    assert gen.off_palette(img, pal) == 1
    assert gen.opaque_count(img) == 2


def test_as_png_crops_a_region():
    src = save("sheet.png", (4, 4), {(2, 2): (255, 0, 0, 255)})
    out = Image.open(gen.as_png(src + "#2,2,2,2")).convert("RGBA")
    assert out.size == (2, 2) and out.getpixel((0, 0)) == (255, 0, 0, 255)


def test_palette_defaults_and_override():
    assert gen.palette_of({"type": "prop"}).endswith("Sprout Lands defautlt palette.png")
    assert gen.palette_of({"type": "ui"}) == gen.palette_of({"type": "prop"})
    assert gen.palette_of({"type": "sprite"}) is None
    assert gen.palette_of({"type": "sprite", "palette": "sprout"}) is not None


def test_sprout_palette_is_extracted():
    assert len(gen.palette_colors(gen.palette_of({"type": "prop"}))) > 90  # ~99 swatches; fails if not extracted


def test_remap_keeps_every_opaque_pixel():  # a black outline must not become transparent
    if not os.path.exists(gen.ASEPRITE):
        print("  skip: Aseprite not found")
        return
    src = save("dark.png", (3, 1), {(0, 0): (0, 0, 0, 255), (1, 0): (5, 5, 5, 255), (2, 0): (250, 250, 250, 255)})
    out = os.path.join(TMP, "dark_remap.png")
    gen.remap(src, out)
    assert gen.opaque_count(out) == 3
    assert gen.off_palette(out, gen.palette_of({"type": "prop"})) == 0


def test_missing_palette_stops_clearly():  # a job pointed at a missing palette must stop cleanly, not crash deep in Aseprite/PIL
    gen.PALETTES["_missing_test"] = "no/such/palette.png"
    dest = save("nopalette.png", (1, 1), {(0, 0): (1, 2, 3, 255)})
    try:
        gen.refine(dest, {"type": "prop", "palette": "_missing_test", "colors": 0})
        raise AssertionError("expected RuntimeError for a missing palette")
    except FileNotFoundError:
        raise AssertionError("refine() must stop clearly, not raise FileNotFoundError")
    except RuntimeError as e:
        assert "no/such/palette.png" in str(e)
        assert "extract the Sprout Lands zips into asset-pipeline/sprout-lands/" in str(e)
    finally:
        del gen.PALETTES["_missing_test"]


def test_missing_ref_stops_before_any_model_call():  # the pre-check must fire before generate() is ever called
    orig_generate = gen.generate
    gen.generate = lambda *a, **kw: (_ for _ in ()).throw(AssertionError("generate() must not be called"))
    try:
        job = {"name": "no_such_ref_job", "type": "prop", "refs": ["no/such/ref.png"]}
        try:
            gen.run(job)
            raise AssertionError("expected RuntimeError for a missing ref")
        except RuntimeError as e:
            assert "no_such_ref_job" in str(e)
            assert "extract the Sprout Lands zips into asset-pipeline/sprout-lands/" in str(e)
    finally:
        gen.generate = orig_generate


def test_missing_palette_stops_before_any_model_call():  # same pre-check, for a job pointed at a missing palette
    gen.PALETTES["_missing_test2"] = "no/such/palette2.png"
    orig_generate = gen.generate
    gen.generate = lambda *a, **kw: (_ for _ in ()).throw(AssertionError("generate() must not be called"))
    try:
        job = {"name": "no_such_palette_job", "type": "prop", "palette": "_missing_test2"}
        try:
            gen.run(job)
            raise AssertionError("expected RuntimeError for a missing palette")
        except RuntimeError as e:
            assert "no/such/palette2.png" in str(e)
    finally:
        gen.generate = orig_generate
        del gen.PALETTES["_missing_test2"]


def test_step_errors_surface_what_agy_swallowed():  # agy replies "done" even when generate_image hit a 429
    conv = os.path.join(TMP, "conv")
    os.makedirs(os.path.join(conv, ".system_generated", "steps", "2"))
    with open(os.path.join(conv, ".system_generated", "steps", "2", "output.txt"), "w") as f:
        f.write("Encountered error in step execution: failed to generate content: 429 Too Many Requests, body: {\n}")
    assert "429 Too Many Requests" in gen.step_errors(conv)
    assert gen.step_errors(TMP) == ""


def test_restyle_review_checks_identity_against_the_source():
    text = gen.review_instruction("v.png", {"type": "restyle", "prompt": "a golem"}, ["src.png", "ex.png", "card.png"])
    assert "source creature" in text and '"src.png"' in text and "distinctive features" in text
    assert '"ex.png"' in text and '"card.png"' in text and "more than one creature" in text
    assert "pastel" in text and "face right" not in text  # the pastel recolour and a front-on pose are intended
    other = gen.review_instruction("v.png", {"type": "prop", "prompt": "a crate"}, ["s1.png"])
    assert "source creature" not in other and "distinctive features" not in other


def test_as_png_trims_to_opaque_bounds_with_padding():
    src = save("cell.png", (16, 16), {(5, 6): (255, 0, 0, 255), (7, 9): (0, 255, 0, 255)})
    out = Image.open(gen.as_png(src + "#0,0,16,16", trim=True)).convert("RGBA")
    assert out.size == (3 + 2 * gen.TRIM_PAD, 4 + 2 * gen.TRIM_PAD)
    assert out.getpixel((gen.TRIM_PAD, gen.TRIM_PAD)) == (255, 0, 0, 255)


def test_restyle_refs_are_source_example_and_palette_card():  # three single-subject files (agy takes at most 3)
    calls, orig = [], gen.as_png
    gen.as_png = lambda r, trim=False: calls.append((r, trim)) or r
    try:
        refs = gen.job_refs({"type": "restyle", "refs": ["a#0,0,1,1", "ignored"]})
        assert calls == [("a#0,0,1,1", True), (gen.STYLE_EXAMPLE, True)]
        assert refs[2] == gen.palette_card(gen.palette_of({"type": "restyle"})) and len(refs) == 3
        calls.clear()
        gen.job_refs({"type": "prop", "refs": ["a", "b"]})
        assert calls == [("a", False), ("b", False)]
    finally:
        gen.as_png = orig


def test_as_png_trims_a_whole_png_by_alpha():
    src = save("whole.png", (16, 16), {(5, 6): (255, 0, 0, 255), (7, 9): (0, 255, 0, 255)})
    out = Image.open(gen.as_png(src, trim=True)).convert("RGBA")
    assert out.size == (3 + 2 * gen.TRIM_PAD, 4 + 2 * gen.TRIM_PAD)


def test_palette_ramps_follow_the_sprout_layout():
    ramps = gen.palette_ramps(gen.palette_of({"type": "restyle"}))
    assert len(ramps) == 12 and all(len(r) >= 8 for r in ramps)
    assert ramps[0][0] == "713970" and ramps[0][-1] == "f3d8c5"  # first ramp, dark to light
    assert ramps[-1][0] == "353738" and ramps[-1][-1] == "f3f4e7"  # grey ramp keeps the extra light grey
    assert sum(len(r) for r in ramps) == len(gen.palette_colors(gen.palette_of({"type": "restyle"})))


def test_palette_card_has_one_row_per_ramp():
    pal = gen.palette_of({"type": "restyle"})
    card = Image.open(gen.palette_card(pal)).convert("RGB")
    assert card.height == 12 * gen.SWATCH and card.getpixel((gen.SWATCH // 2, gen.SWATCH // 2)) == (0x71, 0x39, 0x70)


def test_restyle_prompt_names_one_creature_and_the_palette():
    text = gen.job_prompt({"type": "restyle", "prompt": "a golem"})
    assert "exactly ONE creature" in text and "a golem" in text and "713970" in text and "never pure black" in text
    assert "713970" not in gen.job_prompt({"type": "prop", "prompt": "a crate"})
    assert "fix these issues: x" in gen.job_prompt({"type": "prop", "prompt": "a crate"}, "x")


def test_restyle_without_a_source_ref_stops_clearly():
    try:
        gen.check_inputs({"name": "no_src", "type": "restyle", "prompt": "a golem"})
        raise AssertionError("expected RuntimeError for a restyle job without refs")
    except RuntimeError as e:
        assert "no_src" in str(e) and "creature frame" in str(e)


def test_postprocess_keeps_the_aspect_of_a_wide_image():  # Gemini web returns 16:9 unless told otherwise
    im = Image.new("RGB", (200, 100), (255, 0, 255))
    for x in range(80, 120):
        for y in range(30, 70):
            im.putpixel((x, y), (10, 200, 30))  # a 40x40 square
    path = os.path.join(TMP, "wide.png")
    im.save(path)
    out = gen.postprocess(path, {"type": "restyle", "prompt": "x"})
    x0, y0, x1, y1 = out.getbbox()
    assert out.size == (64, 64) and abs((x1 - x0) - (y1 - y0)) <= 1  # still square, not squashed


def test_ingest_saves_the_still_and_the_raw_source():
    im = Image.new("RGB", (64, 64), (255, 0, 255))
    for x in range(20, 44):
        for y in range(20, 44):
            im.putpixel((x, y), (0x78, 0xa1, 0x58))
    src = os.path.join(TMP, "web.jpg")
    im.save(src)
    out_dir, gen.OUT = gen.OUT, TMP
    try:
        dest = gen.ingest({"name": "ingest_test", "type": "restyle", "prompt": "x"}, src)
        assert dest == os.path.join(TMP, "restyle", "ingest_test.png") and gen.opaque_count(dest) > 0
        assert os.path.exists(os.path.join(TMP, "restyle", "ingest_test.raw.jpg"))
    finally:
        gen.OUT = out_dir


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print("ok  ", name)
    shutil.rmtree(TMP)
