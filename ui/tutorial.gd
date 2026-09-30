class_name Tutorial
extends RefCounted
## The first-days tutorial (docs/superpowers/specs/2026-09-30-tutorial-design.md): ten steps, each finished by one
## action (Game.acted) or by opening a popup (TutorialHint.saw). The current step is GameState.tutorial_step:
## 0..STEPS.size()-1 active, STEPS.size() finished, SKIPPED skipped. Only the current step's action advances.

const SKIPPED := -1
const DONE_TEXT := "You know the ranch now — have fun!"
const STEPS: Array[Dictionary] = [
	{"text": "Customers post requests on the Orders board. Open it from the shop door or the Orders tag.", "done": &"orders"},
	{"text": "Accept a request: it shows what the customer wants and by when.", "done": &"accept"},
	{"text": "Click a creature in the pen to open its card.", "done": &"card"},
	{"text": "Train raises a stat for 1 heart (action point). Hearts refill every morning.", "done": &"train"},
	{"text": "Feed or Play keeps a creature happy; happy babies grow up well.", "done": &"care"},
	{"text": "The Market sells feed, eggs, upgrades and pens.", "done": &"market"},
	{"text": "Out of hearts? Press End Day. Eggs hatch and babies grow overnight.", "done": &"end_day"},
	{"text": "Send up to three creatures on an expedition to find eggs and gold. Check the challenges first.", "done": &"expedition"},
	{"text": "Retire two grown creatures to the Stable and breed them: the egg inherits their sparks.", "done": &"breed"},
	{"text": "When a creature meets a request, deliver it from the Orders board.", "done": &"deliver"},
]


static func active(step: int) -> bool:
	return step >= 0 and step < STEPS.size()


static func advance(step: int, what: StringName) -> int:
	return step + 1 if active(step) and STEPS[step]["done"] == what else step
