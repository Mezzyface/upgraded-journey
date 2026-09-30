extends TestSuite
## The Expedition panel (expedition_panel.tscn): locations, challenges, finds, team slots and Send.

const SAVE := "user://test_expedition_panel_save.json"


## Fixture content, no starters: dark = Spider Albino (Darksight, guard D: passes the cave's first challenge),
## tough = Spider with guard C (passes the second), hurt = an injured Spider, and an egg that must not be listed.
## Returns [host, panel, dark, tough, hurt]; await it.
func _panel() -> Array:
	await tree.process_frame
	Game.save_path = SAVE
	var db := Fixtures.db()
	db.locations[&"mine"].display_name = "Mine"
	var abyss := Location.new()  # a third location, so button order is really by id
	abyss.id = &"abyss"
	abyss.display_name = "Abyss"
	db.add(abyss)
	var setup := NewGameSetup.new()
	setup.start_pen = db.buildables[&"pen"]
	Game.start_new(setup, db, 7)
	var dark := Fixtures.adult(Game.state, "spider_albino", 100)
	var tough := Fixtures.adult(Game.state, "spider", 300)
	var hurt := Fixtures.adult(Game.state, "spider", 300)
	hurt.injured_days = 2
	Fixtures.adult(Game.state, "slime").stage = "egg"
	var host := PanelHost.new()
	host.size = Vector2(640, 320)
	tree.root.add_child(host)
	var panel: ExpeditionPanel = load("res://shop/panels/expedition_panel.tscn").instantiate()
	host.open(panel)
	await tree.process_frame
	return [host, panel, dark, tough, hurt]


func _done(host: Node) -> void:
	host.queue_free()
	DirAccess.remove_absolute(SAVE)


func _texts(parent: Node) -> Array:
	return parent.get_children().map(func(b: Button) -> String: return b.text)


func _row(panel: ExpeditionPanel, c: CreatureData) -> CreatureRow:
	for row: CreatureRow in panel.get_node("%List").get_children():
		if row.creature == c:
			return row
	return null


func test_locations_challenges_and_finds() -> void:
	var parts: Array = await _panel()
	var panel: ExpeditionPanel = parts[1]
	eq(_texts(panel.get_node("%Places")), ["Abyss", "Cave", "Mine"], "a button per location, sorted by id")
	eq(panel.place, &"abyss", "the first is chosen")
	panel.choose(&"cave")
	var cave: Location = Game.db.locations[&"cave"]
	eq(panel.get_node("%Needs").get_child_count(), 2, "a line per challenge")
	var line: Label = panel.get_node("%Needs").get_child(0)
	eq(line.text, "• " + cave.challenges[0].describe(), "its text")
	eq(_color(line), line.get_theme_color("font_color", "Label"), "neutral colour without a team")
	eq(panel.get_node("%Finds").text, "Finds: Spider Albino, Spider eggs · 10–20 gold", "eggs and gold")
	panel.choose(&"mine")
	eq(panel.get_node("%Needs").get_child_count(), 0, "the mine has no challenges")
	eq(panel.get_node("%Finds").text, "Finds: 10–40 gold", "gold only without loot")
	panel.pick(parts[2])
	eq(_texts(panel.get_node("%Places")), ["Abyss 0/0", "Cave 1/2", "Mine 0/0"], "totals for the team")
	check(not panel.get_node("%Send").disabled, "a location without challenges can still be sent to")
	_done(parts[0])


