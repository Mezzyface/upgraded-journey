extends TestSuite


func test_fixture_db_indexes_by_id() -> void:
	var db := Fixtures.db()
	eq(db.species.size(), 5, "species count")
	eq(db.species[&"spider"].evolutions.size(), 2, "spider has two evolution branches")
	eq(db.base_species(&"spider").id, &"spider", "base of spider line")
	eq(db.base_species(&"slime").id, &"slime", "base of slime line")
	check(db.base_species(&"nope") == null, "unknown line has no base")
	eq(db.traits[&"darksight"].display_name, "Darksight", "trait name")
	eq(db.species[&"spider"].potential("speed"), 300, "potential() reads potential_speed")


func test_duplicate_id_keeps_first() -> void:
	var db := Db.new()
	var a := Fixtures.trait_def("x")
	var b := Fixtures.trait_def("x")
	b.display_name = "second"
	db.add(a)
	db.add(b)  # logs "duplicate id" error by design
	eq(db.traits[&"x"].display_name, "X", "first definition kept")


func test_load_dir_reads_tres_files() -> void:
	var dir := "user://test_data/traits"
	DirAccess.make_dir_recursive_absolute(dir)
	ResourceSaver.save(Fixtures.trait_def("glowing"), dir.path_join("glowing.tres"))
	var db := Db.load_dir("user://test_data")
	check(db.traits.has(&"glowing"), "loaded user://test_data/traits/glowing.tres")
	eq(db.species.size(), 0, "missing folders are fine")


func test_add_null_does_not_error() -> void:
	var db := Db.new()
	db.add(null)  # e.g. a definition whose art failed to load on a fresh clone; logs "failed to load" by design
	eq(db.species.size(), 0, "nothing added")


func test_requirement_descriptions() -> void:
	var g := RequirementGroup.new()
	g.any_of.assign([Fixtures.req("move_element", "earth"), Fixtures.req("move_kind", "damaging")])
	eq(g.describe(), "Earth move or damaging move", "group")
	eq(Fixtures.req("stat", "power", Stats.Grade.B).describe(), "Power ≥ B", "stat")
	eq(Fixtures.req("trait", "darksight").describe(), "Darksight", "trait")
	eq(Fixtures.req("lineage", "spider", 0, 3).describe(), "3 generations of Spider", "lineage")


func test_new_definitions_and_fields() -> void:
	var db := Fixtures.db()
	eq(db.upgrades.size(), 3, "upgrades indexed")
	eq(db.upgrades[&"extra_ap"].min_tier, 1, "upgrade fields")
	eq(db.orders.size(), 3, "order templates indexed")
	var cave: Location = db.locations[&"cave"]
	eq(cave.challenges.size(), 2, "challenges")
	eq(cave.loot[0].species.id, &"spider_albino", "loot species")
	eq(db.species[&"slime"].market_tier, 0, "market tier")
	eq(db.species[&"spider_large"].market_tier, -1, "not sold by default")


func test_load_dir_reads_upgrades() -> void:
	var dir := "user://test_data/upgrades"
	DirAccess.make_dir_recursive_absolute(dir)
	ResourceSaver.save(Fixtures.upgrade("extra_pen", 300, 0), dir.path_join("extra_pen.tres"))
	check(Db.load_dir("user://test_data").upgrades.has(&"extra_pen"), "loaded from data/upgrades")
