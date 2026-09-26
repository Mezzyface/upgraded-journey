class_name Orders
extends RefCounted
## Checks a creature against an order: every required group must pass (a group passes when any of its
## requirements does). Only owned adults can be delivered.


static func check(c: CreatureData, order: OrderTemplate, db: Db, state: GameState) -> Dictionary:
	var missing: PackedStringArray = []
	if c.status == CreatureData.Status.RETIRED:
		missing.append("retired creatures stay in the breeding stable")
	elif c.status == CreatureData.Status.GONE:
		missing.append("no longer in the shop")
	elif c.stage != "adult":
		missing.append("must be grown up")
	if not missing.is_empty():
		return {"ok": false, "bonus": false, "missing": missing}
	for g in order.required:
		if not group_met(c, g, db, state):
			missing.append(g.describe())
	var ok := missing.is_empty()
	var bonus := ok and not order.bonus.is_empty() and order.bonus.all(
		func(g: RequirementGroup) -> bool: return group_met(c, g, db, state))
	return {"ok": ok, "bonus": bonus, "missing": missing}


static func group_met(c: CreatureData, g: RequirementGroup, db: Db, state: GameState) -> bool:
	return g.any_of.any(func(r: Requirement) -> bool: return r != null and met(c, r, db, state))


static func met(c: CreatureData, r: Requirement, db: Db, state: GameState) -> bool:
	var sp: Species = db.species[c.species]
	match r.kind:
		"species":
			return c.species == r.id
		"line":
			return sp.line == r.id
		"stat":
			return Stats.grade(c.stats[String(r.id)]) >= r.min_grade
		"trait":
			return c.all_traits(db).has(r.id)
		"move_element":
			return c.moves.any(func(m: StringName) -> bool: return db.moves.has(m) and db.moves[m].element == r.id)
		"move_kind":
			return c.moves.any(func(m: StringName) -> bool: return db.moves.has(m) and db.moves[m].kind == String(r.id))
		"personality":
			return c.personality == r.id
		"lineage":
			return lineage(c, r.id, r.generations, db, state)
	return false


## True when `c` and every recorded ancestor up to `generations` (c = 1) belong to `line`. Both parents must be
## on record for each generation checked.
static func lineage(c: CreatureData, line: StringName, generations: int, db: Db, state: GameState) -> bool:
	if c == null or not db.species.has(c.species) or db.species[c.species].line != line:
		return false
	if generations <= 1:
		return true
	if c.parents.size() < 2:
		return false
	for pid in c.parents:
		if not lineage(state.get_creature(pid), line, generations - 1, db, state):
			return false
	return true
