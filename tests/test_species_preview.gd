extends TestSuite


func test_preview_shows_one_creature_and_its_card_beside_the_pen() -> void:
	var saved := [Game.db, Game.state, Game.save_path]
	var p: Control = load("res://creatures/species_preview.tscn").instantiate()
	p.species = load("res://data/species/dog.tres")
	tree.root.add_child(p)
	await tree.process_frame
	var shop := p.get_child(0)
	var pens: SpawnArea = shop.get_node("%Pens")
	eq(pens.sprites().size(), 1, "just the previewed creature")
	eq(pens.sprites()[0].creature.species, &"dog", "of that species")
	await tree.process_frame  # the card widens after its first layout pass
	var card: Control = shop.get_node("%PanelHost").current()
	check(card != null, "its card is open")
	check(not card.get_global_rect().intersects(pens.get_global_rect()), "the card doesn't cover the pen")
	eq(Game.save_path, "user://species_preview_save.json", "never the player's save")
	p.queue_free()
	Game.db = saved[0]
	Game.state = saved[1]
	Game.save_path = saved[2]
