class_name Fixtures
extends RefCounted
## In-code content for tests, independent of data/: a spider line with two evolution branches
## (Darksight -> Albino, Power B -> Large) and a slime line (Cheerful -> Antenna).


static func db() -> Db:
	var d := Db.new()
	var darksight := trait_def("darksight")
	var glowing := trait_def("glowing")
	var tunnel := trait_def("tunnel_wise")
	for t in [darksight, glowing, tunnel]:
		d.add(t)
	var bite := move_def("bite", "beast", "damaging")
	var web := move_def("web", "dark", "utility")
	var dig := move_def("dig", "earth", "damaging")
	for m in [bite, web, dig]:
		d.add(m)
	var cheerful := Personality.new()
	cheerful.id = &"cheerful"
	cheerful.favored_stat = "heart"
	var timid := Personality.new()
	timid.id = &"timid"
	timid.favored_stat = "speed"
	timid.disfavored_stat = "power"
	d.add(cheerful)
	d.add(timid)
	var mine := Location.new()
	mine.id = &"mine"
	mine.trains_trait = tunnel
	mine.trait_chance = 1.0
	d.add(mine)

	var albino := species("spider_albino", "spider", 2, "dark", "bug", [darksight])
	var large := species("spider_large", "spider", 2, "dark", "bug", [])
	var spider := species("spider", "spider", 1, "dark", "bug", [])
	spider.potential_speed = 300
	spider.moves.assign([unlock(bite, "power", Stats.Grade.D), unlock(web, "speed", Stats.Grade.C)])
	spider.evolutions.assign([
		evo(albino, "none", 0, darksight, null),
		evo(large, "power", Stats.Grade.B, null, null),
	])
	var antenna := species("slime_antenna", "slime", 2, "light", "amorphous", [glowing])
	var slime := species("slime", "slime", 1, "water", "amorphous", [])
	slime.evolutions.assign([evo(antenna, "none", 0, null, cheerful)])
	for s in [spider, albino, large, slime, antenna]:
		d.add(s)
	return d


static func trait_def(id: String) -> TraitDef:
	var t := TraitDef.new()
	t.id = StringName(id)
	t.display_name = id.capitalize()
	return t


static func move_def(id: String, element: String, kind: String) -> MoveDef:
	var m := MoveDef.new()
	m.id = StringName(id)
	m.display_name = id.capitalize()
	m.element = StringName(element)
	m.kind = kind
	return m


static func species(id: String, line: String, stage: int, element: String, egg_group: String, traits: Array) -> Species:
	var s := Species.new()
	s.id = StringName(id)
	s.display_name = id.capitalize()
	s.line = StringName(line)
	s.stage = stage
	s.element = StringName(element)
	s.egg_group = StringName(egg_group)
	s.natural_traits.assign(traits)
	return s


static func unlock(move: MoveDef, stat: String, grade: int) -> MoveUnlock:
	var u := MoveUnlock.new()
	u.move = move
	u.stat = stat
	u.grade = grade
	return u


static func evo(into: Species, stat: String, min_grade: int, required_trait: TraitDef, personality: Personality) -> EvolutionDef:
	var e := EvolutionDef.new()
	e.into = into
	e.stat = stat
	e.min_grade = min_grade
	e.required_trait = required_trait
	e.personality = personality
	return e


static func req(kind: String, id: String, min_grade := 0, generations := 2) -> Requirement:
	var r := Requirement.new()
	r.kind = kind
	r.id = StringName(id)
	r.min_grade = min_grade
	r.generations = generations
	return r


static func rng(seed_value := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r
