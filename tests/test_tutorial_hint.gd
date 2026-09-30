extends TestSuite
## The tutorial hint box (ui/tutorial_hint.tscn).

const SAVE := "user://test_tutorial_hint_save.json"


## A fresh fixture game at `step` (0 = a new ranch). Returns the hint; await it.
func _hint(step := 0) -> TutorialHint:
	await tree.process_frame
	Game.save_path = SAVE
	var db := Fixtures.db()
	var setup := NewGameSetup.new()
	setup.species.assign([db.species[&"spider"], db.species[&"slime"]])
	setup.start_pen = db.buildables[&"pen"]
	Game.start_new(setup, db, 5)
	Game.state.tutorial_step = step
	var hint: TutorialHint = load("res://ui/tutorial_hint.tscn").instantiate()
	tree.root.add_child(hint)
	await tree.process_frame
	return hint


func _done(hint: Node) -> void:
	hint.queue_free()
	DirAccess.remove_absolute(SAVE)


func test_shows_the_current_step_and_advances_on_it() -> void:
	var hint := await _hint()
	check(hint.visible, "shown on a new game")
	eq(hint.get_node("%Text").text, Tutorial.STEPS[0]["text"], "step 1 text")
	eq(hint.get_node("%Step").text, "1/%d" % Tutorial.STEPS.size(), "counter")
	hint.saw(&"card")
	eq(Game.state.tutorial_step, 0, "another step's popup doesn't advance")
	hint.saw(&"orders")
	eq(Game.state.tutorial_step, 1, "opening Orders finishes step 1")
	eq(hint.get_node("%Text").text, Tutorial.STEPS[1]["text"], "step 2 shown")
	Game.accept(Game.state.board[0])
	eq(Game.state.tutorial_step, 2, "accepting finishes step 2 through Game.acted")
	_done(hint)


func test_skip_hides_it_and_is_saved() -> void:
	var hint := await _hint()
	hint.get_node("%Skip").pressed.emit()
	eq(Game.state.tutorial_step, 0, "the first press only arms Skip")
	check(hint.get_node("%Skip").text.begins_with("Sure?"), "armed: %s" % hint.get_node("%Skip").text)
	hint.get_node("%Skip").pressed.emit()
	eq(Game.state.tutorial_step, Tutorial.SKIPPED, "skipped")
	check(not hint.visible, "hidden")
	eq(GameState.load_file(Game.db, SAVE).tutorial_step, Tutorial.SKIPPED, "saved")
	_done(hint)


func test_finished_shows_the_goodbye_then_closes() -> void:
	var hint := await _hint()
	Game.set_tutorial_step(Tutorial.STEPS.size() - 1)
	Game.acted.emit(Tutorial.STEPS[-1]["done"])
	eq(hint.get_node("%Text").text, Tutorial.DONE_TEXT, "goodbye")
	eq(hint.get_node("%Skip").text, "Close", "Close instead of Skip")
	hint.get_node("%Skip").pressed.emit()
	check(not hint.visible, "closed")
	_done(hint)


func test_old_saves_never_see_it_and_clicks_pass_through() -> void:
	var hint := await _hint(Tutorial.STEPS.size())  # a save from before the tutorial
	check(not hint.visible, "finished before: hidden")
	eq(hint.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the box lets clicks through")
	eq(hint.get_node("%Text").mouse_filter, Control.MOUSE_FILTER_IGNORE, "its text too")
	eq(hint.get_node("%Skip").mouse_filter, Control.MOUSE_FILTER_STOP, "only Skip takes clicks")
	_done(hint)
