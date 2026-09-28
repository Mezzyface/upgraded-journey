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


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print("ok  ", name)
    shutil.rmtree(TMP)
