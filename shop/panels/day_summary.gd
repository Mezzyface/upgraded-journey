extends PanelContainer
## The end-of-day summary (Game.report): the day's totals (%Gold, %Reputation, %Feed, green up / red down), a
## DayCreatureRow per creature that changed, and the events (the day's actions, then the evening: expedition finds,
## missed orders — highlighted). Continue shows the new morning. Laid out in day_summary.tscn.

const ROW := preload("res://shop/panels/day_creature_row.tscn")
const HIGHLIGHT_WORDS: PackedStringArray = ["Missed", "injured", "Couldn't save"]

@export var up_color := Color("67835c")
@export var down_color := Color("a16159")
@export var highlight_color := Color("a16159")  ## event lines with a HIGHLIGHT_WORDS word


func _ready() -> void:
	%Continue.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close()
		else:
			queue_free())


func show_report(report: Dictionary) -> void:
	%Title.text = "End of day %d" % report.get("day", 0)
	var totals: Dictionary = report.get("totals", {})
	_total(%Gold, "Gold", totals.get("gold", 0))
	_total(%Reputation, "Reputation", totals.get("reputation", 0))
	_total(%Feed, "Feed", totals.get("feed", 0))
	for box: Node in [%Creatures, %Events]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for r in report.get("creatures", []):
		var c := Game.state.get_creature(r["id"])
		if c == null:
			continue
		var row: DayCreatureRow = ROW.instantiate()
		%Creatures.add_child(row)
		row.show_row(c, r["changes"])
	%CreaturesTitle.visible = %Creatures.get_child_count() > 0
	var events: PackedStringArray = report.get("events", PackedStringArray())
	if events.is_empty() and %Creatures.get_child_count() == 0:
		events = PackedStringArray(["A quiet day."])
	for e in events:
		var l := Label.new()
		l.text = e
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if Array(HIGHLIGHT_WORDS).any(func(w: String) -> bool: return e.contains(w)):
			l.add_theme_color_override("font_color", highlight_color)
		%Events.add_child(l)
	%EventsTitle.visible = not events.is_empty()


func _total(label: Label, title: String, amount: int) -> void:
	label.text = "%s %+d" % [title, amount]
	if amount == 0:
		label.remove_theme_color_override("font_color")
	else:
		label.add_theme_color_override("font_color", up_color if amount > 0 else down_color)
