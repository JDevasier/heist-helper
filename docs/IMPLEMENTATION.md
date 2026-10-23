# Implementation notes

## Automatic tracking

The runtime requires a stolen-goods item and an active heist context. `BOSS_INSTANCE_CURRENT_BOSS` identifies Hereditas as 501 and Arsenal as 500; heist-specific loaded entities provide fallback evidence. Entrances alone do not establish an active run.

`lib/auto_tracker.lua` reads the fields in `data/tracking_fields.lua`. Named lookups fall back to numeric IDs or exact packed-field extraction. The bag quantity is `HEIST_LOOT_QUANTITY`: base variable 12482, mask `0x1FF8`, shifted right by 3. The adjacent final-loot flag uses `0x2000` and is handled separately.

Positive body, chest and safe state fields indicate remaining sources. The final-chest flag is inverted: zero means available. Invalid or missing values remain unknown. Current counters initialize from the active run on reload; no saved totals or presumed fresh-run counts are used.

## Reward estimates

Hereditas bodies have five successful rummages at two base points each. Partial bodies contribute two points per remaining rummage. Remaining chest types are mapped through their scenery definitions' `multiVar` controllers. A fresh vault provides 535 base points across 30 sources.

The estimate sorts remaining source rewards from largest to smallest and counts enough to cover `500 - currentLoot`. A deterministic tie order keeps the chosen plan stable. Each overlay icon shows only the number of its sources used by that one minimum-source plan; these are not separate independent minima. The footer's base maximum is `min(500, currentLoot + accessibleRemainingBaseRewards)`. When this falls below 500, the plan retains every accessible source rather than displaying unknown counts. Safes are eligible at boosted Thieving 102 in Hereditas or 114 in Arsenal. Future bonus rolls are excluded; earned bonuses already appear in the authoritative bag total and can raise the estimate. A shortfall refers to available base loot.

Arsenal counts fourteen non-final chest fields plus its separate final-chest flag. This supports combined counts without guessing which state slots belong to ordinary or ornate rewards. The reward estimate remains unavailable until that mapping is established.

## Highlight completion and geometry

`lib/source_state.lua` handles completion independently of automatic counts. Explicit chest/safe definitions identify open states. A body is complete when its reliably matched loot slot has zero remaining rummages, independently of labels and chat permission. Unknown or ambiguous mappings cannot establish completion. The optional chat fallback requires a valid nearby Rummage target followed by the game's exhaustion message. Target validation rejects stale or unrelated interactions.

Bodies prefer native model bounds. Scenery prefers custom click bounds transformed into world coordinates. Missing bounds use an approximate footprint; Hereditas's final chest has an enlarged fallback. The open Hereditas final-chest definition remains unmapped.

Hereditas's Shadow dial is a door highlight, controlled by the Doors switch and unaffected by loot-completion filtering. Its active definition is 134609 (`HEIST_KHARIDET_VAULT_BUTTON_ACTIVE`) and its parent is 134606 (`HEIST_KHARIDET_VAULT_BUTTON_1`). Exact numbered `HEIST_KHARIDET_VAULT_BUTTON_n` parent families cover other dial placements without matching unrelated dials. Variable notifications for base 12470 invalidate scenery when vault-button state changes.

3D mode draws all twelve box edges. 2D mode projects the cached corners and retains only their convex-hull perimeter. Both modes share source filters, colors, completion state and native depth testing. Optional text labels project above cached bounds each rendered frame and remain readable through walls independently of box depth testing. Labels hide whenever their screen rectangles overlap cached UI panel bounds; native layer ordering alone cannot guarantee that game panels cover them. Stable text, colors and unchanged pixel positions are not rewritten.

Label activation discovers UI geometry through the game area's ancestor tree using the [component collection API](https://developer.runescape.com/rs/ui/component_collection.html). `ONSUBCHANGE`, `ONRESIZE`, plugin settings/content events and viewport changes coalesce rediscovery into a single logic callback. Traversal is bounded to 4,096 components and 24 levels. Transparent layout wrappers are traversed rather than treated as opaque windows; smaller painted panes are grouped only when a background covers their bounds. The label layer and its text children are excluded. No UI content, chat text or inventory data is read.

