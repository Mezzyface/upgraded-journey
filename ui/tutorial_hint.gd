class_name TutorialHint
extends PanelContainer
## The tutorial's corner box on the farm (Tutorial): the current step's text and "n/10", finished by doing it —
## Game.acted for actions, saw() from shop.gd for opening a popup. Skip ends it; after the last step it says goodbye
## and Skip becomes Close. Only Skip takes clicks, so the farm under the box stays usable.

var _was_active := false  ## the goodbye shows only to a player who just finished, not to old saves


func _ready() -> void:
	%Skip.pressed.connect(func() -> void: Game.set_tutorial_step(Tutorial.SKIPPED))
	Game.acted.connect(saw)
	Game.changed.connect(refresh)
	refresh()


## Something the player did or opened (Game.acted keys, or "orders" / "card" / "market" from shop.gd).
func saw(what: StringName) -> void:
	if Game.state == null:
		return
	var step := Game.state.tutorial_step
	var next := Tutorial.advance(step, what)
	if next != step:
		Game.set_tutorial_step(next)
	refresh()


func refresh() -> void:
	var step: int = Game.state.tutorial_step if Game.state else Tutorial.SKIPPED
	var finished := step == Tutorial.STEPS.size() and _was_active
	visible = Tutorial.active(step) or finished
	if Tutorial.active(step):
		_was_active = true
		%Text.text = Tutorial.STEPS[step]["text"]
		%Step.text = "%d/%d" % [step + 1, Tutorial.STEPS.size()]
		%Skip.text = "Skip tutorial"
	elif finished:
		%Text.text = Tutorial.DONE_TEXT
		%Step.text = ""
		%Skip.text = "Close"

