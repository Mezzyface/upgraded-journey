class_name CreatureRow
extends HBoxContainer
## One creature in a list (creature_row.tscn), used by the Stable and the Expedition panel: Pick (portrait and name)
## puts it in the panel's next empty slot, the note gives its element and egg group, how long it still rests, or
## `blocked` (why it can't be picked), the mark is the panel's score for it, and Card opens its card.

signal picked(c: CreatureData)
signal card_pressed(c: CreatureData)

var creature: CreatureData


func _ready() -> void:
	%Pick.pressed.connect(func() -> void: picked.emit(creature))
	%Card.pressed.connect(func() -> void: card_pressed.emit(creature))


## `mark`: the panel's score for this creature ("" for none). `in_slot` or a non-empty `blocked` disables Pick;
## `blocked` also replaces the note.
func show_row(c: CreatureData, mark: String, in_slot: bool, blocked := "") -> void:
	creature = c
	var sp := Game.species_of(c)
	%Pick.icon = CreatureAnim.portrait(sp.sprite_frames) if sp else null
	%Pick.text = Game.who(c)
	%Pick.disabled = in_slot or blocked != ""
	if blocked != "":
		%Note.text = blocked
	elif c.breed_cooldown > 0:
		%Note.text = "rests %d day%s" % [c.breed_cooldown, "" if c.breed_cooldown == 1 else "s"]
	else:
		%Note.text = "%s · %s" % [String(sp.element).capitalize(), String(sp.egg_group).capitalize()] if sp else ""
	%Note.tooltip_text = %Note.text
	%Mark.text = mark
