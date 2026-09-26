class_name Evolution
extends RefCounted
## Branching evolution: a species lists branches; the first whose conditions an adult meets wins.


static func check(c: CreatureData, db: Db) -> Species:
	if c.stage != "adult":
		return null
	for evo in db.species[c.species].evolutions:
		if evo and evo.into and db.species.has(evo.into.id) and met(c, evo, db):
			return db.species[evo.into.id]
	return null


static func met(c: CreatureData, evo: EvolutionDef, db: Db) -> bool:
	if evo.stat != "none" and Stats.grade(c.stats[evo.stat]) < evo.min_grade:
		return false
	if evo.required_trait and not c.all_traits(db).has(evo.required_trait.id):
		return false
	if evo.personality and c.personality != evo.personality.id:
		return false
	return c.age_days >= evo.min_age_days
