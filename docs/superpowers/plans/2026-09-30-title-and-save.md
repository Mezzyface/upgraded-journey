# Title Screen and Mid-day Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The game opens on a title screen (Continue / New game / Quit) and saves after every action.

**Architecture:** `Game._did` saves on success; `Game.has_save()` / `Game.new_game()`; `ui/title.tscn` + `ui/title.gd`
(`TitleScreen`) becomes the main scene and opens the farm through a replaceable `go_to_farm` Callable.

**Tech Stack:** Godot 4.7 GDScript; headless scene build while the editor is closed.

**Spec:** `docs/superpowers/specs/2026-09-30-title-and-save-design.md`

## Global Constraints

As in `docs/superpowers/plans/2026-09-29-expeditions.md` (headless builds, uids restored, `--import` then
`git checkout -- art`, scene tests await a frame first, no co-author trailer, never push). Branch `title` (stacked on
`pedigree`). Suite baseline `233 tests, 1 failed` (known only). Tests must never write `user://save.json`: the runner
defaults `Game.save_path` to `user://test_runner_save.json`.

## Review Focus

1. A test or tool acting through `Game` without setting `save_path` would overwrite the player's save once every action
   saves. → Task 1: runner default + `test_game` checks the path.
2. Quit mid-day, Continue: same day, AP, money, busy, cared, expeditions. → Task 1 `test_every_action_saves`.
3. New game over an existing save needs two presses. → Task 2 `test_new_game_over_a_save_needs_two_presses`.
4. No save: Continue hidden, New game starts at once. → Task 2 test.
5. A save that fails to write (read-only dir) warns but doesn't break the action. → Task 1 test.

---

### Task 1: Save after every action; `has_save`, `new_game`

**Files:** `game/game.gd`, `tests/run_tests.gd`; test `tests/test_game.gd`.
**Produces:** `Game.has_save() -> bool`, `Game.new_game(content: Db = null) -> void`, private `_save()`.

- [ ] **Step 1: Tests** (append to `tests/test_game.gd`):

```gdscript
func test_every_action_saves() -> void:
	var g := _game()
	DirAccess.remove_absolute(SAVE)
	check(not g.has_save(), "no save yet")
	var c: CreatureData = g.owned()[0]
	eq(g.care(c, "play"), "", "played")
	check(g.has_save(), "saved after the action")
	eq(g.send_expedition(&"cave", [c]), "", "sent")
	var loaded := GameState.load_file(g.db, SAVE)
	eq(loaded.to_dict(), g.state.to_dict(), "the save is this moment: AP, cared, busy, expeditions")
	g.state.ap = 0
	var before := FileAccess.get_file_as_string(SAVE)
	eq(g.care(c, "feed"), "not enough action points", "refused")
	eq(FileAccess.get_file_as_string(SAVE), before, "a refusal doesn't save")
	_cleanup(g)


func test_new_game_replaces_the_save() -> void:
	var g := _game()
	g.end_day()
	eq(g.state.day, 2, "day 2 saved")
	g.new_game(Fixtures.db())
	eq(g.state.day, 1, "a fresh game")
	eq(GameState.load_file(g.db, SAVE).day, 1, "and it's the save now")
	_cleanup(g)


func test_a_failed_save_warns_but_the_action_stands() -> void:
	var g := _game()
	g.save_path = "user://no_such_dir/deeper/save.json"
	var c: CreatureData = g.owned()[0]
	eq(g.care(c, "play"), "", "the action still happens")
	_cleanup(g)


func test_the_runner_never_uses_the_players_save() -> void:
	check(Game.save_path != GameState.SAVE_PATH, "tests default to %s" % Game.save_path)
```

- [ ] **Step 2: Run** `test_game.gd` → FAIL (`has_save` nonexistent; runner uses `user://save.json`).
- [ ] **Step 3: Implement.** In `tests/run_tests.gd` `_run()`, first line:
  `	Game.save_path = "user://test_runner_save.json"  # every action saves: never the player's save`.
  In `game/game.gd`: header comment "Autosaves after each evening." → "Saves after every action and each evening."; in
  `_did` after `if log_line != "": day_log.append(log_line)` add `		_save()` (before `changed.emit()`), and add:

