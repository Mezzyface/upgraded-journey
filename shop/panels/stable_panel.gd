class_name StablePanel
extends PanelContainer
## Retired creatures, one button each; pressing one emits creature_chosen (shop.gd opens its card in place).

signal creature_chosen(c: CreatureData)


func _ready() -> void:
	%Close.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close())


func show_creatures(retired: Array) -> void:
	for row in %List.get_children():
		%List.remove_child(row)
		row.queue_free()
	%Empty.visible = retired.is_empty()
	for c: CreatureData in retired:
		var b := Button.new()
		b.theme_type_variation = &"DecoratedButton"
		var sp := Game.species_of(c)
		b.text = "%s #%d" % [sp.display_name if sp else String(c.species), c.id]
		b.pressed.connect(creature_chosen.emit.bind(c))
		%List.add_child(b)
