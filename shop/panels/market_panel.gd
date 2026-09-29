extends "res://shop/panels/closable_panel.gd"
## The Market. For now only its Pens list (docs/superpowers/specs/2026-09-29-buildable-pens-design.md): one
## buildable_row.tscn per buildable that holds creatures, cheapest first. Buy doesn't charge — it asks the farm to
## start placement (shop.gd connects build_requested); the price is paid when the pen is placed.

signal build_requested(def_id: StringName)

const ROW := preload("res://shop/panels/buildable_row.tscn")


func _ready() -> void:
	super()
	var defs: Array = Game.db.buildables.values().filter(func(d: BuildableDef) -> bool: return d.capacity > 0)
	defs.sort_custom(func(a: BuildableDef, b: BuildableDef) -> bool: return a.cost < b.cost)
	for def: BuildableDef in defs:
		var row: Control = ROW.instantiate()
		%Pens.add_child(row)
		row.get_node("%Name").text = def.display_name
		row.get_node("%Holds").text = "holds %d" % def.capacity
		row.get_node("%Price").text = str(def.cost)
		var buy: Button = row.get_node("%Buy")
		buy.disabled = Game.state.money < def.cost
		buy.tooltip_text = "not enough money" if buy.disabled else def.description
		buy.pressed.connect(func() -> void: build_requested.emit(def.id))
