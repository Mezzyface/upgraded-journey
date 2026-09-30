class_name StableRow
extends HBoxContainer
## One retired creature in the Stable (stable_row.tscn): Pick (portrait and name) puts it in the next empty parent
## slot, the note gives its element and egg group or how long it still rests, the mark is its compatibility with
## parent slot A, and Card opens its card.

signal picked(c: CreatureData)
signal card_pressed(c: CreatureData)

var creature: CreatureData


func _ready() -> void:
	%Pick.pressed.connect(func() -> void: picked.emit(creature))
	%Card.pressed.connect(func() -> void: card_pressed.emit(creature))


## `mark`: compatibility with slot A ("" when A is empty or is this creature). `in_slot` disables Pick.
func show_row(c: CreatureData, mark: String, in_slot: bool) -> void:
	creature = c
	var sp := Game.species_of(c)
	%Pick.icon = CreatureAnim.portrait(sp.sprite_frames) if sp else null
	%Pick.text = Game.who(c)
	%Pick.disabled = in_slot
	if c.breed_cooldown > 0:
		%Note.text = "rests %d day%s" % [c.breed_cooldown, "" if c.breed_cooldown == 1 else "s"]
	else:
		%Note.text = "%s · %s" % [String(sp.element).capitalize(), String(sp.egg_group).capitalize()] if sp else ""
	%Mark.text = mark
