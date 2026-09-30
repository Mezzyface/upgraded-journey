extends Control
## The farm. The map is laid out in the editor; placed buildables (pens) are instanced under %Buildings from
## Game.state.placed and each pen's %Creatures area shows the creatures living in it. %Buildable marks where the
## player may build (hidden except while %Placer is placing). The hanging %TopBar shows the state and its tags (and
## %ShopDoor, over the shop building) open popups in %PanelHost, each its own scene.
## Creatures away on an expedition are not drawn until the evening.

const TOAST_SECONDS := 2.5
const CARD := preload("res://shop/panels/creature_card.tscn")
const ORDERS := preload("res://shop/panels/orders_panel.tscn")
const SUMMARY := preload("res://shop/panels/day_summary.tscn")
const STABLE := preload("res://shop/panels/stable_panel.tscn")
const MARKET := preload("res://shop/panels/market_panel.tscn")
const EXPEDITION := preload("res://shop/panels/expedition_panel.tscn")

var _rng := RandomNumberGenerator.new()


## After `--`: `--save=<path>` uses that save file (for screenshots),
## `--open=card|orders|summary|stable|market|expedition` opens a popup, `--screenshot=<path>` saves a capture and
## quits. The same pattern as ui/gallery.gd. `--screenshot=` without `--save=` never touches the real save.
func _read_save_arg() -> void:
	var args := OS.get_cmdline_user_args()
	var has_save := false
	var has_screenshot := false
	for arg in args:
		if arg.begins_with("--save="):
			Game.save_path = arg.trim_prefix("--save=")
			has_save = true
		elif arg.begins_with("--screenshot="):
			has_screenshot = true
	if has_screenshot and not has_save:
		Game.save_path = "user://shot_save.json"


func _handle_cmdline() -> void:
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		match arg:
			"--open=card":
				if not Game.owned().is_empty():
					open_card(Game.owned()[0])
			"--open=orders":
				open_orders()
			"--open=summary":
				end_day()
			"--open=stable":
				open_stable()
			"--open=market":
				open_market()
			"--open=expedition":
				open_expedition()
		if arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
	if shot != "":
		await RenderingServer.frame_post_draw
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _ready() -> void:
	_rng.randomize()
	_read_save_arg()
	if Game.state == null:
		Game.start()
	Game.changed.connect(_refresh)
	%TopBar.orders_pressed.connect(open_orders)
	%TopBar.stable_pressed.connect(open_stable)
	%TopBar.expedition_pressed.connect(open_expedition)
	%TopBar.market_pressed.connect(open_market)
	%TopBar.end_day_pressed.connect(end_day)
	%ShopDoor.pressed.connect(open_orders)
	%Buildable.hide()
	%Placer.finished.connect(_placed)
	_refresh()
	_handle_cmdline()


func _refresh() -> void:
	%TopBar.show_state(Game.state, Game.tier())
	for p in Game.state.placed:
		var node := %Buildings.get_node_or_null("Placed%d" % p["id"])
		if node == null:
			var def: BuildableDef = Game.db.buildables[p["def"]]
			node = def.scene.instantiate()
			node.name = "Placed%d" % p["id"]
			node.position = Vector2(p["cell"] * Placer.TILE)
			%Buildings.add_child(node)
			var area := node.get_node_or_null("%Creatures") as SpawnArea
			if area:
				area.creature_clicked.connect(open_card)
		var pen := node.get_node_or_null("%Creatures") as SpawnArea
		if pen:
			pen.sync(Game.owned().filter(func(c: CreatureData) -> bool:
				return c.pen == p["id"] and not Game.state.busy.has(c.id)), Game.db, _rng)  # away: gone until evening


## The creature area of placed pen `placed_id`, or null.
func pen_area(placed_id: int) -> SpawnArea:
	var node := %Buildings.get_node_or_null("Placed%d" % placed_id)
	return node.get_node_or_null("%Creatures") as SpawnArea if node else null


## The cells painted on %Buildable, as a set for Build.can_place.
func buildable_cells() -> Dictionary:
	var cells := {}
	for c in %Buildable.get_used_cells():
		cells[c] = true
	return cells


func open_card(c: CreatureData) -> void:
	var card := CARD.instantiate()
	%PanelHost.open(card)
	card.show_creature(c)
	%TutorialHint.saw(&"card")


func open_orders() -> void:
	%PanelHost.open(ORDERS.instantiate())
	%TutorialHint.saw(&"orders")


func open_stable() -> void:
	var stable: StablePanel = STABLE.instantiate()
	%PanelHost.open(stable)
	stable.show_creatures(Game.retired())
	stable.creature_chosen.connect(open_card)
	stable.bred.connect(toast.bind("An egg was laid"))
	%TutorialHint.saw(&"stable")


func open_market() -> void:
	var market := MARKET.instantiate()
	%PanelHost.open(market)
	market.build_requested.connect(start_building)
	market.bought.connect(toast)
	%TutorialHint.saw(&"market")


## Closes any popup and enters placement mode for `def_id`, showing where building is allowed.
func start_building(def_id: StringName) -> void:
	%PanelHost.close()
	%Buildable.show()
	%Placer.start(def_id, buildable_cells())


func _placed(built: bool) -> void:
	%Buildable.hide()
	if built:
		toast("Pen built")


func open_expedition() -> void:
	var panel: ExpeditionPanel = EXPEDITION.instantiate()
	%PanelHost.open(panel)
	panel.creature_chosen.connect(open_card)
	panel.sent.connect(func(loc: Location) -> void: toast("Off to the %s — back this evening" % loc.display_name))


func end_day() -> void:
	%Toast.text = ""  # the morning's news doesn't belong over the evening summary
	Game.end_day()
	var summary := SUMMARY.instantiate()
	%PanelHost.open(summary)
	summary.show_report(Game.report)


func toast(msg: String) -> void:
	%Toast.text = msg
	get_tree().create_timer(TOAST_SECONDS).timeout.connect(func() -> void:
		if %Toast.text == msg:
			%Toast.text = "")
