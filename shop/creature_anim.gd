class_name CreatureAnim
extends RefCounted
## Which animation a creature plays when its pack lacks one (issue #1), so every creature always animates, and
## a close-up portrait for panels.

const FALLBACKS := {
	"move": ["move", "idle"],
	"attack": ["attack", "melee", "ability", "idle"],
	"idle": ["idle", "move"],
}
const PORTRAIT_CELL := 64  ## the centre of the 128 px cell, where the creature stands


static func pick(frames: SpriteFrames, wanted: String, facing: String) -> StringName:
	if frames == null:
		return &""
	for base in FALLBACKS.get(wanted, [wanted, "idle"]):
		var name := StringName("%s_%s" % [base, facing])
		if frames.has_animation(name):
			return name
	for name in frames.get_animation_names():  # a pack with other sheets only: same facing first
		if name.ends_with("_" + facing) and frames.get_frame_count(name) > 0:
			return StringName(name)
	for name in frames.get_animation_names():
		if frames.get_frame_count(name) > 0:
			return StringName(name)
	return &""


static func portrait(frames: SpriteFrames) -> Texture2D:
	var anim := pick(frames, "idle", "down")
	if anim == &"":
		return null
	var tex := frames.get_frame_texture(anim, 0)
	if tex is AtlasTexture:
		var src := tex as AtlasTexture
		var crop := AtlasTexture.new()
		crop.atlas = src.atlas
		crop.region = _bounded_region(src)
		return crop
	return tex


## The opaque bounding box of `src`'s frame, squared with 2px padding on every side and clamped inside the cell,
## so a small-bodied species (a spider in a 128px cell drawn with lots of headroom) reads bigger in the card than
## a fixed centre crop would. Falls back to the old centred `PORTRAIT_CELL` crop when the frame is fully
## transparent (a blank texture, as in tests, has no bounding box to hug).
static func _bounded_region(src: AtlasTexture) -> Rect2:
	var cell := src.region.size
	var used := src.get_image().get_used_rect()
	if used.size == Vector2i.ZERO:
		var inset := (cell.x - PORTRAIT_CELL) / 2.0
		return Rect2(src.region.position + Vector2(inset, inset), Vector2(PORTRAIT_CELL, PORTRAIT_CELL))
	var side := minf(maxf(used.size.x, used.size.y) + 4.0, minf(cell.x, cell.y))
	var half := side / 2.0
	var centre := Vector2(used.position) + Vector2(used.size) / 2.0
	centre.x = clampf(centre.x, half, cell.x - half)
	centre.y = clampf(centre.y, half, cell.y - half)
	return Rect2(src.region.position + centre - Vector2(half, half), Vector2(side, side))
