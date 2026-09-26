# Creature Core Implementation Plan (Plan 1 of 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the creature core of the breeding-shop game: content definitions edited in the Inspector, a registry,
runtime creature/game state with safe JSON saves, and the rules for training, sparks, breeding, inspiration,
growth, evolution and order matching, plus the monster-pack import tool and the first-slice content.

**Architecture:** Content is `class_name` Resources (`.tres` under `data/`) indexed by id in a `Db`. Runtime state
(`CreatureData`, `GameState`) is plain `RefCounted` objects that reference content by id and serialize to versioned
JSON. Rules are scene-free static classes that take a seeded `RandomNumberGenerator`, so every outcome is
testable headless. No scenes or UI in this plan (that is Plan 2: shop & day loop).

**Tech Stack:** Godot 4.7.2, typed GDScript, godot-ai MCP (editor-first edits), one MIT editor addon
(Edit Resources as Table), a headless test runner with no framework.

**Spec:** `docs/superpowers/specs/2026-09-26-creature-shop-design.md`

## Global Constraints

- Godot binary: `C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
  (below: `$GODOT`). In bash: `GODOT="C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`.
- Editor-first (repo `CLAUDE.md`): while the editor is open, create and edit `.gd`/`.tres` with the `godot-ai` MCP
  tools (`script_create`, `script_patch`, `resource_manage`, `filesystem_manage`). Only if the MCP is unavailable,
  write the text files directly and then run `"$GODOT" --headless --path . --import` and confirm no errors.
- Nothing may silently overwrite an editor-editable file. Generators are editor tools; overwrites are named in the
  menu item. The pack importer in this plan is create-only.
- Stats: Power, Guard, Speed, Wits, Heart; range 0–999; grade breakpoints E 0, D 100, C 250, B 400, A 600, S 800.
- Saves are JSON in `user://` via `to_dict()`/`from_dict()`, never `.tres` (loaded resources can run embedded scripts).
- Every random roll in rules takes a `RandomNumberGenerator` argument; rules never call global `randf()`.
- Licensed art is git-ignored: `asset-pipeline/80_Monster_Packs/` (already), `creatures/pack/` (added in Task 8).
- Typed GDScript everywhere (`: int`, `-> void`, typed arrays). Values read from a `Dictionary` need an explicit
  type (`var x: int = d["x"]`), because `:=` cannot infer from `Variant`.
- JSON numbers load as `float`: every `from_dict` converts with `int()` / `float()`.
- Run tests: `"$GODOT" --headless --path . -s res://tests/run_tests.gd` (exit code 0 = all pass). If a new
  `class_name` script was written outside the editor, run `"$GODOT" --headless --path . --import` first so the
  global class cache knows it.
- Work on a feature branch from `design/creature-shop`: `git switch -c feat/creature-core`.
- Commit message style: plain imperative sentence, ending with the line
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A missing, corrupt, or newer-version save file must make `GameState.load_file` return `null` with a warning,
   never crash (pinned in Task 3).
2. A save that references a species removed from `data/` must still load, skipping only that creature with a
   warning (pinned in Task 3).
3. Sparks and pools reloaded from JSON (stars as floats) must still drive inspiration correctly (pinned in Task 5).
4. Breeding parents whose own parents are wild or no longer recorded must work, with a smaller spark pool, not an
   error (pinned in Task 5).
5. No training, inspiration or mutation may push a stat above its potential or any value above 999 (pinned in
   Tasks 4 and 5).

## File Structure

```
creatures/
  stats.gd                    Stats: stat names, range, grade breakpoints
  db.gd                       Db: registry of all content by id; load_dir() scans data/<kind>/
  defs/                       content Resource classes (edited in the Inspector)
    trait_def.gd  move_def.gd  personality.gd  location.gd
    move_unlock.gd  evolution_def.gd  species.gd
    requirement.gd  requirement_group.gd  order_template.gd
  state/
    creature_data.gd          CreatureData: one creature, to_dict/from_dict
    game_state.gd             GameState: day, AP, money, reputation, creatures; JSON save/load
  rules/
    training.gd               Training: train(), learn_moves()
    sparks.gd                 Sparks: roll(), retire()
    inheritance.gd            Inheritance: compatibility(), can_breed(), breed(), inspire()
    evolution.gd              Evolution: check(), met()
    lifecycle.gd              Lifecycle: advance_day()
    orders.gd                 Orders: check(), met(), lineage()
  frames/                     SpriteFrames .tres made by the importer (committed)
  pack/                       copied licensed PNGs (git-ignored)
data/
  species/ traits/ moves/ personalities/ locations/   content .tres (committed)
addons/creature_tools/        plugin.cfg, plugin.gd, pack_importer.gd
addons/resources_spreadsheet_view/                   third-party (MIT), Task 9
tests/
  run_tests.gd                runner: every test_* method in every tests/test_*.gd
  suite.gd                    TestSuite base: check(), eq()
  fixtures.gd                 Fixtures: in-code content + creature helpers
  test_stats.gd test_db.gd test_state.gd test_training.gd test_inheritance.gd
  test_lifecycle.gd test_orders.gd test_pack_importer.gd test_content.gd
```

---

### Task 1: Test runner and Stats

**Files:**
- Create: `tests/run_tests.gd`, `tests/suite.gd`, `tests/test_stats.gd`, `creatures/stats.gd`

**Interfaces:**
- Produces: `TestSuite` (`check(cond: bool, msg: String)`, `eq(actual, expected, what: String)`, `failures`);
  `Stats.NAMES: PackedStringArray`, `Stats.MAX := 999`, `Stats.Grade {E, D, C, B, A, S}`,
  `Stats.GRADE_NAMES`, `Stats.BREAKPOINTS`, `Stats.grade(value: int) -> int`, `Stats.grade_name(value: int) -> String`.

- [ ] **Step 1: Create the branch**

```bash
git switch -c feat/creature-core
```

- [ ] **Step 2: Write the runner and the suite base**

`tests/suite.gd`:
```gdscript
class_name TestSuite
extends RefCounted
## Base for tests/test_*.gd. `check` records a failure instead of stopping, so one run reports everything.

var failures: PackedStringArray = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, what: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [what, expected, actual])
```

`tests/run_tests.gd`:
```gdscript
extends SceneTree
## Headless test runner (no framework). From the repo root:
##   godot --headless --path . -s res://tests/run_tests.gd
## Runs every test_* method of every tests/test_*.gd. Exit code 1 if anything fails.


func _init() -> void:
	var ran := 0
	var failed := 0
	for file in ResourceLoader.list_directory("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: Script = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			printerr("FAIL %s  does not compile" % file)
			failed += 1
			continue
		var suite: TestSuite = script.new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			suite.failures.clear()
			suite.call(name)
			ran += 1
			if suite.failures.is_empty():
				continue
			failed += 1
			for f in suite.failures:
				printerr("FAIL %s::%s  %s" % [file, name, f])
	print("%d tests, %d failed" % [ran, failed])
	quit(1 if failed > 0 else 0)
```

- [ ] **Step 3: Write the failing test**

`tests/test_stats.gd`:
```gdscript
extends TestSuite


func test_grade_breakpoints() -> void:
	eq(Stats.grade(0), Stats.Grade.E, "0")
	eq(Stats.grade(99), Stats.Grade.E, "99")
	eq(Stats.grade(100), Stats.Grade.D, "100")
	eq(Stats.grade(249), Stats.Grade.D, "249")
	eq(Stats.grade(250), Stats.Grade.C, "250")
	eq(Stats.grade(399), Stats.Grade.C, "399")
	eq(Stats.grade(400), Stats.Grade.B, "400")
	eq(Stats.grade(600), Stats.Grade.A, "600")
	eq(Stats.grade(799), Stats.Grade.A, "799")
	eq(Stats.grade(800), Stats.Grade.S, "800")
	eq(Stats.grade(999), Stats.Grade.S, "999")


func test_grade_name() -> void:
	eq(Stats.grade_name(450), "B", "450")
	eq(Stats.grade_name(0), "E", "0")
	eq(Stats.NAMES.size(), 5, "five stats")
```

- [ ] **Step 4: Run it to verify it fails**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_stats.gd  does not compile` (Stats is not defined), exit code 1.

- [ ] **Step 5: Implement Stats**

`creatures/stats.gd`:
```gdscript
class_name Stats
extends RefCounted
## Stat names, the 0-999 range and the grade breakpoints that orders and evolutions use.

enum Grade { E, D, C, B, A, S }

const NAMES: PackedStringArray = ["power", "guard", "speed", "wits", "heart"]
const MAX := 999
const GRADE_NAMES: PackedStringArray = ["E", "D", "C", "B", "A", "S"]
const BREAKPOINTS: PackedInt32Array = [0, 100, 250, 400, 600, 800]


static func grade(value: int) -> int:
	for g in range(BREAKPOINTS.size() - 1, 0, -1):
		if value >= BREAKPOINTS[g]:
			return g
	return Grade.E


static func grade_name(value: int) -> String:
	return GRADE_NAMES[grade(value)]
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `2 tests, 0 failed`, exit code 0.

- [ ] **Step 7: Commit**

```bash
git add tests creatures/stats.gd
git commit -m "Add headless test runner and stat grades" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Content definitions and the Db registry

**Files:**
- Create: `creatures/defs/trait_def.gd`, `move_def.gd`, `personality.gd`, `location.gd`, `move_unlock.gd`,
  `evolution_def.gd`, `species.gd`, `requirement.gd`, `requirement_group.gd`, `order_template.gd`;
  `creatures/db.gd`; `tests/fixtures.gd`; `tests/test_db.gd`

**Interfaces:**
- Consumes: `Stats` (Task 1).
- Produces (all `extends Resource`, fields `@export`):
  - `TraitDef { id: StringName, display_name: String, description: String }`
  - `MoveDef { id, display_name, element: StringName, kind: String ("damaging"|"utility") }`
  - `Personality { id, display_name, favored_stat: String, disfavored_stat: String ("none" or a stat) }`
  - `Location { id, display_name, trains_trait: TraitDef, trait_chance: float }`
  - `MoveUnlock { move: MoveDef, stat: String, grade: int }`
  - `EvolutionDef { into: Species, stat: String ("none"|stat), min_grade: int, required_trait: TraitDef, personality: Personality, min_age_days: int }`
  - `Species { id, display_name, line: StringName, stage: int, element: StringName, egg_group: StringName, potential_power..potential_heart: int, natural_traits: Array[TraitDef], moves: Array[MoveUnlock], evolutions: Array[EvolutionDef], sprite_frames: SpriteFrames; potential(stat: String) -> int }`
  - `Requirement { kind: String, id: StringName, min_grade: int, generations: int; describe() -> String }`
  - `RequirementGroup { any_of: Array[Requirement]; describe() -> String }`
  - `OrderTemplate { id, customer: String, request_text: String, required: Array[RequirementGroup], bonus: Array[RequirementGroup], reward_money: int, bonus_money: int, reward_rep: int, deadline_days: int, min_rep_tier: int }`
  - `Db` (`RefCounted`): typed dictionaries `species`, `traits`, `moves`, `personalities`, `locations`, `orders`
    keyed by `StringName` id; `static load_dir(root := "res://data") -> Db`; `add(def: Resource) -> void`;
    `base_species(line: StringName) -> Species`.
  - `Fixtures` (tests): `db() -> Db`, `trait_def(id) -> TraitDef`, `move_def(id, element, kind) -> MoveDef`,
    `species(...)`, `unlock(...)`, `evo(...)`, `rng(seed := 1) -> RandomNumberGenerator`.

- [ ] **Step 1: Write the failing test**

`tests/test_db.gd`:
```gdscript
extends TestSuite


func test_fixture_db_indexes_by_id() -> void:
	var db := Fixtures.db()
	eq(db.species.size(), 5, "species count")
	eq(db.species[&"spider"].evolutions.size(), 2, "spider has two evolution branches")
	eq(db.base_species(&"spider").id, &"spider", "base of spider line")
	eq(db.base_species(&"slime").id, &"slime", "base of slime line")
	check(db.base_species(&"nope") == null, "unknown line has no base")
	eq(db.traits[&"darksight"].display_name, "Darksight", "trait name")
	eq(db.species[&"spider"].potential("speed"), 300, "potential() reads potential_speed")


