extends Control
## The farm. The map is laid out in the editor; creatures are spawned into %Pens, the hanging %TopBar shows the
## state and its tags (and %ShopDoor, over the shop building) open popups in %PanelHost, each its own scene.

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
	%Pens.creature_clicked.connect(open_card)
	_refresh()
	_handle_cmdline()


func _refresh() -> void:
	%TopBar.show_state(Game.state, Game.tier())
	%Pens.sync(Game.owned(), Game.db, _rng)


func open_card(c: CreatureData) -> void:
	var card := CARD.instantiate()
	%PanelHost.open(card)
	card.show_creature(c)


func open_orders() -> void:
	%PanelHost.open(ORDERS.instantiate())


func open_stable() -> void:
	var stable: StablePanel = STABLE.instantiate()
	%PanelHost.open(stable)
	stable.show_creatures(Game.retired())
	stable.creature_chosen.connect(open_card)


func open_market() -> void:
	%PanelHost.open(MARKET.instantiate())


func open_expedition() -> void:
	%PanelHost.open(EXPEDITION.instantiate())


func end_day() -> void:
	var day := Game.state.day
	var events := Game.end_day()
	var summary := SUMMARY.instantiate()
	%PanelHost.open(summary)
	summary.show_events(day, events)


func toast(msg: String) -> void:
	%Toast.text = msg
	get_tree().create_timer(TOAST_SECONDS).timeout.connect(func() -> void:
		if %Toast.text == msg:
			%Toast.text = "")
