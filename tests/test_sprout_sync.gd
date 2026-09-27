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


func test_reports_failed_copy_instead_of_going_silent() -> void:
	var first: String = Sync.FILES.keys()[0]
	var src_file := ProjectSettings.globalize_path(SRC).path_join(Sync.FILES[first])
	DirAccess.make_dir_recursive_absolute(src_file.get_base_dir())
	var f := FileAccess.open(src_file, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	var dst_path := ProjectSettings.globalize_path(DST).path_join(first)
	if FileAccess.file_exists(dst_path):
		DirAccess.remove_absolute(dst_path)
	# a directory sitting at the destination path stops copy_absolute from ever writing the file there
	DirAccess.make_dir_recursive_absolute(dst_path)
	var missing := Sync.sync(SRC, DST)
	var reported := false
	for m in missing:
		if m.begins_with(Sync.FILES[first]):
			reported = true
	check(reported, "failed copy is named in the returned list: %s" % missing)
	DirAccess.remove_absolute(dst_path)  # leave a plain, copyable path behind for the other tests / next run
