extends TestSuite
## The ranch map under the shop: grass everywhere on screen, fences around the pen and stable yard, and map pieces
## that never take a click.

const SAVE := "user://test_ranch_map_save.json"


func _shop() -> Control:
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)
	var shop: Control = load("res://shop/shop.tscn").instantiate()
	tree.root.add_child(shop)
	return shop


func test_grass_covers_the_screen() -> void:
	var shop := _shop()
	await tree.process_frame
	var ground: TileMapLayer = shop.get_node("Ranch/Ground")
	var bare := 0
	for y in 23:
		for x in 40:
			if ground.get_cell_source_id(Vector2i(x, y)) != 0:
				bare += 1
	eq(bare, 0, "on-screen cells without grass")
	_done(shop)


func test_fences_ring_the_pen_and_the_stable_yard() -> void:
	var shop := _shop()
	await tree.process_frame
	var fences: TileMapLayer = shop.get_node("Ranch/Fences")
	for cell in [Vector2i(1, 12), Vector2i(16, 20), Vector2i(1, 20), Vector2i(24, 13), Vector2i(35, 20)]:
		eq(fences.get_cell_source_id(cell), 2, "fence at %s" % cell)
	for gate in [Vector2i(9, 12), Vector2i(29, 13)]:
		eq(fences.get_cell_source_id(gate), -1, "gate gap at %s" % gate)
	_done(shop)


func test_map_pieces_ignore_the_mouse() -> void:
	var shop := _shop()
	await tree.process_frame
	var stack: Array[Node] = [shop.get_node("Ranch")]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			eq(n.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % n.name)
		stack.append_array(n.get_children())
	eq(shop.get_child(0).name, "Ranch", "the map draws first, under everything")
	_done(shop)


func _done(shop: Control) -> void:
	shop.queue_free()
	DirAccess.remove_absolute(SAVE)
