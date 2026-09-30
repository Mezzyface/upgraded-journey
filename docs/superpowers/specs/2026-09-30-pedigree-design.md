# Pedigree tab — design

Status: approved by delegation 2026-09-30 (owner asleep; standing instruction "keep working until the game is done").

## Goal

Slice goal: "the pedigree shows 3 generations; compatibility marks show." The creature card gets a **Family** tab:
the creature, its two parents with their compatibility mark, and its four grandparents. Done when a creature bred
from bred parents shows all three generations on its card.

## Decisions

- A third card tab, `Family`, after `Traits & Moves` and `Sparks`.
- Layout (inside the 72 px tab, scrolling with the PackScrollBar like Sparks):
  - `Parents: Spider #1 ◎ Spider #4` — the mark is `Game.compat_mark` of the two parents (kept even when one is gone).
  - `Grandparents: Spider #0, Slime #2 · Spider #3, ?` — each parent's parents in order, `?` for an unknown one.
  - A creature without parents shows `Wild — no recorded parents`.
- Gone (sold or delivered) ancestors are still named — the state keeps them for pedigrees.
- Names are plain text; clicking an ancestor is out of scope.

## 1. `Game.family(c) -> Dictionary`

`{"parents": Array[CreatureData] (0 or 2, entries may be null when missing), "grandparents": Array[Array] (per parent,
its 0 or 2 parents, entries may be null)}`. Pure lookup through `state.get_creature`.

## 2. Card

`%FamilyRows` VBox in a `Family` page (ScrollContainer "Show Never" + PackScrollBar, same as Sparks), filled in
`_refresh()` by `_fill_family()`: plain Labels, autowrap.

## Testing

`test_game.gd`: `family` for a wild creature, a first-generation child, and a third-generation child with one missing
grandparent. `test_creature_card.gd`: the Family tab's three lines, the mark, `?` for a missing ancestor, the wild
text, and three tabs. Screenshot of the tab.