func test_duplicate_id_keeps_first() -> void:
	var db := Db.new()
	var a := Fixtures.trait_def("x")
	var b := Fixtures.trait_def("x")
	b.display_name = "second"
	db.add(a)
	db.add(b)  # logs "duplicate id" error by design
	eq(db.traits[&"x"].display_name, "X", "first definition kept")


func test_load_dir_reads_tres_files() -> void:
	var dir := "user://test_data/traits"
	DirAccess.make_dir_recursive_absolute(dir)
	ResourceSaver.save(Fixtures.trait_def("glowing"), dir.path_join("glowing.tres"))
	var db := Db.load_dir("user://test_data")
	check(db.traits.has(&"glowing"), "loaded user://test_data/traits/glowing.tres")
	eq(db.species.size(), 0, "missing folders are fine")


func test_requirement_descriptions() -> void:
	var g := RequirementGroup.new()
	g.any_of.assign([Fixtures.req("move_element", "earth"), Fixtures.req("move_kind", "damaging")])
	eq(g.describe(), "Earth move or damaging move", "group")
	eq(Fixtures.req("stat", "power", Stats.Grade.B).describe(), "Power ≥ B", "stat")
	eq(Fixtures.req("trait", "darksight").describe(), "Darksight", "trait")
	eq(Fixtures.req("lineage", "spider", 0, 3).describe(), "3 generations of Spider", "lineage")
```

- [ ] **Step 2: Run to verify it fails**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_db.gd  does not compile`.

- [ ] **Step 3: Write the definition classes**

`creatures/defs/trait_def.gd`:
```gdscript
class_name TraitDef
extends Resource
## A trait a creature can have: natural (from its species), learned (training/care) or inherited (spark).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
```

`creatures/defs/move_def.gd`:
```gdscript
class_name MoveDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var element: StringName
@export_enum("damaging", "utility") var kind: String = "damaging"
```

`creatures/defs/personality.gd`:
```gdscript
class_name Personality
extends Resource
## Training on the favored stat gains 25% more, on the disfavored stat 25% less.

@export var id: StringName
@export var display_name: String
@export_enum("power", "guard", "speed", "wits", "heart") var favored_stat: String = "power"
@export_enum("none", "power", "guard", "speed", "wits", "heart") var disfavored_stat: String = "none"
```

`creatures/defs/location.gd`:
```gdscript
class_name Location
extends Resource
## A place to train (and, in Plan 2, to send expeditions). Training here may teach `trains_trait`.

@export var id: StringName
@export var display_name: String
@export var trains_trait: TraitDef
@export_range(0.0, 1.0) var trait_chance: float = 0.15
```

`creatures/defs/move_unlock.gd`:
```gdscript
class_name MoveUnlock
extends Resource
## A species learns `move` once `stat` reaches `grade`.

@export var move: MoveDef
@export_enum("power", "guard", "speed", "wits", "heart") var stat: String = "power"
@export_enum("E", "D", "C", "B", "A", "S") var grade: int = 1
```

`creatures/defs/evolution_def.gd`:
```gdscript
class_name EvolutionDef
extends Resource
## One evolution branch. Every set condition must hold; unset ones are ignored.

@export var into: Species
@export_enum("none", "power", "guard", "speed", "wits", "heart") var stat: String = "none"
@export_enum("E", "D", "C", "B", "A", "S") var min_grade: int = 0
@export var required_trait: TraitDef
@export var personality: Personality
@export var min_age_days: int = 0
```

`creatures/defs/species.gd`:
```gdscript
class_name Species
extends Resource
## A kind of creature. Potentials are the typical stat caps of a wild one; bred ones inherit their parents' instead.

@export var id: StringName
@export var display_name: String
## Evolution line shared by every stage, e.g. &"spider" for Spider, Spider Albino and Spider Large.
@export var line: StringName
@export_range(1, 3) var stage: int = 1
@export var element: StringName
@export var egg_group: StringName
@export_group("Potential")
@export_range(0, 999) var potential_power: int = 300
@export_range(0, 999) var potential_guard: int = 300
@export_range(0, 999) var potential_speed: int = 300
@export_range(0, 999) var potential_wits: int = 300
@export_range(0, 999) var potential_heart: int = 300
@export_group("")
@export var natural_traits: Array[TraitDef] = []
@export var moves: Array[MoveUnlock] = []
## Checked in order at the end of each day; the first satisfied branch wins.
@export var evolutions: Array[EvolutionDef] = []
@export var sprite_frames: SpriteFrames


func potential(stat: String) -> int:
	return get("potential_" + stat)
```

`creatures/defs/requirement.gd`:
```gdscript
class_name Requirement
extends Resource
## One condition an order checks. `id` is the species id, line id, stat name, trait id, element, move kind
## ("damaging"/"utility"), personality id, or (lineage) the line id.

@export_enum("species", "line", "stat", "trait", "move_element", "move_kind", "personality", "lineage")
var kind: String = "species"
@export var id: StringName
@export_enum("E", "D", "C", "B", "A", "S") var min_grade: int = 0  ## stat only
@export_range(1, 5) var generations: int = 2  ## lineage only


func describe() -> String:
	var name := String(id).capitalize()
	match kind:
		"species":
			return "a %s" % name
		"line":
			return "any %s" % name
		"stat":
			return "%s ≥ %s" % [name, Stats.GRADE_NAMES[min_grade]]
		"move_element":
			return "%s move" % name
		"move_kind":
			return "%s move" % id
		"personality":
			return "%s personality" % name
		"lineage":
			return "%d generations of %s" % [generations, name]
	return name  # trait
```

`creatures/defs/requirement_group.gd`:
```gdscript
class_name RequirementGroup
extends Resource
## Passes when any one of its requirements passes. An order passes when all its groups pass.

@export var any_of: Array[Requirement] = []


func describe() -> String:
	return " or ".join(any_of.map(func(r: Requirement) -> String: return r.describe()))
```

`creatures/defs/order_template.gd`:
```gdscript
class_name OrderTemplate
extends Resource
## A customer request. All `required` groups must pass; `bonus` groups add `bonus_money` when they all pass too.

@export var id: StringName
@export var customer: String
@export_multiline var request_text: String
@export var required: Array[RequirementGroup] = []
@export var bonus: Array[RequirementGroup] = []
@export var reward_money: int = 100
@export var bonus_money: int = 50
@export var reward_rep: int = 5
@export var deadline_days: int = 5
@export_range(0, 5) var min_rep_tier: int = 0
```

- [ ] **Step 4: Write the Db**

`creatures/db.gd`:
```gdscript
class_name Db
extends RefCounted
## Every content definition, indexed by id. load_dir() reads data/<kind>/*.tres, so a new .tres made in the
## editor is all it takes to add content. Definitions are read-only at runtime.

const FOLDERS: PackedStringArray = ["species", "traits", "moves", "personalities", "locations", "orders"]

var species: Dictionary[StringName, Species] = {}
var traits: Dictionary[StringName, TraitDef] = {}
var moves: Dictionary[StringName, MoveDef] = {}
var personalities: Dictionary[StringName, Personality] = {}
var locations: Dictionary[StringName, Location] = {}
var orders: Dictionary[StringName, OrderTemplate] = {}


static func load_dir(root := "res://data") -> Db:
	var db := Db.new()
	for sub in FOLDERS:
		var dir := root.path_join(sub)
		for file in ResourceLoader.list_directory(dir):
			if file.ends_with(".tres") or file.ends_with(".res"):
				db.add(load(dir.path_join(file)))
	return db


func add(def: Resource) -> void:
	var table: Dictionary
	if def is Species:
		table = species
	elif def is TraitDef:
		table = traits
	elif def is MoveDef:
		table = moves
	elif def is Personality:
		table = personalities
	elif def is Location:
		table = locations
	elif def is OrderTemplate:
		table = orders
	else:
		push_error("Db: %s is not a content definition" % def.resource_path)
		return
	var id: StringName = def.get("id")
	if id == &"":
		push_error("Db: %s has no id" % def.resource_path)
		return
	if table.has(id):
		push_error("Db: duplicate id '%s' (%s)" % [id, def.resource_path])
		return
	table[id] = def


func base_species(line: StringName) -> Species:
	for s: Species in species.values():
		if s.line == line and s.stage == 1:
			return s
	return null
```

- [ ] **Step 5: Write the fixtures**

`tests/fixtures.gd`:
```gdscript
class_name Fixtures
extends RefCounted
## In-code content for tests, independent of data/: a spider line with two evolution branches
## (Darksight -> Albino, Power B -> Large) and a slime line (Cheerful -> Antenna).


static func db() -> Db:
	var d := Db.new()
	var darksight := trait_def("darksight")
	var glowing := trait_def("glowing")
	var tunnel := trait_def("tunnel_wise")
	for t in [darksight, glowing, tunnel]:
		d.add(t)
	var bite := move_def("bite", "beast", "damaging")
	var web := move_def("web", "dark", "utility")
	var dig := move_def("dig", "earth", "damaging")
	for m in [bite, web, dig]:
		d.add(m)
	var cheerful := Personality.new()
	cheerful.id = &"cheerful"
	cheerful.favored_stat = "heart"
	var timid := Personality.new()
	timid.id = &"timid"
	timid.favored_stat = "speed"
	timid.disfavored_stat = "power"
	d.add(cheerful)
	d.add(timid)
	var mine := Location.new()
	mine.id = &"mine"
	mine.trains_trait = tunnel
	mine.trait_chance = 1.0
	d.add(mine)

	var albino := species("spider_albino", "spider", 2, "dark", "bug", [darksight])
	var large := species("spider_large", "spider", 2, "dark", "bug", [])
	var spider := species("spider", "spider", 1, "dark", "bug", [])
	spider.potential_speed = 300
	spider.moves.assign([unlock(bite, "power", Stats.Grade.D), unlock(web, "speed", Stats.Grade.C)])
	spider.evolutions.assign([
		evo(albino, "none", 0, darksight, null),
		evo(large, "power", Stats.Grade.B, null, null),
	])
	var antenna := species("slime_antenna", "slime", 2, "light", "amorphous", [glowing])
	var slime := species("slime", "slime", 1, "water", "amorphous", [])
	slime.evolutions.assign([evo(antenna, "none", 0, null, cheerful)])
	for s in [spider, albino, large, slime, antenna]:
		d.add(s)
	return d


static func trait_def(id: String) -> TraitDef:
	var t := TraitDef.new()
	t.id = StringName(id)
	t.display_name = id.capitalize()
	return t


static func move_def(id: String, element: String, kind: String) -> MoveDef:
	var m := MoveDef.new()
	m.id = StringName(id)
	m.display_name = id.capitalize()
	m.element = StringName(element)
	m.kind = kind
	return m


static func species(id: String, line: String, stage: int, element: String, egg_group: String, traits: Array) -> Species:
	var s := Species.new()
	s.id = StringName(id)
	s.display_name = id.capitalize()
	s.line = StringName(line)
	s.stage = stage
	s.element = StringName(element)
	s.egg_group = StringName(egg_group)
	s.natural_traits.assign(traits)
	return s


static func unlock(move: MoveDef, stat: String, grade: int) -> MoveUnlock:
	var u := MoveUnlock.new()
	u.move = move
	u.stat = stat
	u.grade = grade
	return u


static func evo(into: Species, stat: String, min_grade: int, required_trait: TraitDef, personality: Personality) -> EvolutionDef:
	var e := EvolutionDef.new()
	e.into = into
	e.stat = stat
	e.min_grade = min_grade
	e.required_trait = required_trait
	e.personality = personality
	return e


static func req(kind: String, id: String, min_grade := 0, generations := 2) -> Requirement:
	var r := Requirement.new()
	r.kind = kind
	r.id = StringName(id)
	r.min_grade = min_grade
	r.generations = generations
	return r


static func rng(seed_value := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `6 tests, 0 failed`. (The "duplicate id" error line in the log is expected.)

- [ ] **Step 7: Check the classes open in the editor**

With the editor open, use godot-ai `resource_manage` (or FileSystem > New Resource) to create a throwaway
`Species` in `res://` and confirm the Inspector shows the Potential group, the three arrays and the enum dropdowns.
Delete the throwaway. Take an `editor_screenshot` of the Inspector.

