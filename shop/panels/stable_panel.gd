class_name StablePanel
extends PanelContainer
## The breeding stable, laid out like Uma Musume's parent select: two parent slots with their compatibility mark,
## Breed or the reason the pair can't breed, and a StableRow per retired creature. A row's Pick fills the next empty
## slot, pressing a filled slot empties it, and a row's Card emits creature_chosen (shop.gd opens the card in place).
## Refreshes on Game.changed, so AP, pens and cooldowns stay current.

signal creature_chosen(c: CreatureData)
signal bred

const ROW := preload("res://shop/panels/stable_row.tscn")
const EMPTY_SLOT := "Pick a parent"

var slots: Array[CreatureData] = [null, null]
var _retired: Array = []


func _ready() -> void:
	%Close.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close())
	%SlotA.pressed.connect(_empty_slot.bind(0))
	%SlotB.pressed.connect(_empty_slot.bind(1))
	%Breed.text = "Breed (%d AP)" % Day.COST_BREED
	%Breed.pressed.connect(_breed)
	Game.changed.connect(_on_game_changed)


func show_creatures(retired: Array) -> void:
	_retired = retired
	for i in slots.size():
		if slots[i] and not retired.has(slots[i]):
			slots[i] = null
	_refresh()


## Puts `c` in the next empty slot; ignored when both are full or `c` is already in one.
func pick(c: CreatureData) -> void:
	var i := slots.find(null)
	if i < 0 or slots.has(c):
		return
	slots[i] = c
	_refresh()


func _empty_slot(i: int) -> void:
	slots[i] = null
	_refresh()


func _breed() -> void:
	if slots.has(null):
		return  # e.g. a second click after the slots cleared
	var reason := Game.breed(slots[0], slots[1])
	if reason != "":
		%Reason.text = _sentence(reason)
		return
	slots.fill(null)
	_refresh()
	bred.emit()


func _on_game_changed() -> void:
	show_creatures(Game.retired())


func _refresh() -> void:
	for i in slots.size():
		var slot: Button = %SlotA if i == 0 else %SlotB
		var c: CreatureData = slots[i]
		var sp: Species = Game.species_of(c) if c else null
		slot.text = Game.who(c) if c else EMPTY_SLOT
		slot.icon = CreatureAnim.portrait(sp.sprite_frames) if sp else null
	var pair := not slots.has(null)
	%Mark.text = Game.compat_mark(slots[0], slots[1]) if pair else ""
	var reason := Game.breed_reason(slots[0], slots[1]) if pair else ""
	%Breed.disabled = not pair or reason != ""
	%Reason.text = _sentence(reason)
	for row in %List.get_children():
		%List.remove_child(row)
		row.queue_free()
	%Empty.visible = _retired.is_empty()
	var a := slots[0]
	for c: CreatureData in _retired:
		var row: StableRow = ROW.instantiate()
		%List.add_child(row)
		row.show_row(c, Game.compat_mark(a, c) if a and a != c else "", slots.has(c))
		row.picked.connect(pick)
		row.card_pressed.connect(creature_chosen.emit)


static func _sentence(reason: String) -> String:
	return reason.left(1).to_upper() + reason.substr(1)
