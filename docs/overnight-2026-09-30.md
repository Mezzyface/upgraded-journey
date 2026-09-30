# Overnight run — 2026-09-29/30

Built while the owner slept ("keep working until the game is done, add a tutorial, have a bot playtest it").
Every item: spec → plan → test-first implementation → fresh reviewer → fix pass → merged into local `main` (not pushed).

Editor/MCP was closed all night: scenes were built by headless Godot (uid lines restored), and checked with `--headless --import`. **Open and save these scenes once in the editor:** `shop/panels/stable_panel.tscn`, `creature_row.tscn`, `creature_card.tscn`, `expedition_panel.tscn`, `market_panel.tscn`, `buildable_row.tscn`, `ui/title.tscn`, `ui/tutorial_hint.tscn`, `shop/shop.tscn`; and check `project.godot` (main scene now `res://ui/title.tscn`).

## expeditions

Fixed after review:
- row portraits squeezed (Note expanding + expand_icon) — test_row_leaves_room_for_the_portrait RED (0 px reserved) → GREEN (Pick expand_icon off, icon_max_width 24; Note fixed 96 px, clips; Expedition Left min 280→220 so the panel fits), suite 223/1 known; renders exp_panel3 + stable_rows3 show portraits.

Rulings (decisions made on your behalf):
- complete (6040f6e; stable 8/0, popups 3/0, shop_scene 9/0; suite 216/1 known). Ruling: Note edited as tscn text (3 property lines) — editor closed — cost: none.
- complete (6040f6e; stable 8/0, popups 3/0, shop_scene 9/0; suite 216/1 known). Ruling: Note edited as tscn text (3 property lines) — editor closed — cost: none. Note: --import rewrites art/*.import with LF only (empty content diff); restored with git checkout -- art after imports.
- complete (97e4667; expedition_panel 5/0, popups 3/0, panel_fit 1/0, shop_scene 9/0; suite 221/1 known). Ruling: scene Godot-built headless, uids restored by text.
- Ruling: challenge lines are plain Labels ("• " + describe, met_color/missing_color overrides) instead of the spec's OrderNeed — OrderNeed is styled for the paper order notes (smooth font, white when neutral) and was unreadable here — cost if wrong: re-skin in the editor.
- Ruling: team slots show portrait + "#id" (full name as tooltip), empty "+" — three slots in the right column clipped "Spider #1" / "Pick a creature" — cost: names only on hover.
- Ruling: Toast z_index 10 in shop.tscn (text edit) — it drew under the 600-px panel — cost: none.
- Ruling: location buttons sort by String(id) — StringName sort is by pointer.

Deferred minors:
- blocked reason hidden in the tooltip in the narrow right column (give Right a larger stretch ratio in the editor).
- disabled DecoratedButton text nearly unreadable (theme).
- left column jumps when the first creature is picked (place buttons wrap once totals appear).
- Slot1..3 scene text "Pick a creature" vs script "+".
- challenge lines built as Label.new() — style only via two exported colours.
- location buttons keyed by node name.
- a slotted creature that becomes blocked isn't named in the reason (unreachable today).
- opening a row's card drops the picks (same as the Stable).
- nits — empty assertion in test_game, blank-line style, long doc lines; Stable notes now clip ("Water · Amor…").

## market goods

Rulings (decisions made on your behalf):
- complete (d8a0dfb; market_panel 5/0, popups 3/0, panel_fit 1/0, shop_scene 10/0). Ruling: scene headless-built, uids restored (market_panel.gd had no uid before; added).
- Ruling: section titles plain Labels like the existing PensTitle (spec said HeaderLabel — title-sized, dwarfed the list). Locked eggs show their reason in the detail column (test RED→GREEN). complete (764dca9; suite 230/1 known)
- Ruling: re-graded Minor 1 (locked upgrades' reason only on hover while affordable-looking) to Important by effect — fixed: test_sections_and_rows RED→GREEN ("Unlocks at T1" detail, description on hover); lock detection by tier comparison instead of string match (clears Minor 3). Suite 230/1 known.

Deferred minors:
- Helping Hands bought mid-day adds an empty 6th heart until tomorrow — owner decides (grant +1 AP now, or say "from tomorrow").
- "Owned" drawn in the faint disabled style and wider than "Buy" (row price shifts) — give %Buy a fixed min width in the editor.
- section titles look like item rows (plain Labels) — a small theme variation would help.
- spec says min size 360×260, built 380×280 (plan); _refresh named refresh; blank-line style.

## pedigree

Fixed after review:
- card height — measured 318 px ending at y=359 with a message (fits by 1 px; the reviewer's overflow didn't reproduce, fragility did): test_panel_fit card-with-message margin check RED at 96 (and 84) → GREEN at 80 (two family lines still fit: 43 px ≥ 42), suite 233/1 known.
- test fixture with duplicate parent ids (impossible pair) → two different wild parents.

Deferred minors:
- grandparent groups don't name their parent; long species names make the Family tab scroll (test assumes short names); duplicate parent ids would show a self-mark ◎ in a hand-edited save; header comment wrap + redundant null checks around Game.who.

## title and save

Fixed after review:
- board re-roll on Continue (empty board looked like an old save) — test_continue_keeps_an_emptied_board RED→GREEN (GameState.predates_board from the missing "board" key; old-format test rewritten to drop the key).
- unreadable save → Continue silently new-gamed and the first click overwrote it — test_an_unreadable_save_is_kept_aside_not_overwritten + test_an_unreadable_save_disables_continue RED→GREEN (Game.can_continue; start() moves it to .bad; Continue disabled "Save can't be read").
- README screenshot command (now names shop.tscn) and main-scene line.

Rulings (decisions made on your behalf):
- branch title stacked on pedigree 9b9d12f. Pre-flight: T1 has_save/new_game → T2 matches. Ruling: New game arms like Sell (spec updated; no Confirm/Cancel nodes).
- complete (0e5c494; suite 237/1 known). Ruling: runner sets the autoload's save_path via root.get_node('Game') (the runner compiles before autoloads). Test fix: refusal check used a creature already away.
- complete (662f5fc; test_title 4/0; suite 241/1 known). Ruling: project.godot main scene by one-line text edit (editor closed). Ruling: new scenes (title, creature_row) given Godot-generated uids by text.
- Ruling: re-graded Minor 1 (double-click New game wipes the ranch) to Important — new_game keeps the old save as .bak and builds the fresh game directly (also fixes Minor 2, delete failure) — test_new_game_keeps_a_backup_of_the_old_ranch RED→GREEN. Suite 245/1 known.

Deferred minors:
- a failed save is only a console warning (no toast).
- runner-save test is order-dependent (earlier files set their own path).
- title has no keyboard/gamepad focus.
- pretty-printed save grows with every creature ever owned (drop the indent later).
- mid-day load resets the evening summary's baseline (spec-accepted).

## tutorial

Fixed after review:
- step 9 impossible on a fresh ranch (starters in 3 egg groups; the text led players to retire two creatures for nothing) — step now explains the same-egg-group rule, warns retiring is permanent, and finishes on opening the Stable (shop.open_stable → saw(stable)) — test_the_breeding_step_never_asks_to_retire_on_a_fresh_ranch RED→GREEN.
- Skip over order notes / one-click skip — Skip now two presses ("Sure?") — test_skip_hides_it_and_is_saved RED→GREEN.
- hint covering the left of Orders/Expedition — compact mode (step's short line) whenever the open popup reaches under the column (exported panel_host; node_paths header needed in shop.tscn) — test_the_tutorial_hint_never_covers_a_popups_buttons now runs every step x every popup incl. OrderNote targets, RED→GREEN; renders tut_orders2/tut_exp2 read. Suite 259/1 known.

Rulings (decisions made on your behalf):
- complete (c12e68d; hint 4/0, shop_scene 11/0; suite 252/1 known). Ruling: test fixture fix — the 'old save' case must start finished, not jump there (jumping correctly shows the goodbye). shop.tscn edited as text (ext_resource + instanced node).
- renders tut_farm/orders/card read — the 230 px box covered the card's Train/Feed and the Expedition Send → test_the_tutorial_hint_never_covers_a_popups_buttons RED → GREEN (96 px column at the left edge, 'Skip'). Ruling: spec said bottom-left box; narrowed to the only strip no popup uses. complete (6497317; suite 257/1 known)

Deferred minors:
- acted not asserted for breed/deliver/retire/sell/build; double save+refresh per advancing action; game_state depends on ui/tutorial.gd (layering); 10/10 header may widen the box; step 5 doesn't say hearts refill tomorrow; goodbye stays until Close and finished==skipped in the save.

## bot playtest

Fixed after review:
- unverified actions (Buy/Place/Retire/Accept/Send logged without checking) and pressing disabled/hidden buttons — press() helper records a gap; each action checks its effect; Deliver checks the menu item — test_a_disabled_button_is_a_gap_not_a_press + gaps.is_empty() in the 3-day test, RED→GREEN.
- false branching (name suffix match) — evolutions from species changes — test_evolutions_come_from_species_changes_not_names RED→GREEN.
- inflated order kinds — kinds_met(c, t) — test_only_the_requirements_a_creature_meets_count_as_filled RED→GREEN.
- "mid-day reload" being end-of-run — bot.reload_on_day (halfway, after sending an expedition), plays on from the reload — asserted in the 3-day test.

Rulings (decisions made on your behalf):
- Ruling: offer ranking stays "best current fit" instead of the spec's "reward per difficulty" — fits the bot's goal of exercising delivery — cost: slightly different economy numbers.

Deferred minors:
- errors outside play_day not captured; only script errors counted (push_error not); runner exits 0 on findings; rule refusals filed as UI gaps; idle-stall needs zero actions; mixed-moment columns; bot buys only the first 60-gold egg (Dog); retires 2 more adults whenever pairs cool down.

