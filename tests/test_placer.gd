extends TestSuite
## Placement mode on its own: tint follows Build.can_place, Place charges, Cancel / Esc / right-click don't.

const PLACER := preload("res://shop/placer.tscn")


func _placer() -> Placer:
	Game.save_path = "user://test_placer_save.json"
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 5)
	Game.state.money = 1000
	var p: Placer = PLACER.instantiate()
	tree.root.add_child(p)
	p.size = Vector2(640, 360)
	var ground := {}
	for x in range(20, 32):
		for y in range(5, 15):
			ground[Vector2i(x, y)] = true
	p.start(&"pen", ground)
	return p


func test_the_ghost_is_green_where_it_fits_and_red_with_a_reason_where_not() -> void:
	var p := _placer()
	eq(p.move_to(Vector2(20 * 16 + 48, 5 * 16 + 40)), "", "fits")
	eq(p.cell, Vector2i(20, 5), "centred on the cursor, snapped")
	var ghost: Node2D = p.get_node("%Ghost").get_child(0)
	eq(ghost.modulate, p.ok_tint, "green")
	eq(ghost.position, Vector2(320, 80), "drawn at its cell")
	eq(p.move_to(Vector2(8, 8)), "can't build there", "off the ground")
	eq(ghost.modulate, p.bad_tint, "red")
	eq(p.get_node("%Reason").text, "can't build there", "says why")
	check(ghost.find_children("*", "TileMapLayer", true, false).all(
		func(l: TileMapLayer) -> bool: return not l.collision_enabled), "the ghost doesn't collide")
	p.queue_free()


func test_place_charges_and_cancel_does_not() -> void:
	var p := _placer()
	var built := []
	p.finished.connect(func(b: bool) -> void: built.append(b))
	p.move_to(Vector2(20 * 16 + 48, 5 * 16 + 40))
	p.pin(true)
	check(p.get_node("%Confirm").visible, "Place / Cancel shown")
	(p.get_node("%Place") as Button).pressed.emit()
	eq(built, [true], "finished built")
	eq(Game.state.money, 700, "paid 300")
	check(not p.visible, "hidden after")
	p.start(&"pen", {})
	(p.get_node("%Cancel") as Button).pressed.emit()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	p.start(&"pen", {})
	p._unhandled_input(esc)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	p.start(&"pen", {})
	p._gui_input(right)
	eq(built, [true, false, false, false], "Cancel, Esc and right-click end without building")
	eq(Game.state.money, 700, "and charge nothing")
	p.queue_free()
