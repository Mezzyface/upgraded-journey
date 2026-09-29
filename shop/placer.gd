class_name Placer
extends Control
## Placement mode (docs/superpowers/specs/2026-09-29-buildable-pens-design.md): a see-through ghost of a buildable
## follows the mouse on the 16 px grid, tinted by Build.can_place. Click a green spot to pin it, then %Place or
## %Cancel; Esc or right-click cancels. Nothing is paid until Place. Covers the farm (and the top-bar tags) while
## placing so nothing else takes clicks; hidden otherwise. Tints and the button/hint layout are edited in placer.tscn.

signal finished(built: bool)

const TILE := 16

@export var ok_tint := Color(0.6, 1, 0.6, 0.75)
@export var bad_tint := Color(1, 0.45, 0.45, 0.75)

var cell := Vector2i.ZERO  ## the ghost's top-left tile
var _def: BuildableDef
var _buildable: Dictionary
var _ghost: Node2D
var _pinned := false


func _ready() -> void:
	_stop()
	%Place.pressed.connect(_place)
	%Cancel.pressed.connect(_finish.bind(false))


## Enters placement mode for `def_id`; `buildable` is the set of cells building is allowed on (Shop.buildable_cells).
func start(def_id: StringName, buildable: Dictionary) -> void:
	_def = Game.db.buildables[def_id]
	_buildable = buildable
	_ghost = _def.scene.instantiate()
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	for layer: TileMapLayer in _ghost.find_children("*", "TileMapLayer", true, false):
		layer.collision_enabled = false  # creatures don't bump into a ghost
	%Ghost.add_child(_ghost)
	_pinned = false
	%Confirm.hide()
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to(get_local_mouse_position())


## Puts the ghost's centre near `pos` (snapped to the grid) and re-tints it. Returns Build.can_place's reason.
func move_to(pos: Vector2) -> String:
	cell = Vector2i(((pos - Vector2(_def.footprint * TILE) / 2.0) / TILE).round())
	_ghost.position = Vector2(cell * TILE)
	var reason := Build.can_place(Game.state, Game.db, _def.id, cell, _buildable)
	_ghost.modulate = ok_tint if reason == "" else bad_tint
	%Reason.text = reason
	%Reason.position = _ghost.position + Vector2(0, _def.footprint.y * TILE + 2)
	return reason


func _gui_input(event: InputEvent) -> void:
	if _def == null:
		return
	if event is InputEventMouseMotion and not _pinned:
		move_to(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_finish(false)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			pin(move_to(event.position) == "")
	accept_event()


## Pins the ghost where it is (showing Place / Cancel above it) or lets it follow the mouse again.
func pin(on: bool) -> void:
	_pinned = on
	%Confirm.visible = on
	if on:
		%Confirm.reset_size()
		%Confirm.position = (_ghost.position + Vector2(0, -%Confirm.size.y - 2)).clamp(Vector2.ZERO, size - %Confirm.size)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_finish(false)
		get_viewport().set_input_as_handled()


func _place() -> void:
	var reason := Game.place(_def.id, cell, _buildable)
	if reason == "":
		_finish(true)
	else:
		%Reason.text = reason
		pin(false)


func _finish(built: bool) -> void:
	_stop()
	finished.emit(built)


func _stop() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_def = null
	_pinned = false
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
