extends TestSuite
## creatures/variants_review.tscn: one group per species (original | palette swap | still), built without saving.

const SCENE := "res://creatures/variants_review.tscn"
const FRAMES_DIR := "res://creatures/frames"
const SWAP_PATH := "res://creatures/sprout_palette.tres"


func _ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for f in ResourceLoader.list_directory(FRAMES_DIR):
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
	return ids


## Untyped members: restyle_dir and build() live on the scene's script, not on Node, so use set()/call().
func _open(restyle_dir := "") -> Node:
	var r: Node = load(SCENE).instantiate()
	if restyle_dir != "":
		r.set("restyle_dir", restyle_dir)
	tree.root.add_child(r)
	return r


func _groups(r: Node) -> int:
	var n := 0
	for id in _ids():
		n += 1 if r.has_node(NodePath(id)) else 0
	return n


func test_one_group_per_species_with_all_three_slots() -> void:
	var r := _open()
	await tree.process_frame
	var ids := _ids()
	check(ids.size() >= 13, "found the species SpriteFrames")
	var swap := load(SWAP_PATH)
	for id in ids:
		var g := r.get_node_or_null(NodePath(id))
		check(g != null, "group for %s" % id)
		if g == null:
			continue
		var orig := g.get_node_or_null("Original") as AnimatedSprite2D
		check(orig != null and orig.sprite_frames.has_animation(&"idle_right") and orig.is_playing(), "%s original plays idle_right" % id)
		var sw := g.get_node_or_null("Swap") as AnimatedSprite2D
		check(sw != null and sw.material == swap and sw.is_playing(), "%s swap uses sprout_palette.tres" % id)
		check(g.has_node("Still") != g.has_node("Missing"), "%s has a still or the missing label" % id)
		check(g.get_node_or_null("Name") is Label, "%s has a name label" % id)
	r.queue_free()


func test_missing_still_shows_the_gen_command() -> void:
	var r := _open("res://no/such/dir")
	await tree.process_frame
	var l := r.get_node_or_null("slime/Missing") as Label
	check(l != null and l.text.contains("restyle_slime"), "missing still label names gen.py restyle_slime")
	check(not r.has_node("slime/Still"), "no Still when the file is missing")
	r.queue_free()


func test_broken_still_shows_the_gen_command() -> void:
	DirAccess.make_dir_recursive_absolute("user://variants_test")
	FileAccess.open("user://variants_test/restyle_slime.png", FileAccess.WRITE).close()  # 0 bytes
	var r := _open("user://variants_test")
	await tree.process_frame
	check(r.has_node("slime/Missing") and not r.has_node("slime/Still"), "a 0-byte still shows the missing label")
	r.queue_free()
	DirAccess.remove_absolute("user://variants_test/restyle_slime.png")


func test_build_twice_does_not_duplicate() -> void:
	var r := _open()
	await tree.process_frame
	var before := r.get_child_count()
	r.call("build")
	eq(r.get_child_count(), before, "child count after a second build")
	eq(_groups(r), _ids().size(), "one group per species after a second build")
	r.queue_free()


func test_built_nodes_are_not_saved() -> void:
	var r := _open()
	await tree.process_frame
	var packed := PackedScene.new()
	packed.pack(r)
	eq(packed.get_state().get_node_count(), 2, "saved nodes (root + Camera)")
	r.queue_free()


func test_builds_without_the_palette() -> void:
	var swap := load(SWAP_PATH) as ShaderMaterial
	var pal: Variant = swap.get_shader_parameter("palette")
	swap.set_shader_parameter("palette", null)
	var r := _open()
	await tree.process_frame
	eq(_groups(r), _ids().size(), "groups built with no palette texture")
	swap.set_shader_parameter("palette", pal)
	r.queue_free()
