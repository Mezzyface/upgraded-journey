extends TestSuite

const SAVE := "user://test_card_save.json"


func _card() -> Array:  # [host, card, creature]
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"], db.species[&"slime"]])
	Game.start_new(setup, db, 2)
	var host := PanelHost.new()
	host.size = Vector2(900, 620)
	tree.root.add_child(host)
	var card: Control = load("res://shop/panels/creature_card.tscn").instantiate()
	host.open(card)
	var c: CreatureData = Game.owned()[0]
	card.show_creature(c)
	return [host, card, c]


func test_card_shows_the_creature() -> void:
	var parts := _card()
	await tree.process_frame
	var card: Control = parts[1]
	var c: CreatureData = parts[2]
	check(card.get_node("%Name").text.contains("#%d" % c.id), "name and id")
	eq(card.get_node("%Stats").get_child_count(), 5, "five stat boxes")
	var power: StatBox = card.get_node("%Stats/Power")
	eq(power.get_node("%Grade").text, Stats.grade_name(c.stats["power"]), "grade letter")
	eq(power.get_node("%Value").text, str(c.stats["power"]), "value")
	var colours := {}
	for box: StatBox in card.get_node("%Stats").get_children():
		var grade: Label = box.get_node("%Grade")
		var shown: Color = grade.label_settings.font_color if grade.label_settings else grade.get_theme_color("font_color")
		eq(shown, box.grade_colors[Stats.grade(c.stats[box.stat])], "%s letter in its grade's colour" % box.stat)
		colours[grade.label_settings] = true
	check(colours.has(null) or colours.size() == 5, "each box has its own Label Settings")
	eq(card.get_node("%RankText").text, Stats.rank_name(c.stats), "rank badge")
	eq(card.get_node("%Score").text.replace(",", ""), str(Stats.score(c.stats)), "score")
	check(card.get_node("%Epithet").text.begins_with("["), "personality as the epithet")
	check(card.get_node("%Sell").text.contains(str(Game.sell_price(c))), "sell price on the button")
	parts[0].queue_free()


func test_actions_go_through_game_and_refusals_show_a_reason() -> void:
	var parts := _card()
	await tree.process_frame
	var card: Control = parts[1]
	var c: CreatureData = parts[2]
	var mood := c.mood
	card.get_node("%Play").pressed.emit()
	eq(c.mood, mood + Day.PLAY_MOOD, "played")
	eq(card.get_node("%Message").text, "", "no message on success")
	Game.state.ap = 0
	card.get_node("%Feed").pressed.emit()
	eq(card.get_node("%Message").text, "Not enough action points", "reason shown")
	parts[0].queue_free()


func test_card_closes_when_the_creature_leaves() -> void:
	var parts := _card()
	await tree.process_frame
	var host: PanelHost = parts[0]
	parts[1].get_node("%Sell").pressed.emit()  # arms the button
	parts[1].get_node("%Sell").pressed.emit()  # confirms
	await tree.process_frame
	check(host.current() == null, "sold: the card closed")
	host.queue_free()
	DirAccess.remove_absolute(SAVE)


func test_sell_needs_a_second_press_to_act() -> void:
	var parts := _card()
	await tree.process_frame
	var card: Control = parts[1]
	var c: CreatureData = parts[2]
	card.get_node("%Sell").pressed.emit()
	eq(c.status, CreatureData.Status.OWNED, "the first press only arms the button")
	check(card.get_node("%Sell").text.begins_with("Sure?"), "armed: %s" % card.get_node("%Sell").text)
	card.get_node("%Sell").pressed.emit()
	eq(c.status, CreatureData.Status.GONE, "the second press, while armed, sells")
	parts[0].queue_free()


func test_an_eggs_portrait_is_the_egg_texture() -> void:
	var parts := _card()
	await tree.process_frame
	var card: Control = parts[1]
	var c: CreatureData = parts[2]
	c.stage = "egg"
	card.show_creature(c)
	eq(card.get_node("%Portrait").texture, load("res://creatures/egg.tres"),
			"an egg shows the egg texture, not the species portrait")
	parts[0].queue_free()


func test_another_action_disarms_the_sell_button() -> void:
	var parts := _card()
	await tree.process_frame
	var card: Control = parts[1]
	var c: CreatureData = parts[2]
	card.get_node("%Sell").pressed.emit()
	check(card.get_node("%Sell").text.begins_with("Sure?"), "armed")
	card.get_node("%Play").pressed.emit()
	check(not card.get_node("%Sell").text.begins_with("Sure?"), "Play in between resets Sell")
	eq(c.status, CreatureData.Status.OWNED, "not sold")
	parts[0].queue_free()


func test_tabs_hold_traits_and_moves_then_sparks() -> void:
	var parts := _card()
	await tree.process_frame
	var card: Control = parts[1]
	var c: CreatureData = parts[2]
	var tabs: TabContainer = card.get_node("%Tabs")
	eq(tabs.get_tab_count(), 2, "Traits & Moves and Sparks")
	eq(tabs.get_tab_title(0), "Traits & Moves", "first title")
	eq(tabs.get_tab_title(1), "Sparks", "second title")
	eq(tabs.current_tab, 0, "opens on Traits & Moves")
	eq(card.get_node("%Chips").get_child_count(), c.all_traits(Game.db).size() + c.moves.size(), "a chip per trait and move")
	parts[0].queue_free()


func _texts(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func test_sparks_tab_shows_own_parents_and_hidden_grandparents() -> void:
	var parts := _card()
	await tree.process_frame
	var card: Control = parts[1]
	var gp := Fixtures.adult(Game.state, "spider")
	var p := Fixtures.adult(Game.state, "spider")
	p.parents = PackedInt32Array([gp.id])
	eq(Game.retire(gp), "", "retire the grandparent")
	eq(Game.retire(p), "", "retire the parent")
	var child := Fixtures.adult(Game.state, "spider")
	child.parents = PackedInt32Array([p.id])
	card.show_creature(child)
	var texts := _texts(card.get_node("%SparkRows"))
	eq(texts[0], Game.who(p), "parent header first")
	check(texts.has(Game.who(gp)), "grandparent header")
	var stat: Dictionary = p.sparks[0]  # Sparks.roll puts the stat spark first
	var shown := "%s %s" % [String(stat["id"]).capitalize(), "★".repeat(stat["stars"])]
	check(texts.has(shown), "parent's stat spark '%s' in %s" % [shown, texts])
	var hidden := texts.filter(func(t: String) -> bool: return t.begins_with("? ★"))
	eq(hidden.size(), gp.sparks.size(), "every grandparent spark hidden")
	Game.state.upgrades.append(&"gene_scanner")
	card.show_creature(child)
	eq(_texts(card.get_node("%SparkRows")).filter(func(t: String) -> bool: return t.begins_with("? ★")).size(), 0,
		"the Gene Scanner reveals them")
	card.show_creature(p)
	eq(_texts(card.get_node("%SparkRows"))[0], "Own", "a retired creature's own sparks come first")
	card.show_creature(parts[2])  # a starter: no parents, not retired
	eq(_texts(card.get_node("%SparkRows")), ["No sparks yet — retire it to lock its sparks"], "empty text")
	parts[0].queue_free()
	DirAccess.remove_absolute(SAVE)
