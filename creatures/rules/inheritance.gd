class_name Inheritance
extends RefCounted
## Breeding, compatibility and inspiration. A child carries a pool of its parents' sparks (weight = compatibility
## multiplier) and grandparents' sparks (half that). At each inspiration (hatch, mid-growth, adulthood) every
## pooled spark procs with PROC_CHANCE[stars] x weight.

const HATCH_DAYS := 2
const COOLDOWN_DAYS := 3
const POTENTIAL_VARIANCE := 30
const MUTATION_CHANCE := 0.05
const EVOLVED_CHILD_CHANCE := 0.1
const GRANDPARENT_WEIGHT := 0.5
const COMPAT_MULT: PackedFloat32Array = [1.0, 1.25, 1.5]  ## index = compatibility()
const COMPAT_MARKS: PackedStringArray = ["△", "○", "◎"]
const PROC_CHANCE: PackedFloat32Array = [0.0, 0.2, 0.35, 0.5]  ## index = stars
const STAT_BOOST: PackedInt32Array = [0, 10, 20, 35]
const POTENTIAL_BOOST: PackedInt32Array = [0, 15, 30, 50]


## 0 = △, 1 = ○, 2 = ◎. Score: same line 2, same element 1, same egg group 1, shared sparks up to 2.
static func compatibility(a: CreatureData, b: CreatureData, db: Db) -> int:
	var sa: Species = db.species[a.species]
	var sb: Species = db.species[b.species]
	var score := 0
	if sa.line == sb.line:
		score += 2
	if sa.element == sb.element:
		score += 1
	if sa.egg_group == sb.egg_group:
		score += 1
	var shared := 0
	for x in a.sparks:
		for y in b.sparks:
			if x["kind"] == y["kind"] and x["id"] == y["id"]:
				shared += 1
	score += mini(shared, 2)
	if score >= 4:
		return 2
	return 1 if score >= 2 else 0


## "" when the pair can breed, otherwise the reason (shown in the breeding panel).
static func can_breed(a: CreatureData, b: CreatureData, db: Db) -> String:
	if a.id == b.id:
		return "needs two different creatures"
	for c in [a, b]:
		var name: String = db.species[c.species].display_name
		if c.status != CreatureData.Status.RETIRED:
			return "%s #%d is not in the breeding stable" % [name, c.id]
		if c.breed_cooldown > 0:
			return "%s #%d needs %d more days of rest" % [name, c.id, c.breed_cooldown]
	if db.species[a.species].egg_group != db.species[b.species].egg_group:
		return "their egg groups differ"
	return ""


static func breed(a: CreatureData, b: CreatureData, state: GameState, db: Db, rng: RandomNumberGenerator) -> CreatureData:
	var reason := can_breed(a, b, db)
	if reason != "":
		push_error("Inheritance.breed: " + reason)
		return null
	var picked: Species = db.species[(a if rng.randf() < 0.5 else b).species]
	var both_evolved: bool = db.species[a.species].stage > 1 and db.species[b.species].stage > 1
	var child_species := picked
	if not (both_evolved and rng.randf() < EVOLVED_CHILD_CHANCE):
		var base := db.base_species(picked.line)
		child_species = base if base else picked

	var c := CreatureData.new()
	c.id = state.new_id()
	c.species = child_species.id
	c.parents = PackedInt32Array([a.id, b.id])
	c.stage = "egg"
	c.days_left = HATCH_DAYS
	for s in Stats.NAMES:
		var p := roundi((int(a.potential[s]) + int(b.potential[s])) / 2.0)
		p += rng.randi_range(-POTENTIAL_VARIANCE, POTENTIAL_VARIANCE)
		if rng.randf() < MUTATION_CHANCE:
			p += rng.randi_range(50, 120)
		var cap := clampi(p, 0, Stats.MAX)
		c.potential[s] = cap
		c.stats[s] = roundi(cap * CreatureData.START_FRACTION)
	c.personality = (a if rng.randf() < 0.5 else b).personality

	var mult := COMPAT_MULT[compatibility(a, b, db)]
	for parent in [a, b]:
		_add_to_pool(c, parent.sparks, mult)
		for gp_id in parent.parents:
			var gp := state.get_creature(gp_id)
			if gp:
				_add_to_pool(c, gp.sparks, mult * GRANDPARENT_WEIGHT)
	a.breed_cooldown = COOLDOWN_DAYS
	b.breed_cooldown = COOLDOWN_DAYS
	state.add(c)
	return c


## Rolls every pooled spark once; returns the ones that procced.
static func inspire(c: CreatureData, db: Db, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var procs: Array[Dictionary] = []
	for sp in c.pool:
		var stars: int = sp["stars"]
		if rng.randf() >= PROC_CHANCE[stars] * float(sp["weight"]):
			continue
		procs.append(sp)
		var id: String = sp["id"]
		match sp["kind"]:
			"stat":
				c.potential[id] = mini(int(c.potential[id]) + POTENTIAL_BOOST[stars], Stats.MAX)
				c.stats[id] = mini(int(c.stats[id]) + STAT_BOOST[stars], int(c.potential[id]))
			"trait":
				if not c.traits.has(StringName(id)):
					c.traits.append(StringName(id))
			"move":
				if not c.moves.has(StringName(id)):
					c.moves.append(StringName(id))
			"personality":
				c.personality = StringName(id)
	c.inspirations += 1
	Training.learn_moves(c, db)
	return procs


static func _add_to_pool(child: CreatureData, sparks: Array[Dictionary], weight: float) -> void:
	for s in sparks:
		child.pool.append({"kind": s["kind"], "id": s["id"], "stars": s["stars"], "weight": weight})
