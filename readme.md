# Heist Helper

Keep your next loot source and your progress toward 500 in sight. Heist Helper supports the Vault of Hereditas and Asuran Arsenal with automatic loot tracking, a movable overlay and configurable object highlights.

## Features

- See your current loot, the base maximum available and any shortfall.
- Find the fewest sources needed to reach 500 in Hereditas.
- Highlight bodies, chests, safes and useful objects with 3D boxes or a 2D outline.
- Show highlights through walls, and hide completed sources or turn them grey.
- Enable optional source labels with loot values and per-body looting progress.
- Move the tracker and save your preferred settings.

## Installation

### 1. Start the plugin beta

Use the **RuneScape plugin beta** for this manual installation. Jagex's [setup guide](https://developer.runescape.com/rs/tutorial/1helloworld.html#joining-the-environment) includes the launch links. Launch it at least once to create its cache folder.

### 2. Find your plugin folder

These are the default installation locations. Replace `<you>` with your computer's username.

| System | Heist Helper folder |
| --- | --- |
| Windows | `C:\ProgramData\Jagex\RuneScape-BETA\dev_plugins\heist-helper` |
| macOS | `/Users/<you>/Jagex/RuneScape-BETA/dev_plugins/heist-helper` |
| Linux (Bolt) | `/home/<you>/.local/share/bolt-launcher/jagex/RuneScape-BETA/dev_plugins/heist-helper` |

On Windows, paste `C:\ProgramData\Jagex\RuneScape-BETA` into File Explorer's address bar to open the cache, even if ProgramData is hidden. Create `dev_plugins` and then `heist-helper` if they do not exist.

**Custom cache or sandbox:** click the cog on the client's loading window to find the cache used by that client. The cache contains `.jcache` files; create `dev_plugins/heist-helper` inside it. A sandboxed client can use a different cache from the regular client.

### 3. Extract the release

Open the [latest release](https://github.com/JDevasier/heist-helper/releases/latest) and download the attached `heist-helper-<version>.zip` under **Assets**. Extract its contents into the `heist-helper` folder from the previous step.

The result should look like this:

```text
RuneScape-BETA/
└── dev_plugins/
    └── heist-helper/
        ├── main.lua
        ├── plugin.json
        ├── data/
        ├── lib/
        ├── docs/
        └── readme.md
```

`main.lua` and `plugin.json` must be directly inside `dev_plugins/heist-helper`. An extra nested folder will prevent the client from finding the plugin.

### 4. Enable it in-game

Log into a beta world and open the console with **Alt + the key directly below Esc**. Run these commands one at a time:

```text
prf
plist
pon heist-helper
```

`plist` should include `heist-helper`. After enabling it, the console shows a Heist Helper version message. Close the console with the same keyboard shortcut.

## Using Heist Helper

The overlay and highlights activate automatically inside a supported heist while you are carrying stolen goods.

- **Move the tracker:** drag its **Heist loot** header. Use **Reset position** in settings to restore its position.
- **Choose your highlights:** open Heist Helper's settings or ribbon panel to toggle source types, through-wall visibility and 2D/3D boxes.
- **Show loot labels:** turn on **Loot labels**. Labels and safe highlights start off; completed highlights start hidden.
- **Read the estimate:** the source counts form one plan to reach 500. **Max possible** uses remaining base rewards; future bonus loot can raise it. A shortfall means those base rewards are insufficient.

Arsenal currently supports actual loot tracking and object highlights; its needed-source and maximum estimates display `?`.

## Updating

1. Disable the plugin with `poff heist-helper`.
2. Extract the latest release into the same `heist-helper` folder, replacing existing files.
3. Run `prf`, then `pon heist-helper`.

The client retains your saved settings. For Lua-only edits to an enabled installation, `prl heist-helper` reloads the plugin.

## Troubleshooting

- **Not listed by `plist`:** check the running client's cache location and the folder layout above, then run `prf` again.
- **Enabled, but no overlay:** enter a supported heist with stolen goods in your backpack. Check that **Visible** is enabled in the plugin settings, then try **Reset position**.
- **A fully looted body stays highlighted:** optional chat access provides a completion fallback. Run `ppe heist-helper chatAccess`, then `ppr heist-helper`, and rummage the body again. Normal automatic tracking does not require this permission.

For other problems, [open an issue](https://github.com/JDevasier/heist-helper/issues) with the plugin version and any console error. Developer details are in [Implementation notes](docs/IMPLEMENTATION.md).
