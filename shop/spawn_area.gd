@tool
class_name SpawnArea
extends Control
## Where creatures appear and pick spots to walk to (the pen's fence tiles are what stop them). In the editor it draws
## its outline and `preview_count` ghost creatures from `preview_frames` at one tile (Species.size_tiles = 1), so
## size and spacing are tuned right here; at runtime sync() spawns one CreatureSprite per creature inside this rect.

signal creature_clicked(c: CreatureData)

const CREATURE_SPRITE := preload("res://shop/creature_sprite.tscn")
const OUTLINE := Color(1, 1, 1, 0.7)
const GHOST := Color(1, 1, 1, 0.45)

@export var preview_frames: SpriteFrames:
	set(v):
		preview_frames = v
		queue_redraw()
@export_range(0, 12) var preview_count := 4:
	set(v):
		preview_count = v
		queue_redraw()
@export_range(0.2, 1.0, 0.05) var baby_scale := 0.7
@export_range(1, 40) var max_shown := 12
@export var wander_speed := 30.0  ## pixels per second

var _rng: RandomNumberGenerator


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Control has no `y_sort_enabled` (that's a Node2D/CanvasItem-only property that doesn't reach a Control
## parent), so a lower creature is kept drawn in front of a higher one here instead: reorder the CreatureSprite
## children by y every frame (cheap at `max_shown`-many creatures) so the later sibling — drawn last, on top —
## is always the one standing lower in the pen.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var kids := sprites()
	kids.sort_custom(func(a: CreatureSprite, b: CreatureSprite) -> bool: return a.position.y < b.position.y)
	for i in kids.size():
		move_child(kids[i], i)


## Containers size this area after the first layout pass, so sprites synced earlier (all at 0, 0) or left outside
## by a resize are re-placed inside.
func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED or Engine.is_editor_hint() or _rng == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	for s in sprites():
		if s.position == Vector2.ZERO or not r.has_point(s.position):
			s.place(random_point(_rng))


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(Vector2.ZERO, size)
	for edge in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		draw_dashed_line(edge[0], edge[1], OUTLINE, 2.0, 8.0)
	var anim := CreatureAnim.pick(preview_frames, "idle", "down")
	if anim == &"":
		return
	var tex := preview_frames.get_frame_texture(anim, 0)
	var cell := tex.get_size() * CreatureAnim.pen_scale(preview_frames, 1.0)
	for i in preview_count:
		var centre := Vector2(size.x * (i + 1) / (preview_count + 1), size.y * 0.5)
		draw_texture_rect(tex, Rect2(centre - cell / 2.0, cell), false, GHOST)


func sprites() -> Array[CreatureSprite]:
	var out: Array[CreatureSprite] = []
	for child in get_children():
		if child is CreatureSprite and not child.is_queued_for_deletion():
			out.append(child)
	return out


## Shows exactly `creatures` (up to max_shown): keeps the sprites of creatures still here where they are, removes
## the others, adds new ones at random points, and refreshes stage-dependent looks.
func sync(creatures: Array, db: Db, rng: RandomNumberGenerator) -> void:
	_rng = rng
	var wanted := creatures.slice(0, max_shown)
	for s in sprites():
		if not wanted.has(s.creature):
			remove_child(s)
			s.queue_free()
	var shown := sprites().map(func(s: CreatureSprite) -> CreatureData: return s.creature)
	for c: CreatureData in wanted:
		if shown.has(c):
			continue
		var s: CreatureSprite = CREATURE_SPRITE.instantiate()
		add_child(s)
		var sp: Species = db.species.get(c.species)
		s.setup(c, sp.sprite_frames if sp else null, self, rng, sp.size_tiles if sp else 1.0)
		s.clicked.connect(func(clicked: CreatureData) -> void: creature_clicked.emit(clicked))
	for s in sprites():
		s.refresh()


func random_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y))
