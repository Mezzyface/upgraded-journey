extends Control
## The shop floor. Everything visible is laid out in the editor; creatures are spawned into %Pens and %Stable
## (SpawnAreas) and panels into %PanelHost at runtime.

const TOAST_SECONDS := 2.5
const CARD := preload("res://shop/panels/creature_card.tscn")

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if Game.state == null:
		Game.start()
	Game.changed.connect(_refresh)
	%EndDayButton.pressed.connect(end_day)
	%Counter.pressed.connect(open_orders)
	%MarketStall.pressed.connect(toast.bind("The market opens soon"))
	%Door.pressed.connect(toast.bind("Expeditions start soon"))
	%Pens.creature_clicked.connect(open_card)
	%Stable.creature_clicked.connect(open_card)
	_refresh()


func _refresh() -> void:
	var s := Game.state
	%DayLabel.text = "Day %d" % s.day
	%ApLabel.text = "AP %d / %d" % [s.ap, Day.max_ap(s)]
	%MoneyLabel.text = "%d gold" % s.money
	%RepLabel.text = "Reputation %d · tier %d" % [s.reputation, Game.tier()]
	%Pens.sync(Game.owned(), Game.db, _rng)
	%Stable.sync(Game.retired(), Game.db, _rng)


func open_card(c: CreatureData) -> void:
	var card := CARD.instantiate()
	%PanelHost.open(card)
	card.show_creature(c)


func open_orders() -> void:
	toast("Orders come in the next step")  # Task 9


func end_day() -> void:
	Game.end_day()  # Task 9 shows the summary


func toast(msg: String) -> void:
	%Toast.text = msg
	get_tree().create_timer(TOAST_SECONDS).timeout.connect(func() -> void:
		if %Toast.text == msg:
			%Toast.text = "")
