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