- [ ] **Step 8: Commit**

```bash
git add creatures tests
git commit -m "Add content definition resources and the Db registry" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Creature and game state with JSON saves

**Files:**
- Create: `creatures/state/creature_data.gd`, `creatures/state/game_state.gd`, `tests/test_state.gd`
- Modify: `tests/fixtures.gd` (add `adult()`)

**Interfaces:**
- Consumes: `Stats`, `Db`, `Species` (Tasks 1–2).
- Produces:
  - `CreatureData` (`RefCounted`): `enum Status {OWNED, RETIRED, GONE}`, `const START_FRACTION := 0.2`; fields
    `id: int, species: StringName, parents: PackedInt32Array, status: Status, stage: String ("egg"|"baby"|"adult"),
    days_left: int, age_days: int, potential: Dictionary (String->int), stats: Dictionary (String->int),
    traits: Array[StringName], moves: Array[StringName], personality: StringName, mood: int, breed_cooldown: int,
    sparks: Array[Dictionary], pool: Array[Dictionary], inspirations: int`;
    `static wild(sp: Species, new_id: int, rng) -> CreatureData`; `all_traits(db: Db) -> Array[StringName]`;
    `to_dict() -> Dictionary`; `static from_dict(d: Dictionary) -> CreatureData`.
    Spark dict: `{"kind": String, "id": String, "stars": int}`; pool entries add `"weight": float`.
  - `GameState` (`RefCounted`): `SAVE_VERSION := 1`, `SAVE_PATH := "user://save.json"`, `START_AP := 5`; fields
    `day, ap, money, reputation, next_id: int`, `creatures: Dictionary[int, CreatureData]`;
    `new_id() -> int`, `add(c)`, `get_creature(id: int) -> CreatureData`, `to_dict()`,
    `static from_dict(d, db) -> GameState`, `save(path := SAVE_PATH) -> Error`,
    `static load_file(db: Db, path := SAVE_PATH) -> GameState` (null on missing/corrupt/unsupported).
  - `Fixtures.adult(state, species_id: String, stat := 200, cap := 500) -> CreatureData`.

- [ ] **Step 1: Add the fixture helper**

Append to `tests/fixtures.gd`:
```gdscript


## An adult of `species_id` with every stat at `stat` and every potential at `cap`, added to `state`.
static func adult(state: GameState, species_id: String, stat := 200, cap := 500) -> CreatureData:
	var c := CreatureData.new()
	c.id = state.new_id()
	c.species = StringName(species_id)
	for s in Stats.NAMES:
		c.stats[s] = stat
		c.potential[s] = cap
	state.add(c)
	return c
```

- [ ] **Step 2: Write the failing tests**

`tests/test_state.gd`:
```gdscript
extends TestSuite

const PATH := "user://test_save.json"


func _sample() -> GameState:
	var st := GameState.new()
	st.day = 4
	st.money = 1234
	var a := Fixtures.adult(st, "spider", 210, 480)
	a.traits.append(&"tunnel_wise")
	a.moves.append(&"bite")
	a.personality = &"timid"
	a.status = CreatureData.Status.RETIRED
	a.sparks.append({"kind": "trait", "id": "tunnel_wise", "stars": 2})
	var b := Fixtures.adult(st, "slime")
	b.parents = PackedInt32Array([a.id, 99])
	b.pool.append({"kind": "stat", "id": "power", "stars": 3, "weight": 0.5})
	return st


func test_wild_creature_rolls_near_species_potential() -> void:
	var sp: Species = Fixtures.db().species[&"spider"]
	var c := CreatureData.wild(sp, 7, Fixtures.rng())
	eq(c.id, 7, "id")
	for s in Stats.NAMES:
		check(c.potential[s] >= 270 and c.potential[s] <= 330, "%s potential within ±10%%" % s)
		eq(c.stats[s], roundi(c.potential[s] * CreatureData.START_FRACTION), "%s starts at 20%%" % s)


func test_all_traits_merges_natural_without_duplicates() -> void:
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider_albino")
	c.traits.append(&"darksight")
	c.traits.append(&"tunnel_wise")
	eq(c.all_traits(Fixtures.db()), [&"darksight", &"tunnel_wise"], "merged")


func test_json_round_trip_restores_everything() -> void:
	var st := _sample()
	var d := st.to_dict()
	var back := GameState.from_dict(JSON.parse_string(JSON.stringify(d)), Fixtures.db())
	eq(back.to_dict(), d, "round trip")
	eq(typeof(back.creatures[1].stats["power"]), TYPE_INT, "ints stay ints")
	eq(typeof(back.creatures[2].pool[0]["stars"]), TYPE_INT, "stars stay ints")


func test_save_and_load_file_twice() -> void:
	var db := Fixtures.db()
	var st := _sample()
	eq(st.save(PATH), OK, "first save")
	st.money = 50
	eq(st.save(PATH), OK, "second save overwrites")
	var back := GameState.load_file(db, PATH)
	check(back != null, "loads")
	eq(back.money, 50, "latest save wins")
	check(not FileAccess.file_exists(PATH + ".tmp"), "temp file cleaned up")


func test_missing_corrupt_or_newer_save_returns_null() -> void:
	var db := Fixtures.db()
	check(GameState.load_file(db, "user://does_not_exist.json") == null, "missing")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	check(GameState.load_file(db, PATH) == null, "corrupt")
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": GameState.SAVE_VERSION + 1}))
	f.close()
	check(GameState.load_file(db, PATH) == null, "newer version")


func test_unknown_species_is_skipped_not_fatal() -> void:
	var d := _sample().to_dict()
	d["creatures"][0]["species"] = "removed_species"
	var back := GameState.from_dict(d, Fixtures.db())
	eq(back.creatures.size(), 1, "only the valid creature loads")
	check(back.creatures.has(2), "slime kept")
```

- [ ] **Step 3: Run to verify they fail**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_state.gd  does not compile` (and fixtures fail to compile because `GameState` is missing).

- [ ] **Step 4: Implement CreatureData**

`creatures/state/creature_data.gd`:
```gdscript
class_name CreatureData
extends RefCounted
## One individual creature: runtime state, saved as JSON. Content is referenced by id.
## GONE creatures (delivered or sold) are kept as records so pedigrees survive.

enum Status { OWNED, RETIRED, GONE }

const START_FRACTION := 0.2  ## a new creature starts with stats at 20% of its potential

var id := 0
var species: StringName
var parents: PackedInt32Array = []  ## empty for wild or bought creatures
var status := Status.OWNED
var stage := "adult"  ## "egg", "baby" or "adult"
var days_left := 0  ## egg: days to hatch; baby: days to adulthood
var age_days := 0  ## days since hatching
var potential := {}  ## stat name -> cap
var stats := {}  ## stat name -> value
var traits: Array[StringName] = []  ## learned and inherited; natural ones come from the species
var moves: Array[StringName] = []
var personality: StringName
var mood := 50
var breed_cooldown := 0
var sparks: Array[Dictionary] = []  ## locked on retire: {kind, id, stars}
var pool: Array[Dictionary] = []  ## inherited sparks waiting for inspiration: {kind, id, stars, weight}
var inspirations := 0


static func wild(sp: Species, new_id: int, rng: RandomNumberGenerator) -> CreatureData:
	var c := CreatureData.new()
	c.id = new_id
	c.species = sp.id
	for s in Stats.NAMES:
		var cap := clampi(roundi(sp.potential(s) * rng.randf_range(0.9, 1.1)), 0, Stats.MAX)
		c.potential[s] = cap
		c.stats[s] = roundi(cap * START_FRACTION)
	return c


func all_traits(db: Db) -> Array[StringName]:
	var out: Array[StringName] = traits.duplicate()
	for t in db.species[species].natural_traits:
		if t and not out.has(t.id):
			out.append(t.id)
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"species": String(species),
		"parents": Array(parents),
		"status": status,
		"stage": stage,
		"days_left": days_left,
		"age_days": age_days,
		"potential": potential.duplicate(),
		"stats": stats.duplicate(),
		"traits": Array(traits).map(func(t: StringName) -> String: return String(t)),
		"moves": Array(moves).map(func(m: StringName) -> String: return String(m)),
		"personality": String(personality),
		"mood": mood,
		"breed_cooldown": breed_cooldown,
		"sparks": sparks.duplicate(true),
		"pool": pool.duplicate(true),
		"inspirations": inspirations,
	}


static func from_dict(d: Dictionary) -> CreatureData:
	var c := CreatureData.new()
	c.id = int(d.get("id", 0))
	c.species = StringName(str(d.get("species", "")))
	for p in d.get("parents", []):
		c.parents.append(int(p))
	c.status = int(d.get("status", Status.OWNED)) as Status
	c.stage = str(d.get("stage", "adult"))
	c.days_left = int(d.get("days_left", 0))
	c.age_days = int(d.get("age_days", 0))
	var pot: Dictionary = d.get("potential", {})
	var sts: Dictionary = d.get("stats", {})
	for s in Stats.NAMES:
		c.potential[s] = int(pot.get(s, 0))
		c.stats[s] = int(sts.get(s, 0))
	for t in d.get("traits", []):
		c.traits.append(StringName(str(t)))
	for m in d.get("moves", []):
		c.moves.append(StringName(str(m)))
	c.personality = StringName(str(d.get("personality", "")))
	c.mood = int(d.get("mood", 50))
	c.breed_cooldown = int(d.get("breed_cooldown", 0))
	c.sparks = _sparks_from(d.get("sparks", []))
	c.pool = _sparks_from(d.get("pool", []))
	c.inspirations = int(d.get("inspirations", 0))
	return c


static func _sparks_from(list: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if list is not Array:
		return out
	for s in list:
		if s is not Dictionary:
			continue
		var e := {"kind": str(s.get("kind", "")), "id": str(s.get("id", "")), "stars": clampi(int(s.get("stars", 1)), 1, 3)}
		if s.has("weight"):
			e["weight"] = float(s["weight"])
		out.append(e)
	return out
```

- [ ] **Step 5: Implement GameState**

`creatures/state/game_state.gd`:
```gdscript
class_name GameState
extends RefCounted
## Everything that changes during play. Saved as versioned JSON in user://, never as .tres: loading a resource
## can run embedded scripts, and players share save files.

const SAVE_VERSION := 1
const SAVE_PATH := "user://save.json"
const START_AP := 5

var day := 1
var ap := START_AP
var money := 500
var reputation := 0
var next_id := 1
var creatures: Dictionary[int, CreatureData] = {}  ## every creature ever owned; GONE ones stay for pedigrees


func new_id() -> int:
	next_id += 1
	return next_id - 1


func add(c: CreatureData) -> void:
	creatures[c.id] = c


func get_creature(id: int) -> CreatureData:
	return creatures.get(id)


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"day": day,
		"ap": ap,
		"money": money,
		"reputation": reputation,
		"next_id": next_id,
		"creatures": creatures.values().map(func(c: CreatureData) -> Dictionary: return c.to_dict()),
	}


## Creatures whose species no longer exists in `db` are skipped with a warning, so removing content never
## makes an old save unloadable.
static func from_dict(d: Dictionary, db: Db) -> GameState:
	var g := GameState.new()
	g.day = int(d.get("day", 1))
	g.ap = int(d.get("ap", START_AP))
	g.money = int(d.get("money", 0))
	g.reputation = int(d.get("reputation", 0))
	g.next_id = int(d.get("next_id", 1))
	for cd in d.get("creatures", []):
		if cd is not Dictionary:
			continue
		var c := CreatureData.from_dict(cd)
		if not db.species.has(c.species):
			push_warning("save: creature #%d has unknown species '%s'; skipped" % [c.id, c.species])
			continue
		g.creatures[c.id] = c
	return g


## Writes to a temp file first, then renames, so a crash mid-write never destroys the previous save.
func save(path := SAVE_PATH) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, path)


## Returns null (with a warning) when the file is missing, not valid JSON, or from an unsupported version.
static func load_file(db: Db, path := SAVE_PATH) -> GameState:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		push_warning("save: %s is not valid JSON" % path)
		return null
	var version := int(data.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		push_warning("save: %s has unsupported version %d" % [path, version])
		return null
	return from_dict(data, db)
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: all pass. If `test_save_and_load_file_twice` fails on "second save overwrites" (rename refusing to
replace an existing file on Windows), change `save()` to call `DirAccess.remove_absolute(path)` right before the
rename when `FileAccess.file_exists(path)`, and re-run.

- [ ] **Step 7: Commit**

```bash
git add creatures/state tests
git commit -m "Add creature and game state with versioned JSON saves" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Training and move learning

