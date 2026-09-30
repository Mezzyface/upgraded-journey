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
	if Game.has_save() and not Game.can_continue():
		%Continue.disabled = true  # Continue would start over; the unreadable save is kept aside as .bad
		%Continue.text = "Save can't be read"
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
