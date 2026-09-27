extends TestSuite

const SAVE := "user://test_orders_save.json"


func _panel() -> Array:  # [host, panel]
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"], db.species[&"slime"]])
	Game.start_new(setup, db, 2)  # both tier-0 templates are on the board
	var host := PanelHost.new()
	host.size = Vector2(900, 620)
	tree.root.add_child(host)
	var panel: Control = load("res://shop/panels/orders_panel.tscn").instantiate()
	host.open(panel)
	return [host, panel]


func _buttons(root: Node, text: String) -> Array:
	return root.find_children("*", "BaseButton", true, false).filter(func(b: BaseButton) -> bool: return b.text == text)


func test_offers_can_be_accepted() -> void:
	var parts := _panel()
	await tree.process_frame
	var panel: Control = parts[1]
	eq(_buttons(panel, "Accept").size(), 2, "two offers")
	_buttons(panel, "Accept")[0].pressed.emit()
	await tree.process_frame
	eq(Game.state.orders.size(), 1, "accepted")
	eq(_buttons(panel, "Accept").size(), 1, "one offer left")
	check(panel.get_node("%Slots").text.contains("1"), "slots updated")
	parts[0].queue_free()


func test_deliver_menu_lists_eligible_creatures_and_pays() -> void:
	var parts := _panel()
	await tree.process_frame
	var panel: Control = parts[1]
	Game.accept(&"t0_slime")
	await tree.process_frame
	var deliver: MenuButton = _buttons(panel, "Deliver…")[0]
	var menu := deliver.get_popup()
	eq(menu.item_count, 1, "only the slime qualifies")
	var money := Game.state.money
	menu.id_pressed.emit(menu.get_item_id(0))
	eq(Game.state.money, money + 80, "paid")
	eq(Game.state.orders.size(), 0, "order closed")
	parts[0].queue_free()
	DirAccess.remove_absolute(SAVE)


func test_day_summary_lists_and_highlights_events() -> void:
	var summary: Control = load("res://shop/panels/day_summary.tscn").instantiate()
	tree.root.add_child(summary)
	await tree.process_frame
	summary.show_events(3, PackedStringArray(["Slime #2 hatched", "Missed Pip's order (-3 reputation)"]))
	check(summary.get_node("%Title").text.contains("3"), "title names the day")
	var lines: Array = summary.get_node("%Events").get_children()
	eq(lines.size(), 2, "one line per event")
	check(lines[1].has_theme_color_override("font_color"), "missed order highlighted")
	check(not lines[0].has_theme_color_override("font_color"), "normal line plain")
	summary.queue_free()
