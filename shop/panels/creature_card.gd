extends PanelContainer
## The creature card: stats against their caps, traits and moves, family, and this creature's actions. Every action
## goes through Game; a refused one shows its reason. Closes itself if the creature leaves the shop.

var creature: CreatureData


func _ready() -> void:
	%Feed.pressed.connect(_act.bind(func() -> String: return Game.care(creature, "feed")))
	%Play.pressed.connect(_act.bind(func() -> String: return Game.care(creature, "play")))
	%Retire.pressed.connect(_act.bind(func() -> String: return Game.retire(creature)))
	%Sell.pressed.connect(_act.bind(func() -> String: return Game.sell(creature)))
	%Close.pressed.connect(_close)
	var menu: PopupMenu = %Train.get_popup()
	for s in Stats.NAMES:
		menu.add_item(s.capitalize())
	menu.id_pressed.connect(func(i: int) -> void: _act(func() -> String: return Game.train(creature, Stats.NAMES[i])))
	Game.changed.connect(_refresh)


func show_creature(c: CreatureData) -> void:
	creature = c
	_refresh()


func _act(action: Callable) -> void:
	var reason: String = action.call()
	%Message.text = reason.left(1).to_upper() + reason.substr(1)


func _refresh() -> void:
	if creature == null:
		return
	if creature.status == CreatureData.Status.GONE:
		_close()
		return
	var sp := Game.species_of(creature)
	%Portrait.texture = CreatureAnim.portrait(sp.sprite_frames) if sp else null
	%Name.text = "%s #%d" % [sp.display_name if sp else String(creature.species), creature.id]
	var notes: PackedStringArray = [creature.stage.capitalize()]
	if sp:
		notes.append_array([String(sp.element).capitalize(), String(sp.egg_group).capitalize()])
	notes.append(String(creature.personality).capitalize() if creature.personality != &"" else "Personality not settled")
	notes.append("Mood %d" % creature.mood)
	if creature.injured_days > 0:
		notes.append("Injured %d days" % creature.injured_days)
	if Game.state.busy.has(creature.id):
		notes.append("Away today")
	if creature.status == CreatureData.Status.RETIRED:
		notes.append("Retired")
	%Info.text = " · ".join(notes)
	_fill_stats()
	_fill_chips()
	%Family.text = _family()
	%Sell.text = "Sell · %d" % Game.sell_price(creature)


func _fill_stats() -> void:
	for child in %Stats.get_children():
		child.queue_free()
		%Stats.remove_child(child)
	for s in Stats.NAMES:
		var name := Label.new()
		name.text = s.capitalize()
		var bar := StatBar.new()
		bar.value = creature.stats[s]
		bar.cap = creature.potential[s]
		var grade := Label.new()
		grade.text = Stats.grade_name(creature.stats[s])
		for n in [name, bar, grade]:
			%Stats.add_child(n)


func _fill_chips() -> void:
	for child in %Chips.get_children():
		child.queue_free()
		%Chips.remove_child(child)
	var names: PackedStringArray = []
	for t in creature.all_traits(Game.db):
		var def: TraitDef = Game.db.traits.get(t)
		names.append(def.display_name if def else String(t).capitalize())
	for m in creature.moves:
		var def: MoveDef = Game.db.moves.get(m)
		names.append(def.display_name if def else String(m).capitalize())
	for n in names:
		var chip := Label.new()
		chip.text = n
		chip.theme_type_variation = &"NamePlate"
		%Chips.add_child(chip)


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
