extends TestSuite

const Sync := preload("res://addons/sprout_tools/sprout_sync.gd")
const THEME := "res://ui/theme/sprout_lands.tres"


func test_project_uses_the_sprout_theme_on_a_640x360_grid() -> void:
	eq(ProjectSettings.get_setting("gui/theme/custom"), THEME, "project theme")
	eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640, "viewport width")
	eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360, "viewport height")
	eq(ProjectSettings.get_setting("display/window/size/window_width_override"), 1280, "window width")
	eq(ProjectSettings.get_setting("display/window/size/window_height_override"), 720, "window height")
	eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "stretch mode")
	check(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"), "pixel snap")


## Everything the theme draws with must come from art/sprout and be in the sync list, or a fresh clone breaks.
func test_theme_art_is_all_synced() -> void:
	var theme: Theme = load(THEME)
	var paths := _theme_resource_paths(theme)
	check(paths.size() > 0, "theme references some art")
	check(theme.default_font != null, "default font set")
	for p in paths:
		check(p.begins_with(Sync.DST + "/"), "under art/sprout: %s" % p)
		check(Sync.FILES.has(p.trim_prefix(Sync.DST + "/")), "in SproutSync.FILES: %s" % p)
		check(FileAccess.file_exists(p), "synced (run Sprout Lands: Sync pack files): %s" % p)


func _theme_resource_paths(theme: Theme) -> PackedStringArray:
	var out := PackedStringArray()
	var add := func(r: Resource) -> void:
		if r is AtlasTexture:
			r = r.atlas
		if r is StyleBoxTexture:
			r = r.texture
		if r != null and r.resource_path != "" and not out.has(r.resource_path):
			out.append(r.resource_path)
	if theme.default_font:
		add.call(theme.default_font)
	for type in theme.get_type_list():
		for n in theme.get_stylebox_list(type):
			add.call(theme.get_stylebox(n, type))
		for n in theme.get_icon_list(type):
			add.call(theme.get_icon(n, type))
		for n in theme.get_font_list(type):
			add.call(theme.get_font(n, type))
	return out
