class_name TutorialHint
extends PanelContainer
## The tutorial's corner box on the farm (Tutorial): the current step's text and "n/10", finished by doing it —
## Game.acted for actions, saw() from shop.gd for opening a popup. Skip ends it; after the last step it says goodbye
## and Skip becomes Close. Only Skip takes clicks, so the farm under the box stays usable. It is a narrow column
## on the left edge (shop.tscn); a popup that reaches under it (Orders, Expedition) shrinks it to the short line.

## The farm's PanelHost: while its popup reaches under this column, only the step's short line shows.
@export var panel_host: PanelHost

var _was_active := false  ## the goodbye shows only to a player who just finished, not to old saves
var _compact := false
var _skip_armed := false  ## Skip takes two presses, like the card's Sell: one stray click mustn't end the tutorial


func _ready() -> void:
	%Skip.pressed.connect(_press_skip)
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


func _process(_delta: float) -> void:
	var popup: Control = panel_host.current() if panel_host else null
	var compact := popup != null and popup.get_global_rect().position.x < get_global_rect().end.x + 4
	if compact != _compact:
		_compact = compact
		refresh()


func _press_skip() -> void:
	if Tutorial.active(Game.state.tutorial_step) and not _skip_armed:
		_skip_armed = true
		%Skip.text = "Sure?"
		return
	_skip_armed = false
	Game.set_tutorial_step(Tutorial.SKIPPED)


func refresh() -> void:
	var step: int = Game.state.tutorial_step if Game.state else Tutorial.SKIPPED
	var finished := step == Tutorial.STEPS.size() and _was_active
	visible = Tutorial.active(step) or finished
	if Tutorial.active(step):
		_was_active = true
		%Text.text = Tutorial.STEPS[step]["short" if _compact else "text"]
		%Step.text = "%d/%d" % [step + 1, Tutorial.STEPS.size()]
		%Skip.text = "Sure?" if _skip_armed else "Skip"
	elif finished:
		%Text.text = Tutorial.DONE_TEXT
		%Step.text = ""
		%Skip.text = "Close"