**Files:**
- Create: `creatures/rules/training.gd`, `tests/test_training.gd`

**Interfaces:**
- Consumes: `CreatureData`, `Db`, `Location`, `Personality`, `Stats`.
- Produces: `Training.BASE_GAIN := 40`, `Training.MOOD_COST := 10`;
  `Training.train(c: CreatureData, stat: String, location: Location, db: Db, rng) -> Dictionary`
  returning `{"gain": int, "trait": String ("" if none), "moves": Array[StringName]}`;
  `Training.learn_moves(c: CreatureData, db: Db) -> Array[StringName]` (newly learned).

- [ ] **Step 1: Write the failing tests**

`tests/test_training.gd`:
```gdscript
extends TestSuite


func test_gain_uses_personality_and_mood() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 200, 500)
	c.personality = &"timid"  # favours speed, dislikes power
	var r := Training.train(c, "speed", null, db, Fixtures.rng())
	eq(r["gain"], 50, "40 * 1.25 at mood 50")
	eq(c.stats["speed"], 250, "speed raised")
	eq(c.mood, 40, "mood cost")
	var p := Training.train(c, "power", null, db, Fixtures.rng())
	eq(p["gain"], 27, "40 * 0.75 * (0.5 + 0.40)")


func test_gain_never_exceeds_potential() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 490, 500)
	var r := Training.train(c, "guard", null, db, Fixtures.rng())
	eq(r["gain"], 10, "capped gain")
	eq(c.stats["guard"], 500, "at potential")
	Training.train(c, "guard", null, db, Fixtures.rng())
	eq(c.stats["guard"], 500, "still at potential")


func test_moves_unlock_at_stat_grades() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 200, 500)  # power 200 = D, speed 200 = D
	var r := Training.train(c, "speed", null, db, Fixtures.rng())  # speed -> 240, still D
	eq(r["moves"], [&"bite"], "bite unlocks at power D")
	r = Training.train(c, "speed", null, db, Fixtures.rng())  # speed crosses 250 = C
	eq(r["moves"], [&"web"], "web unlocks at speed C")
	eq(c.moves, [&"bite", &"web"], "both known, no duplicates")


func test_location_teaches_its_trait_once() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	var mine: Location = db.locations[&"mine"]  # trait_chance 1.0 in fixtures
	var r := Training.train(c, "power", mine, db, Fixtures.rng())
	eq(r["trait"], "tunnel_wise", "learned at the mine")
	r = Training.train(c, "power", mine, db, Fixtures.rng())
	eq(r["trait"], "", "not learned twice")
	eq(c.traits.count(&"tunnel_wise"), 1, "one copy")
```

Note on `test_moves_unlock_at_stat_grades`: mood 50 → first gain 40 (speed 240), mood 40 → second gain
`roundi(40 * 0.9) = 36` (speed 276 ≥ 250).

- [ ] **Step 2: Run to verify they fail**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_training.gd  does not compile`.

- [ ] **Step 3: Implement Training**

`creatures/rules/training.gd`:
```gdscript
class_name Training
extends RefCounted
## One training drill: a stat gain toward its potential, possibly a trait from the location, and any moves
## the new stat unlocks. Gain = BASE_GAIN x personality (±25%) x mood (0.5 at 0 mood, 1.5 at 100).

const BASE_GAIN := 40
const MOOD_COST := 10


static func train(c: CreatureData, stat: String, location: Location, db: Db, rng: RandomNumberGenerator) -> Dictionary:
	var mult := 1.0
	var p: Personality = db.personalities.get(c.personality)
	if p:
		if p.favored_stat == stat:
			mult += 0.25
		if p.disfavored_stat == stat:
			mult -= 0.25
	mult *= 0.5 + c.mood / 100.0
	var before: int = c.stats[stat]
	var cap: int = c.potential[stat]
	c.stats[stat] = mini(before + roundi(BASE_GAIN * mult), cap)
	c.mood = maxi(c.mood - MOOD_COST, 0)
	var result := {"gain": int(c.stats[stat]) - before, "trait": "", "moves": learn_moves(c, db)}
	if location and location.trains_trait:
		var t := location.trains_trait.id
		if not c.all_traits(db).has(t) and rng.randf() < location.trait_chance:
			c.traits.append(t)
			result["trait"] = String(t)
	return result


static func learn_moves(c: CreatureData, db: Db) -> Array[StringName]:
	var learned: Array[StringName] = []
	for u in db.species[c.species].moves:
		if u.move and not c.moves.has(u.move.id) and Stats.grade(c.stats[u.stat]) >= u.grade:
			c.moves.append(u.move.id)
			learned.append(u.move.id)
	return learned
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add creatures/rules/training.gd tests/test_training.gd
git commit -m "Add training rules and move unlocks" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Sparks, breeding and inspiration

**Files:**
- Create: `creatures/rules/sparks.gd`, `creatures/rules/inheritance.gd`, `tests/test_inheritance.gd`

**Interfaces:**
- Consumes: `CreatureData`, `GameState`, `Db`, `Stats`, `Training.learn_moves` (Task 4).
- Produces:
  - `Sparks.roll(c, db, rng) -> Array[Dictionary]`: one stat spark (best stat; stars 1 below B, 2 for B/A, 3 for S),
    one per trait in `c.all_traits(db)` (1–3★ random), one move spark if any moves (1–3★), one personality spark
    if set (1–3★). `Sparks.retire(c, db, rng) -> void` sets `c.sparks` and `c.status = RETIRED`.
  - `Inheritance`: constants `HATCH_DAYS := 2`, `COOLDOWN_DAYS := 3`, `POTENTIAL_VARIANCE := 30`,
    `MUTATION_CHANCE := 0.05`, `EVOLVED_CHILD_CHANCE := 0.1`, `GRANDPARENT_WEIGHT := 0.5`,
    `COMPAT_MULT := [1.0, 1.25, 1.5]`, `COMPAT_MARKS := ["△", "○", "◎"]`, `PROC_CHANCE := [0, 0.2, 0.35, 0.5]`,
    `STAT_BOOST := [0, 10, 20, 35]`, `POTENTIAL_BOOST := [0, 15, 30, 50]`;
    `compatibility(a, b, db) -> int` (0 △, 1 ○, 2 ◎); `can_breed(a, b, db) -> String` ("" = OK, else reason);
    `breed(a, b, state, db, rng) -> CreatureData` (egg added to state; null + error if `can_breed` fails);
    `inspire(c, db, rng) -> Array[Dictionary]` (procced sparks).

- [ ] **Step 1: Write the failing tests**

`tests/test_inheritance.gd`:
```gdscript
extends TestSuite


func _retired(st: GameState, db: Db, species_id: String, seed_value := 1) -> CreatureData:
	var c := Fixtures.adult(st, species_id)
	Sparks.retire(c, db, Fixtures.rng(seed_value))
	return c


func test_roll_one_spark_per_source() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider_albino", 200, 900)
	c.stats["power"] = 650
	c.traits.append(&"tunnel_wise")
	c.moves.append(&"bite")
	c.personality = &"timid"
	var sparks := Sparks.roll(c, db, Fixtures.rng())
	eq(sparks.size(), 5, "stat + 2 traits + move + personality")
	eq(sparks[0], {"kind": "stat", "id": "power", "stars": 2}, "best stat is power at A")
	# learned traits first, then natural ones (CreatureData.all_traits order)
	eq(sparks.map(func(s: Dictionary) -> String: return s["id"]), ["power", "tunnel_wise", "darksight", "bite", "timid"], "ids")
	for s in sparks:
		check(s["stars"] >= 1 and s["stars"] <= 3, "stars in 1..3")


func test_stat_spark_stars_follow_grade() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	for pair in [[300, 1], [450, 2], [650, 2], [850, 3]]:
		var c := Fixtures.adult(st, "spider", pair[0], 999)
		eq(Sparks.roll(c, db, Fixtures.rng())[0]["stars"], pair[1], "stat %d" % pair[0])


func test_retire_locks_sparks() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := _retired(st, db, "spider")
	eq(c.status, CreatureData.Status.RETIRED, "retired")
	check(not c.sparks.is_empty(), "sparks locked")


func test_compatibility_marks() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var spider := _retired(st, db, "spider")
	var albino := _retired(st, db, "spider_albino")
	var slime := _retired(st, db, "slime")
	var antenna := Fixtures.adult(st, "slime_antenna")
	antenna.stats["heart"] = 300  # best stat differs from slime's, so no shared stat spark
	Sparks.retire(antenna, db, Fixtures.rng())
	eq(Inheritance.compatibility(spider, albino, db), 2, "same line+element+group = ◎")
	eq(Inheritance.compatibility(slime, antenna, db), 1, "same line+group, different element = ○")
	eq(Inheritance.compatibility(spider, slime, db), 0, "only a shared stat spark (score 1) = △")


func test_can_breed_reasons() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var a := _retired(st, db, "spider")
	var b := Fixtures.adult(st, "spider")
	check(Inheritance.can_breed(a, b, db) != "", "b not retired")
	Sparks.retire(b, db, Fixtures.rng())
	eq(Inheritance.can_breed(a, b, db), "", "ok")
	check(Inheritance.can_breed(a, a, db) != "", "same creature")
	var s := _retired(st, db, "slime")
	check(Inheritance.can_breed(a, s, db) != "", "egg groups differ")
	b.breed_cooldown = 1
	check(Inheritance.can_breed(a, b, db) != "", "cooldown")


func test_breed_makes_base_form_egg_with_pool_and_cooldowns() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var a := _retired(st, db, "spider")
	var b := _retired(st, db, "spider")
	var child := Inheritance.breed(a, b, st, db, Fixtures.rng())
	eq(child.species, &"spider", "base form")
	eq(child.stage, "egg", "egg")
	eq(child.days_left, Inheritance.HATCH_DAYS, "hatch timer")
	eq(child.parents, PackedInt32Array([a.id, b.id]), "parents recorded")
	check(st.get_creature(child.id) == child, "added to state")
	eq(child.pool.size(), a.sparks.size() + b.sparks.size(), "parents' sparks, no grandparents")
	for p in child.pool:
		eq(p["weight"], 1.5, "◎ multiplier on parent sparks")
	eq(a.breed_cooldown, Inheritance.COOLDOWN_DAYS, "cooldown a")
	eq(b.breed_cooldown, Inheritance.COOLDOWN_DAYS, "cooldown b")


func test_potential_is_average_plus_variance_and_capped() -> void:
	var db := Fixtures.db()
	for seed_value in 50:
		var st := GameState.new()
		var a := _retired(st, db, "spider")
		var b := _retired(st, db, "spider")
		a.potential["power"] = 400
		b.potential["power"] = 600
		a.potential["heart"] = 999
		b.potential["heart"] = 999
		var c := Inheritance.breed(a, b, st, db, Fixtures.rng(seed_value))
		var p: int = c.potential["power"]
		check(p >= 470 and p <= 650, "power %d within 500-30 .. 500+30+120" % p)
		check(c.potential["heart"] <= Stats.MAX, "heart capped at 999")


func test_evolved_child_only_when_both_parents_evolved() -> void:
	var db := Fixtures.db()
	var evolved := 0
	for seed_value in 400:
		var st := GameState.new()
		var a := _retired(st, db, "spider_albino")
		var b := _retired(st, db, "spider_large")
		if db.species[Inheritance.breed(a, b, st, db, Fixtures.rng(seed_value)).species].stage > 1:
			evolved += 1
		var c := _retired(st, db, "spider")
		var d := _retired(st, db, "spider")
		eq(Inheritance.breed(c, d, st, db, Fixtures.rng(seed_value)).species, &"spider", "base parents -> base child")
	check(evolved >= 20 and evolved <= 70, "about 10%% evolved children (got %d/400)" % evolved)


func test_grandparents_join_pool_at_half_weight_and_missing_ones_are_skipped() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var gp1 := _retired(st, db, "spider")
	var gp2 := _retired(st, db, "spider")
	var parent := _retired(st, db, "spider")
	parent.parents = PackedInt32Array([gp1.id, gp2.id])
	var other := _retired(st, db, "spider")
	other.parents = PackedInt32Array([424242, 434343])  # records no longer exist
	var child := Inheritance.breed(parent, other, st, db, Fixtures.rng())
	var expected := parent.sparks.size() + other.sparks.size() + gp1.sparks.size() + gp2.sparks.size()
	eq(child.pool.size(), expected, "parents + known grandparents only")
	# pool order: parent's sparks, then parent's grandparents, then other's sparks
	eq(child.pool[0]["weight"], 1.5, "parent weight = ◎ multiplier")
	eq(child.pool[parent.sparks.size()]["weight"], 0.75, "grandparent weight = 1.5 * 0.5")


func test_inspire_applies_every_kind_and_respects_caps() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 980, 990)
	c.pool.assign([
		{"kind": "stat", "id": "power", "stars": 3, "weight": 2.0},
		{"kind": "trait", "id": "darksight", "stars": 3, "weight": 2.0},
		{"kind": "move", "id": "dig", "stars": 3, "weight": 2.0},
		{"kind": "personality", "id": "cheerful", "stars": 3, "weight": 2.0},
	])  # 0.5 x 2.0 = always procs
	var procs := Inheritance.inspire(c, db, Fixtures.rng())
	eq(procs.size(), 4, "all proc")
	eq(c.potential["power"], 999, "potential capped at 999")
	eq(c.stats["power"], 999, "stat capped at potential")
	eq(c.traits, [&"darksight"], "trait granted")
	check(c.moves.has(&"dig"), "move granted")
	eq(c.personality, &"cheerful", "personality set")
	eq(c.inspirations, 1, "counted")
	Inheritance.inspire(c, db, Fixtures.rng())
	eq(c.traits.count(&"darksight"), 1, "trait not duplicated")


func test_inspire_after_json_round_trip() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var a := _retired(st, db, "spider_albino", 3)
	var b := _retired(st, db, "spider", 4)
	var child := Inheritance.breed(a, b, st, db, Fixtures.rng(5))
	var back := CreatureData.from_dict(JSON.parse_string(JSON.stringify(child.to_dict())))
	var n1 := Inheritance.inspire(child, db, Fixtures.rng(9)).size()
	var n2 := Inheritance.inspire(back, db, Fixtures.rng(9)).size()
	eq(n2, n1, "same procs from reloaded pool")


func test_darksight_can_pass_two_generations() -> void:
	# An Albino's natural Darksight reaches a grandchild that has no Albino parent.
	var db := Fixtures.db()
	var got_child := 0
	var got_grandchild := 0
	for seed_value in 60:
		var rng := Fixtures.rng(seed_value)
		var st := GameState.new()
		var albino := _retired(st, db, "spider_albino", seed_value)
		var mate := _retired(st, db, "spider", seed_value + 1000)
		var child := Inheritance.breed(albino, mate, st, db, rng)
		for i in 3:
			Inheritance.inspire(child, db, rng)
		if not child.traits.has(&"darksight"):
			continue
		got_child += 1
		child.stage = "adult"
		Sparks.retire(child, db, rng)
		var mate2 := _retired(st, db, "spider", seed_value + 2000)
		var grandchild := Inheritance.breed(child, mate2, st, db, rng)
		for i in 3:
			Inheritance.inspire(grandchild, db, rng)
		if grandchild.traits.has(&"darksight"):
			got_grandchild += 1
	check(got_child > 0, "some children inherit Darksight (%d/60)" % got_child)
	check(got_grandchild > 0, "some grandchildren inherit Darksight (%d)" % got_grandchild)
```