```gdscript
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Starts over: deletes the save, begins a fresh game from NEW_GAME and saves it.
func new_game(content: Db = null) -> void:
	DirAccess.remove_absolute(save_path)
	state = null
	start(content)
	_save()


## Saves now; a failure is warned about, never fatal (end_day reports its own).
func _save() -> void:
	var err := state.save(save_path)
	if err != OK:
		push_warning("Game: couldn't save to %s (%s)" % [save_path, error_string(err)])
```

- [ ] **Step 4: Run** `test_game.gd` and the suite → PASS; suite `237 tests, 1 failed`.
- [ ] **Step 5: Commit** `game/game.gd tests/run_tests.gd tests/test_game.gd`: "Save after every action; add
  Game.has_save and Game.new_game".

### Task 2: Title screen as the main scene

**Files:** create `ui/title.gd`, `ui/title.tscn` (headless build); modify `project.godot` (one line); test
`tests/test_title.gd`.
**Produces:** `class_name TitleScreen extends Control`, `const FARM := "res://shop/shop.tscn"`,
`var go_to_farm: Callable`; unique nodes `%Continue`, `%NewGame`, `%Quit`, `%Name`.

- [ ] **Step 1: Tests** — `tests/test_title.gd`:

```gdscript
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
```

- [ ] **Step 2: Run** → FAIL (`TitleScreen` unknown).
- [ ] **Step 3: Script** `ui/title.gd`:

```gdscript
class_name TitleScreen
extends Control
## The title screen and main scene: Continue loads the save (hidden without one), New game starts over (two presses
## when a save exists, like the card's Sell), Quit. Both open the farm through `go_to_farm`, which tests replace.

const FARM := "res://shop/shop.tscn"

var go_to_farm: Callable
var _armed := false


func _init() -> void:
	go_to_farm = _open_farm


func _ready() -> void:
	%Continue.visible = Game.has_save()
	%Continue.pressed.connect(_continue)
	%NewGame.pressed.connect(_new_game)
	%Quit.pressed.connect(func() -> void: get_tree().quit())


func _continue() -> void:
	Game.start()
	go_to_farm.call()


func _new_game() -> void:
	if Game.has_save() and not _armed:
		_armed = true
		%NewGame.text = "Sure? Start over"
		return
	Game.new_game()
	go_to_farm.call()


func _open_farm() -> void:
	get_tree().change_scene_to_file(FARM)
```

- [ ] **Step 4: Scene** — headless build of `ui/title.tscn`: root `Title` Control (full rect anchors preset 15, script
  `ui/title.gd`) → `Backdrop` Panel (full rect) → `Center` CenterContainer (full rect) → `Box` PanelContainer →
  `Margin` MarginContainer (12 each side) → `Rows` VBox (separation 8): `%Name` Label (`HeaderLabel`, "Creature
  Ranch", centered), `%Continue`, `%NewGame` ("New game"), `%Quit` — `DecoratedButton`s, `custom_minimum_size =
  Vector2(160, 0)`. `--import`; `git checkout -- art`. In `project.godot` change the line
  `run/main_scene="res://shop/shop.tscn"` to `run/main_scene="res://ui/title.tscn"` (text edit).
- [ ] **Step 5: Run** `test_title.gd`, suite → PASS; suite `241 tests, 1 failed`.
- [ ] **Step 6: Commit** `ui/title.gd ui/title.gd.uid ui/title.tscn project.godot tests/test_title.gd
  tests/test_title.gd.uid`: "Open on a title screen with Continue and New game".

### Task 3: Verify

- [ ] Render the title (no save, and with a save). Read the PNGs. Run the game's real start once headless for a few
  frames (`godot --headless --path . --quit-after 60`) and check the log has no errors.
