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
		var inset := (src.region.size.x - PORTRAIT_CELL) / 2.0
		crop.region = Rect2(src.region.position + Vector2(inset, inset), Vector2(PORTRAIT_CELL, PORTRAIT_CELL))
		return crop
	return tex