- [ ] **Step 2: Run to verify they fail**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_inheritance.gd  does not compile`.

- [ ] **Step 3: Implement Sparks**

`creatures/rules/sparks.gd`:
```gdscript
class_name Sparks
extends RefCounted
## Rolls a creature's sparks when it retires to the breeding stable (Uma Musume-style inheritance factors).
## Each spark is {kind: "stat"|"trait"|"move"|"personality", id: String, stars: 1..3}.


static func roll(c: CreatureData, db: Db, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var best: String = Stats.NAMES[0]
	for s in Stats.NAMES:
		if int(c.stats[s]) > int(c.stats[best]):
			best = s
	var g := Stats.grade(c.stats[best])
	out.append({"kind": "stat", "id": best, "stars": 1 + int(g >= Stats.Grade.B) + int(g >= Stats.Grade.S)})
	for t in c.all_traits(db):
		out.append({"kind": "trait", "id": String(t), "stars": rng.randi_range(1, 3)})
	if not c.moves.is_empty():
		out.append({"kind": "move", "id": String(c.moves[rng.randi() % c.moves.size()]), "stars": rng.randi_range(1, 3)})
	if c.personality != &"":
		out.append({"kind": "personality", "id": String(c.personality), "stars": rng.randi_range(1, 3)})
	return out


static func retire(c: CreatureData, db: Db, rng: RandomNumberGenerator) -> void:
	c.sparks = roll(c, db, rng)
	c.status = CreatureData.Status.RETIRED
```

- [ ] **Step 4: Implement Inheritance**

`creatures/rules/inheritance.gd`:
```gdscript
class_name Inheritance
extends RefCounted
## Breeding, compatibility and inspiration. A child carries a pool of its parents' sparks (weight = compatibility
## multiplier) and grandparents' sparks (half that). At each inspiration (hatch, mid-growth, adulthood) every
## pooled spark procs with PROC_CHANCE[stars] x weight.

const HATCH_DAYS := 2
const COOLDOWN_DAYS := 3
const POTENTIAL_VARIANCE := 30
const MUTATION_CHANCE := 0.05
const EVOLVED_CHILD_CHANCE := 0.1
const GRANDPARENT_WEIGHT := 0.5
const COMPAT_MULT: PackedFloat32Array = [1.0, 1.25, 1.5]  ## index = compatibility()
const COMPAT_MARKS: PackedStringArray = ["△", "○", "◎"]
const PROC_CHANCE: PackedFloat32Array = [0.0, 0.2, 0.35, 0.5]  ## index = stars
const STAT_BOOST: PackedInt32Array = [0, 10, 20, 35]
const POTENTIAL_BOOST: PackedInt32Array = [0, 15, 30, 50]


## 0 = △, 1 = ○, 2 = ◎. Score: same line 2, same element 1, same egg group 1, shared sparks up to 2.
static func compatibility(a: CreatureData, b: CreatureData, db: Db) -> int:
	var sa: Species = db.species[a.species]
	var sb: Species = db.species[b.species]
	var score := 0
	if sa.line == sb.line:
		score += 2
	if sa.element == sb.element:
		score += 1
	if sa.egg_group == sb.egg_group:
		score += 1
	var shared := 0
	for x in a.sparks:
		for y in b.sparks:
			if x["kind"] == y["kind"] and x["id"] == y["id"]:
				shared += 1
	score += mini(shared, 2)
	if score >= 4:
		return 2
	return 1 if score >= 2 else 0


## "" when the pair can breed, otherwise the reason (shown in the breeding panel).
static func can_breed(a: CreatureData, b: CreatureData, db: Db) -> String:
	if a.id == b.id:
		return "needs two different creatures"
	for c in [a, b]:
		var name: String = db.species[c.species].display_name
		if c.status != CreatureData.Status.RETIRED:
			return "%s #%d is not in the breeding stable" % [name, c.id]
		if c.breed_cooldown > 0:
			return "%s #%d needs %d more days of rest" % [name, c.id, c.breed_cooldown]
	if db.species[a.species].egg_group != db.species[b.species].egg_group:
		return "their egg groups differ"
	return ""


static func breed(a: CreatureData, b: CreatureData, state: GameState, db: Db, rng: RandomNumberGenerator) -> CreatureData:
	var reason := can_breed(a, b, db)
	if reason != "":
		push_error("Inheritance.breed: " + reason)
		return null
	var picked: Species = db.species[(a if rng.randf() < 0.5 else b).species]
	var both_evolved: bool = db.species[a.species].stage > 1 and db.species[b.species].stage > 1
	var child_species := picked
	if not (both_evolved and rng.randf() < EVOLVED_CHILD_CHANCE):
		var base := db.base_species(picked.line)
		child_species = base if base else picked

	var c := CreatureData.new()
	c.id = state.new_id()
	c.species = child_species.id
	c.parents = PackedInt32Array([a.id, b.id])
	c.stage = "egg"
	c.days_left = HATCH_DAYS
	for s in Stats.NAMES:
		var p := roundi((int(a.potential[s]) + int(b.potential[s])) / 2.0)
		p += rng.randi_range(-POTENTIAL_VARIANCE, POTENTIAL_VARIANCE)
		if rng.randf() < MUTATION_CHANCE:
			p += rng.randi_range(50, 120)
		var cap := clampi(p, 0, Stats.MAX)
		c.potential[s] = cap
		c.stats[s] = roundi(cap * CreatureData.START_FRACTION)
	c.personality = (a if rng.randf() < 0.5 else b).personality

	var mult := COMPAT_MULT[compatibility(a, b, db)]
	for parent in [a, b]:
		_add_to_pool(c, parent.sparks, mult)
		for gp_id in parent.parents:
			var gp := state.get_creature(gp_id)
			if gp:
				_add_to_pool(c, gp.sparks, mult * GRANDPARENT_WEIGHT)
	a.breed_cooldown = COOLDOWN_DAYS
	b.breed_cooldown = COOLDOWN_DAYS
	state.add(c)
	return c


## Rolls every pooled spark once; returns the ones that procced.
static func inspire(c: CreatureData, db: Db, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var procs: Array[Dictionary] = []
	for sp in c.pool:
		var stars: int = sp["stars"]
		if rng.randf() >= PROC_CHANCE[stars] * float(sp["weight"]):
			continue
		procs.append(sp)
		var id: String = sp["id"]
		match sp["kind"]:
			"stat":
				c.potential[id] = mini(int(c.potential[id]) + POTENTIAL_BOOST[stars], Stats.MAX)
				c.stats[id] = mini(int(c.stats[id]) + STAT_BOOST[stars], int(c.potential[id]))
			"trait":
				if not c.traits.has(StringName(id)):
					c.traits.append(StringName(id))
			"move":
				if not c.moves.has(StringName(id)):
					c.moves.append(StringName(id))
			"personality":
				c.personality = StringName(id)
	c.inspirations += 1
	Training.learn_moves(c, db)
	return procs


static func _add_to_pool(child: CreatureData, sparks: Array[Dictionary], weight: float) -> void:
	for s in sparks:
		child.pool.append({"kind": s["kind"], "id": s["id"], "stars": s["stars"], "weight": weight})
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: all pass. If `test_darksight_can_pass_two_generations` fails on the grandchild count, report the
counts rather than tuning constants silently: the proc numbers are a design value (spec section "Inheritance").

- [ ] **Step 6: Commit**

```bash
git add creatures/rules tests/test_inheritance.gd
git commit -m "Add spark rolls, breeding and inspiration" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Evolution and daily growth

**Files:**
- Create: `creatures/rules/evolution.gd`, `creatures/rules/lifecycle.gd`, `tests/test_lifecycle.gd`
- Modify: `docs/superpowers/specs/2026-09-26-creature-shop-design.md` (growth days, see Step 5)

**Interfaces:**
- Consumes: `CreatureData`, `Db`, `Stats`, `Inheritance.inspire` (Task 5).
- Produces:
  - `Evolution.check(c, db) -> Species` (first satisfied branch of an adult, else null);
    `Evolution.met(c, evo: EvolutionDef, db) -> bool`.
  - `Lifecycle.GROW_DAYS := 4`, `Lifecycle.MID_DAYS := 2` (days left at mid-growth);
    `Lifecycle.advance_day(c, db, rng) -> PackedStringArray` (events for the day summary).

- [ ] **Step 1: Write the failing tests**

`tests/test_lifecycle.gd`:
```gdscript
extends TestSuite


func test_branching_evolution_picks_first_satisfied() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var dark := Fixtures.adult(st, "spider", 200)
	dark.traits.append(&"darksight")
	var strong := Fixtures.adult(st, "spider", 450)  # power B
	var both := Fixtures.adult(st, "spider", 450)
	both.traits.append(&"darksight")
	var plain := Fixtures.adult(st, "spider", 200)
	eq(Evolution.check(dark, db).id, &"spider_albino", "darksight branch")
	eq(Evolution.check(strong, db).id, &"spider_large", "power branch")
	eq(Evolution.check(both, db).id, &"spider_albino", "first listed wins")
	check(Evolution.check(plain, db) == null, "no branch met")


func test_personality_evolution_and_babies_never_evolve() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var slime := Fixtures.adult(st, "slime")
	slime.personality = &"cheerful"
	eq(Evolution.check(slime, db).id, &"slime_antenna", "cheerful slime")
	slime.stage = "baby"
	check(Evolution.check(slime, db) == null, "baby")


func test_min_age_condition() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 450)
	var e := Fixtures.evo(db.species[&"spider_large"], "power", Stats.Grade.B, null, null)
	e.min_age_days = 5
	c.age_days = 4
	check(not Evolution.met(c, e, db), "too young")
	c.age_days = 5
	check(Evolution.met(c, e, db), "old enough")


func test_egg_hatches_grows_and_is_inspired_three_times() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	c.stage = "egg"
	c.days_left = Inheritance.HATCH_DAYS
	var rng := Fixtures.rng()
	var stages: PackedStringArray = []
	for day in 6:
		Lifecycle.advance_day(c, db, rng)
		stages.append(c.stage)
	eq(stages, PackedStringArray(["egg", "baby", "baby", "baby", "baby", "adult"]), "timeline")
	eq(c.inspirations, 3, "hatch, mid-growth, adulthood")


func test_events_and_cooldowns() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	c.traits.append(&"darksight")
	c.breed_cooldown = 1
	var events := Lifecycle.advance_day(c, db, Fixtures.rng())
	eq(c.species, &"spider_albino", "evolved at end of day")
	check(events.size() == 1 and events[0].contains("evolved into Spider Albino"), "event: %s" % events)
	eq(c.breed_cooldown, 0, "cooldown ticks")
	Lifecycle.advance_day(c, db, Fixtures.rng())
	eq(c.breed_cooldown, 0, "never negative")


func test_gone_creatures_are_frozen() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider")
	c.status = CreatureData.Status.GONE
	Lifecycle.advance_day(c, db, Fixtures.rng())
	eq(c.age_days, 0, "no ageing")
```

- [ ] **Step 2: Run to verify they fail**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_lifecycle.gd  does not compile`.

- [ ] **Step 3: Implement Evolution**

`creatures/rules/evolution.gd`:
```gdscript
class_name Evolution
extends RefCounted
## Branching evolution: a species lists branches; the first whose conditions an adult meets wins.


static func check(c: CreatureData, db: Db) -> Species:
	if c.stage != "adult":
		return null
	for evo in db.species[c.species].evolutions:
		if evo and evo.into and db.species.has(evo.into.id) and met(c, evo, db):
			return db.species[evo.into.id]
	return null


static func met(c: CreatureData, evo: EvolutionDef, db: Db) -> bool:
	if evo.stat != "none" and Stats.grade(c.stats[evo.stat]) < evo.min_grade:
		return false
	if evo.required_trait and not c.all_traits(db).has(evo.required_trait.id):
		return false
	if evo.personality and c.personality != evo.personality.id:
		return false
	return c.age_days >= evo.min_age_days
```

- [ ] **Step 4: Implement Lifecycle**

`creatures/rules/lifecycle.gd`:
```gdscript
class_name Lifecycle
extends RefCounted
## End-of-day growth for one creature: eggs hatch, babies grow up, adults may evolve, cooldowns tick.
## Inspiration fires at hatch, at mid-growth and at adulthood. Returns events for the day summary.

const GROW_DAYS := 4  ## baby -> adult
const MID_DAYS := 2  ## days_left at the mid-growth inspiration


static func advance_day(c: CreatureData, db: Db, rng: RandomNumberGenerator) -> PackedStringArray:
	var events: PackedStringArray = []
	if c.status == CreatureData.Status.GONE:
		return events
	c.age_days += 1
	c.breed_cooldown = maxi(c.breed_cooldown - 1, 0)
	match c.stage:
		"egg":
			c.days_left -= 1
			if c.days_left <= 0:
				c.stage = "baby"
				c.days_left = GROW_DAYS
				c.age_days = 0
				events.append(_event(c, db, "hatched", Inheritance.inspire(c, db, rng)))
		"baby":
			c.days_left -= 1
			if c.days_left <= 0:
				c.stage = "adult"
				events.append(_event(c, db, "grew up", Inheritance.inspire(c, db, rng)))
			elif c.days_left == MID_DAYS:
				events.append(_event(c, db, "is growing", Inheritance.inspire(c, db, rng)))
		"adult":
			var into := Evolution.check(c, db)
			if into:
				var was: String = db.species[c.species].display_name
				c.species = into.id
				events.append("%s #%d evolved into %s" % [was, c.id, into.display_name])
	return events


static func _event(c: CreatureData, db: Db, verb: String, procs: Array[Dictionary]) -> String:
	var text := "%s #%d %s" % [db.species[c.species].display_name, c.id, verb]
	if not procs.is_empty():
		var names := procs.map(func(p: Dictionary) -> String: return "%s %s" % [String(p["id"]).capitalize(), "★".repeat(p["stars"])])
		text += " — inspired by " + ", ".join(names)
	return text
```

- [ ] **Step 5: Align the spec's growth numbers**

In `docs/superpowers/specs/2026-09-26-creature-shop-design.md`, in the Day table's Breed row, change
`(hatches ~2 days, adult ~3 more)` to `(hatches in 2 days, adult 4 days later)`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add creatures/rules tests/test_lifecycle.gd docs/superpowers/specs
git commit -m "Add branching evolution and daily growth with three inspirations" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Order matching

**Files:**
- Create: `creatures/rules/orders.gd`, `tests/test_orders.gd`

**Interfaces:**
- Consumes: `OrderTemplate`, `RequirementGroup`, `Requirement` (Task 2), `CreatureData`, `GameState`, `Db`.
- Produces: `Orders.check(c, order, db, state) -> Dictionary` `{"ok": bool, "bonus": bool, "missing": PackedStringArray}`
  (only OWNED adults can be delivered: an egg/baby adds "must be grown up", a retired one adds
  "retired creatures stay in the breeding stable", a gone one adds "no longer in the shop");
  `Orders.group_met(c, g, db, state) -> bool`; `Orders.met(c, r, db, state) -> bool`;
  `Orders.lineage(c, line: StringName, generations: int, db, state) -> bool`.

- [ ] **Step 1: Write the failing tests**

`tests/test_orders.gd`:
```gdscript
extends TestSuite


func _group(reqs: Array) -> RequirementGroup:
	var g := RequirementGroup.new()
	g.any_of.assign(reqs)
	return g


func _order(required: Array, bonus: Array = []) -> OrderTemplate:
	var o := OrderTemplate.new()
	o.id = &"test"
	o.required.assign(required)
	o.bonus.assign(bonus)
	return o


func _mining_order() -> OrderTemplate:
	return _order([
		_group([Fixtures.req("trait", "darksight"), Fixtures.req("trait", "glowing")]),
		_group([Fixtures.req("move_element", "earth"), Fixtures.req("move_kind", "damaging")]),
	])


func test_and_of_or_groups() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider_albino")  # natural darksight
	var r := Orders.check(c, _mining_order(), db, st)
	check(not r["ok"], "no moves yet")
	eq(r["missing"], PackedStringArray(["Earth move or damaging move"]), "missing list")
	c.moves.append(&"bite")  # beast, damaging
	check(Orders.check(c, _mining_order(), db, st)["ok"], "damaging move satisfies the second group")


func test_stat_species_line_personality() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider_large", 399)
	c.personality = &"timid"
	var power_b := _order([_group([Fixtures.req("stat", "power", Stats.Grade.B)])])
	check(not Orders.check(c, power_b, db, st)["ok"], "399 is C")
	c.stats["power"] = 400
	check(Orders.check(c, power_b, db, st)["ok"], "400 is B")
	check(Orders.check(c, _order([_group([Fixtures.req("species", "spider_large")])]), db, st)["ok"], "species")
	check(Orders.check(c, _order([_group([Fixtures.req("line", "spider")])]), db, st)["ok"], "line")
	check(not Orders.check(c, _order([_group([Fixtures.req("species", "spider")])]), db, st)["ok"], "other species")
	check(Orders.check(c, _order([_group([Fixtures.req("personality", "timid")])]), db, st)["ok"], "personality")


func test_bonus_needs_required_too() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var c := Fixtures.adult(st, "spider", 650)  # power A
	var o := _order(
		[_group([Fixtures.req("stat", "power", Stats.Grade.B)])],
		[_group([Fixtures.req("stat", "power", Stats.Grade.A)])])
	var r := Orders.check(c, o, db, st)
	check(r["ok"] and r["bonus"], "A power meets required and bonus")
	c.stats["power"] = 450
	r = Orders.check(c, o, db, st)
	check(r["ok"] and not r["bonus"], "B power: required only")
	var no_bonus := Orders.check(c, _order([_group([Fixtures.req("line", "spider")])]), db, st)
	check(not no_bonus["bonus"], "orders without bonus groups never report a bonus")


func test_only_owned_adults_can_be_delivered() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var o := _order([_group([Fixtures.req("line", "spider")])])
	var c := Fixtures.adult(st, "spider")
	c.stage = "baby"
	eq(Orders.check(c, o, db, st)["missing"], PackedStringArray(["must be grown up"]), "baby")
	c.stage = "adult"
	c.status = CreatureData.Status.RETIRED
	eq(Orders.check(c, o, db, st)["missing"], PackedStringArray(["retired creatures stay in the breeding stable"]), "retired")


func test_lineage() -> void:
	var db := Fixtures.db()
	var st := GameState.new()
	var gps: Array[CreatureData] = []
	for i in 4:
		gps.append(Fixtures.adult(st, "spider"))
	var p1 := Fixtures.adult(st, "spider")
	p1.parents = PackedInt32Array([gps[0].id, gps[1].id])
	var p2 := Fixtures.adult(st, "spider_albino")
	p2.parents = PackedInt32Array([gps[2].id, gps[3].id])
	var c := Fixtures.adult(st, "spider")
	c.parents = PackedInt32Array([p1.id, p2.id])
	check(Orders.lineage(c, &"spider", 3, db, st), "3 generations of spider line")
	gps[3].species = &"slime"
	check(not Orders.lineage(c, &"spider", 3, db, st), "a slime grandparent breaks it")
	check(Orders.lineage(c, &"spider", 2, db, st), "2 generations still hold")
	var wild := Fixtures.adult(st, "spider")
	check(not Orders.lineage(wild, &"spider", 2, db, st), "no recorded parents")
	var lost := Fixtures.adult(st, "spider")
	lost.parents = PackedInt32Array([999999, 999998])
	check(not Orders.lineage(lost, &"spider", 2, db, st), "parent records missing")
```

- [ ] **Step 2: Run to verify they fail**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_orders.gd  does not compile`.

- [ ] **Step 3: Implement Orders**

`creatures/rules/orders.gd`:
```gdscript
class_name Orders
extends RefCounted
## Checks a creature against an order: every required group must pass (a group passes when any of its
## requirements does). Only owned adults can be delivered.


static func check(c: CreatureData, order: OrderTemplate, db: Db, state: GameState) -> Dictionary:
	var missing: PackedStringArray = []
	if c.status == CreatureData.Status.RETIRED:
		missing.append("retired creatures stay in the breeding stable")
	elif c.status == CreatureData.Status.GONE:
		missing.append("no longer in the shop")
	elif c.stage != "adult":
		missing.append("must be grown up")
	if not missing.is_empty():
		return {"ok": false, "bonus": false, "missing": missing}
	for g in order.required:
		if not group_met(c, g, db, state):
			missing.append(g.describe())
	var ok := missing.is_empty()
	var bonus := ok and not order.bonus.is_empty() and order.bonus.all(
		func(g: RequirementGroup) -> bool: return group_met(c, g, db, state))
	return {"ok": ok, "bonus": bonus, "missing": missing}


static func group_met(c: CreatureData, g: RequirementGroup, db: Db, state: GameState) -> bool:
	return g.any_of.any(func(r: Requirement) -> bool: return r != null and met(c, r, db, state))


static func met(c: CreatureData, r: Requirement, db: Db, state: GameState) -> bool:
	var sp: Species = db.species[c.species]
	match r.kind:
		"species":
			return c.species == r.id
		"line":
			return sp.line == r.id
		"stat":
			return Stats.grade(c.stats[String(r.id)]) >= r.min_grade
		"trait":
			return c.all_traits(db).has(r.id)
		"move_element":
			return c.moves.any(func(m: StringName) -> bool: return db.moves.has(m) and db.moves[m].element == r.id)
		"move_kind":
			return c.moves.any(func(m: StringName) -> bool: return db.moves.has(m) and db.moves[m].kind == String(r.id))
		"personality":
			return c.personality == r.id
		"lineage":
			return lineage(c, r.id, r.generations, db, state)
	return false


## True when `c` and every recorded ancestor up to `generations` (c = 1) belong to `line`. Both parents must be
## on record for each generation checked.
static func lineage(c: CreatureData, line: StringName, generations: int, db: Db, state: GameState) -> bool:
	if c == null or not db.species.has(c.species) or db.species[c.species].line != line:
		return false
	if generations <= 1:
		return true
	if c.parents.size() < 2:
		return false
	for pid in c.parents:
		if not lineage(state.get_creature(pid), line, generations - 1, db, state):
			return false
	return true
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add creatures/rules/orders.gd tests/test_orders.gd
git commit -m "Add order matching with and/or groups, bonus and lineage" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Monster pack importer (editor tool)

**Files:**
- Create: `addons/creature_tools/plugin.cfg`, `addons/creature_tools/plugin.gd`,
  `addons/creature_tools/pack_importer.gd`, `tests/test_pack_importer.gd`
- Modify: `.gitignore` (add `creatures/pack/`), `project.godot` (enable the plugin — through the editor),
  `README.md` (document the tool)

**Interfaces:**
- Consumes: `Species` (Task 2).
- Produces (`pack_importer.gd`, preloaded as `Importer`): `PACKS_DIR`, `OUT_DIR := "res://creatures/pack"`,
  `FRAMES_DIR := "res://creatures/frames"`, `SPECIES_DIR := "res://data/species"`, `CELL := 128`,
  `FACINGS := ["down", "left", "right", "up"]` (sheet rows top to bottom), `FPS := 8.0`;
  `variant_id(folder: String) -> String`; `common_prefix(files: Array) -> String`;
  `copy_pack(pack_dir: String) -> Dictionary` (`{variant_id: {anim: res_path}}`);
  `frames_from_textures(textures: Dictionary) -> SpriteFrames` (anim -> Texture2D; animations named
  `<anim>_<facing>`, idle/move loop); `build_resources(copied: Dictionary) -> PackedStringArray` (paths created).
  SpriteFrames go to `creatures/frames/<id>.tres` (committed), Species to `data/species/<id>.tres` (committed),
  PNG copies to `creatures/pack/<id>/<anim>.png` (git-ignored).

Sheet facts (checked 2026-09-26 on packs 1, 2, 9, 14, 19): every variant folder under `Spritesheets/` (skip
`Old Versions`) holds `<Prefix>_<Anim>.png` sheets of 128x128 cells, 4 rows (facings) and 4 (idle) or 6
(move/attack) columns. Examples: `Updated Slime Antenna/Slime_Antenna_Idle.png` (512x512),
`Updated Party Mushroom/Mushroom_Party_Attack_FX.png` (768x512).

- [ ] **Step 1: Write the failing tests**

`tests/test_pack_importer.gd`:
```gdscript
extends TestSuite

const Importer := preload("res://addons/creature_tools/pack_importer.gd")


func test_variant_ids() -> void:
	eq(Importer.variant_id("Updated Slime Antenna"), "slime_antenna", "strips Updated")
	eq(Importer.variant_id("Updated Blue Golem"), "blue_golem", "two words")
	eq(Importer.variant_id("Wolf"), "wolf", "no prefix")


func test_common_prefix_finds_animation_names() -> void:
	eq(Importer.common_prefix(["Slime_Attack.png", "Slime_Idle.png", "Slime_Move.png"]), "Slime_", "slime")
	eq(Importer.common_prefix(["Mushroom_Party_Ability.png", "Mushroom_Party_Attack.png",
		"Mushroom_Party_Attack_FX.png", "Mushroom_Party_Idle.png"]), "Mushroom_Party_", "party mushroom")
	eq(Importer.common_prefix(["Golem_Blue_Idle.png"]), "Golem_Blue_", "single sheet")


func test_frames_from_textures_slices_cells_by_facing() -> void:
	var move := ImageTexture.create_from_image(Image.create(768, 512, false, Image.FORMAT_RGBA8))
	var attack := ImageTexture.create_from_image(Image.create(768, 512, false, Image.FORMAT_RGBA8))
	var sf: SpriteFrames = Importer.frames_from_textures({"move": move, "attack": attack})
	eq(sf.get_animation_names().size(), 8, "2 anims x 4 facings")
	check(not sf.has_animation(&"default"), "default animation removed")
	eq(sf.get_frame_count(&"move_left"), 6, "6 columns")
	var frame: AtlasTexture = sf.get_frame_texture(&"move_right", 1)
	eq(frame.region, Rect2(128, 256, 128, 128), "row 2 = right, column 1")
	check(sf.get_animation_loop(&"move_down"), "move loops")
	check(not sf.get_animation_loop(&"attack_down"), "attack plays once")
```

- [ ] **Step 2: Run to verify they fail**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `FAIL test_pack_importer.gd  does not compile`.

- [ ] **Step 3: Implement the importer**

`addons/creature_tools/pack_importer.gd`:
```gdscript
@tool
extends RefCounted
## Copies a monster pack's spritesheets into creatures/pack/ (git-ignored, licensed art) and creates a
## SpriteFrames (creatures/frames/) and a starter Species (data/species/) per variant. Create-only: an existing
## SpriteFrames or Species is never touched, so edits made in the editor are safe.
## Sheet layout (all packs): 128x128 cells, one row per facing (FACINGS, top to bottom), columns are frames.

const PACKS_DIR := "res://asset-pipeline/80_Monster_Packs/Monster Packs"
const OUT_DIR := "res://creatures/pack"
const FRAMES_DIR := "res://creatures/frames"
const SPECIES_DIR := "res://data/species"
const CELL := 128
const FACINGS: PackedStringArray = ["down", "left", "right", "up"]
const FPS := 8.0


static func variant_id(folder: String) -> String:
	return folder.trim_prefix("Updated ").strip_edges().to_lower().replace(" ", "_")


## The shared "<Name>_" part of a variant's sheet names; what follows it is the animation name.
static func common_prefix(files: Array) -> String:
	var stems: Array = files.map(func(f: String) -> String: return f.get_basename())
	var p: String = stems[0]
	for s: String in stems:
		while not s.begins_with(p):
			p = p.left(-1)
	var cut := p.rfind("_")
	return p.left(cut + 1) if cut >= 0 else ""


## pack_dir is an absolute OS path. Returns {variant_id: {anim: res_path}}; already-copied files are reused.
static func copy_pack(pack_dir: String) -> Dictionary:
	var sheets := pack_dir.path_join("Spritesheets")
	var out := {}
	for folder in DirAccess.get_directories_at(sheets):
		if folder.begins_with("Old"):
			continue
		var src := sheets.path_join(folder)
		var pngs := Array(DirAccess.get_files_at(src)).filter(func(f: String) -> bool: return f.ends_with(".png"))
		if pngs.is_empty():
			continue
		var vid := variant_id(folder)
		var dst := OUT_DIR.path_join(vid)
		DirAccess.make_dir_recursive_absolute(dst)
		var prefix := common_prefix(pngs)
		var anims := {}
		for f: String in pngs:
			var anim := f.get_basename().substr(prefix.length()).to_lower()
			var to := dst.path_join(anim + ".png")
			if not FileAccess.file_exists(to):
				DirAccess.copy_absolute(src.path_join(f), ProjectSettings.globalize_path(to))
			anims[anim] = to
		out[vid] = anims
	return out


static func frames_from_textures(textures: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for anim: String in textures:
		var tex: Texture2D = textures[anim]
		var cols := tex.get_width() / CELL
		var rows := mini(tex.get_height() / CELL, FACINGS.size())
		for r in rows:
			var name := StringName("%s_%s" % [anim, FACINGS[r]])
			sf.add_animation(name)
			sf.set_animation_speed(name, FPS)
			sf.set_animation_loop(name, anim == "idle" or anim == "move")
			for col in cols:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(col * CELL, r * CELL, CELL, CELL)
				sf.add_frame(name, at)
	return sf


## Creates missing SpriteFrames and Species for copied variants. A variant whose PNGs are not imported yet is
## skipped (run the menu item again after the import finishes).
static func build_resources(copied: Dictionary) -> PackedStringArray:
	var made: PackedStringArray = []
	DirAccess.make_dir_recursive_absolute(FRAMES_DIR)
	DirAccess.make_dir_recursive_absolute(SPECIES_DIR)
	for vid: String in copied:
		var frames_path := FRAMES_DIR.path_join(vid + ".tres")
		if not ResourceLoader.exists(frames_path):
			var textures := {}
			for anim: String in copied[vid]:
				var path: String = copied[vid][anim]
				if not ResourceLoader.exists(path):
					textures = {}
					break
				textures[anim] = load(path)
			if textures.is_empty():
				push_warning("[creature_tools] %s: textures not imported yet; run the import again" % vid)
				continue
			ResourceSaver.save(frames_from_textures(textures), frames_path)
			made.append(frames_path)
		var species_path := SPECIES_DIR.path_join(vid + ".tres")
		if not ResourceLoader.exists(species_path):
			var sp := Species.new()
			sp.id = StringName(vid)
			sp.display_name = vid.capitalize()
			sp.line = StringName(vid)
			sp.sprite_frames = load(frames_path)
			ResourceSaver.save(sp, species_path)
			made.append(species_path)
	return made
```

`addons/creature_tools/plugin.cfg`:
```ini
[plugin]

name="Creature Tools"
description="Tools menu: import a monster pack as SpriteFrames and starter Species (create-only)."
author="Upgraded Journey"
version="1.0"
script="plugin.gd"
```

`addons/creature_tools/plugin.gd`:
```gdscript
@tool
extends EditorPlugin
## Project > Tools > "Creatures: Import monster pack…": pick a pack folder; each variant is copied into
## creatures/pack/ and gets a SpriteFrames and a starter Species. Create-only, never overwrites.

const Importer := preload("res://addons/creature_tools/pack_importer.gd")
const MENU := "Creatures: Import monster pack…"

var _dialog: EditorFileDialog


func _enter_tree() -> void:
	add_tool_menu_item(MENU, _open)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	if _dialog:
		_dialog.queue_free()


func _open() -> void:
	if _dialog == null:
		_dialog = EditorFileDialog.new()
		_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
		_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		_dialog.title = "Pick a Monster Pack folder"
		_dialog.dir_selected.connect(_import)
		EditorInterface.get_base_control().add_child(_dialog)
	_dialog.current_dir = ProjectSettings.globalize_path(Importer.PACKS_DIR)
	_dialog.popup_file_dialog()


func _import(pack_dir: String) -> void:
	var copied := Importer.copy_pack(pack_dir)
	if copied.is_empty():
		push_warning("[creature_tools] no spritesheets under %s/Spritesheets" % pack_dir)
		return
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	await get_tree().process_frame
	while fs.is_scanning() or fs.is_importing():
		await get_tree().process_frame
	var made := Importer.build_resources(copied)
	fs.scan()
	print("[creature_tools] %s: %d variants, created %s" % [pack_dir.get_file(), copied.size(), made])
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: all pass.

- [ ] **Step 5: Ignore copied art, enable the plugin**

Append `creatures/pack/` to `.gitignore`. Enable "Creature Tools" through the editor (godot-ai `plugin_manage`,
or Project > Project Settings > Plugins) so `project.godot` is written by the editor.

- [ ] **Step 6: Import the five slice packs in the editor**

Run Project > Tools > "Creatures: Import monster pack…" for each of: `Monster Pack 1 (Slimes)`,
`Monster Pack 19 (Mushrooms)`, `Monster Pack 2 (Spiders)`, `Monster Pack 14 (Golems)`, `Monster Pack 9 (Canines)`.
(If the executor cannot click the menu through godot-ai, ask the owner to run it.) If the log says "textures not
imported yet", run the same pack again. Expected result: `data/species/` holds `slime`, `slime_antenna`,
`mushroom`, `party_mushroom`, `spider`, `spider_albino`, `spider_large`, `blue_golem`, `green_golem`,
`red_golem`, `yellow_golem`, `dog`, `wolf`, and `creatures/frames/` one `.tres` per id.

- [ ] **Step 7: Verify the facing order visually**

Open `creatures/frames/spider.tres` in the SpriteFrames panel (or a throwaway scene with an `AnimatedSprite2D`,
texture filter Nearest, scale 4), play `move_left` and `move_right`, and take an `editor_screenshot`. If a
creature faces the wrong way, fix the row order in `FACINGS`, delete `creatures/frames/*.tres` (the only
overwrite, done by hand and on purpose), re-run the imports, and re-check. Record the confirmed order in the
`FACINGS` doc comment.

- [ ] **Step 8: Document the tool**

Add to `README.md` under the UI theme section:
```markdown
## Creatures

Content lives in `data/` as Resources (Species, TraitDef, MoveDef, Personality, Location, OrderTemplate); edit
them in the Inspector. **Project > Tools > Creatures: Import monster pack…** copies a pack from
`asset-pipeline/80_Monster_Packs/` into `creatures/pack/` (git-ignored, licensed) and creates a SpriteFrames in
`creatures/frames/` and a starter Species in `data/species/` for each variant. It never overwrites an existing
file; delete a file first to regenerate it. Tests: `godot --headless --path . -s res://tests/run_tests.gd`.
```

- [ ] **Step 9: Commit**

```bash
git add .gitignore project.godot README.md addons/creature_tools creatures/frames data/species tests/test_pack_importer.gd
git commit -m "Add create-only monster pack importer and import the five slice packs" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Table editor addon and first-slice content

**Files:**
- Create: `addons/resources_spreadsheet_view/` (third-party, MIT, pinned), `data/traits/*.tres`,
  `data/moves/*.tres`, `data/personalities/*.tres`, `data/locations/*.tres`, `tests/test_content.gd`
- Modify: `data/species/*.tres` (fields set in the editor), `project.godot` (plugin enabled via the editor)

**Interfaces:**
- Consumes: every definition class (Task 2), `Db.load_dir()`, the imported species (Task 8).
- Produces: the slice content set that Plan 2 builds on; `tests/test_content.gd` guards its integrity from now on.

- [ ] **Step 1: Write the failing content test**

`tests/test_content.gd`:
```gdscript
extends TestSuite
## Integrity of the real content in data/. Runs against whatever the editor has saved.


func test_content_is_consistent() -> void:
	var db := Db.load_dir()
	check(db.species.size() >= 10, "at least 10 species (got %d)" % db.species.size())
	check(db.traits.size() >= 11, "at least 11 traits (got %d)" % db.traits.size())
	check(db.moves.size() >= 12, "at least 12 moves (got %d)" % db.moves.size())
	eq(db.personalities.size(), 5, "personalities")
	eq(db.locations.size(), 3, "locations")
	var lines := {}
	for sp: Species in db.species.values():
		check(sp.line != &"" and sp.element != &"" and sp.egg_group != &"", "%s: line, element, egg group set" % sp.id)
		if sp.stage == 1:
			check(not lines.has(sp.line), "%s: one stage-1 species per line" % sp.line)
			lines[sp.line] = true
		for s in Stats.NAMES:
			check(sp.potential(s) > 0 and sp.potential(s) <= Stats.MAX, "%s: %s potential in range" % [sp.id, s])
		for t in sp.natural_traits:
			check(t != null and db.traits.has(t.id), "%s: natural trait is in data/traits" % sp.id)
		for u in sp.moves:
			check(u != null and u.move != null and db.moves.has(u.move.id), "%s: move unlock points at data/moves" % sp.id)
		for e in sp.evolutions:
			check(e != null and e.into != null and db.species.has(e.into.id), "%s: evolution target exists" % sp.id)
			if e and e.into:
				eq(e.into.line, sp.line, "%s -> %s stays in its line" % [sp.id, e.into.id])
	for sp: Species in db.species.values():
		check(lines.has(sp.line), "%s: its line has a stage-1 species" % sp.id)
	for loc: Location in db.locations.values():
		check(loc.trains_trait != null and db.traits.has(loc.trains_trait.id), "%s: trains a known trait" % loc.id)


func test_some_species_branch() -> void:
	var db := Db.load_dir()
	check(db.species[&"spider"].evolutions.size() >= 2, "spider branches")
	check(db.species[&"green_golem"].evolutions.size() >= 2, "green golem branches")
```

- [ ] **Step 2: Run to verify it fails**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: `test_content.gd` failures (no traits, moves, personalities, locations; species fields unset).

- [ ] **Step 3: Install Edit Resources as Table (pinned)**

```bash
git clone https://github.com/don-tnowe/godot-resources-as-sheets-plugin "$TMP/rs-sheets"
git -C "$TMP/rs-sheets" checkout 3363e0d2136c432c989ac1f249aa8aaa634e84e9
cp -r "$TMP/rs-sheets/addons/resources_spreadsheet_view" addons/
cp "$TMP/rs-sheets/LICENSE" addons/resources_spreadsheet_view/LICENSE
```
(`$TMP` = the session scratchpad directory.) Enable it through the editor (godot-ai `plugin_manage` or Project
Settings > Plugins). Confirm a "ResourceTables" main-screen tab appears; take an `editor_screenshot`.

- [ ] **Step 4: Author traits, moves, personalities and locations in the editor**

Create each `.tres` with godot-ai `resource_manage` (type = the class, path = `res://data/<folder>/<id>.tres`),
setting `id` and `display_name` (= id capitalized) plus the fields below.

Traits (`data/traits/`, `TraitDef`): `darksight`, `glowing`, `thick_hide`, `swift`, `fireproof`, `spore_cloud`,
`keen_nose`, `sticky` (natural), `tunnel_wise`, `forest_wise`, `sunny` (learned at locations). One-line
descriptions, e.g. darksight "Sees in total darkness."

Moves (`data/moves/`, `MoveDef` — id: element, kind):
`tackle`: beast, damaging · `bite`: beast, damaging · `howl`: beast, utility · `slam`: earth, damaging ·
`dig`: earth, damaging · `rock_throw`: earth, damaging · `spore`: nature, utility · `vine_lash`: nature, damaging ·
`web`: dark, utility · `shadow_bite`: dark, damaging · `glow`: light, utility · `splash`: water, damaging

Personalities (`data/personalities/`, `Personality` — favored / disfavored):
`cheerful`: heart / none · `stubborn`: power / wits · `gentle`: heart / power · `bold`: power / guard ·
`timid`: speed / power

Locations (`data/locations/`, `Location` — trains_trait, trait_chance):
`meadow`: sunny, 0.15 · `mine`: tunnel_wise, 0.15 · `old_forest`: forest_wise, 0.15

- [ ] **Step 5: Fill in the imported species**

Set fields on `data/species/<id>.tres` with godot-ai `resource_manage` (or the ResourceTables tab). Display
names: fix `Party Mushroom`, `Green Golem` etc. if the capitalization reads oddly. Potentials are P/G/S/W/H.
Move unlocks are `MoveUnlock` sub-resources (move, stat, grade); evolutions are `EvolutionDef` sub-resources in
the listed order.

| id | line | stage | element | egg group | potential | natural traits | moves (stat grade) | evolutions (in order) |
|---|---|---|---|---|---|---|---|---|
| slime | slime | 1 | water | amorphous | 250/300/250/200/350 | sticky | splash (power D) | slime_antenna: heart ≥ C |
| slime_antenna | slime | 2 | light | amorphous | 300/350/300/300/450 | sticky, glowing | splash (power D), glow (wits C) | — |
| mushroom | mushroom | 1 | nature | plant | 250/300/200/300/300 | spore_cloud | spore (wits D) | party_mushroom: personality cheerful |
| party_mushroom | mushroom | 2 | nature | plant | 350/350/300/400/400 | spore_cloud, glowing | spore (wits D), vine_lash (power C) | — |
| spider | spider | 1 | dark | bug | 300/250/350/250/250 | — | bite (power D), web (speed D) | spider_albino: trait darksight; spider_large: power ≥ B |
| spider_albino | spider | 2 | dark | bug | 350/300/450/400/300 | darksight | bite (power D), web (speed D), shadow_bite (speed C) | — |
| spider_large | spider | 2 | dark | bug | 500/400/350/250/350 | thick_hide | bite (power D), web (speed D), shadow_bite (power C) | — |
| green_golem | golem | 1 | earth | mineral | 350/450/150/200/300 | thick_hide | slam (power D), dig (guard C) | yellow_golem: trait tunnel_wise; blue_golem: guard ≥ B; red_golem: power ≥ B |
| blue_golem | golem | 2 | earth | mineral | 400/600/200/250/350 | thick_hide | slam (power D), dig (guard C), rock_throw (power C) | — |
| red_golem | golem | 2 | earth | mineral | 550/450/200/200/350 | thick_hide, fireproof | slam (power D), dig (guard C), rock_throw (power C) | — |
| yellow_golem | golem | 2 | earth | mineral | 400/450/200/350/350 | thick_hide, glowing | slam (power D), dig (guard C), rock_throw (power C) | — |
| dog | canine | 1 | beast | beast | 300/250/350/250/350 | keen_nose | tackle (power D), howl (heart D) | wolf: power ≥ C, min age 3 days |
| wolf | canine | 2 | beast | beast | 450/300/450/300/350 | keen_nose, swift | tackle (power D), bite (power C), howl (heart D) | — |

- [ ] **Step 6: Run the tests to verify they pass**

Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd`
Expected: all pass (including `test_content.gd`). Open two species and one move in the Inspector and one
folder in the ResourceTables tab; take `editor_screenshot`s to confirm they read and edit cleanly.

- [ ] **Step 7: Commit**

```bash
git add addons/resources_spreadsheet_view project.godot data tests/test_content.gd
git commit -m "Add Resources-as-Table addon and first-slice creature content" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## After this plan

Plan 2 (shop & day loop) is written once this lands, against these real interfaces: `Game` autoload (Db +
GameState + day phases), `Events` bus, care actions and the care-learned traits, market, expeditions
(`Expedition.resolve`), order board generation from `OrderTemplate`s, the shop scene with pens, all panels
(orders, creature card with pedigree and compatibility marks, breeding, training, expedition, market, day
summary), Maaack Menus Template, and the seeded 10-day playthrough from the spec's "Done when" list.
