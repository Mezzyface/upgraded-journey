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


const STAGES: PackedStringArray = ["egg", "baby", "adult"]
const SPARK_KINDS: PackedStringArray = ["stat", "trait", "move", "personality"]


## Saves are untrusted (players share them). Returns null for a record whose type Godot can't coerce
## safely -- a hand-edited or corrupted field, not just an unknown id -- so the caller can skip just this
## creature instead of the whole load aborting on a script error.
static func from_dict(d: Dictionary) -> CreatureData:
	var id_v: Variant = d.get("id", 0)
	if not _is_num(id_v):
		return null
	var status_v: Variant = d.get("status", Status.OWNED)
	if not _is_num(status_v) or not [Status.OWNED, Status.RETIRED, Status.GONE].has(int(status_v)):
		return null
	var stage_v: Variant = d.get("stage", "adult")
	if stage_v is not String or not STAGES.has(stage_v):
		return null
	var pot_v: Variant = d.get("potential", {})
	var sts_v: Variant = d.get("stats", {})
	if pot_v is not Dictionary or sts_v is not Dictionary:
		return null
	var parents_v: Variant = d.get("parents", [])
	if parents_v is not Array:
		return null

	var c := CreatureData.new()
	c.id = int(id_v)
	c.species = StringName(str(d.get("species", "")))
	for p in parents_v:
		if c.parents.size() >= 2:  # at most 2 parents kept
			break
		if _is_num(p):
			c.parents.append(int(p))
	c.status = int(status_v) as Status
	c.stage = stage_v
	c.days_left = maxi(_num(d.get("days_left", 0)), 0)
	c.age_days = maxi(_num(d.get("age_days", 0)), 0)
	for s in Stats.NAMES:
		var cap := clampi(_num(pot_v.get(s, 0)), 0, Stats.MAX)
		c.potential[s] = cap
		c.stats[s] = clampi(mini(_num(sts_v.get(s, 0)), cap), 0, Stats.MAX)
	var traits_v: Variant = d.get("traits", [])
	for t in (traits_v if traits_v is Array else []):
		c.traits.append(StringName(str(t)))
	var moves_v: Variant = d.get("moves", [])
	for m in (moves_v if moves_v is Array else []):
		c.moves.append(StringName(str(m)))
	c.personality = StringName(str(d.get("personality", "")))
	c.mood = clampi(_num(d.get("mood", 50)), 0, 100)
	c.breed_cooldown = maxi(_num(d.get("breed_cooldown", 0)), 0)
	c.sparks = _sparks_from(d.get("sparks", []), false)
	c.pool = _sparks_from(d.get("pool", []), true)
	c.inspirations = maxi(_num(d.get("inspirations", 0)), 0)
	return c


static func _is_num(v: Variant) -> bool:
	return v is int or v is float


## Reads v as an int, falling back to def when v isn't numeric (e.g. a string or null from a hand-edited save).
static func _num(v: Variant, def: int = 0) -> int:
	return int(v) if _is_num(v) else def


## kind must be one of SPARK_KINDS and id a String (a stat spark's id must also be a known stat); anything
## else is dropped. Pool entries missing "weight" default to 1.0 (Inheritance.inspire always reads it);
## locked sparks keep the "no weight" shape they're saved with.
static func _sparks_from(list: Variant, is_pool: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if list is not Array:
		return out
	for s in list:
		if s is not Dictionary:
			continue
		var kind_v: Variant = s.get("kind")
		if kind_v is not String or not SPARK_KINDS.has(kind_v):
			continue
		var id_v: Variant = s.get("id")
		if id_v is not String:
			continue
		if kind_v == "stat" and not Stats.NAMES.has(id_v):
			continue
		var e := {"kind": kind_v, "id": id_v, "stars": clampi(_num(s.get("stars"), 1), 1, 3)}
		var weight_v: Variant = s.get("weight")
		if is_pool:
			e["weight"] = float(weight_v) if _is_num(weight_v) else 1.0
		elif _is_num(weight_v):
			e["weight"] = float(weight_v)
		out.append(e)
	return out
