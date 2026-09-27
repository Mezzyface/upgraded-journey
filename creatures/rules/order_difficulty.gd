class_name OrderDifficulty
extends RefCounted
## How many days a customer gives for an order: BASE_DAYS + the cost of each required group (a group passes when
## any of its requirements does, so it costs its cheapest one) + the template's extra_days. Bonus groups don't count.

const BASE_DAYS := 3
const RAISE_DAYS := 6  ## a species or line you'd have to raise from an egg (2 days to hatch + 4 to grow)
const EVOLVED_DAYS := 4  ## on top of RAISE_DAYS when the species is an evolved form
const LINEAGE_DAYS_PER_GENERATION := 8
const STAT_DAYS: PackedInt32Array = [0, 1, 2, 4, 6, 8]  ## by grade E..S
const COMMON_TRAIT_DAYS := 1  ## some stage-1 species has the trait naturally
const RARE_TRAIT_DAYS := 3
const MOVE_DAYS := 1
const PERSONALITY_DAYS := 2


static func days(order: OrderTemplate, db: Db) -> int:
	var total := BASE_DAYS + order.extra_days
	for g in order.required:
		if g == null:
			continue
		var cheapest := -1
		for r in g.any_of:
			if r == null:
				continue
			var d := requirement_days(r, db)
			if cheapest < 0 or d < cheapest:
				cheapest = d
		total += maxi(cheapest, 0)
	return total


static func requirement_days(r: Requirement, db: Db) -> int:
	match r.kind:
		"species":
			var sp: Species = db.species.get(r.id)
			return RAISE_DAYS + (EVOLVED_DAYS if sp and sp.stage > 1 else 0)
		"line":
			return RAISE_DAYS
		"lineage":
			return LINEAGE_DAYS_PER_GENERATION * r.generations
		"stat":
			return STAT_DAYS[clampi(r.min_grade, 0, STAT_DAYS.size() - 1)]
		"trait":
			return COMMON_TRAIT_DAYS if _natural_on_a_base_species(r.id, db) else RARE_TRAIT_DAYS
		"move_element", "move_kind":
			return MOVE_DAYS
		"personality":
			return PERSONALITY_DAYS
	return 0


static func _natural_on_a_base_species(trait_id: StringName, db: Db) -> bool:
	for s: Species in db.species.values():
		if s.stage == 1 and s.natural_traits.any(func(t: TraitDef) -> bool: return t != null and t.id == trait_id):
			return true
	return false
