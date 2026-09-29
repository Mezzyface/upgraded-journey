extends TestSuite
## The popup scenes (Stable, Market, Expedition) and PanelHost's backdrop.

const SAVE := "user://test_popups_save.json"
const SCENES := {"StablePanel": "res://shop/panels/stable_panel.tscn",
	"MarketPanel": "res://shop/panels/market_panel.tscn", "ExpeditionPanel": "res://shop/panels/expedition_panel.tscn"}


func _host() -> PanelHost:
	Game.save_path = SAVE
	Game.start_new(load("res://data/new_game.tres"), Db.load_dir(), 3)
	var host := PanelHost.new()
	host.size = Vector2(640, 320)
	tree.root.add_child(host)
	return host


func _done(host: Node) -> void:
	host.queue_free()
	DirAccess.remove_absolute(SAVE)


func test_each_popup_closes() -> void:
	var host := _host()
	await tree.process_frame
	for name in SCENES:
		var panel: Control = load(SCENES[name]).instantiate()
		host.open(panel)
		await tree.process_frame  # the panel's _ready connects its Close button
		eq(panel.name, name, "root name")
		check(host.backdrop, "%s: backdrop while open" % name)
		panel.get_node("%Close").pressed.emit()
		await tree.process_frame
		check(host.current() == null, "%s: Close closes it" % name)
		check(not host.backdrop, "%s: backdrop gone" % name)
		eq(host.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: farm clickable again" % name)
		host.open(load(SCENES[name]).instantiate())
		var esc := InputEventAction.new()
		esc.action = &"ui_cancel"
		esc.pressed = true
		host._unhandled_input(esc)
		await tree.process_frame
		check(host.current() == null, "%s: Esc closes it" % name)
	_done(host)


func test_stable_lists_retired_creatures_and_emits_the_choice() -> void:
	var host := _host()
	await tree.process_frame
	Game.retire(Game.owned()[0])
	var panel: StablePanel = load(SCENES.StablePanel).instantiate()
	host.open(panel)
	await tree.process_frame
	panel.show_creatures(Game.retired())
	eq(panel.get_node("%List").get_child_count(), Game.retired().size(), "one row per retired creature")
	check(not panel.get_node("%Empty").visible, "no empty text")
	var chosen: Array = []
	panel.creature_chosen.connect(func(c: CreatureData) -> void: chosen.append(c))
	(panel.get_node("%List").get_child(0) as Button).pressed.emit()
	eq(chosen, [Game.retired()[0]], "row press emits creature_chosen")
	_done(host)


func test_empty_stable_says_so() -> void:
	var host := _host()
	await tree.process_frame
	var panel: StablePanel = load(SCENES.StablePanel).instantiate()
	host.open(panel)
	await tree.process_frame
	panel.show_creatures([])
	eq(panel.get_node("%List").get_child_count(), 0, "no rows")
	check(panel.get_node("%Empty").visible, "empty text shown")
	_done(host)
