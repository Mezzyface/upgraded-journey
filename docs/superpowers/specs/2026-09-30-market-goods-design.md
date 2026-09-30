# Market goods (feed, eggs, upgrades) — design

Status: approved by delegation 2026-09-30 (owner asleep; standing instruction "keep working until the game is done").
Decisions below were made by Claude and are listed in the morning report for review.

## Goal

The Market sells everything the rules already support. Feed runs out today (Feed costs 1 feed; nothing restocks it),
eggs are the only way to get new species besides expeditions, and the +1 AP and Gene Scanner upgrades exist but
can't be bought. Done when a player can buy feed, an egg and an upgrade from the Market by hand, and every refusal
says why before the player presses Buy.

## What already exists (not changed)

- `Market.buy_feed(state, count)` (10 gold each), `Market.egg_for_sale` / `Market.buy_egg` (species with
  `market_tier >= 0` unlocked by reputation tier; needs pen space), `Market.buy_upgrade` (once each; tier gate).
- `data/upgrades/`: Helping Hands (`extra_ap`, 400, tier 1), Gene Scanner (500, tier 1). Species market data:
  Slime, Mushroom, Dog (60, tier 0), Spider, Green Golem (90, tier 1).
- The Market panel's Pens list (`buildable_row.tscn`: `%Name`, `%Holds`, `%Price`, `%Buy`).

## Decisions

- One scrolling Market list with four sections in this order: **Feed**, **Eggs**, **Upgrades**, **Pens** (daily
  needs first). Section headers are `HeaderLabel`s, rows reuse `buildable_row.tscn` (`%Holds` is the detail column).
- Feed: two rows, "Feed ×1" and "Feed ×5", detail "N in stock".
- Eggs: every species with `market_tier >= 0`, cheapest first then by name; a locked one is listed disabled with
  its reason ("needs reputation tier 1") so the player sees what reputation unlocks.
- Upgrades: every upgrade, cheapest first; detail is its description; a bought one shows "Owned" and is disabled.
- A refused Buy is disabled with the refusal as its tooltip (the row stays one line); pressing an enabled Buy acts
  at once (no confirm: purchases are cheap and reversible enough, and the money shows in the bar).
- After a purchase the list refreshes from `Game.changed`, and the shop toasts it ("Bought 5 feed").

## Constraints

Same as the expeditions spec: editor-first (headless Godot builds scenes when the editor is closed; uid lines kept;
`--import` clean), 640×360 / PanelHost 640×320, existing theme variations, the `PackScrollBar` page pattern for the
new scroll, `Game` is the one path from the UI to the rules.

## 1. Rules and `Game`

- `Market.feed_reason(state, count) -> String`, `Market.egg_reason(state, db, species_id) -> String`,
  `Market.upgrade_reason(state, db, upgrade_id) -> String`: the checks now inside `buy_feed` / `buy_egg` /
  `buy_upgrade`, same order and wording; each `buy_*` calls its reason first. `egg_reason` for a locked species
  returns `"needs reputation tier N"` (its `market_tier`) instead of `"not sold here yet"`; a species with
  `market_tier < 0` or unknown stays `"not sold here yet"`.
- `Game.buy_feed(count)`, `Game.buy_egg(species_id)`, `Game.buy_upgrade(upgrade_id)` through `_did` with log lines
  `"Bought 5 feed (-50 gold)"`, `"Bought a Slime egg (-60 gold)"`, `"Bought Gene Scanner (-500 gold)"`.
- `Game.feed_reason(count)`, `Game.egg_reason(species_id)`, `Game.upgrade_reason(upgrade_id)`,
  `Game.eggs_on_offer() -> Array[Species]` (market_tier >= 0; price then name),
  `Game.upgrades_on_offer() -> Array[UpgradeDef]` (cost then name).

## 2. Market panel — `shop/panels/market_panel.tscn` / `.gd`

- `Margin/Rows`: Title/`%Close`, then `Page` HBox: `Scroll` (vertical "Show Never") → `Sections` VBox holding
  `FeedTitle` + `%Feed`, `EggsTitle` + `%Eggs`, `UpgradesTitle` + `%Upgrades`, `PensTitle` + `%Pens` (existing nodes
  moved in), plus a `PackScrollBar` VSlider. Minimum size 360×260.
- Script fills the four lists in `_refresh()` (called from `_ready` and `Game.changed`); Pens keep today's behaviour
  (Buy asks the farm to start placement).
- `signal bought(text: String)`; `shop.gd open_market()` connects it to `toast`.

## Testing

- `test_market.gd`: each reason (money, stock count < 1, locked tier, not sold, pens full, already bought, tier) and
  that each `buy_*` refuses with its reason's text.
- `test_game.gd`: each Game buy costs the right money, logs, emits `changed`; the offer lists' order.
- `test_market_panel.gd` (new): four sections; feed rows buy 1 and 5; a locked egg is disabled with its reason as
  tooltip; buying an upgrade turns its row "Owned"; the list refreshes after a purchase; `bought` is emitted; Pens
  still emit `build_requested`.
- `test_panel_fit.gd` keeps the Market inside 640×360. Screenshot of the Market.

## Out of scope

Selling from the Market (the card sells) · daily stock or price changes · new upgrades or items.
