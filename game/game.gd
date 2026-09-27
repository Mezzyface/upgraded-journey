extends Node
## The one path from the UI to the rules (autoload "Game"). Holds the content, the game state and the RNG. Every
## action returns "" or the reason it was refused and emits `changed` only when it did something. Autosaves after
## each evening. start() is called by the shop scene, not _ready, so tests and tools never touch the player's save.

signal changed

const NEW_GAME := "res://data/new_game.tres"
const TRAINING_LOCATION := &"mine"  ## where the creature card trains (2b-2 adds a location choice)

var db: Db
var state: GameState
var rng := RandomNumberGenerator.new()
var save_path := GameState.SAVE_PATH


## Loads the save at save_path, or starts a new game from NEW_GAME when there is none or it can't be read.
func start(content: Db = null) -> void:
	db = content if content else Db.load_dir()
	rng.randomize()
	state = GameState.load_file(db, save_path)
	if state == null:
		state = Day.new_game(load(NEW_GAME), db, rng)
	elif state.board.is_empty():
		OrderBoard.post_offers(state, db, rng)  # saves from before the order board had none
	changed.emit()


func start_new(setup: NewGameSetup, content: Db, seed_value: int) -> void:
	db = content
	rng.seed = seed_value
	state = Day.new_game(setup, db, rng)
	changed.emit()


func train(c: CreatureData, stat: String) -> String:
	return _did(Day.train(state, db, c, stat, db.locations.get(TRAINING_LOCATION), rng))


func care(c: CreatureData, kind: String) -> String:
	return _did(Day.care(state, c, kind))


func retire(c: CreatureData) -> String:
	return _did(Day.retire(state, db, c, rng))


func sell(c: CreatureData) -> String:
	return _did(Day.sell(state, c))


func accept(template_id: StringName) -> String:
	return _did(OrderBoard.accept(state, db, template_id))


func deliver(index: int, c: CreatureData) -> String:
	return _did(Day.deliver(state, db, index, c))


func end_day() -> PackedStringArray:
	var events := Day.end_day(state, db, rng)
	var err := state.save(save_path)
	if err != OK:
		events.append("Couldn't save the game (%s)" % error_string(err))
	changed.emit()
	return events


func owned() -> Array[CreatureData]:
	return _with_status(CreatureData.Status.OWNED)


func retired() -> Array[CreatureData]:
	return _with_status(CreatureData.Status.RETIRED)


func tier() -> int:
	return OrderBoard.tier(state.reputation)


func sell_price(c: CreatureData) -> int:
	return Market.sell_price(c)


func species_of(c: CreatureData) -> Species:
	return db.species.get(c.species)


func order_template(index: int) -> OrderTemplate:
	return db.orders.get(StringName(state.orders[index]["template"]))


func order_check(index: int, c: CreatureData) -> Dictionary:
	return Orders.check(c, order_template(index), db, state)


func group_met(c: CreatureData, g: RequirementGroup) -> bool:
	return c != null and Orders.group_met(c, g, db, state)


## The owned creature meeting the most required groups of order `index` (ties: lowest id); null when none owned.
func best_match(index: int) -> CreatureData:
	var best: CreatureData = null
	var best_n := -1
	for c in owned():
		var n := order_template(index).required.filter(func(g: RequirementGroup) -> bool: return group_met(c, g)).size()
		if n > best_n:
			best = c
			best_n = n
	return best


## The deadline day an offer would get if accepted today.
func offer_days(template_id: StringName) -> int:
	return state.day + OrderDifficulty.days(db.orders[template_id], db)


func _with_status(status: CreatureData.Status) -> Array[CreatureData]:
	var out: Array[CreatureData] = []
	for c: CreatureData in state.creatures.values():
		if c.status == status:
			out.append(c)
	out.sort_custom(func(a: CreatureData, b: CreatureData) -> bool: return a.id < b.id)
	return out


func _did(reason: String) -> String:
	if reason == "":
		changed.emit()
	return reason
