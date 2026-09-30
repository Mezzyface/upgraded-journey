class_name DayCreatureRow
extends HBoxContainer
## One creature in the end-of-day summary (day_summary.tscn): its portrait, name, and a chip per change today
## ("Power +24", "Grew up!"). Laid out in day_creature_row.tscn; chips use `chip_variation`. Milestones (hatched, grew
## up, evolved, learned, gained, new) are tinted `milestone_tint`; setbacks (injured, left, anything that went down)
## `setback_tint`.

const EGG_TEXTURE := preload("res://creatures/egg.tres")

@export var chip_variation := &"NamePlate"
@export var milestone_tint := Color("c0d470")
@export var setback_tint := Color("e8b5ac")


func show_row(c: CreatureData, changes: PackedStringArray) -> void:
	var sp := Game.species_of(c)
	%Portrait.texture = EGG_TEXTURE if c.stage == "egg" else (CreatureAnim.portrait(sp.sprite_frames) if sp else null)
	%Name.text = "%s #%d" % [sp.display_name if sp else String(c.species), c.id]
	for child in %Changes.get_children():
		%Changes.remove_child(child)
		child.queue_free()
	for change in changes:
		var chip := PanelContainer.new()
		chip.theme_type_variation = chip_variation
		if change in ["Injured", "Left the shop"] or change.contains(" -"):  # setbacks and losses ("Mood -10")
			chip.self_modulate = setback_tint
		elif change.ends_with("!") or change == "New" or change.begins_with("Learned") or change.begins_with("Gained"):
			chip.self_modulate = milestone_tint
		var label := Label.new()
		label.text = change
		chip.add_child(label)
		%Changes.add_child(chip)
