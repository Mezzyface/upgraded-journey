# Breeding — design

Status: approved in chat 2026-09-29 (sections 1–3). Approach 1: two parent slots in the Stable (Uma Musume's parent
select), plus a Sparks tab on the creature card. The pedigree tree gets its own spec.

## Goal

The player can breed from the UI. In the Stable they pick two retired creatures, see the compatibility mark or the
reason they can't breed, and press Breed. An egg appears in a pen and hatches over the next evenings, with
inspirations in the day summary. The card shows which sparks a creature carries and inherited, so the choice isn't
blind. Done when the slice goal "Retire → breed → inspiration visibly transfers a spark" plays through by hand.

## What already exists (not changed)

- `Day.breed` (2 AP, refuses when injured, pens full or short on AP), `Inheritance.breed` / `can_breed` /
  `compatibility` / `inspire`, `Sparks.roll` on retire.
- Eggs take a pen space, show in their pen through `creature_sprite.gd`, hatch in `Lifecycle.advance_day`, and
  report inspirations ("… hatched — inspired by Power ★★") in the day summary.
- `test_playthrough.gd` breeds through `Day.breed`.

## Decisions

- Pairing lives in the Stable panel: slot A, mark, slot B, Breed button or reason.
- Once slot A is filled, every list row shows its mark against A.
- Grandparent sparks show as `? ★★` (stars visible, kind and id hidden) until the Gene Scanner upgrade is owned.
  The original spec's "unless the player raised it" exception is dropped: every creature with sparks was retired by
  the player, so it would always hold and the Scanner would do nothing.
- No new state and no save changes.

## Constraints

- Godot changes go through the open editor via the godot-ai MCP (CLAUDE.md). The Stable, the new row scene and the
  card's Sparks tab are laid out in the editor; scripts only fill them.
- Viewport 640×360. Existing theme variations only (`DecoratedButton`, `NamePlate`, `HeaderLabel`); no new theme
  types, so the gallery doesn't change.
- `Game` stays the one path from the UI to the rules.

## 1. Rules and `Game`

- `Day.breed_reason(state, db, a, b) -> String`: the checks now inside `Day.breed`, in the same order (missing
  creature, `Inheritance.can_breed`, injured, pens full, `_afford`), returning `""` or the reason. `Day.breed` calls
  it, so the reason the Stable shows before pressing is the one a refused breed gives.
- `Game.breed(a, b) -> String` through `_did`, log line `"Bred Slime #3 and Slime #7 — an egg"`.
- `Game.breed_reason(a, b) -> String` and `Game.compat_mark(a, b) -> String`
  (`Inheritance.COMPAT_MARKS[Inheritance.compatibility(a, b, db)]`).
- `Game.spark_rows(c) -> Array[Dictionary]` for the card: `{who: String, sparks: Array[Dictionary], hidden: bool}`
  for "Own" (retired only, `c.sparks`), each parent (`state.get_creature(id)`, its `sparks`) and each of their
  parents (`hidden = not state.upgrades.has(&"gene_scanner")`). Ancestors missing from the state or without sparks
  are skipped.

## 2. Stable panel — `shop/panels/stable_panel.tscn` / `.gd`

```
┌ Stable ─────────────────────────────── [Close] ┐
│  [ Slime #3  ]    ◎    [ Slime #7  ]           │  PairRow: %SlotA · %Mark · %SlotB
│         [ Breed (2 AP) ]   %Reason             │  %Breed · %Reason
│ ────────────────────────────────────────────── │
│  [portrait] Slime #3   Water · Goo      ◎ [Card] │  StableRow per retired creature
│  [portrait] Spider #5  rests 2 days     △ [Card] │
└────────────────────────────────────────────────┘
```

- Keeps Title/Close, `%Empty`, Scroll/`%List`. Adds the pair row and the Breed row above the scroll.
- `%SlotA` / `%SlotB` (`DecoratedButton`): portrait icon and `"Slime #3"`, or `"Pick a parent"` when empty. Pressing a
  filled slot empties it.
- `%Mark`: the mark when both slots are filled, else empty.
- `%Breed`: `"Breed (2 AP)"`, enabled only when both are filled and `Game.breed_reason` is `""`. `%Reason` shows that
  reason otherwise; empty when fewer than two are picked.
- On Breed: `Game.breed`; on `""` both slots clear, the shop toasts `"An egg was laid"`; otherwise the reason shows in
  `%Reason`. The panel refills from `Game.changed` (cooldowns update).
- `signal creature_chosen(c)` stays (the row's Card button emits it; `shop.gd` opens the card as today).
  New `signal bred` for the toast, connected in `shop.gd open_stable()`.

### `StableRow` — `shop/panels/stable_row.tscn` / `.gd` (new, like `day_creature_row.tscn`)

- Portrait (egg texture never applies: only adults retire), name, note (`"Water · Goo"`, or `"rests N days"` while
  `breed_cooldown > 0`), mark label (against slot A, empty when A is empty or is this creature), `Card` button.
- Pressing the row body fills the next empty slot; a creature already in a slot shows disabled.

## 3. Sparks tab — `shop/panels/creature_card.tscn` / `.gd`

- New page `Sparks` in `%Tabs` next to `Traits & Moves`, laid out in the editor: a VBox `%SparkRows`.
- For each `Game.spark_rows(c)` entry: a small `HeaderLabel` (`"Own"`, `"Slime #3"`) and a chip grid of
  `NamePlate` chips. Chip text `"Power ★★★"` (stat capitalized, trait/move `display_name`, personality
  `display_name`), or `"? ★★"` when hidden. Tints are exports: `stat_tint`, `trait_tint` (existing), `move_tint`
  (existing), `personality_tint`, `hidden_tint`.
- Empty (no rows): label `"No sparks yet — retire it to lock its sparks"`.

## Testing

- `test_day.gd`: `breed_reason` returns each refusal (same creature, not retired, cooldown, egg groups, injured,
  pens full, AP) and `""` for a valid pair; `breed` refuses with the same text.
- `test_game.gd`: `Game.breed` costs 2 AP, adds an egg with both parents, logs the line, emits `changed`;
  `compat_mark` returns one of the marks; `spark_rows` hides grandparents without the Scanner and shows them with it.
- `test_stable_panel.gd` (new): row press fills A then B; mark and reason appear; Breed enabled only for a valid pair;
  pressing it adds an egg and clears the slots; pressing a filled slot empties it.
- `test_creature_card.gd`: the Sparks page lists own/parent sparks and `? ★★` for grandparents without the Scanner.
- `test_panel_fit.gd` already opens a 12-creature Stable at 640×360; it must keep passing with the pair row added.
- `editor_screenshot` of the Stable with a pair picked and of the card's Sparks tab; `--headless --import` clean.

## Out of scope

Pedigree tree (own spec) · which sparks procced shown on the card (the day summary has it) · breeding from the card ·
Gene Lab · un-retiring.
