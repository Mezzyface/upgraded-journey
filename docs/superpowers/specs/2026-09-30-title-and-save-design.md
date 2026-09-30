# Title screen and mid-day save — design

Status: approved by delegation 2026-09-30 (owner asleep; standing instruction "keep working until the game is done").

## Goal

Slice goals: "menus" (build order) and "Save and reload mid-day restores all state". The game opens on a title
screen with Continue / New game / Quit, and every action is saved, so quitting mid-day and continuing restores the
same day, AP, money, busy and cared-for creatures and today's expeditions.

## Decisions

- New main scene `ui/title.tscn` (`class_name TitleScreen`, Control): the game's name, and `DecoratedButton`s
  `%Continue` (hidden when there is no save), `%NewGame`, `%Quit`. The farm map is not shown behind it; a plain
  themed backdrop (`PanelContainer`) keeps it cheap. Working title text: "Creature Ranch" (spec §Goal says the title
  is TBD; the owner renames it in the editor).
- New game when a save exists takes two presses, like the card's Sell: the first only arms it and changes its text to
  "Sure? Start over" (the ranch will be lost); the second starts over. Starting over deletes the save and calls `Game.start()` (which starts
  a fresh game from `data/new_game.tres` when no save exists).
- Continue calls `Game.start()` (loads the save). Both then `change_scene_to_file("res://shop/shop.tscn")`.
- `project.godot` `run/main_scene` becomes `res://ui/title.tscn` — a one-line text edit (the editor is closed;
  `ProjectSettings.save()` would rewrite the whole owner file), flagged in the morning report.
- Saving: `Game._did` saves after every successful action (as `end_day` does in the evening). A load is then "the
  moment of the last action": `day_start` and `day_log` are not saved, so after a mid-day load the evening summary
  covers only what happened since the load — accepted.
- The `--save=`/`--screenshot=`/`--open=` flags keep working on `shop.tscn` directly.
- A "Title" button is not added to the farm (Quit from the window; the title shows on next launch).

## 1. Game

- `_did` calls `_save()` after a successful action; `_save()` wraps `state.save(save_path)` and pushes a warning on
  failure (end_day keeps reporting its own failure in the events).
- `Game.has_save() -> bool` (`FileAccess.file_exists(save_path)`), `Game.new_game()` (removes the save file, clears
  `state`, then `start()`).

## 2. Title screen

`ui/title.tscn` + `ui/title.gd`: `_ready` hides `%Continue` without a save; `%NewGame` arms/confirms when a save
exists; `%Quit` → `get_tree().quit()`. Signals-free; scene change in the script.

## Testing

- `test_game.gd`: an action saves (file exists, loaded state equals current); `new_game()` replaces a save with day 1.
- `test_title.gd` (new): Continue hidden without a save and shown with one; New game over a save needs two presses;
  both leave `Game.state` started (the scene change itself is not asserted: tests stay in the runner's tree — the
  title exposes `go_to_farm` as a Callable the test replaces).
- `project.godot` main scene check in `test_title.gd`.
- Screenshot of the title.
