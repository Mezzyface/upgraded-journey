class_name EmoteFace
extends TextureRect
## A face that plays one emote from an emote sheet: a grid of `cell`-sized frames, one emote per row, each row's
## frames starting at column 0 (the pack's Teemo premium emote sheet). Frames are cut from `sheet` at runtime, so
## there is no generated resource to keep in sync. play_random() picks one of the rows with at least `min_frames`
## frames; the same seed always picks the same row.

@export var sheet: Texture2D
@export var cell := Vector2i(32, 32)
@export var fps := 6.0
@export var min_frames := 2

static var _counts := {}  ## sheet resource path -> PackedInt32Array of frames per row, measured once

var row := -1  ## the emote playing, or -1
var _frames: Array[AtlasTexture] = []
var _time := 0.0


func _ready() -> void:
	set_process(not _frames.is_empty())


## Plays a row picked by `seed_value` among those with at least `min_frames` frames.
func play_random(seed_value: int) -> void:
	var rows := emote_rows()
	if rows.is_empty():
		stop()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	play_row(rows[rng.randi() % rows.size()])


func play_row(r: int) -> void:
	_frames.clear()
	for c in frame_counts()[r]:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(Vector2(c, r) * Vector2(cell), Vector2(cell))
		_frames.append(frame)
	row = r
	_time = 0.0
	texture = _frames[0]
	set_process(_frames.size() > 1)


func stop() -> void:
	_frames.clear()
	row = -1
	texture = null
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	texture = _frames[int(_time * fps) % _frames.size()]


## The rows with at least `min_frames` frames.
func emote_rows() -> Array[int]:
	var out: Array[int] = []
	var counts := frame_counts()
	for r in counts.size():
		if counts[r] >= min_frames:
			out.append(r)
	return out


## Frames per row: cells from column 0 up to the first empty one. Measured from the sheet's pixels once per sheet.
func frame_counts() -> PackedInt32Array:
	if sheet == null:
		return PackedInt32Array()
	if _counts.has(sheet.resource_path):
		return _counts[sheet.resource_path]
	var img := sheet.get_image()
	var counts := PackedInt32Array()
	for r in floori(img.get_height() / float(cell.y)):
		var n := 0
		while n < floori(img.get_width() / float(cell.x)) \
				and img.get_region(Rect2i(Vector2i(n, r) * cell, cell)).get_used_rect().size != Vector2i.ZERO:
			n += 1
		counts.append(n)
	_counts[sheet.resource_path] = counts
	return counts
