extends PanelContainer
## What happened in the evening. Missed orders and injuries are highlighted; Continue shows the new morning.

const HIGHLIGHT := Color(0.75, 0.2, 0.2)
const HIGHLIGHT_WORDS: PackedStringArray = ["Missed", "injured", "Couldn't save"]


func _ready() -> void:
	%Continue.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close()
		else:
			queue_free())


func show_events(day: int, events: PackedStringArray) -> void:
	%Title.text = "End of day %d" % day
	for child in %Events.get_children():
		%Events.remove_child(child)
		child.queue_free()
	if events.is_empty():
		events = PackedStringArray(["A quiet evening."])
	for e in events:
		var l := Label.new()
		l.text = e
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if Array(HIGHLIGHT_WORDS).any(func(w: String) -> bool: return e.contains(w)):
			l.add_theme_color_override("font_color", HIGHLIGHT)
		%Events.add_child(l)
