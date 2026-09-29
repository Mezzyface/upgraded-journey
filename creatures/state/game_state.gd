class_name GameState
extends RefCounted
## Everything that changes during play. Saved as versioned JSON in user://, never as .tres: loading a resource
## can run embedded scripts, and players share save files.

const SAVE_VERSION := 2
const SAVE_PATH := "user://save.json"
const START_AP := 5

var day := 1
var ap := START_AP
var money := 500
var reputation := 0
var next_id := 1
var creatures: Dictionary[int, CreatureData] = {}  ## every creature ever owned; GONE ones stay for pedigrees
var orphans: Array[Dictionary] = []  ## raw records that failed to load (unknown species, malformed); kept
## as-is and written back out on save so a later content fix or re-import can bring them back
var board: Array[StringName] = []  ## template ids offered this morning
var orders: Array[Dictionary] = []  ## accepted: {"template": String, "deadline_day": int}
var recent_templates: Array[StringName] = []  ## last offered, newest last (OrderBoard.RECENT_LIMIT)
var inventory := {}  ## item id (String) -> count; only "feed" for now
var upgrades: Array[StringName] = []
var expeditions: Array[Dictionary] = []  ## sent today, resolved in the evening: {"location": String, "team": Array}
var busy: Array[int] = []  ## creature ids away on an expedition for the rest of the day
var cared: Array[int] = []  ## creature ids cared for today
var placed: Array[Dictionary] = []  ## buildables on the farm, in placing order: {"id": int, "def": StringName, "cell": Vector2i}
var next_placed_id := 1
var content: Db  ## the game content, for pen capacities; set by Day.new_game and from_dict, never saved


func new_id() -> int:
	next_id += 1
	return next_id - 1


## Every new creature comes through here and moves into the first pen with room (Build); with no content (a bare
## GameState in tests) it stays at pen -1.
func add(c: CreatureData) -> void:
	if c.pen < 0 and content != null:
		c.pen = Build.first_pen_with_room(self, content)
	creatures[c.id] = c


func get_creature(id: int) -> CreatureData:
	return creatures.get(id)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"day": day,
		"ap": ap,
		"money": money,
		"reputation": reputation,
		"next_id": next_id,
		"creatures": creatures.values().map(func(c: CreatureData) -> Dictionary: return c.to_dict()) + orphans.duplicate(true),
		"board": Array(board).map(func(id: StringName) -> String: return String(id)),
		"orders": orders.duplicate(true),
		"recent_templates": Array(recent_templates).map(func(id: StringName) -> String: return String(id)),
		"inventory": inventory.duplicate(),
		"upgrades": Array(upgrades).map(func(id: StringName) -> String: return String(id)),
		"expeditions": expeditions.duplicate(true),
		"busy": busy.duplicate(),
		"cared": cared.duplicate(),
		"placed": placed.map(func(p: Dictionary) -> Dictionary:
			return {"id": p["id"], "def": String(p["def"]), "x": p["cell"].x, "y": p["cell"].y}),
		"next_placed_id": next_placed_id,
	}


