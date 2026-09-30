extends TestSuite
## The title screen (ui/title.tscn): Continue, New game (two presses over a save), Quit; the main scene.

const SAVE := "user://test_title_save.json"


## Returns [title, farm_opened]; await it. `with_save` writes a day-3 save first.
func _title(with_save: bool) -> Array:
	await tree.process_frame
	Game.save_path = SAVE
	Game.state = null
	DirAccess.remove_absolute(SAVE)
	if with_save:
		var st := Day.new_game(load("res://data/new_game.tres"), Db.load_dir(), Fixtures.rng())
		st.day = 3
		st.save(SAVE)
	var title: TitleScreen = load("res://ui/title.tscn").instantiate()
	var opened := [0]
	title.go_to_farm = func() -> void: opened[0] += 1
	tree.root.add_child(title)
	await tree.process_frame
	return [title, opened]


func _done(title: Node) -> void:
	title.queue_free()
	DirAccess.remove_absolute(SAVE)


func test_without_a_save_new_game_starts_at_once() -> void:
	var parts: Array = await _title(false)
	var title: TitleScreen = parts[0]
	check(not title.get_node("%Continue").visible, "nothing to continue")
	title.get_node("%NewGame").pressed.emit()
	eq(parts[1][0], 1, "farm opened")
	eq(Game.state.day, 1, "a new game")
	check(Game.has_save(), "saved at once")
	_done(title)


func test_continue_loads_the_save() -> void:
	var parts: Array = await _title(true)
	var title: TitleScreen = parts[0]
	check(title.get_node("%Continue").visible, "Continue shown")
	title.get_node("%Continue").pressed.emit()
	eq(Game.state.day, 3, "the saved day")
	eq(parts[1][0], 1, "farm opened")
	_done(title)


func test_new_game_over_a_save_needs_two_presses() -> void:
	var parts: Array = await _title(true)
	var title: TitleScreen = parts[0]
	title.get_node("%NewGame").pressed.emit()
	eq(parts[1][0], 0, "first press only arms")
	check(title.get_node("%NewGame").text.begins_with("Sure?"), "armed: %s" % title.get_node("%NewGame").text)
	title.get_node("%NewGame").pressed.emit()
	eq(parts[1][0], 1, "second press starts over")
	eq(Game.state.day, 1, "day 1")
	_done(title)


func test_the_title_is_the_main_scene() -> void:
	eq(ProjectSettings.get_setting("application/run/main_scene"), "res://ui/title.tscn", "main scene")


func test_an_unreadable_save_disables_continue() -> void:
	var parts: Array = await _title(false)
	parts[0].queue_free()
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	var title: TitleScreen = load("res://ui/title.tscn").instantiate()
	title.go_to_farm = func() -> void: pass
	tree.root.add_child(title)
	await tree.process_frame
	check(title.get_node("%Continue").visible and title.get_node("%Continue").disabled, "shown but disabled")
	eq(title.get_node("%Continue").text, "Save can't be read", "says why")
	_done(title)
	DirAccess.remove_absolute(SAVE + ".bad")


func test_the_first_button_has_keyboard_focus() -> void:
	var parts: Array = await _title(true)
	var title: TitleScreen = parts[0]
	await tree.process_frame
	check(title.get_node("%Continue").has_focus(), "Continue focused when there is a save")
	_done(title)
	var parts2: Array = await _title(false)
	await tree.process_frame
	check(parts2[0].get_node("%NewGame").has_focus(), "New game focused without one")
	_done(parts2[0])
