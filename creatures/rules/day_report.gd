class_name DayReport
extends RefCounted
## What changed over one day, for the end-of-day summary: snapshots of the state compared. Pure rules, no scene; the
## Game takes the snapshots (each morning, and just before the evening resolves).


static func snapshot(state: GameState) -> Dictionary:
	var creatures := {}
	for c: CreatureData in state.creatures.values():
		creatures[c.id] = {"species": c.species, "stage": c.stage, "status": c.status, "stats": c.stats.duplicate(),
			"mood": c.mood, "traits": c.traits.duplicate(), "moves": c.moves.duplicate(), "injured": c.injured_days}
	return {"money": state.money, "reputation": state.reputation, "feed": int(state.inventory.get("feed", 0)),
		"creatures": creatures}


## The day from `morning` to `now`: {"totals": {"gold", "reputation", "feed"}, "creatures": [{"id", "changes"}]} with a
## row (in id order) only for creatures that changed. Mood comes from `before_evening`, because resting overnight
## raises everyone's mood and would otherwise show on every row.
static func compare(morning: Dictionary, before_evening: Dictionary, now: GameState, db: Db) -> Dictionary:
	var after := snapshot(now)
	var totals := {}
	for key in ["reputation", "feed"]:
		totals[key] = after[key] - morning[key]
	totals["gold"] = after["money"] - morning["money"]
	var rows: Array[Dictionary] = []
	var ids: Array = after["creatures"].keys()
	ids.sort()
	for id in ids:
		var changes := _changes(morning["creatures"].get(id), before_evening["creatures"].get(id),
			after["creatures"][id], db)
		if not changes.is_empty():
			rows.append({"id": id, "changes": changes})
	return {"totals": totals, "creatures": rows}


static func _changes(m: Variant, e: Variant, a: Dictionary, db: Db) -> PackedStringArray:
	var out := PackedStringArray()
	if m == null:  # bought, bred or found today
		if a["status"] != CreatureData.Status.GONE:
			out.append("New")
		return out
	if m["status"] == CreatureData.Status.GONE:
		return out
	if m["species"] != a["species"]:
		var sp: Species = db.species.get(a["species"])
		out.append("Evolved into %s!" % (sp.display_name if sp else String(a["species"]).capitalize()))
	if m["stage"] == "egg" and a["stage"] != "egg":
		out.append("Hatched!")
	if m["stage"] == "baby" and a["stage"] == "adult":
		out.append("Grew up!")
	for s in Stats.NAMES:
		var d: int = int(a["stats"].get(s, 0)) - int(m["stats"].get(s, 0))
		if d != 0:
			out.append("%s %+d" % [s.capitalize(), d])
	if e != null and e["mood"] != m["mood"]:
		out.append("Mood %+d" % (e["mood"] - m["mood"]))
	for t in a["traits"]:
		if not m["traits"].has(t):
			var def: TraitDef = db.traits.get(t)
			out.append("Gained %s" % (def.display_name if def else String(t).capitalize()))
	for mv in a["moves"]:
		if not m["moves"].has(mv):
			var def: MoveDef = db.moves.get(mv)
			out.append("Learned %s" % (def.display_name if def else String(mv).capitalize()))
	if m["injured"] == 0 and a["injured"] > 0:
		out.append("Injured")
	if m["status"] != a["status"]:
		out.append("Retired" if a["status"] == CreatureData.Status.RETIRED else "Left the shop")
	return out
