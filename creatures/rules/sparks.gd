class_name Sparks
extends RefCounted
## Rolls a creature's sparks when it retires to the breeding stable (Uma Musume-style inheritance factors).
## Each spark is {kind: "stat"|"trait"|"move"|"personality", id: String, stars: 1..3}.


static func roll(c: CreatureData, db: Db, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var best: String = Stats.NAMES[0]
	for s in Stats.NAMES:
		if int(c.stats[s]) > int(c.stats[best]):
			best = s
	var g := Stats.grade(c.stats[best])
	out.append({"kind": "stat", "id": best, "stars": 1 + int(g >= Stats.Grade.B) + int(g >= Stats.Grade.S)})
	for t in c.all_traits(db):
		out.append({"kind": "trait", "id": String(t), "stars": rng.randi_range(1, 3)})
	if not c.moves.is_empty():
		out.append({"kind": "move", "id": String(c.moves[rng.randi() % c.moves.size()]), "stars": rng.randi_range(1, 3)})
	if c.personality != &"":
		out.append({"kind": "personality", "id": String(c.personality), "stars": rng.randi_range(1, 3)})
	return out


static func retire(c: CreatureData, db: Db, rng: RandomNumberGenerator) -> void:
	c.sparks = roll(c, db, rng)
	c.status = CreatureData.Status.RETIRED