func test_picking_fills_slots_and_totals_update() -> void:
	var parts: Array = await _panel()
	var panel: ExpeditionPanel = parts[1]
	var dark: CreatureData = parts[2]
	var tough: CreatureData = parts[3]
	var hurt: CreatureData = parts[4]
	panel.choose(&"cave")
	eq(panel.get_node("%List").get_child_count(), 3, "every owned non-egg creature")
	eq(panel.get_node("%Slot1").text, ExpeditionPanel.EMPTY_SLOT, "empty slot")
	check(panel.get_node("%Send").disabled, "no team, no Send")
	check(not panel.get_node("%Reason").visible, "no reason without a team")
	eq(_row(panel, tough).get_node("%Mark").text, "1/2", "a row's mark: challenges it meets alone")
	check(_row(panel, hurt).get_node("%Pick").disabled, "injured: disabled")
	eq(_row(panel, hurt).get_node("%Note").text, "injured for 2 more days", "and says why")
	panel.pick(dark)
	eq(panel.get_node("%Slot1").text, "#%d" % dark.id, "slot 1 filled: portrait and number")
	eq(panel.get_node("%Slot1").tooltip_text, Game.who(dark), "full name on hover")
	check(_row(panel, dark).get_node("%Pick").disabled, "a slotted creature can't be picked twice")
	var need: Label = panel.get_node("%Needs").get_child(1)
	eq(_color(need), panel.missing_color, "guard challenge missing with only dark")
	panel.pick(tough)
	eq(_texts(panel.get_node("%Places"))[1], "Cave 2/2", "both challenges with both")
	need = panel.get_node("%Needs").get_child(1)
	eq(_color(need), panel.met_color, "guard challenge met with tough")
	panel.pick(hurt)
	eq(panel.team[2], null, "an injured creature can't be picked")
	panel.get_node("%Slot1").pressed.emit()
	eq(panel.team[0], null, "pressing a filled slot empties it")
	eq(panel.members(), [tough] as Array[CreatureData], "members skips empty slots")
	_done(parts[0])


func _color(line: Label) -> Color:
	return line.get_theme_color("font_color")


func test_send_costs_ap_clears_slots_and_lists_it() -> void:
	var parts: Array = await _panel()
	var panel: ExpeditionPanel = parts[1]
	var dark: CreatureData = parts[2]
	var tough: CreatureData = parts[3]
	panel.choose(&"cave")
	var sent: Array = []
	panel.sent.connect(func(l: Location) -> void: sent.append(l.id))
	check(not panel.get_node("%Out").visible, "nothing out yet")
	panel.pick(dark)
	panel.pick(tough)
	var ap := Game.state.ap
	panel.get_node("%Send").pressed.emit()
	eq(Game.state.ap, ap - Day.COST_EXPEDITION, "2 AP")
	eq(sent, [&"cave"], "sent emitted")
	check(panel.members().is_empty(), "slots cleared")
	eq(panel.get_node("%Out").text, "Out today: Cave (%s, %s)" % [Game.who(dark), Game.who(tough)], "listed")
	check(panel.get_node("%Out").visible, "shown")
	eq(_row(panel, dark).get_node("%Note").text, "busy on an expedition today", "away now")
	panel.get_node("%Send").pressed.emit()  # a second click with the slots empty
	eq(Game.state.ap, ap - Day.COST_EXPEDITION, "nothing more spent")
	_done(parts[0])


func test_send_state_follows_game_changes() -> void:
	var parts: Array = await _panel()
	var panel: ExpeditionPanel = parts[1]
	panel.pick(parts[3])
	check(not panel.get_node("%Send").disabled, "can send")
	Game.state.ap = 0
	Game.changed.emit()
	check(panel.get_node("%Send").disabled, "AP gone: Send disabled")
	eq(panel.get_node("%Reason").text, "Not enough action points", "and says why")
	check(panel.get_node("%Reason").visible, "shown")
	eq(panel.team[0], parts[3], "the team is kept")
	_done(parts[0])


func test_card_button_emits_creature_chosen() -> void:
	var parts: Array = await _panel()
	var panel: ExpeditionPanel = parts[1]
	var chosen: Array = []
	panel.creature_chosen.connect(func(c: CreatureData) -> void: chosen.append(c))
	_row(panel, parts[3]).get_node("%Card").pressed.emit()
	eq(chosen, [parts[3]], "Card opens that creature")
	_done(parts[0])