Each rendered frame reads bounds/visibility from cached component references and checks rectangle overlap, accounting for interface units, ancestor clipping, live panel movement and closing. Horizontal bounds use the longest rendered line measured by the label's font, centered inside its layout width, with a two-unit margin per side for the shadow. Width measurement occurs only when text changes; vertical bounds retain the existing line heights. Unavailable font measurement falls back to the layout width. This geometry fallback is necessary because the exposed hooks do not cover every visibility/position change; it never traverses the UI hierarchy or samples game loot. UI discovery and watches stop when labels are disabled or no eligible labels exist. Failed native UI discovery hides labels, leaves boxes/tracking working, and logs one warning; a later UI event can retry. Native interface layouts still require in-game acceptance testing.

Body labels use the NPC's display name and a second line, `Looted 0/10` through `Looted 10/10`. The eight `HEIST_PICKPOCKET_n_NPC_UID` fields (12501–12508) associate each visible NPC with the tracker's cached remaining-rummage value. An explicit per-body MultiNPC controller can also establish the slot. Five remaining rummages means zero base points looted; zero means ten. Unknown, ambiguous or invalid mappings display `?/10`. These are base depletion points; bonus loot is reflected in the bag total independently. A confirmed exhaustion message also displays 10/10 in grey completion mode.

Line thickness is saved as `highlightLineWidth`, with integer values from 1 to 10 pixels and a default of 4. Changes update existing native shapes in both display modes; newly discovered highlights inherit the setting. Thickness changes do not rebuild meshes, search entities or attach runtime callbacks.

## Runtime cost and lifecycle

Initialisation reads 31 distinct tracking fields in Hereditas and 24 in Arsenal. Relevant `VarTransmit` events queue a fresh snapshot on the next client logic turn; a packet's notifications coalesce into one refresh. Both direct VarBits and packed base-variable updates are recognised. Masks filter unrelated suspicion, stealth, history and antispam bits. Stable play performs no recurring loot reads. `SkillTransmit` uses the boosted-level payload to update safe access only when its eligibility changes.

Discovery is invalidated by scenery/NPC addition, removal, customisation or animation, relevant MultiLoc controllers, region/world changes, or a moved local-player tile. There is no periodic discovery expiry. The API has no player-moved event, so `ServerLogic` compares the cached local player's tile after a packet while highlights are enabled; stationary packets perform no searches or loot/skill/player lookups. Unknown-instance entry waits for recognised entity payloads instead of repeatedly scanning.

2D outlines and optional labels attach camera callbacks only while eligible markers exist. Outline selection checks remain capped at 20Hz as a rendering optimisation. Labels project cached anchors every rendered frame, including render interpolation and projection changes without a logic-camera change. Counter reads and discovery never run in the drawing callback. With body highlights enabled, initial activation and relevant body-variable events read eight UID fields, reusing the tracker's cached remaining-rummage values for completion and labels. Other source changes do not read UID fields. Default 3D boxes with labels disabled add no camera callback. Stable play adds no recurring UID reads.

Outside a heist, normal recurring tracking stops after context reconciliation. Passive inventory, area and instance events can wake it. A retained bag in an unknown instance also permits payload-filtered entity notifications; unrelated entities cause no native reads. Loading and unavailable UI/geometry use half-second retries for at most two seconds after a relevant event, then sleep until another event. A selected body keeps only a scalar clock until its 60-second attribution deadline; that clock performs no loot or entity polling. Logout, profile changes, bag removal and shutdown clear active state; shutdown removes owned handlers and drawing resources. See [the timing review](EVENT_REVIEW.md) for each retained timed operation.

## Validation

Client-independent checks cover variable extraction, partial/exhausted states, bonus bag changes, reload/reset behavior, entry recovery, bounded work, UI preferences and geometry cleanup. Native rendering, model bounds and packet ordering also require in-game acceptance checks.
