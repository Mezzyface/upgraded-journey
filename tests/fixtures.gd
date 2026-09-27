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
	for pid in ["gentle", "bold", "stubborn"]:
		var p := Personality.new()
		p.id = StringName(pid)
		d.add(p)
	slime.market_price = 60
	slime.market_tier = 0
	spider.market_price = 90
	spider.market_tier = 1
	var cave := Location.new()
	cave.id = &"cave"
	cave.display_name = "Cave"
	cave.challenges.assign([group([req("trait", "darksight")]), group([req("stat", "guard", Stats.Grade.C)])])
	cave.loot.assign([loot(albino, 1), loot(spider, 9)])
	cave.money_min = 10
	cave.money_max = 20
	d.add(cave)
	d.add(order("t0_slime", 0, [group([req("line", "slime")])], [], 80, 3, 0))
	d.add(order("t0_power", 0, [group([req("stat", "power", Stats.Grade.D)])],
		[group([req("stat", "power", Stats.Grade.C)])], 100, 4, 0))
	d.add(order("t1_dark", 1, [group([req("trait", "darksight")])], [], 200, 8, 0))
	d.add(upgrade("extra_pen", 300, 0))
	d.add(upgrade("extra_ap", 400, 1))
	d.add(upgrade("gene_scanner", 500, 1))
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


## An adult of `species_id` with every stat at `stat` and every potential at `cap`, added to `state`.
static func adult(state: GameState, species_id: String, stat := 200, cap := 500) -> CreatureData:
	var c := CreatureData.new()
	c.id = state.new_id()
	c.species = StringName(species_id)
	for s in Stats.NAMES:
		c.stats[s] = stat
		c.potential[s] = cap
	state.add(c)
	return c


static func group(reqs: Array) -> RequirementGroup:
	var g := RequirementGroup.new()
	g.any_of.assign(reqs)
	return g


static func loot(sp: Species, weight: int) -> LootEntry:
	var e := LootEntry.new()
	e.species = sp
	e.weight = weight
	return e


static func order(id: String, tier: int, required: Array, bonus: Array, money: int, rep: int, extra_days: int) -> OrderTemplate:
	var o := OrderTemplate.new()
	o.id = StringName(id)
	o.customer = id.capitalize()
	o.min_rep_tier = tier
	o.required.assign(required)
	o.bonus.assign(bonus)
	o.reward_money = money
	o.bonus_money = 50
	o.reward_rep = rep
	o.extra_days = extra_days
	return o


static func upgrade(id: String, cost: int, tier: int) -> UpgradeDef:
	var u := UpgradeDef.new()
	u.id = StringName(id)
	u.display_name = id.capitalize()
	u.cost = cost
	u.min_tier = tier
	return u
