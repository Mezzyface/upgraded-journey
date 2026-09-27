class_name CreatureSprite
extends Node2D
## One creature in a pen: idles a moment, then walks to a random point in its SpawnArea, facing left or right.
## Eggs show the Egg sprite (shop/art/egg.png) until they hatch. Clicking it emits `clicked`.

signal clicked(c: CreatureData)

var creature: CreatureData
var _frames: SpriteFrames
var _area: SpawnArea
var _rng: RandomNumberGenerator
var _target := Vector2.ZERO
var _wait := 0.0
var _facing := "right"


func _ready() -> void:
	%Hit.pressed.connect(func() -> void: clicked.emit(creature))


func setup(c: CreatureData, frames: SpriteFrames, area: SpawnArea, rng: RandomNumberGenerator) -> void:
	creature = c
	_frames = frames
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


## Re-reads the creature's stage (egg, baby, adult) and scale.
func refresh() -> void:
	var egg := creature.stage == "egg"
	scale = Vector2.ONE * _area.sprite_scale * (_area.baby_scale if creature.stage == "baby" else 1.0)
	%Sprite.visible = not egg and _frames != null
	%Egg.visible = egg
	var body := CreatureAnim.body_rect(_frames)
	%Hit.position = body.position
	%Hit.size = body.size
	_play("idle")


func _process(delta: float) -> void:
	if creature == null or _area == null or creature.stage == "egg":
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_target = _area.random_point(_rng)
			_facing = "left" if _target.x < position.x else "right"
			_play("move")
		return
	position = position.move_toward(_target, _area.wander_speed * delta)
	if position.is_equal_approx(_target):
		_wait = _rng.randf_range(1.0, 3.0)
		_play("idle")


func _play(wanted: String) -> void:
	var s: AnimatedSprite2D = %Sprite
	var anim := CreatureAnim.pick(_frames, wanted, _facing)
	if anim != &"" and s.animation != anim:
		s.play(anim)
