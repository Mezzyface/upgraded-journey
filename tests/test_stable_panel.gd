extends TestSuite
## The Stable's parent slots, marks and Breed (stable_panel.tscn) and its rows (creature_row.tscn).

const SAVE := "user://test_stable_panel_save.json"


## Game on fixture content with three retired creatures: spider, spider, slime (the slime's egg group differs).
## Returns [host, panel, retired]; await it. The first frame lets earlier tests' queued frees land, so no leftover
## card is still listening to Game.changed when start_new swaps in the fixture content.
func _stable() -> Array:
	await tree.process_frame
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
	await tree.process_frame  # earlier tests' queued frees land first (see _stable)
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"]])
	Game.start_new(setup, db, 4)
	var spider: CreatureData = Game.owned()[0]
	var row: CreatureRow = load("res://shop/panels/creature_row.tscn").instantiate()
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


func test_picking_fills_slots_and_shows_the_mark() -> void:
	var parts: Array = await _stable()
	await tree.process_frame
	var panel: StablePanel = parts[1]
	var r: Array = parts[2]
	eq(panel.get_node("%SlotA").text, StablePanel.EMPTY_SLOT, "empty slot")
	check(panel.get_node("%Breed").disabled, "no pair, no Breed")
	panel.pick(r[0])
	eq(panel.get_node("%SlotA").text, Game.who(r[0]), "A filled")
	var rows: Array = panel.get_node("%List").get_children()
	check(rows[0].get_node("%Pick").disabled, "a slotted creature can't be picked again")
	eq(rows[0].get_node("%Mark").text, "", "no mark against itself")
	eq(rows[1].get_node("%Mark").text, Game.compat_mark(r[0], r[1]), "rows show their mark against A")
	panel.pick(r[0])
	eq(panel.slots[1], null, "picking the same creature again is ignored")
	panel.pick(r[1])
	eq(panel.get_node("%Mark").text, Game.compat_mark(r[0], r[1]), "pair mark")
	check(not panel.get_node("%Breed").disabled, "a valid pair can breed")
	eq(panel.get_node("%Reason").text, "", "no reason")
	panel.get_node("%SlotB").pressed.emit()
	eq(panel.slots[1], null, "pressing a filled slot empties it")
	eq(panel.get_node("%Mark").text, "", "no pair, no mark")
	panel.pick(r[2])
	eq(panel.get_node("%Reason").text, "Their egg groups differ", "the refusal reason, capitalised")
	check(panel.get_node("%Breed").disabled, "no Breed for a refused pair")
	panel.pick(r[1])
	eq(panel.slots[1], r[2], "a full pair ignores more picks")
	_done(parts[0])


func test_breed_lays_an_egg_and_clears_the_slots() -> void:
	var parts: Array = await _stable()
	await tree.process_frame
	var panel: StablePanel = parts[1]
	var r: Array = parts[2]
	var bred := [0]
	panel.bred.connect(func() -> void: bred[0] += 1)
	var n := Game.state.creatures.size()
	panel.pick(r[0])
	panel.pick(r[1])
	panel.get_node("%Breed").pressed.emit()
	eq(Game.state.creatures.size(), n + 1, "an egg")
	eq(bred[0], 1, "bred emitted")
	eq(panel.slots[0], null, "slot A cleared")
	eq(panel.slots[1], null, "slot B cleared")
	eq(panel.get_node("%List").get_child(0).get_node("%Note").text, "rests %d days" % Inheritance.COOLDOWN_DAYS,
		"the list shows the rest")
	panel.get_node("%Breed").pressed.emit()  # a double click
	eq(Game.state.creatures.size(), n + 1, "no second egg")
	eq(panel.get_node("%Reason").text, "", "no 'No such creature'")
	_done(parts[0])


