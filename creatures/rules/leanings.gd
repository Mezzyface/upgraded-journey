class_name Leanings
extends RefCounted
## Babies' personality leanings. Care and events add to them; when the creature grows up, the strongest
## leaning becomes its personality for good.

const SPARK_LEANING := 3  ## a personality spark's inspiration counts as this many leanings


static func add(c: CreatureData, personality: StringName, amount := 1) -> void:
	if c.stage != "baby":
		return
	var key := String(personality)
	c.leanings[key] = int(c.leanings.get(key, 0)) + amount


## Called once when a creature grows up. The strongest leaning wins; a tie or no leanings keeps the current
## personality; a creature with none gets a random one.
static func settle(c: CreatureData, db: Db, rng: RandomNumberGenerator) -> void:
	var best := ""
	var best_n := 0
	var tie := false
	for key: String in c.leanings:
		var n: int = c.leanings[key]
		if n > best_n:
			best = key
			best_n = n
			tie = false
		elif n == best_n and n > 0:
			tie = true
	if best != "" and not tie:
		c.personality = StringName(best)
	elif c.personality == &"":
		c.personality = random_personality(db, rng)


static func random_personality(db: Db, rng: RandomNumberGenerator) -> StringName:
	var ids: PackedStringArray = []
	for id: StringName in db.personalities:
		ids.append(String(id))
	if ids.is_empty():
		return &""
	ids.sort()  # independent of load order
	return StringName(ids[rng.randi() % ids.size()])
