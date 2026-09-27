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
	eq(card.get_node("%Stats").get_child_count(), 15, "5 rows x (label, bar, grade)")
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
