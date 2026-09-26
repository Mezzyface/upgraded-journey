@tool
extends RefCounted
## Builds ui/theme/isle_of_lore.tres from the Isle of Lore 2 UI pack.
## Nine-patch margins come straight from the pack docs: "3x3 18x18px" -> margin 18 all round,
## "3x1 20x54px" -> left/right 20, top/bottom 0. The pack and fonts are licensed, so ui/theme/pack is git-ignored.

const PACK_DIR := "res://asset-pipeline/ui-pack"
const ELEMENTS := PACK_DIR + "/Sources/output/ui_pack_elements"
const OUT_DIR := "res://ui/theme/pack"
const THEME_PATH := "res://ui/theme/isle_of_lore.tres"

const BLUE_LINE := Color(0.145, 0.314, 0.502)  # iol2_ui_blue_line #255080
const INK := Color(0.17, 0.17, 0.17)
const BRIGHT := Color(1.08, 1.08, 1.08)
const DIM := Color(0.7, 0.7, 0.7)

## name -> [source relative to ELEMENTS, texture margins (l, t, r, b) or null for plain icons]
const TEX := {
	"button_square_0": ["button_square.standard/button_square_0.png", [18, 18, 18, 18]],
	"button_square_pressed_0": ["button_square_pressed.standard/button_square_pressed_0.png", [18, 16, 18, 16]],
	"button_square_decorated_0": ["button_square_decorated.standard/button_square_decorated_0.png", [20, 0, 20, 0]],
	"button_square_decorated_pressed_0": ["button_square_decorated_pressed.standard/button_square_decorated_pressed_0.png", [20, 0, 20, 0]],
	"button_round_small_0": ["button_round_small.standard/button_round_small_0.png", null],
	"button_round_small_pressed_0": ["button_round_small_pressed.standard/button_round_small_pressed_0.png", null],
	"button_round_big_0": ["button_round_big.standard/button_round_big_0.png", null],
	"button_round_big_pressed_0": ["button_round_big_pressed.standard/button_round_big_pressed_0.png", null],
	"dialog_box_0": ["dialog_box.standard/dialog_box_0.png", [16, 16, 16, 16]],
	"dialog_box_top_right_bg_0": ["dialog_box_top_right_bg.standard/dialog_box_top_right_bg_0.png", [16, 16, 16, 16]],
	"panel_0": ["panel.standard/panel_0.png", [20, 0, 20, 0]],
	"box_0": ["box.standard/box_0.png", [10, 10, 10, 10]],
	"name_plate_0": ["name_plate.standard/name_plate_0.png", [18, 18, 18, 18]],
	"text_input_0": ["text_input.standard/text_input_0.png", [18, 18, 18, 18]],
	"tooltip_0": ["tooltip.standard/tooltip_0.png", [24, 24, 24, 24]],
	"progress_bar_0": ["progress_bar.standard/progress_bar_0.png", [22, 22, 22, 22]],
	"progress_bar_1": ["progress_bar.standard/progress_bar_1.png", [22, 22, 22, 22]],
	"inventory_slot_0": ["inventory_slot.standard/inventory_slot_0.png", [28, 28, 28, 28]],
	"inventory_slot_1": ["inventory_slot.standard/inventory_slot_1.png", [28, 28, 28, 28]],
	"banner_0": ["banner.standard/banner_0.png", [112, 0, 112, 0]],
	"checkbox_0": ["checkbox.standard/checkbox_0.png", null],
	"checkbox_1": ["checkbox.standard/checkbox_1.png", null],
	"checkbox_3": ["checkbox.standard/checkbox_3.png", null],
	"radio_button_0": ["radio_button.standard/radio_button_0.png", null],
	"radio_button_1": ["radio_button.standard/radio_button_1.png", null],
	"scrollbar_vertical_bar_1": ["scrollbar_vertical_bar.standard/scrollbar_vertical_bar_1.png", [0, 12, 0, 12]],
	"scrollbar_vertical_bar_2": ["scrollbar_vertical_bar.standard/scrollbar_vertical_bar_2.png", [0, 12, 0, 12]],
	"scrollbar_vertical_bar_3": ["scrollbar_vertical_bar.standard/scrollbar_vertical_bar_3.png", [0, 12, 0, 12]],
	"scrollbar_horizontal_bar_1": ["scrollbar_horizontal_bar.standard/scrollbar_horizontal_bar_1.png", [12, 0, 12, 0]],
	"scrollbar_horizontal_bar_2": ["scrollbar_horizontal_bar.standard/scrollbar_horizontal_bar_2.png", [12, 0, 12, 0]],
	"scrollbar_horizontal_bar_3": ["scrollbar_horizontal_bar.standard/scrollbar_horizontal_bar_3.png", [12, 0, 12, 0]],
	"scrollbar_vertical_button_1": ["scrollbar_vertical_button.standard/scrollbar_vertical_button_1.png", [13, 14, 13, 14]],
	"scrollbar_vertical_button_pressed_1": ["scrollbar_vertical_button_pressed.standard/scrollbar_vertical_button_pressed_1.png", [13, 14, 13, 14]],
	"scrollbar_vertical_button_2": ["scrollbar_vertical_button.standard/scrollbar_vertical_button_2.png", null],
	"scrollbar_vertical_button_pressed_2": ["scrollbar_vertical_button_pressed.standard/scrollbar_vertical_button_pressed_2.png", null],
	"scrollbar_horizontal_button_1": ["scrollbar_horizontal_button.standard/scrollbar_horizontal_button_1.png", [14, 13, 14, 13]],
	"scrollbar_horizontal_button_pressed_1": ["scrollbar_horizontal_button_pressed.standard/scrollbar_horizontal_button_pressed_1.png", [14, 13, 14, 13]],
	"scrollbar_diamond_0": ["scrollbar_diamond.standard/scrollbar_diamond_0.png", null],
	"scrollbar_diamond_pressed_0": ["scrollbar_diamond_pressed.standard/scrollbar_diamond_pressed_0.png", null],
	"heart_piece_empty_0": ["heart_piece.standard/heart_piece_empty_0.png", null],
	"heart_piece_half_3": ["heart_piece.standard/heart_piece_half_3.png", null],
	"heart_piece_full_5": ["heart_piece.standard/heart_piece_full_5.png", null],
	"example_portrait": ["../../misc/example_portrait/example_portrait.png", null],
}
const FONTS := ["HoneyPigeon.ttf", "honeyblot_caps.ttf"]