func test_breed_state_follows_game_changes() -> void:
	var parts: Array = await _stable()
	await tree.process_frame
	var panel: StablePanel = parts[1]
	var r: Array = parts[2]
	panel.pick(r[0])
	panel.pick(r[1])
	check(not panel.get_node("%Breed").disabled, "can breed")
	Game.state.ap = 0
	Game.changed.emit()
	check(panel.get_node("%Breed").disabled, "AP gone: Breed disabled")
	eq(panel.get_node("%Reason").text, "Not enough action points", "and says why")
	eq(panel.slots[0], r[0], "the pair is kept")
	_done(parts[0])


func test_a_slot_drops_a_creature_that_left_the_stable() -> void:
	var parts: Array = await _stable()
	await tree.process_frame
	var panel: StablePanel = parts[1]
	var r: Array = parts[2]
	panel.pick(r[0])
	panel.pick(r[1])
	panel.show_creatures([r[1], r[2]])
	eq(panel.slots[0], null, "A emptied")
	eq(panel.slots[1], r[1], "B kept")
	eq(panel.get_node("%SlotA").text, StablePanel.EMPTY_SLOT, "A shows empty")
	_done(parts[0])


func test_card_button_emits_creature_chosen() -> void:
	var parts: Array = await _stable()
	await tree.process_frame
	var panel: StablePanel = parts[1]
	var chosen: Array = []
	panel.creature_chosen.connect(func(c: CreatureData) -> void: chosen.append(c))
	panel.get_node("%List").get_child(1).get_node("%Card").pressed.emit()
	eq(chosen, [parts[2][1]], "Card opens that creature")
	_done(parts[0])


func test_the_list_shows_at_least_four_rows() -> void:
	var parts: Array = await _stable()
	await tree.process_frame
	await tree.process_frame  # PanelHost fits the panel after its first layout
	var panel: StablePanel = parts[1]
	check(not panel.get_node("%Reason").visible, "an empty reason takes no line")
	var row: Control = panel.get_node("%List").get_child(0)
	var scroll: Control = panel.get_node("Margin/Rows/Page/Scroll")
	check(scroll.size.y >= 4 * row.size.y, "list %.0f px tall, rows %.0f px" % [scroll.size.y, row.size.y])
	panel.pick(parts[2][0])
	panel.pick(parts[2][2])
	check(panel.get_node("%Reason").visible, "a refusal shows its line")
	_done(parts[0])


func test_blocked_row_is_disabled_and_says_why() -> void:
	await tree.process_frame
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"]])
	Game.start_new(setup, db, 4)
	var spider: CreatureData = Game.owned()[0]
	var row: CreatureRow = load("res://shop/panels/creature_row.tscn").instantiate()
	tree.root.add_child(row)
	await tree.process_frame
	row.show_row(spider, "1/2", false, "busy on an expedition today")
	check(row.get_node("%Pick").disabled, "blocked: not pickable")
	eq(row.get_node("%Note").text, "busy on an expedition today", "says why")
	eq(row.get_node("%Note").tooltip_text, "busy on an expedition today", "full text on hover")
	eq(row.get_node("%Note").text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "long notes clip with …")
	row.show_row(spider, "", false)
	check(not row.get_node("%Pick").disabled, "not blocked: pickable again")
	eq(row.get_node("%Note").text, "Dark · Bug", "back to element and egg group")
	row.queue_free()
	DirAccess.remove_absolute(SAVE)


func test_row_leaves_room_for_the_portrait() -> void:
	await tree.process_frame
	var row: CreatureRow = load("res://shop/panels/creature_row.tscn").instantiate()
	tree.root.add_child(row)
	await tree.process_frame
	var pick: Button = row.get_node("%Pick")
	pick.icon = null
	var bare := pick.get_minimum_size().x
	pick.icon = load("res://creatures/egg.tres")  # any portrait-sized texture
	var with_icon := pick.get_minimum_size().x
	check(with_icon - bare >= 20, "the portrait reserves %.0f px, not what's left over" % (with_icon - bare))
	row.queue_free()
