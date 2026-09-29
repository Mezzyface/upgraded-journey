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


func _ready() -> void:
	%Hit.pressed.connect(func() -> void: clicked.emit(creature))


func setup(c: CreatureData, frames: SpriteFrames, area: SpawnArea, rng: RandomNumberGenerator,
		size_tiles := 1.0) -> void:
	creature = c
	_frames = frames
	_size_tiles = size_tiles
	_area = area
	_rng = rng
	place(area.random_point(rng))
	_wait = rng.randf_range(0.2, 2.0)
	%Sprite.sprite_frames = frames
	refresh()


## Moves the creature to `p` (inside its area) and makes it stand there.
func place(p: Vector2) -> void:
	position = p
	_target = p


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
	if position == _target:
		_play("idle")


func _physics_process(delta: float) -> void:
	if creature == null or _area == null or creature.stage == "egg":
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_target = _area.random_point(_rng)
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