## Creatures whose species no longer exists in `db`, or whose record has a type a save shouldn't have
## (hand-edited or corrupted), are skipped with a warning -- never fatal to the rest of the load. A
## non-Array "creatures" is itself invalid: returns null rather than silently loading nothing.
static func from_dict(d: Dictionary, db: Db) -> GameState:
	var creatures_v: Variant = d.get("creatures", [])
	if creatures_v is not Array:
		push_warning("save: 'creatures' is not a list; save not loaded")
		return null
	var g := GameState.new()
	g.content = db
	g.day = maxi(_int_field(d, "day", g.day), 1)
	g.ap = clampi(_int_field(d, "ap", g.ap), 0, Day.BASE_AP + 1)
	g.money = maxi(_int_field(d, "money", g.money), 0)
	g.reputation = maxi(_int_field(d, "reputation", g.reputation), 0)
	g.next_id = _int_field(d, "next_id", g.next_id)
	var highest_id := 0
	for cd in creatures_v:
		if cd is not Dictionary:
			push_warning("save: a creature record is not an object; skipped")
			continue
		var c := CreatureData.from_dict(cd)
		var raw_id: Variant = cd.get("id")
		if raw_id is int or raw_id is float:
			highest_id = maxi(highest_id, int(raw_id))  # orphans keep their id reserved too
		if c == null:
			push_warning("save: a creature record has invalid fields; skipped")
			g.orphans.append(cd)
			continue
		if not db.species.has(c.species):
			push_warning("save: creature #%d has unknown species '%s'; skipped" % [c.id, c.species])
			g.orphans.append(cd)
			continue
		g.creatures[c.id] = c
		highest_id = maxi(highest_id, c.id)
	g.next_id = maxi(g.next_id, highest_id + 1)  # never reuse an id, even if the saved next_id fell behind
	g.board = _known_ids(d.get("board", []), db.orders)
	g.recent_templates = _known_ids(d.get("recent_templates", []), db.orders, false)  # legitimately repeats: the
	## same template can be re-offered on non-consecutive mornings while still inside the last RECENT_LIMIT
	g.upgrades = _known_ids(d.get("upgrades", []), db.upgrades)
	for o in _list(d.get("orders", [])):
		if o is Dictionary and o.get("template") is String and db.orders.has(StringName(o["template"])) \
				and CreatureData._is_num(o.get("deadline_day")):
			g.orders.append({"template": o["template"], "deadline_day": int(o["deadline_day"])})
	var inv: Variant = d.get("inventory", {})
	if inv is Dictionary:
		for k in inv:
			if k is String and CreatureData._is_num(inv[k]):
				g.inventory[k] = maxi(int(inv[k]), 0)
	for e in _list(d.get("expeditions", [])):
		if e is not Dictionary or e.get("location") is not String or not db.locations.has(StringName(e["location"])):
			continue
		var team: Array = []
		for t in _list(e.get("team", [])):
			if CreatureData._is_num(t) and g.creatures.has(int(t)) and not team.has(int(t)):
				team.append(int(t))
		if not team.is_empty():
			g.expeditions.append({"location": e["location"], "team": team})
	var highest_placed := 0
	for p in _list(d.get("placed", [])):
		if p is Dictionary and p.get("def") is String and db.buildables.has(StringName(p["def"])) \
				and CreatureData._is_num(p.get("id")) and CreatureData._is_num(p.get("x")) \
				and CreatureData._is_num(p.get("y")):
			g.placed.append({"id": int(p["id"]), "def": StringName(p["def"]), "cell": Vector2i(int(p["x"]), int(p["y"]))})
			highest_placed = maxi(highest_placed, int(p["id"]))
	g.next_placed_id = maxi(_int_field(d, "next_placed_id", g.next_placed_id), highest_placed + 1)
	g.busy = _known_creatures(d.get("busy", []), g)
	g.cared = _known_creatures(d.get("cared", []), g)
	return g


static func _int_field(d: Dictionary, key: String, def: int) -> int:
	var v: Variant = d.get(key, def)
	return int(v) if (v is int or v is float) else def


static func _list(v: Variant) -> Array:
	return v if v is Array else []


static func _known_ids(v: Variant, table: Dictionary, dedupe := true) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _list(v):
		if id is String and table.has(StringName(id)) and not (dedupe and out.has(StringName(id))):
			out.append(StringName(id))
	return out


static func _known_creatures(v: Variant, g: GameState) -> Array[int]:
	var out: Array[int] = []
	for id in _list(v):
		if CreatureData._is_num(id) and g.creatures.has(int(id)) and not out.has(int(id)):
			out.append(int(id))
	return out


## Writes to a temp file first, then renames, so a crash mid-write never destroys the previous save. If the
## write itself fails (e.g. disk full), the temp file is removed and the good save is never touched.
func save(path := SAVE_PATH) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	var write_err := f.get_error()
	f.close()
	if write_err != OK:
		DirAccess.remove_absolute(tmp)
		return write_err
	return DirAccess.rename_absolute(tmp, path)


## Returns null (with a warning) when the file is missing, not valid JSON, or from an unsupported version.
static func load_file(db: Db, path := SAVE_PATH) -> GameState:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		push_warning("save: %s is not valid JSON" % path)
		return null
	var version_v: Variant = data.get("version", 0)
	if version_v is not int and version_v is not float:
		push_warning("save: %s has a non-numeric version" % path)
		return null
	var version := int(version_v)
	if version < 1 or version > SAVE_VERSION:
		push_warning("save: %s has unsupported version %d" % [path, version])
		return null
	return from_dict(data, db)
