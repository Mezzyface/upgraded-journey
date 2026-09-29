class_name Build
extends RefCounted
## Placing buildables (pens) on the farm grid. The farm supplies which cells are buildable (its %Buildable layer),
## so these rules need no scene. Placed buildables live in GameState.placed as {"id", "def", "cell"}.


## "" or why `def_id` can't go at `cell` (its top-left tile): checks money, then ground, then overlap.
static func can_place(state: GameState, db: Db, def_id: StringName, cell: Vector2i, buildable: Dictionary) -> String:
	var def: BuildableDef = db.buildables.get(def_id)
	if def == null:
		return "nothing like that to build"
	if state.money < def.cost:
		return "not enough money"
	for x in def.footprint.x:
		for y in def.footprint.y:
			if not buildable.has(cell + Vector2i(x, y)):
				return "can't build there"
	var rect := Rect2i(cell, def.footprint)
	for p in state.placed:
		var other: BuildableDef = db.buildables.get(p["def"])
		if other and rect.intersects(Rect2i(p["cell"], other.footprint)):
			return "overlaps the %s" % other.display_name.to_lower()
	return ""


static func place(state: GameState, db: Db, def_id: StringName, cell: Vector2i, buildable: Dictionary) -> String:
	var reason := can_place(state, db, def_id, cell, buildable)
	if reason != "":
		return reason
	var def: BuildableDef = db.buildables[def_id]
	state.money -= def.cost
	place_free(state, def, cell)
	return ""


## Adds `def` at `cell` without checks or payment (the starting pen). Returns its placed id.
static func place_free(state: GameState, def: BuildableDef, cell: Vector2i) -> int:
	var id := state.next_placed_id
	state.next_placed_id += 1
	state.placed.append({"id": id, "def": def.id, "cell": cell})
	return id


## Creatures living in pen `placed_id` (retired ones included: they keep their slot).
static func pen_used(state: GameState, placed_id: int) -> int:
	return state.creatures.values().filter(func(c: CreatureData) -> bool:
		return c.pen == placed_id and c.status != CreatureData.Status.GONE).size()


## The first placed pen (in placing order) with room, or -1.
static func first_pen_with_room(state: GameState, db: Db) -> int:
	for p in state.placed:
		var def: BuildableDef = db.buildables.get(p["def"])
		if def and def.capacity > 0 and pen_used(state, p["id"]) < def.capacity:
			return p["id"]
	return -1


## Saves from before pens were placed get the starting pen, and every creature without a pen goes into the first pen
## with room, or the last pen when all are full, so nobody is lost. A no-op once anything is placed.
static func migrate(state: GameState, db: Db, setup: NewGameSetup) -> void:
	if not state.placed.is_empty() or setup.start_pen == null:
		return
	place_free(state, setup.start_pen, setup.start_pen_cell)
	for c: CreatureData in state.creatures.values():
		if c.pen < 0 and c.status != CreatureData.Status.GONE:
			var p := first_pen_with_room(state, db)
			c.pen = p if p >= 0 else state.placed[-1]["id"]
