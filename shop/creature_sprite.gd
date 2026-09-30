class_name CreatureSprite
extends CharacterBody2D
## One creature in a pen: idles a moment, then walks to a random point in its SpawnArea, facing left or right.
## It is a physics body (layer 2, mask 1): the pen's fence tiles (physics layer on layer 1) stop it, and it then
## stands where it bumped and picks another spot. Creatures don't collide with each other.
## Eggs show the Egg sprite (creatures/egg.tres, from the Sprout Lands egg sheet) until they hatch. Clicking it emits `clicked`.

signal clicked(c: CreatureData)

const FEET := 0.3  ## collision circle radius, as a share of the body's shorter side

var creature: CreatureData
var _frames: SpriteFrames
var _size_tiles := 1.0
var _area: SpawnArea
var _rng: RandomNumberGenerator
var _target := Vector2.ZERO
var _wait := 0.0
var _facing := "right"
var _body := Rect2()  ## the drawn body around the origin, scaled (set by refresh)


func _ready() -> void:
	%Hit.pressed.connect(func() -> void: clicked.emit(creature))


func setup(c: CreatureData, frames: SpriteFrames, area: SpawnArea, rng: RandomNumberGenerator,
		size_tiles := 1.0) -> void:
	creature = c
	_frames = frames
	_size_tiles = size_tiles
	_area = area
	_rng = rng
	_wait = rng.randf_range(0.2, 2.0)
	%Sprite.sprite_frames = frames
	refresh()
	place(random_spot())  # after refresh: the spot depends on the body size


## Moves the creature to `p` (inside its area) and makes it stand there.
func place(p: Vector2) -> void:
	position = _inside(p)
	_target = position


## Re-reads the creature's stage (egg, baby, adult) and size. Leaves a creature that's mid-walk alone — only
## a standing creature (position == _target) is put back to idle — and falls back to the Egg placeholder
## (sized like the creature) for a species with no usable frames. Eggs are always one tile.
## ponytail: sized from the first idle frame; a species whose frames vary a lot in size would need a max over frames.
func refresh() -> void:
	var egg := creature.stage == "egg"
	var has_frames := _frames != null and CreatureAnim.pick(_frames, "idle", _facing) != &""
	%Sprite.visible = not egg and has_frames
	%Egg.visible = egg or not has_frames
	var body := CreatureAnim.body_rect(_frames)
	if %Egg.visible:
		var egg_px: Vector2 = %Egg.texture.get_size()
		body = Rect2(-egg_px / 2.0, egg_px)
		scale = Vector2.ONE * (1.0 if egg else _size_tiles) * CreatureAnim.TILE / maxf(egg_px.x, egg_px.y)
	else:
		scale = Vector2.ONE * CreatureAnim.pen_scale(_frames, _size_tiles)
	if creature.stage == "baby":
		scale *= _area.baby_scale
	%Hit.position = body.position
	%Hit.size = body.size
	var feet: CircleShape2D = %Feet.shape
	feet.radius = minf(body.size.x, body.size.y) * FEET
	%Feet.position = Vector2(body.get_center().x, body.end.y - feet.radius)
	_body = Rect2(body.position * scale, body.size * scale)
	var standing := position == _target
	position = _inside(position)  # a new size may reach past the pen's edge: step back in
	_target = position if standing else _inside(_target)
	if standing:
		_play("idle")


## A random spot where the whole body fits inside the area, chosen evenly (clamping random points instead would pile
## creatures up against the walls). Vector2.ZERO while the area has no size: SpawnArea re-places those on resize.
func random_spot() -> Vector2:
	if _area == null or _area.size == Vector2.ZERO:
		return Vector2.ZERO
	var lo := -_body.position
	var hi := _area.size - _body.end
	return Vector2(_rng.randf_range(lo.x, maxf(lo.x, hi.x)), _rng.randf_range(lo.y, maxf(lo.y, hi.y)))


## `p` moved just enough that the whole body (not only the origin, which sits above the feet) is inside the area.
func _inside(p: Vector2) -> Vector2:
	if _area == null or _area.size == Vector2.ZERO:
		return p  # not laid out yet: SpawnArea re-places its creatures when it gets a size
	var lo := -_body.position
	var hi := _area.size - _body.end
	return Vector2(clampf(p.x, lo.x, maxf(lo.x, hi.x)), clampf(p.y, lo.y, maxf(lo.y, hi.y)))


func _physics_process(delta: float) -> void:
	if creature == null or _area == null or creature.stage == "egg":
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_target = random_spot()
			_facing = "left" if _target.x < position.x else "right"
			_play("move")
		return
	if move_and_collide(position.move_toward(_target, _area.wander_speed * delta) - position):
		_target = position  # bumped a fence: stand here, then pick another spot
	if position.is_equal_approx(_target):
		position = _target
		_wait = _rng.randf_range(1.0, 3.0)
		_play("idle")


func _play(wanted: String) -> void:
	var s: AnimatedSprite2D = %Sprite
	var anim := CreatureAnim.pick(_frames, wanted, _facing)
	if anim != &"" and s.animation != anim:
		s.play(anim)
