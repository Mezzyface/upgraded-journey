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
		s._process(0.1)
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
	eq(baby.scale, Vector2.ONE * a.sprite_scale * a.baby_scale, "baby scale")
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
