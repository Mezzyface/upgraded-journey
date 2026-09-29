extends Control
## Species preview: one adult of a species walking in the real farm pen, fences and all, with its creature card open
## beside it, to judge how its .tres looks (size_tiles, frames, stats, traits, moves). Run it from a Species in the
## Inspector (the "Preview in pen" button), or set `species` below and press F6.
## Plays on a throwaway state and save file, so it never touches the player's save.

const SHOP := preload("res://shop/shop.tscn")
const PICK_FILE := "user://species_preview.txt"  ## a species path, written by the Inspector button, read once
const SAVE := "user://species_preview_save.json"

@export var species: Species


func _ready() -> void:
	var sp := _picked()
	if sp == null:
		push_warning("[species_preview] no species: use the Inspector's Preview in pen button, or set `species`")
		return
	Game.save_path = SAVE
	Game.start_new(load(Game.NEW_GAME), Db.load_dir(), randi())
	Game.state.creatures.clear()  # only the previewed creature in the pen
	var c := CreatureData.new()
	c.id = Game.state.new_id()
	c.species = sp.id
	for s in Stats.NAMES:
		c.potential[s] = sp.potential(s)
		c.stats[s] = roundi(sp.potential(s) / 2.0)
	Game.state.add(c)
	var shop := SHOP.instantiate()
	add_child(shop)
	var host: PanelHost = shop.get_node("%PanelHost")
	var pen_right := (shop.get_node("%Pens") as Control).get_global_rect().end.x + CreatureAnim.TILE  # past the right fence
	host.position.x = pen_right  # the card centres in the space right of the pen
	host.size.x = get_viewport_rect().size.x - pen_right
	shop.open_card(c)
	host.backdrop = false  # the pen stays bright
	host.queue_redraw()


func _picked() -> Species:
	if not FileAccess.file_exists(PICK_FILE):
		return species
	var path := FileAccess.get_file_as_string(PICK_FILE).strip_edges()
	DirAccess.remove_absolute(PICK_FILE)
	return load(path) as Species
