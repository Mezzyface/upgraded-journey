class_name GameState
extends RefCounted
## Everything that changes during play. Saved as versioned JSON in user://, never as .tres: loading a resource
## can run embedded scripts, and players share save files.

const SAVE_VERSION := 1
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


func new_id() -> int:
	next_id += 1
	return next_id - 1


func add(c: CreatureData) -> void:
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
	g.day = _int_field(d, "day", g.day)
	g.ap = _int_field(d, "ap", g.ap)
	g.money = _int_field(d, "money", g.money)
	g.reputation = _int_field(d, "reputation", g.reputation)
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
	return g


static func _int_field(d: Dictionary, key: String, def: int) -> int:
	var v: Variant = d.get(key, def)
	return int(v) if (v is int or v is float) else def


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
