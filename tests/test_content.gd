extends TestSuite
## Integrity of the real content in data/. Runs against whatever the editor has saved.


func test_content_is_consistent() -> void:
	var db := Db.load_dir()
	check(db.species.size() >= 10, "at least 10 species (got %d)" % db.species.size())
	check(db.traits.size() >= 11, "at least 11 traits (got %d)" % db.traits.size())
	check(db.moves.size() >= 12, "at least 12 moves (got %d)" % db.moves.size())
	eq(db.personalities.size(), 5, "personalities")
	eq(db.locations.size(), 3, "locations")
	var lines := {}
	for sp: Species in db.species.values():
		check(sp.line != &"" and sp.element != &"" and sp.egg_group != &"", "%s: line, element, egg group set" % sp.id)
		if sp.stage == 1:
			check(not lines.has(sp.line), "%s: one stage-1 species per line" % sp.line)
			lines[sp.line] = true
		for s in Stats.NAMES:
			check(sp.potential(s) > 0 and sp.potential(s) <= Stats.MAX, "%s: %s potential in range" % [sp.id, s])
		for t in sp.natural_traits:
			check(t != null and db.traits.has(t.id), "%s: natural trait is in data/traits" % sp.id)
		for u in sp.moves:
			check(u != null and u.move != null and db.moves.has(u.move.id), "%s: move unlock points at data/moves" % sp.id)
		for e in sp.evolutions:
			check(e != null and e.into != null and db.species.has(e.into.id), "%s: evolution target exists" % sp.id)
			if e and e.into:
				eq(e.into.line, sp.line, "%s -> %s stays in its line" % [sp.id, e.into.id])
	for sp: Species in db.species.values():
		check(lines.has(sp.line), "%s: its line has a stage-1 species" % sp.id)
	for loc: Location in db.locations.values():
		check(loc.trains_trait != null and db.traits.has(loc.trains_trait.id), "%s: trains a known trait" % loc.id)


func test_some_species_branch() -> void:
	var db := Db.load_dir()
	check(db.species[&"spider"].evolutions.size() >= 2, "spider branches")
	check(db.species[&"green_golem"].evolutions.size() >= 2, "green golem branches")


func test_day_loop_content() -> void:
	var db := Db.load_dir()
	eq(db.upgrades.size(), 3, "upgrades")
	check(db.orders.size() >= 15, "order templates (got %d)" % db.orders.size())
	var kinds := {}
	for o: OrderTemplate in db.orders.values():
		check(not o.required.is_empty(), "%s has requirements" % o.id)
		for g in o.required + o.bonus:
			check(g != null and not g.any_of.is_empty(), "%s: no empty groups" % o.id)
			for r in (g.any_of if g else []):
				kinds[r.kind] = true
				check(_requirement_resolves(r, db), "%s: %s '%s' exists" % [o.id, r.kind, r.id])
	for k in ["species", "line", "stat", "trait", "move_element", "move_kind", "personality", "lineage"]:
		check(kinds.has(k), "some order asks for %s" % k)
	check(db.orders.values().filter(func(o: OrderTemplate) -> bool: return o.min_rep_tier == 0).size() >= 4,
		"at least 4 tier-0 orders")
	for o: OrderTemplate in db.orders.values():
		if o.min_rep_tier != 0:
			continue  # tier 1+ may expect stock on hand
		var needs_raising := false
		for g in o.required:
			for r in (g.any_of if g else []):
				if r.kind in ["species", "line", "lineage"]:
					needs_raising = true
		if needs_raising:
			check(OrderDifficulty.days(o, db) >= 7, "%s: an egg takes 6 days to raise; computed deadline >= 7" % o.id)
	for pair in [["sticky_helper", 4], ["first_pet", 9], ["help_me_mine", 7], ["spider_family", 19], ["albino_request", 13]]:
		eq(OrderDifficulty.days(db.orders[StringName(pair[0])], db), pair[1], "%s computed deadline" % pair[0])
	for loc: Location in db.locations.values():
		check(not loc.challenges.is_empty() and not loc.loot.is_empty(), "%s has challenges and loot" % loc.id)
		check(loc.money_min <= loc.money_max, "%s money range" % loc.id)
		for e in loc.loot:
			check(e != null and e.species != null and db.species.has(e.species.id), "%s loot species exists" % loc.id)
	check(db.locations[&"mine"].loot.any(func(e: LootEntry) -> bool: return e.species.id == &"spider_albino"),
		"the Mine can find Spider Albino")
	var setup: NewGameSetup = load("res://data/new_game.tres")
	check(setup != null and setup.species.size() == 3, "new game setup")
	check(setup.species.size() <= Market.PEN_BASE, "new game fits the starting pens")
	var sold := db.species.values().filter(func(s: Species) -> bool: return s.market_tier >= 0)
	eq(sold.size(), 5, "five species sold as eggs")
	for s: Species in sold:
		check(s.stage == 1 and s.market_price > 0, "%s is a base form with a price" % s.id)


func _requirement_resolves(r: Requirement, db: Db) -> bool:
	match r.kind:
		"species":
			return db.species.has(r.id)
		"trait":
			return db.traits.has(r.id)
		"personality":
			return db.personalities.has(r.id)
		"line", "lineage":
			return db.species.values().any(func(s: Species) -> bool: return s.line == r.id)
		"stat":
			return Stats.NAMES.has(String(r.id))
		"move_kind":
			return r.id in [&"damaging", &"utility"]
		"move_element":
			return db.moves.values().any(func(m: MoveDef) -> bool: return m.element == r.id)
	return false
