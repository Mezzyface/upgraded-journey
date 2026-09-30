class_name ExpeditionPanel
extends PanelContainer
## Send an expedition (docs/superpowers/specs/2026-09-29-expeditions-design.md). Left: pick a location in %Places
## (with a team, each button shows how many challenges it passes there, "Mine 1/2"), its challenges in %Needs
## (met/missing for the team), what can be found in %Finds, Send or %Reason, and today's expeditions in %Out.
## Right: three team slots and a CreatureRow per owned creature (eggs left out); one that can't go is disabled and
## says why, and its mark is how many challenges it meets alone. Refreshes on Game.changed.

signal creature_chosen(c: CreatureData)
signal sent(location: Location)

const ROW := preload("res://shop/panels/creature_row.tscn")
const NEED := preload("res://shop/panels/order_need.tscn")
const EMPTY_SLOT := "Pick a creature"

var place: StringName
var team: Array[CreatureData] = [null, null, null]
var _group := ButtonGroup.new()


func _ready() -> void:
	%Close.pressed.connect(func() -> void:
		var host := get_parent() as PanelHost
		if host:
			host.close())
	for i in team.size():
		_slot(i).pressed.connect(_empty_slot.bind(i))
	%Send.text = "Send (%d AP)" % Day.COST_EXPEDITION
	%Send.pressed.connect(_send)
	var ids: Array = Game.db.locations.keys()
	ids.sort()
	for id: StringName in ids:
		var b := Button.new()
		b.name = String(id)
		b.theme_type_variation = &"DecoratedButton"
		b.toggle_mode = true
		b.button_group = _group
		b.pressed.connect(choose.bind(id))
		%Places.add_child(b)
	if not ids.is_empty():
		place = ids[0]
	Game.changed.connect(refresh)
	refresh()


func choose(id: StringName) -> void:
	place = id
	refresh()


## Puts `c` in the next empty slot; ignored when the team is full, `c` is already in it, or `c` can't travel.
func pick(c: CreatureData) -> void:
	var i := team.find(null)
	if i < 0 or team.has(c) or Game.travel_reason(c) != "":
		return
	team[i] = c
	refresh()


func members() -> Array[CreatureData]:
	var out: Array[CreatureData] = []
	for c in team:
		if c:
			out.append(c)
	return out


func refresh() -> void:
	var loc: Location = Game.db.locations.get(place)
	var picked := members()
	for b: Button in %Places.get_children():
		var l: Location = Game.db.locations.get(StringName(b.name))
		if l == null:
			continue
		b.text = l.display_name if picked.is_empty() else \
				"%s %d/%d" % [l.display_name, Game.challenges_met(l.id, picked), l.challenges.size()]
		b.set_pressed_no_signal(l.id == place)
	_clear(%Needs)
	if loc:
		for g in loc.challenges:
			if g == null:
				continue
			var line: OrderNeed = NEED.instantiate()
			%Needs.add_child(line)
			var met: Variant = null if picked.is_empty() else picked.any(func(c: CreatureData) -> bool: return Game.group_met(c, g))
			line.show_need(g.describe(), false, met)
	%Finds.text = _finds(loc) if loc else ""
	for i in team.size():
		var c := team[i]
		var sp: Species = Game.species_of(c) if c else null
		_slot(i).text = Game.who(c) if c else EMPTY_SLOT
		_slot(i).icon = CreatureAnim.portrait(sp.sprite_frames) if sp else null
	var reason := Game.expedition_reason(place, picked) if not picked.is_empty() else ""
	%Send.disabled = picked.is_empty() or reason != ""
	_show(%Reason, _sentence(reason))
	var outs: PackedStringArray = []
	for ex in Game.expeditions_today():
		var names := PackedStringArray(ex["team"].map(func(c: CreatureData) -> String: return Game.who(c)))
		outs.append("%s (%s)" % [ex["location"].display_name, ", ".join(names)])
	_show(%Out, "Out today: " + ", ".join(outs) if not outs.is_empty() else "")
	_clear(%List)
	var total := loc.challenges.size() if loc else 0
	for c: CreatureData in Game.owned():
		if c.stage == "egg":
			continue
		var row: CreatureRow = ROW.instantiate()
		%List.add_child(row)
		var alone := "%d/%d" % [Game.challenges_met(place, [c]), total] if total > 0 else ""
		row.show_row(c, alone, team.has(c), Game.travel_reason(c))
		row.picked.connect(pick)
		row.card_pressed.connect(creature_chosen.emit)


func _slot(i: int) -> Button:
	return get_node("%%Slot%d" % (i + 1))


func _empty_slot(i: int) -> void:
	team[i] = null
	refresh()


func _send() -> void:
	var picked := members()
	if picked.is_empty():
		return  # e.g. a second click after the slots cleared
	var reason := Game.send_expedition(place, picked)
	if reason != "":
		_show(%Reason, _sentence(reason))
		return
	team.fill(null)
	refresh()
	sent.emit(Game.db.locations[place])


## "Finds: Spider, Wolf eggs · 10–30 gold" (species in loot order, no repeats); just the gold without loot.
static func _finds(loc: Location) -> String:
	var names: PackedStringArray = []
	for e in loc.loot:
		if e and e.species and not names.has(e.species.display_name):
			names.append(e.species.display_name)
	var eggs := ", ".join(names) + " eggs · " if not names.is_empty() else ""
	return "Finds: %s%d–%d gold" % [eggs, loc.money_min, loc.money_max]


## Empty text hides the line so the column keeps its room.
static func _show(label: Label, text: String) -> void:
	label.text = text
	label.visible = text != ""


static func _sentence(reason: String) -> String:
	return reason.left(1).to_upper() + reason.substr(1)


static func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
