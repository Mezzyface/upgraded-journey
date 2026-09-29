extends TestSuite


func _area(max_shown := 12) -> SpawnArea:
	var a := SpawnArea.new()
	a.size = Vector2(400, 200)
	a.max_shown = max_shown
	tree.root.add_child(a)
	return a


func _creatures(n: int) -> Array:
	var st := GameState.new()
	for i in n:
		Fixtures.adult(st, "spider")
	return st.creatures.values()


func test_sync_spawns_inside_the_rect_up_to_max_shown() -> void:
	var a := _area(3)
	await tree.process_frame
	a.sync(_creatures(5), Fixtures.db(), Fixtures.rng())
	eq(a.sprites().size(), 3, "capped at max_shown")
	for s in a.sprites():
		check(Rect2(Vector2.ZERO, a.size).has_point(s.position), "spawned inside")
	a.queue_free()


func test_sync_keeps_existing_sprites_and_drops_leavers() -> void:
	var a := _area()
	await tree.process_frame
	var cs := _creatures(3)
	a.sync(cs, Fixtures.db(), Fixtures.rng())
	var first := a.sprites()[0]
	var where := first.position
	cs[2].status = CreatureData.Status.GONE
	a.sync(cs.slice(0, 2), Fixtures.db(), Fixtures.rng())
	eq(a.sprites().size(), 2, "the leaver is gone")
	check(a.sprites().has(first) and first.position == where, "the others stay where they were")
	a.queue_free()


func test_wandering_stays_inside() -> void:
	var a := _area()
	await tree.process_frame
	a.sync(_creatures(1), Fixtures.db(), Fixtures.rng())
	var s: CreatureSprite = a.sprites()[0]
	for i in 300:
		s._physics_process(0.1)
		check(Rect2(Vector2.ZERO, a.size).grow(0.5).has_point(s.position), "inside after step %d" % i)
	a.queue_free()


func test_babies_are_smaller_and_eggs_hide_the_sprite() -> void:
	var a := _area()
	await tree.process_frame
	var cs := _creatures(2)
	cs[0].stage = "baby"
	cs[1].stage = "egg"
	a.sync(cs, Fixtures.db(), Fixtures.rng())
	var baby: CreatureSprite = a.sprites()[0]
	eq(baby.scale, Vector2.ONE * a.baby_scale, "baby scale (no frames in the fixtures: the 16 px egg at 1 tile)")
	check(not a.sprites()[1].get_node("Sprite").visible, "eggs don't animate")
	check(a.sprites()[1].get_node("Egg").visible, "eggs show the egg sprite")
	a.queue_free()


func test_clicks_reach_the_area_signal() -> void:
	var a := _area()
	await tree.process_frame
	var cs := _creatures(1)
	a.sync(cs, Fixtures.db(), Fixtures.rng())
	var got := []
	a.creature_clicked.connect(func(c: CreatureData) -> void: got.append(c))
	a.sprites()[0].get_node("Hit").pressed.emit()
	eq(got, [cs[0]], "clicked creature forwarded")
	a.queue_free()


func test_resizing_reflows_sprites_spawned_before_layout() -> void:
	var a := SpawnArea.new()  # size 0 until its container lays it out
	tree.root.add_child(a)
	await tree.process_frame
	a.sync(_creatures(4), Fixtures.db(), Fixtures.rng())
	a.size = Vector2(400, 200)
	await tree.process_frame
	var spots := {}
	for s in a.sprites():
		check(Rect2(Vector2.ZERO, a.size).has_point(s.position), "inside after the resize")
		spots[s.position] = true
	check(spots.size() > 1, "spread out, not stacked in a corner")
	a.queue_free()


const Importer := preload("res://addons/creature_tools/pack_importer.gd")
const CREATURE_SPRITE := preload("res://shop/creature_sprite.tscn")


func _fake_frames() -> SpriteFrames:
	var tex := ImageTexture.create_from_image(Image.create(512, 512, false, Image.FORMAT_RGBA8))
	return Importer.frames_from_textures({"idle": tex, "move": tex})


func test_refresh_does_not_interrupt_a_walking_creature() -> void:
	var a := _area()
	await tree.process_frame
	var s: CreatureSprite = CREATURE_SPRITE.instantiate()
	a.add_child(s)
	s.setup(_creatures(1)[0], _fake_frames(), a, Fixtures.rng())
	s._target = s.position + Vector2(50, 0)  # mid-walk: not standing on its target
	s._facing = "right"
	s._play("move")
	var sprite: AnimatedSprite2D = s.get_node("%Sprite")
	eq(sprite.animation, &"move_right", "walking")
	s.refresh()
	eq(sprite.animation, &"move_right", "refresh left the walk animation alone")
	a.queue_free()


func test_size_tiles_scales_the_body_to_that_many_tiles() -> void:
	var a := _area()
	await tree.process_frame
	var s: CreatureSprite = CREATURE_SPRITE.instantiate()
	a.add_child(s)
	s.setup(_creatures(1)[0], _fake_frames(), a, Fixtures.rng(), 2.0)
	# a blank frame measures as DEFAULT_BODY (20 px), so 2 tiles = 32 px
	eq(s.scale, Vector2.ONE * 32.0 / 20.0, "2 tiles")
	a.queue_free()


func test_a_fence_stops_a_walker() -> void:
	var a := _area()
	await tree.process_frame
	a.sync(_creatures(1), Fixtures.db(), Fixtures.rng())
	var s: CreatureSprite = a.sprites()[0]
	s.place(Vector2(40, 100))
	var fence := StaticBody2D.new()  # layer 1, like the fence tiles
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(16, 400)
	fence.add_child(shape)
	fence.position = a.global_position + Vector2(200, 100)
	tree.root.add_child(fence)
	await tree.physics_frame
	await tree.physics_frame
	s._wait = 0.0
	s._target = Vector2(380, 100)
	for i in 300:
		s._physics_process(0.1)
		check(s.position.x < 192.0, "stayed on its side of the fence at step %d: %s" % [i, s.position])
	fence.queue_free()
	a.queue_free()


func test_no_frames_shows_the_egg_placeholder_instead_of_nothing() -> void:
	var a := _area()
	await tree.process_frame
	var s: CreatureSprite = CREATURE_SPRITE.instantiate()
	a.add_child(s)
	s.setup(_creatures(1)[0], null, a, Fixtures.rng())
	check(s.get_node("%Egg").visible, "no frames: the egg placeholder stands in")
	check(not s.get_node("%Sprite").visible, "no frames: nothing for the sprite to show")
	a.queue_free()


func test_lower_creatures_draw_in_front() -> void:
	var a := _area()
	await tree.process_frame
	a.sync(_creatures(3), Fixtures.db(), Fixtures.rng())
	var s := a.sprites()
	s[0].position.y = 50.0
	s[1].position.y = 10.0
	s[2].position.y = 30.0
	a._process(0.0)
	eq(a.sprites(), [s[1], s[2], s[0]], "reordered lowest-y first so the highest-y (lowest in the pen) draws last, on top")
	a.queue_free()


func test_panel_host_shows_one_panel_at_a_time() -> void:
	var host := PanelHost.new()
	host.size = Vector2(800, 500)
	tree.root.add_child(host)
	await tree.process_frame
	var p1 := PanelContainer.new()
	var p2 := PanelContainer.new()
	host.open(p1)
	host.open(p2)
	eq(host.current(), p2, "the newer panel")
	eq(host.get_child_count(), 1, "the older one is gone")
	host.close()
	check(host.current() == null, "closed")
	host.queue_free()
