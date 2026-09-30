extends TestSuite
## The Stable's parent slots, marks and Breed (stable_panel.tscn) and its rows (stable_row.tscn).

const SAVE := "user://test_stable_panel_save.json"


## Game on fixture content with three retired creatures: spider, spider, slime (the slime's egg group differs).
## Returns [host, panel, retired].
func _stable() -> Array:
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"], db.species[&"spider"], db.species[&"slime"]])
	setup.start_pen = db.buildables[&"pen"]
	Game.start_new(setup, db, 4)
	for c in Game.owned():
		Game.retire(c)
	var host := PanelHost.new()
	host.size = Vector2(640, 320)
	tree.root.add_child(host)
	var panel: StablePanel = load("res://shop/panels/stable_panel.tscn").instantiate()
	host.open(panel)
	panel.show_creatures(Game.retired())
	return [host, panel, Game.retired()]


func _done(host: Node) -> void:
	host.queue_free()
	DirAccess.remove_absolute(SAVE)


func test_row_shows_the_creature_and_its_rest() -> void:
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"]])
	Game.start_new(setup, db, 4)
	var spider: CreatureData = Game.owned()[0]
	var row: StableRow = load("res://shop/panels/stable_row.tscn").instantiate()
	tree.root.add_child(row)
	await tree.process_frame  # the root is busy while tests run: add_child lands next frame
	row.show_row(spider, "", false)
	eq(row.get_node("%Pick").text, Game.who(spider), "name")
	eq(row.get_node("%Note").text, "Dark · Bug", "element and egg group")
	eq(row.get_node("%Mark").text, "", "no mark")
	check(not row.get_node("%Pick").disabled, "pickable")
	spider.breed_cooldown = 2
	row.show_row(spider, "◎", true)
	eq(row.get_node("%Note").text, "rests 2 days", "resting")
	eq(row.get_node("%Mark").text, "◎", "mark shown")
	check(row.get_node("%Pick").disabled, "in a slot: not pickable")
	spider.breed_cooldown = 1
	row.show_row(spider, "", false)
	eq(row.get_node("%Note").text, "rests 1 day", "one day")
	var picked: Array = []
	var carded: Array = []
	row.picked.connect(func(c: CreatureData) -> void: picked.append(c))
	row.card_pressed.connect(func(c: CreatureData) -> void: carded.append(c))
	row.get_node("%Pick").pressed.emit()
	row.get_node("%Card").pressed.emit()
	eq(picked, [spider], "Pick emits picked")
	eq(carded, [spider], "Card emits card_pressed")
	row.queue_free()
	DirAccess.remove_absolute(SAVE)
