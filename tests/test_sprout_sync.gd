extends TestSuite

const Sync := preload("res://addons/sprout_tools/sprout_sync.gd")
const SRC := "user://sprout_src"
const DST := "user://sprout_dst"


func test_copies_listed_files_and_reports_every_missing_one() -> void:
	var first: String = Sync.FILES.keys()[0]
	var src_file := ProjectSettings.globalize_path(SRC).path_join(Sync.FILES[first])
	DirAccess.make_dir_recursive_absolute(src_file.get_base_dir())
	var f := FileAccess.open(src_file, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	var missing := Sync.sync(SRC, DST)
	check(FileAccess.file_exists(ProjectSettings.globalize_path(DST).path_join(first)), "listed file copied")
	eq(missing.size(), Sync.FILES.size() - 1, "every other source reported")
	check(not missing.has(Sync.FILES[first]), "the present source is not reported")


func test_list_only_names_pack_art() -> void:
	for dst in Sync.FILES:
		check(dst.get_extension() in ["png", "ttf", "wav"], "pack art only, never resources: %s" % dst)
