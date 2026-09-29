extends PanelContainer
## The creature card, laid out like Uma Musume's details screen: portrait with its rank badge, epithet (personality),
## name and score; five StatBoxes (grade, value, bar toward the cap); tabs for traits & moves, sparks, and family &
## age; this creature's actions and Close. Every action goes through Game; a refused one shows its reason. Closes
## itself if the creature leaves the shop.

const EGG_TEXTURE := preload("res://creatures/egg.tres")

@export var trait_tint := Color(0.8, 1, 0.75)
@export var move_tint := Color(1, 0.86, 0.7)
@export var spark_tint := Color(0.86, 0.86, 1)

var creature: CreatureData
var _pending_sell := false  ## Sell/Retire are two-step: the first press only arms the button
var _pending_retire := false


func _ready() -> void:
	%Feed.pressed.connect(_act.bind(func() -> String: return Game.care(creature, "feed")))
	%Play.pressed.connect(_act.bind(func() -> String: return Game.care(creature, "play")))
	%Retire.pressed.connect(_press_retire)
	%Sell.pressed.connect(_press_sell)
	%Close.pressed.connect(_close)
	var menu: PopupMenu = %Train.get_popup()
	for s in Stats.NAMES:
		menu.add_item(s.capitalize())
	menu.id_pressed.connect(func(i: int) -> void: _act(func() -> String: return Game.train(creature, Stats.NAMES[i])))
	Game.changed.connect(_refresh)


func show_creature(c: CreatureData) -> void:
	creature = c
	_refresh()


## Sell and Retire are irreversible, so they take two presses: the first arms the button (and disarms the
## other one) without acting; the second — while still armed — performs the action.
func _press_sell() -> void:
	if not _pending_sell:
		_pending_sell = true
		_pending_retire = false
		_update_action_buttons()
		return
	_act(func() -> String: return Game.sell(creature))


func _press_retire() -> void:
	if not _pending_retire:
		_pending_retire = true
		_pending_sell = false
		_update_action_buttons()
		return
	_act(func() -> String: return Game.retire(creature))


func _act(action: Callable) -> void:
	_pending_sell = false
	_pending_retire = false
	var reason: String = action.call()
	%Message.text = reason.left(1).to_upper() + reason.substr(1)
	%Message.visible = reason != ""  # an empty label would still take a line
	_update_action_buttons()


func _update_action_buttons() -> void:
	if creature == null:
		return
	%Sell.text = "Sure? Sell · %d" % Game.sell_price(creature) if _pending_sell \
			else "Sell · %d" % Game.sell_price(creature)
	%Retire.text = "Sure? Retire" if _pending_retire else "Retire"


func _refresh() -> void:
	if creature == null:
		return
	if creature.status == CreatureData.Status.GONE:
		_close()
		return
	_pending_sell = false
	_pending_retire = false
	var sp := Game.species_of(creature)
	%Portrait.texture = EGG_TEXTURE if creature.stage == "egg" else \
			(CreatureAnim.portrait(sp.sprite_frames) if sp else null)
	%Name.text = "%s #%d" % [sp.display_name if sp else String(creature.species), creature.id]
	%Epithet.text = "[%s]" % (String(creature.personality).capitalize() if creature.personality != &"" else "Unsettled")
	%RankText.text = Stats.rank_name(creature.stats)
	%Score.text = _thousands(Stats.score(creature.stats))
	var notes: PackedStringArray = [creature.stage.capitalize()]
	if sp:
		notes.append_array([String(sp.element).capitalize(), String(sp.egg_group).capitalize()])
	notes.append("Mood %d" % creature.mood)
	if creature.injured_days > 0:
		notes.append("Injured %d days" % creature.injured_days)
	if Game.state.busy.has(creature.id):
		notes.append("Away today")
	if creature.status == CreatureData.Status.RETIRED:
		notes.append("Retired")
	%Info.text = " · ".join(notes)
	for box: StatBox in %Stats.get_children():
		box.show_value(creature.stats[box.stat], creature.potential[box.stat])
	_fill_chips()
	_fill_sparks()
	%Family.text = _family()
	%Age.text = _age()
	_update_action_buttons()


func _fill_chips() -> void:
	_clear(%Chips)
	for t in creature.all_traits(Game.db):
		var def: TraitDef = Game.db.traits.get(t)
		_chip(%Chips, def.display_name if def else String(t).capitalize(), trait_tint)
	for m in creature.moves:
		var def: MoveDef = Game.db.moves.get(m)
		_chip(%Chips, def.display_name if def else String(m).capitalize(), move_tint)


## Its own sparks (locked when it retires) and the inherited pool still waiting for inspiration.
func _fill_sparks() -> void:
	_clear(%Sparks)
	for s in creature.sparks:
		_chip(%Sparks, "%s %s" % [_spark_name(s), "*".repeat(s["stars"])], spark_tint)
	for s in creature.pool:
		_chip(%Sparks, "%s %s (inherited)" % [_spark_name(s), "*".repeat(s["stars"])], spark_tint)
	if creature.sparks.is_empty() and creature.pool.is_empty():
		var none := Label.new()
		none.text = "No sparks yet"
		%Sparks.add_child(none)


func _spark_name(s: Dictionary) -> String:
	var id := StringName(s["id"])
	var def: Resource = {"trait": Game.db.traits, "move": Game.db.moves,
		"personality": Game.db.personalities}.get(s["kind"], {}).get(id)
	return def.get("display_name") if def else String(id).capitalize()


func _chip(parent: Node, text: String, tint: Color) -> void:
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"NamePlate"
	plate.self_modulate = tint
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = text
	plate.add_child(label)
	parent.add_child(plate)


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _age() -> String:
	match creature.stage:
		"egg":
			return "An egg · hatches in %d days" % creature.days_left
		"baby":
			return "Age %d days · grows up in %d days" % [creature.age_days, creature.days_left]
	return "Age %d days" % creature.age_days


static func _thousands(n: int) -> String:
	var s := str(n)
	for i in range(s.length() - 3, 0, -3):
		s = s.insert(i, ",")
	return s


func _family() -> String:
	if creature.parents.is_empty():
		return "Wild"
	var parents := Array(creature.parents).map(func(id: int) -> String: return _who(id))
	var gps := 0
	for id in creature.parents:
		var p := Game.state.get_creature(id)
		if p:
			gps += p.parents.size()
	return "Parents: %s · grandparents on record: %d" % [" and ".join(parents), gps]


func _who(id: int) -> String:
	var c := Game.state.get_creature(id)
	if c == null:
		return "#%d" % id
	var sp := Game.species_of(c)
	return "%s #%d" % [sp.display_name if sp else String(c.species), id]


func _close() -> void:
	var host := get_parent() as PanelHost
	if host:
		host.close()
