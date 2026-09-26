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


func test_requirement_descriptions() -> void:
	var g := RequirementGroup.new()
	g.any_of.assign([Fixtures.req("move_element", "earth"), Fixtures.req("move_kind", "damaging")])
	eq(g.describe(), "Earth move or damaging move", "group")
	eq(Fixtures.req("stat", "power", Stats.Grade.B).describe(), "Power ≥ B", "stat")
	eq(Fixtures.req("trait", "darksight").describe(), "Darksight", "trait")
	eq(Fixtures.req("lineage", "spider", 0, 3).describe(), "3 generations of Spider", "lineage")
