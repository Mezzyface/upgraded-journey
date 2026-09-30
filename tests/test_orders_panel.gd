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


func _notes(panel: Control) -> Array:
	return panel.get_node("%Accepted").get_children() + panel.get_node("%Offers").get_children()


func test_accepted_and_new_requests_are_separate_sections() -> void:
	var parts := _panel()
	await tree.process_frame
	var panel: Control = parts[1]
	eq(panel.get_node("%Offers").get_child_count(), 2, "two new requests")
	check(not panel.get_node("%AcceptedTitle").visible and not panel.get_node("%Accepted").visible,
		"no Accepted section while nothing is accepted")
	Game.accept(&"t0_slime")
	await tree.process_frame
	eq(panel.get_node("%Accepted").get_child_count(), 1, "the accepted order moved to Accepted")
	eq(panel.get_node("%Offers").get_child_count(), 1, "one new request left")
	check(panel.get_node("%AcceptedTitle").visible and panel.get_node("%Accepted").visible, "Accepted section shown")
	var accepted: OrderNote = panel.get_node("%Accepted").get_child(0)
	check(accepted.get_node("%Tag").visible and accepted.get_node("%Tag").text.ends_with("left"), "tagged with its countdown")
	eq(accepted.get_node("%Frame").theme_type_variation, &"PortraitFrameWoodLight", "light frame when accepted")
	var offer: OrderNote = panel.get_node("%Offers").get_child(0)
	eq(offer.get_node("%Frame").theme_type_variation, &"PortraitFrameWood", "new requests use the dark frame")
	check(panel.get_node("%Slots").text.begins_with("1 of"), "slots updated")
	parts[0].queue_free()


func test_the_countdown_includes_today_and_is_coloured_by_urgency() -> void:
	eq(OrderNote.days_left(6, 6), 1, "the deadline day is the last chance")
	eq(OrderNote.days_left(8, 6), 3, "counting today")
	eq(OrderNote.days_left(5, 6), 0, "never negative")
	eq(OrderNote.days_left_text(1), "1 day left", "singular")
	eq(OrderNote.days_left_text(3), "3 days left", "plural")
	var note: OrderNote = load("res://shop/panels/order_note.tscn").instantiate()
	tree.root.add_child(note)
	eq(note.countdown_color(1), note.urgent_color, "last day: red")
	eq(note.countdown_color(2), note.soon_color, "two days: yellow")
	eq(note.countdown_color(3), note.plenty_color, "three or more: green")
	var t := OrderTemplate.new()
	t.customer = "Pip"
	note.show_order(t, 2)
	var tag: Label = note.get_node("%Tag")
	var shown: Color = tag.label_settings.font_color if tag.label_settings else tag.get_theme_color("font_color")
	check(tag.visible and tag.text == "2 days left" and shown == note.soon_color, "the tag shows and is tinted")
	note.show_order(t)
	check(not tag.visible, "an offer has no countdown")
	note.queue_free()


func test_clicking_an_offer_opens_its_details_and_accept_closes_them() -> void:
	var parts := _panel()
	await tree.process_frame
	var panel: Control = parts[1]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	(_notes(panel)[0] as OrderNote)._gui_input(click)
	check(panel.get_node("%DetailsLayer").visible, "details open")
	var details: OrderDetails = panel.get_node("%Details")
	check(details.get_node("%Accept").visible and not details.get_node("%Deliver").visible, "an offer can be accepted")
	check(details.get_node("%Needs").get_child_count() > 0, "lists what is needed")
	check(details.get_node("%Reward").text.contains("gold"), "shows the reward")
	details.get_node("%Accept").pressed.emit()
	await tree.process_frame
	eq(Game.state.orders.size(), 1, "accepted")
	check(not panel.get_node("%DetailsLayer").visible, "back to the board")
	parts[0].queue_free()


func test_deliver_from_the_details_lists_eligible_creatures_and_pays() -> void:
	var parts := _panel()
	await tree.process_frame
	var panel: Control = parts[1]
	Game.accept(&"t0_slime")
	await tree.process_frame
	panel.open_active(0)
	var details: OrderDetails = panel.get_node("%Details")
	check(details.get_node("%Deliver").visible and not details.get_node("%Accept").visible, "an accepted order is delivered")
	var menu: PopupMenu = details.get_node("%Deliver").get_popup()
	eq(menu.item_count, 1, "only the slime qualifies")
	var need: OrderNeed = details.get_node("%Needs").get_child(0)
	var text: Label = need.get_node("%Text")
	var shown: Color = text.label_settings.font_color if text.label_settings else text.get_theme_color("font_color")
	eq(shown, need.met_color, "the slime meets it: the met colour")
	check(not need.get_node("%Bonus").visible, "a required line has no Bonus prefix")
	var money := Game.state.money
	menu.id_pressed.emit(menu.get_item_id(0))
	eq(Game.state.money, money + 80, "paid")
	eq(Game.state.orders.size(), 0, "order closed")
	check(not panel.get_node("%DetailsLayer").visible, "back to the board")
	parts[0].queue_free()
	DirAccess.remove_absolute(SAVE)


