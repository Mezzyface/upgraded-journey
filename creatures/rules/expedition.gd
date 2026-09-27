class_name Expedition
extends RefCounted
## Auto-resolved expeditions (Tactics replaces this later). Each location challenge passes if any team member
## meets it; each pass is one loot roll (a wild egg or money), each failure injures a random member.

const MAX_TEAM := 3
const EGG_CHANCE := 0.4
const INJURY_DAYS := 2
const XP_GAIN := 10


static func resolve(state: GameState, db: Db, location_id: StringName, team_ids: Array, rng: RandomNumberGenerator) -> PackedStringArray:
	var events: PackedStringArray = []
	var loc: Location = db.locations.get(location_id)
	var team: Array[CreatureData] = []
	for id in team_ids:
		var c := state.get_creature(int(id))
		if c and c.status == CreatureData.Status.OWNED:
			team.append(c)
	if loc == null or team.is_empty():
		return events
	var passes := 0
	for g in loc.challenges:
		if g and team.any(func(c: CreatureData) -> bool: return Orders.group_met(c, g, db, state)):
			passes += 1
	var failures := loc.challenges.size() - passes
	events.append("%s: %d of %d challenges passed" % [loc.display_name, passes, loc.challenges.size()])
	for i in passes:
		var sp := _roll_egg(loc, db, rng)
		if sp == null:
			var found := rng.randi_range(loc.money_min, loc.money_max)
			state.money += found
			events.append("found %d money" % found)
		elif Market.has_pen_space(state):
			state.add(CreatureData.wild_egg(sp, state.new_id(), rng))
			events.append("found a %s egg" % sp.display_name)
		else:
			events.append("found a %s egg, but the pens are full, so it was released" % sp.display_name)
	for i in failures:
		var hurt := team[rng.randi() % team.size()]
		hurt.injured_days = INJURY_DAYS
		events.append("%s #%d was injured" % [db.species[hurt.species].display_name, hurt.id])
	for c in team:
		var s: String = Stats.NAMES[rng.randi() % Stats.NAMES.size()]
		c.stats[s] = mini(int(c.stats[s]) + XP_GAIN, int(c.potential[s]))
		Leanings.add(c, &"bold")
	return events


## A species from the loot table (by weight) EGG_CHANCE of the time, otherwise null (a money find).
static func _roll_egg(loc: Location, db: Db, rng: RandomNumberGenerator) -> Species:
	if loc.loot.is_empty() or rng.randf() >= EGG_CHANCE:
		return null
	var total := 0
	for e in loc.loot:
		total += e.weight
	var roll := rng.randi_range(1, total)
	for e in loc.loot:
		roll -= e.weight
		if roll <= 0:
			return db.species.get(e.species.id) if e.species else null
	return null