## Copies the pack files the theme uses into OUT_DIR and composes the two CheckButton switch images.
static func sync() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var n := 0
	for name in TEX:
		if DirAccess.copy_absolute(_abs(ELEMENTS + "/" + TEX[name][0]), _abs(OUT_DIR + "/" + name + ".png")) == OK:
			n += 1
	for font in FONTS:
		if DirAccess.copy_absolute(_abs(PACK_DIR + "/" + font), _abs(OUT_DIR + "/" + font)) == OK:
			n += 1
	var bar := Image.load_from_file(_abs(ELEMENTS + "/toggle_bar.standard/toggle_bar_0.png"))
	var knob := Image.load_from_file(_abs(ELEMENTS + "/toggle_button.standard/toggle_button_0.png"))
	var knob_x := {"off": 0, "on": bar.get_width() - knob.get_width()}
	for state in knob_x:
		var im := bar.duplicate() as Image
		im.blend_rect(knob, Rect2i(Vector2i.ZERO, knob.get_size()), Vector2i(knob_x[state], 0))
		if im.save_png(_abs(OUT_DIR + "/toggle_%s.png" % state)) == OK:
			n += 1
	return n


## Writes THEME_PATH. Requires the OUT_DIR files to be imported already (run sync, let the editor import, then this).
static func build() -> Error:
	var t := Theme.new()
	var body_font := load(OUT_DIR + "/HoneyPigeon.ttf") as Font
	var head_font := load(OUT_DIR + "/honeyblot_caps.ttf") as Font
	if body_font == null or head_font == null:
		push_error("[iol_theme] fonts not imported yet in " + OUT_DIR)
		return ERR_FILE_NOT_FOUND
	t.default_font = body_font
	t.default_font_size = 20
	var white := Color.WHITE

	# Button (square blue). Pressed art is 6px shorter; shifting the content margin drops the label 3px like a real press.
	t.set_stylebox("normal", "Button", _box("button_square_0", [18, 10, 18, 10]))
	t.set_stylebox("hover", "Button", _box("button_square_0", [18, 10, 18, 10], BRIGHT))
	t.set_stylebox("pressed", "Button", _box("button_square_pressed_0", [18, 13, 18, 7]))
	t.set_stylebox("disabled", "Button", _box("button_square_0", [18, 10, 18, 10], DIM))
	t.set_stylebox("focus", "Button", _empty())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", white)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.6))
	t.set_color("font_outline_color", "Button", BLUE_LINE)
	t.set_constant("outline_size", "Button", 3)
	t.set_constant("h_separation", "Button", 8)

	# DecoratedButton variation: scrollwork on the sides, 3x1 art so it is meant for one row of text
	t.set_type_variation("DecoratedButton", "Button")
	t.set_stylebox("normal", "DecoratedButton", _box("button_square_decorated_0", [28, 10, 28, 10]))
	t.set_stylebox("hover", "DecoratedButton", _box("button_square_decorated_0", [28, 10, 28, 10], BRIGHT))
	t.set_stylebox("pressed", "DecoratedButton", _box("button_square_decorated_pressed_0", [28, 13, 28, 7]))
	t.set_stylebox("disabled", "DecoratedButton", _box("button_square_decorated_0", [28, 10, 28, 10], DIM))

	# CheckBox / radio and CheckButton (switch): no button background, pack icons, dark text
	for typ in ["CheckBox", "CheckButton"]:
		for s in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			t.set_stylebox(s, typ, _empty([4, 4, 4, 4]))
		t.set_stylebox("focus", typ, _empty())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, typ, INK)
		t.set_color("font_disabled_color", typ, Color(0.17, 0.17, 0.17, 0.5))
		t.set_constant("outline_size", typ, 0)
		t.set_constant("h_separation", typ, 8)
	t.set_icon("checked", "CheckBox", _tex("checkbox_1"))
	t.set_icon("unchecked", "CheckBox", _tex("checkbox_0"))
	t.set_icon("checked_disabled", "CheckBox", _tex("checkbox_3"))
	t.set_icon("unchecked_disabled", "CheckBox", _tex("checkbox_0"))
	t.set_icon("radio_checked", "CheckBox", _tex("radio_button_1"))
	t.set_icon("radio_unchecked", "CheckBox", _tex("radio_button_0"))
	t.set_icon("radio_checked_disabled", "CheckBox", _tex("radio_button_1"))
	t.set_icon("radio_unchecked_disabled", "CheckBox", _tex("radio_button_0"))
	for pair in [["on", "checked"], ["off", "unchecked"]]:
		for suffix in ["", "_disabled", "_mirrored", "_disabled_mirrored"]:
			t.set_icon(pair[1] + suffix, "CheckButton", _tex("toggle_" + pair[0]))

	# Panels: dialog box by default, plus named variations for the other box styles in the pack
	t.set_stylebox("panel", "Panel", _box("dialog_box_0", [20, 20, 20, 20]))
	t.set_stylebox("panel", "PanelContainer", _box("dialog_box_0", [20, 20, 20, 20]))
	for v in [
		["FlatPanel", "box_0", [16, 12, 16, 12]],                       # plain white box (conversation box)
		["BarPanel", "panel_0", [24, 8, 24, 8]],                        # HUD strip with baked shadow, 3x1 art
		["InsetPanel", "dialog_box_top_right_bg_0", [12, 12, 12, 12]],  # gray inset inside a dialog box
		["InventorySlot", "inventory_slot_0", [10, 10, 10, 10]],
		["InventorySlotSelected", "inventory_slot_1", [10, 10, 10, 10]],
		["NamePlate", "name_plate_0", [16, 6, 16, 6]],
	]:
		t.set_type_variation(v[0], "PanelContainer")
		t.set_stylebox("panel", v[0], _box(v[1], v[2]))

	# Tooltip
	t.set_stylebox("panel", "TooltipPanel", _box("tooltip_0", [16, 10, 16, 10]))
	t.set_color("font_color", "TooltipLabel", white)
	t.set_font_size("font_size", "TooltipLabel", 18)

	# Labels
	t.set_color("font_color", "Label", INK)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", head_font)
	t.set_font_size("font_size", "HeaderLabel", 34)
	t.set_color("font_color", "HeaderLabel", BLUE_LINE)
	t.set_type_variation("BannerLabel", "Label")  # text on the flag banner; pack docs suggest a 3px #255080 outline
	t.set_font("font", "BannerLabel", head_font)
	t.set_font_size("font_size", "BannerLabel", 36)
	t.set_color("font_color", "BannerLabel", white)
	t.set_color("font_outline_color", "BannerLabel", BLUE_LINE)
	t.set_constant("outline_size", "BannerLabel", 3)
	t.set_stylebox("normal", "BannerLabel", _box("banner_0", [40, 24, 40, 40]))
	t.set_type_variation("OnDarkLabel", "Label")
	t.set_color("font_color", "OnDarkLabel", white)

	# LineEdit / TextEdit
	t.set_stylebox("normal", "LineEdit", _box("text_input_0", [14, 6, 14, 6]))
	t.set_stylebox("focus", "LineEdit", _empty())
	t.set_stylebox("read_only", "LineEdit", _box("text_input_0", [14, 6, 14, 6], Color(0.85, 0.85, 0.85)))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.17, 0.17, 0.17, 0.45))
	t.set_color("font_uneditable_color", "LineEdit", Color(0.17, 0.17, 0.17, 0.6))
	t.set_color("caret_color", "LineEdit", BLUE_LINE)
	t.set_color("selection_color", "LineEdit", Color(0.145, 0.314, 0.502, 0.35))
	t.set_stylebox("normal", "TextEdit", _box("text_input_0", [14, 10, 14, 10]))
	t.set_stylebox("focus", "TextEdit", _empty())
	t.set_color("font_color", "TextEdit", INK)
	t.set_color("caret_color", "TextEdit", BLUE_LINE)

	# ProgressBar: dark track, blue fill
	t.set_stylebox("background", "ProgressBar", _box("progress_bar_0", [0, 0, 0, 0]))
	t.set_stylebox("fill", "ProgressBar", _box("progress_bar_1", [0, 0, 0, 0]))
	t.set_color("font_color", "ProgressBar", white)
	t.set_color("font_outline_color", "ProgressBar", BLUE_LINE)
	t.set_constant("outline_size", "ProgressBar", 3)

	# Scrollbars: gray track widened to the 28px pill grabber so the two sit flush.
	# Tracks need content margins or the stylebox reports zero thickness.
	for sb in [["VScrollBar", "vertical", [14, 0, 14, 0]], ["HScrollBar", "horizontal", [0, 14, 0, 14]]]:
		t.set_stylebox("scroll", sb[0], _box("scrollbar_%s_bar_2" % sb[1], sb[2]))
		t.set_stylebox("scroll_focus", sb[0], _box("scrollbar_%s_bar_2" % sb[1], sb[2]))
		t.set_stylebox("grabber", sb[0], _box("scrollbar_%s_button_1" % sb[1], [0, 0, 0, 0]))
		t.set_stylebox("grabber_highlight", sb[0], _box("scrollbar_%s_button_1" % sb[1], [0, 0, 0, 0], BRIGHT))
		t.set_stylebox("grabber_pressed", sb[0], _box("scrollbar_%s_button_pressed_1" % sb[1], [0, 0, 0, 0]))

	# Sliders: white track, blue filled part, diamond knob
	for sl in [["HSlider", "horizontal", [0, 6, 0, 6]], ["VSlider", "vertical", [6, 0, 6, 0]]]:
		t.set_stylebox("slider", sl[0], _box("scrollbar_%s_bar_3" % sl[1], sl[2]))
		t.set_stylebox("grabber_area", sl[0], _box("scrollbar_%s_bar_1" % sl[1], sl[2]))
		t.set_stylebox("grabber_area_highlight", sl[0], _box("scrollbar_%s_bar_1" % sl[1], sl[2]))
		t.set_icon("grabber", sl[0], _tex("scrollbar_diamond_0"))
		t.set_icon("grabber_highlight", sl[0], _tex("scrollbar_diamond_pressed_0"))
		t.set_icon("grabber_disabled", sl[0], _tex("scrollbar_diamond_0"))

	# PackScrollBar: the pack draws scrollbars as a thin bar with a fixed-size knob, which is a VSlider in Godot
	# (VScrollBar stretches its grabber). ui/pack_scroll_bar.gd drives a ScrollContainer with it.
	t.set_type_variation("PackScrollBar", "VSlider")
	t.set_stylebox("slider", "PackScrollBar", _box("scrollbar_vertical_bar_2", [6, 0, 6, 0]))
	t.set_stylebox("grabber_area", "PackScrollBar", _empty())
	t.set_stylebox("grabber_area_highlight", "PackScrollBar", _empty())
	t.set_icon("grabber", "PackScrollBar", _tex("scrollbar_vertical_button_2"))
	t.set_icon("grabber_highlight", "PackScrollBar", _tex("scrollbar_vertical_button_pressed_2"))
	t.set_icon("grabber_disabled", "PackScrollBar", _tex("scrollbar_vertical_button_2"))

	# Popups (OptionButton / MenuButton dropdowns) and SpinBox reuse the dialog box
	t.set_stylebox("panel", "PopupMenu", _box("dialog_box_0", [12, 12, 12, 12]))
	t.set_stylebox("hover", "PopupMenu", _box("dialog_box_top_right_bg_0", [8, 4, 8, 4]))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_stylebox("panel", "PopupPanel", _box("dialog_box_0", [16, 16, 16, 16]))
	t.set_icon("updown", "SpinBox", _tex("scrollbar_diamond_0"))

	return ResourceSaver.save(t, THEME_PATH)


static func _abs(res_path: String) -> String:
	return ProjectSettings.globalize_path(res_path)


static func _tex(name: String) -> Texture2D:
	return load(OUT_DIR + "/" + name + ".png") as Texture2D


static func _box(name: String, content: Array, modulate := Color.WHITE, expand: Array = []) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(name)
	var m: Array = TEX[name][1]
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = content[0]
	sb.content_margin_top = content[1]
	sb.content_margin_right = content[2]
	sb.content_margin_bottom = content[3]
	if not expand.is_empty():
		sb.expand_margin_left = expand[0]
		sb.expand_margin_top = expand[1]
		sb.expand_margin_right = expand[2]
		sb.expand_margin_bottom = expand[3]
	sb.modulate_color = modulate
	return sb


static func _empty(content: Array = [0, 0, 0, 0]) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = content[0]
	sb.content_margin_top = content[1]
	sb.content_margin_right = content[2]
	sb.content_margin_bottom = content[3]
	return sb