func test_a_customer_without_a_portrait_plays_an_emote() -> void:
	var note: OrderNote = load("res://shop/panels/order_note.tscn").instantiate()
	tree.root.add_child(note)
	var face: EmoteFace = note.get_node("%Face")
	var counts := face.frame_counts()
	eq(counts.size(), 46, "one emote per row of the sheet")
	eq(counts[0], 13, "a full row")
	eq(counts[2], 1, "a one-frame row")
	eq(face.emote_rows().size(), 41, "rows that animate")
	var t := OrderTemplate.new()
	t.customer = "Farmer Tess"
	note.show_order(t)
	check(face.row in face.emote_rows(), "an animated emote: row %d" % face.row)
	var first: AtlasTexture = face.texture
	eq(first.atlas, face.sheet, "cut from the sheet")
	eq(first.region.position, Vector2(0, face.row * 32), "starting at its first frame")
	face._process(1.0 / face.fps)
	check(face.texture != first, "it animates")
	var row := face.row
	note.show_order(t)
	eq(face.row, row, "the same customer makes the same face")
	t.portrait = PlaceholderTexture2D.new()
	note.show_order(t)
	check(face.row == -1 and face.texture == t.portrait, "a portrait replaces the emote")
	t.portrait = null
	face.sheet = null
	note.show_order(t)
	check(face.row == -1 and face.texture == null, "no portrait and no sheet: an empty frame, not an error")
	note.queue_free()


func test_the_details_head_is_the_same_note_scene() -> void:
	var parts := _panel()
	await tree.process_frame
	var panel: Control = parts[1]
	panel.open_offer(Game.state.board[0])
	var prompt: OrderNote = panel.get_node("%Details").get_node("%Prompt")
	eq(prompt.scene_file_path, "res://shop/panels/order_note.tscn", "one scene for portrait and prompt")
	eq(prompt.get_node("%Who").text, (Game.db.orders[Game.state.board[0]] as OrderTemplate).customer, "shows the customer")
	check(not prompt.get_node("%Tag").visible, "no tag in the details")
	parts[0].queue_free()


func test_day_summary_shows_totals_creatures_and_events() -> void:
	var parts := _panel()
	parts[0].queue_free()
	var c: CreatureData = Game.owned()[0]
	var summary: Control = load("res://shop/panels/day_summary.tscn").instantiate()
	tree.root.add_child(summary)
	await tree.process_frame
	summary.show_report({"day": 3, "totals": {"gold": 80, "reputation": -3, "feed": 0},
		"creatures": [{"id": c.id, "changes": PackedStringArray(["Power +24", "Grew up!"])}],
		"events": PackedStringArray(["Slime #2 hatched", "Missed Pip's order (-3 reputation)"])})
	check(summary.get_node("%Title").text.contains("3"), "title names the day")
	eq(summary.get_node("%Gold").text, "Gold +80", "gold total")
	eq(summary.get_node("%Gold").get_theme_color("font_color"), summary.up_color, "up is green")
	eq(summary.get_node("%Reputation").get_theme_color("font_color"), summary.down_color, "down is red")
	check(not summary.get_node("%Feed").has_theme_color_override("font_color"), "no change: plain")
	var rows: Array = summary.get_node("%Creatures").get_children()
	eq(rows.size(), 1, "one row per creature that changed")
	eq(rows[0].get_node("%Changes").get_child_count(), 2, "a chip per change")
	var lines: Array = summary.get_node("%Events").get_children()
	eq(lines.size(), 2, "one line per event")
	check(lines[1].has_theme_color_override("font_color"), "missed order highlighted")
	check(not lines[0].has_theme_color_override("font_color"), "normal line plain")
	summary.show_report({"day": 4, "totals": {}, "creatures": [], "events": PackedStringArray()})
	await tree.process_frame
	eq((summary.get_node("%Events").get_child(0) as Label).text, "A quiet day.", "a quiet day")
	check(not summary.get_node("%CreaturesTitle").visible, "no Creatures heading without rows")
	summary.queue_free()
