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
		"creatures": creatures.values().map(func(c: CreatureData) -> Dictionary: return c.to_dict()),
	}


## Creatures whose species no longer exists in `db` are skipped with a warning, so removing content never
## makes an old save unloadable.
static func from_dict(d: Dictionary, db: Db) -> GameState:
	var g := GameState.new()
	g.day = int(d.get("day", 1))
	g.ap = int(d.get("ap", START_AP))
	g.money = int(d.get("money", 0))
	g.reputation = int(d.get("reputation", 0))
	g.next_id = int(d.get("next_id", 1))
	for cd in d.get("creatures", []):
		if cd is not Dictionary:
			continue
		var c := CreatureData.from_dict(cd)
		if not db.species.has(c.species):
			push_warning("save: creature #%d has unknown species '%s'; skipped" % [c.id, c.species])
			continue
		g.creatures[c.id] = c
	return g


## Writes to a temp file first, then renames, so a crash mid-write never destroys the previous save.
func save(path := SAVE_PATH) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, path)


## Returns null (with a warning) when the file is missing, not valid JSON, or from an unsupported version.
static func load_file(db: Db, path := SAVE_PATH) -> GameState:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		push_warning("save: %s is not valid JSON" % path)
		return null
	var version := int(data.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		push_warning("save: %s has unsupported version %d" % [path, version])
		return null
	return from_dict(data, db)
