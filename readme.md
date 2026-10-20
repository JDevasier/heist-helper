# Heist Helper

Keep your next loot source and your progress toward 500 in sight. Heist Helper supports the Vault of Hereditas and Asuran Arsenal with automatic tracking, a movable overlay and configurable object highlights.

## Features

- Track current loot, the base maximum, and bodies, chests and safes needed to finish.
- Estimate the sources needed to reach 500 in Hereditas.
- Highlight loot and useful objects with 3D boxes or a 2D outer perimeter.
- Show highlights through walls, or use normal world occlusion.
- Hide completed sources or turn them grey.
- Optionally display source names and base-loot values above objects, with per-body looting progress.
- Move the tracker and retain your preferences across reloads.

## Installation

Extract the plugin into the RuneScape beta cache's `dev_plugins/heist-helper` directory. Place `main.lua`, `plugin.json`, `data/` and `lib/` directly inside that directory.

In the beta console, run:

```text
prf
pon heist-helper
```

After updating an enabled installation, run `prl heist-helper`.

## Settings

The heist is detected automatically while carrying stolen goods. Open the plugin's settings or ribbon entry to adjust the overlay and highlights.

Each source counter shows how many are **needed** in one plan using the fewest sources to reach 500 from known base rewards. They are not independent requirements for every source type. **Max possible** shows current loot plus accessible remaining base rewards, capped at 500. If that estimate is below 500, the counters include all accessible sources to reach it. Future bonus loot can raise the estimate. Unknown estimates show `?`.

A base-loot shortfall appears beside the current loot total; that space stays empty when there is no shortfall.

Drag the **Heist loot** header to move the tracker. **Reset position** restores the default location. The **3D / 2D** buttons choose a full wireframe or the outer perimeter of the same bounds. Loot labels and safe highlights default off. Completed-source highlights default to hidden.

## Body-completion permission

Bodies with a reliable NPC-to-loot-slot match disappear automatically when their remaining rummages reach zero. This works with labels disabled and needs no chat permission. Optional `chatAccess` provides a fallback for unmatched bodies by associating the game's exhaustion message with a recently selected body. To enable it in the beta console:

```text
ppe heist-helper chatAccess
ppr heist-helper
```

Rummage an unmatched exhausted body to confirm its completion through this fallback. Automatic loot totals and chest-state filtering work independently of this permission.

## Tracking limits

Actual loot is read directly from game state, including bonuses and penalties. Hereditas's sources-needed estimate uses remaining base rewards; future double/triple-loot rolls are not predicted. Safes below your current boosted Thieving requirement are excluded from the estimate.

Arsenal supports actual loot tracking and object highlights. Its sources-needed and maximum estimates remain unavailable until ordinary and ornate chest-state slots can be distinguished reliably.

Highlights cover loaded objects nearby on your floor. They outline enclosing bounds rather than exact model silhouettes. Guard highlights, minimap markers and hidden-puzzle solutions are not included.

Body labels show the NPC's name and `Looted 0/10` through `Looted 10/10`, based on remaining rummages. This is base-loot progress; bonus rewards are included in the bag tracker. A body whose progress cannot be matched reliably displays `?/10`.

Loot labels hide when their screen rectangles overlap detected UI panels. Panel references are cached on interface changes; rendering checks their current geometry without searching the UI tree every frame. Unusual native interface layouts may need further mapping.

## Documentation

- [Implementation notes](docs/IMPLEMENTATION.md)
- [Event and timing review](docs/EVENT_REVIEW.md)
- [Feature status](docs/FEATURE_CHECKLIST.md)
- [Arsenal definition reference](docs/ARSENAL_IDS.md)
