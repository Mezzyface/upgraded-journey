class_name CreatureData
extends RefCounted
## One individual creature: runtime state, saved as JSON. Content is referenced by id.
## GONE creatures (delivered or sold) are kept as records so pedigrees survive.

enum Status { OWNED, RETIRED, GONE }

const START_FRACTION := 0.2  ## a new creature starts with stats at 20% of its potential

var id := 0
var species: StringName
var parents: PackedInt32Array = []  ## empty for wild or bought creatures
var status := Status.OWNED
var stage := "adult"  ## "egg", "baby" or "adult"
var days_left := 0  ## egg: days to hatch; baby: days to adulthood
var age_days := 0  ## days since hatching
var potential := {}  ## stat name -> cap
var stats := {}  ## stat name -> value
var traits: Array[StringName] = []  ## learned and inherited; natural ones come from the species
var moves: Array[StringName] = []
var personality: StringName
var mood := 50
var breed_cooldown := 0
var sparks: Array[Dictionary] = []  ## locked on retire: {kind, id, stars}
var pool: Array[Dictionary] = []  ## inherited sparks waiting for inspiration: {kind, id, stars, weight}
var inspirations := 0


static func wild(sp: Species, new_id: int, rng: RandomNumberGenerator) -> CreatureData:
	var c := CreatureData.new()
	c.id = new_id
	c.species = sp.id
	for s in Stats.NAMES:
		var cap := clampi(roundi(sp.potential(s) * rng.randf_range(0.9, 1.1)), 0, Stats.MAX)
		c.potential[s] = cap
		c.stats[s] = roundi(cap * START_FRACTION)
	return c


func all_traits(db: Db) -> Array[StringName]:
	var out: Array[StringName] = traits.duplicate()
	for t in db.species[species].natural_traits:
		if t and not out.has(t.id):
			out.append(t.id)
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"species": String(species),
		"parents": Array(parents),
		"status": status,
		"stage": stage,
		"days_left": days_left,
		"age_days": age_days,
		"potential": potential.duplicate(),
		"stats": stats.duplicate(),
		"traits": Array(traits).map(func(t: StringName) -> String: return String(t)),
		"moves": Array(moves).map(func(m: StringName) -> String: return String(m)),
		"personality": String(personality),
		"mood": mood,
		"breed_cooldown": breed_cooldown,
		"sparks": sparks.duplicate(true),
		"pool": pool.duplicate(true),
		"inspirations": inspirations,
	}


static func from_dict(d: Dictionary) -> CreatureData:
	var c := CreatureData.new()
	c.id = int(d.get("id", 0))
	c.species = StringName(str(d.get("species", "")))
	for p in d.get("parents", []):
		c.parents.append(int(p))
	c.status = int(d.get("status", Status.OWNED)) as Status
	c.stage = str(d.get("stage", "adult"))
	c.days_left = int(d.get("days_left", 0))
	c.age_days = int(d.get("age_days", 0))
	var pot: Dictionary = d.get("potential", {})
	var sts: Dictionary = d.get("stats", {})
	for s in Stats.NAMES:
		c.potential[s] = int(pot.get(s, 0))
		c.stats[s] = int(sts.get(s, 0))
	for t in d.get("traits", []):
		c.traits.append(StringName(str(t)))
	for m in d.get("moves", []):
		c.moves.append(StringName(str(m)))
	c.personality = StringName(str(d.get("personality", "")))
	c.mood = int(d.get("mood", 50))
	c.breed_cooldown = int(d.get("breed_cooldown", 0))
	c.sparks = _sparks_from(d.get("sparks", []))
	c.pool = _sparks_from(d.get("pool", []))
	c.inspirations = int(d.get("inspirations", 0))
	return c


static func _sparks_from(list: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if list is not Array:
		return out
	for s in list:
		if s is not Dictionary:
			continue
		var e := {"kind": str(s.get("kind", "")), "id": str(s.get("id", "")), "stars": clampi(int(s.get("stars", 1)), 1, 3)}
		if s.has("weight"):
			e["weight"] = float(s["weight"])
		out.append(e)
	return out
