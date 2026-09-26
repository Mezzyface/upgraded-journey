class_name Training
extends RefCounted
## One training drill: a stat gain toward its potential, possibly a trait from the location, and any moves
## the new stat unlocks. Gain = BASE_GAIN x personality (±25%) x mood (0.5 at 0 mood, 1.5 at 100).

const BASE_GAIN := 40
const MOOD_COST := 10


static func train(c: CreatureData, stat: String, location: Location, db: Db, rng: RandomNumberGenerator) -> Dictionary:
	var mult := 1.0
	var p: Personality = db.personalities.get(c.personality)
	if p:
		if p.favored_stat == stat:
			mult += 0.25
		if p.disfavored_stat == stat:
			mult -= 0.25
	mult *= 0.5 + clampi(c.mood, 0, 100) / 100.0
	var before: int = c.stats[stat]
	var cap: int = c.potential[stat]
	c.stats[stat] = mini(before + roundi(BASE_GAIN * mult), cap)
	c.mood = maxi(c.mood - MOOD_COST, 0)
	var result := {"gain": int(c.stats[stat]) - before, "trait": "", "moves": learn_moves(c, db)}
	if location and location.trains_trait:
		var t := location.trains_trait.id
		if not c.all_traits(db).has(t) and rng.randf() < location.trait_chance:
			c.traits.append(t)
			result["trait"] = String(t)
	return result


static func learn_moves(c: CreatureData, db: Db) -> Array[StringName]:
	var learned: Array[StringName] = []
	for u in db.species[c.species].moves:
		if u.move and not c.moves.has(u.move.id) and Stats.grade(c.stats[u.stat]) >= u.grade:
			c.moves.append(u.move.id)
			learned.append(u.move.id)
	return learned
