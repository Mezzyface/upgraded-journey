class_name Db
extends RefCounted
## Every content definition, indexed by id. load_dir() reads data/<kind>/*.tres, so a new .tres made in the
## editor is all it takes to add content. Definitions are read-only at runtime.

const FOLDERS: PackedStringArray = ["species", "traits", "moves", "personalities", "locations", "orders"]

var species: Dictionary[StringName, Species] = {}
var traits: Dictionary[StringName, TraitDef] = {}
var moves: Dictionary[StringName, MoveDef] = {}
var personalities: Dictionary[StringName, Personality] = {}
var locations: Dictionary[StringName, Location] = {}
var orders: Dictionary[StringName, OrderTemplate] = {}


static func load_dir(root := "res://data") -> Db:
	var db := Db.new()
	for sub in FOLDERS:
		var dir := root.path_join(sub)
		for file in ResourceLoader.list_directory(dir):
			if file.ends_with(".tres") or file.ends_with(".res"):
				var path := dir.path_join(file)
				var def: Resource = load(path)
				if def == null:
					push_error("Db: failed to load %s" % path)
					continue
				db.add(def)
	return db


func add(def: Resource) -> void:
	if def == null:
		push_error("Db: failed to load a definition")
		return
	var table: Dictionary
	if def is Species:
		table = species
	elif def is TraitDef:
		table = traits
	elif def is MoveDef:
		table = moves
	elif def is Personality:
		table = personalities
	elif def is Location:
		table = locations
	elif def is OrderTemplate:
		table = orders
	else:
		push_error("Db: %s is not a content definition" % def.resource_path)
		return
	var id: StringName = def.get("id")
	if id == &"":
		push_error("Db: %s has no id" % def.resource_path)
		return
	if table.has(id):
		push_error("Db: duplicate id '%s' (%s)" % [id, def.resource_path])
		return
	table[id] = def


func base_species(line: StringName) -> Species:
	for s: Species in species.values():
		if s.line == line and s.stage == 1:
			return s
	return null
