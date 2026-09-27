class_name Lifecycle
extends RefCounted
## End-of-day growth for one creature: eggs hatch, babies grow up, adults may evolve, cooldowns tick.
## Retired creatures are pickled: they never age or evolve, only their breeding cooldown ticks.
## Inspiration fires at hatch, at mid-growth and at adulthood. Returns events for the day summary.

const GROW_DAYS := 4  ## baby -> adult
const MID_DAYS := 2  ## days_left at the mid-growth inspiration


static func advance_day(c: CreatureData, db: Db, rng: RandomNumberGenerator) -> PackedStringArray:
	var events: PackedStringArray = []
	if c.status == CreatureData.Status.GONE:
		return events
	c.breed_cooldown = maxi(c.breed_cooldown - 1, 0)
	if c.status == CreatureData.Status.RETIRED:
		return events  # pickled: a retired creature only breeds, so only its breeding cooldown ticks
	c.age_days += 1
	match c.stage:
		"egg":
			c.days_left -= 1
			if c.days_left <= 0:
				c.stage = "baby"
				c.days_left = GROW_DAYS
				c.age_days = 0
				events.append(_event(c, db, "hatched", Inheritance.inspire(c, db, rng)))
		"baby":
			c.days_left -= 1
			if c.days_left <= 0:
				c.stage = "adult"
				events.append(_event(c, db, "grew up", Inheritance.inspire(c, db, rng)))
			elif c.days_left == MID_DAYS:
				events.append(_event(c, db, "is growing", Inheritance.inspire(c, db, rng)))
		"adult":
			var into := Evolution.check(c, db)
			if into:
				var was: String = db.species[c.species].display_name
				c.species = into.id
				events.append("%s #%d evolved into %s" % [was, c.id, into.display_name])
	return events


static func _event(c: CreatureData, db: Db, verb: String, procs: Array[Dictionary]) -> String:
	var text := "%s #%d %s" % [db.species[c.species].display_name, c.id, verb]
	if not procs.is_empty():
		var names := procs.map(func(p: Dictionary) -> String: return "%s %s" % [String(p["id"]).capitalize(), "★".repeat(p["stars"])])
		text += " — inspired by " + ", ".join(names)
	return text
