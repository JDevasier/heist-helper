-- Fallback size for the final chest when native bounds are unavailable.
local finalChestMarker = { scale = 1.5, height = 640 }
return {
    hereditas = {
        npc = {
            [17477] = { role = "body" },
            [17478] = { role = "body" },
            [17479] = { role = "body" },
            [17480] = { role = "body" },
            [17485] = { role = "guard" },
            [17486] = { role = "praetorian" }
        },
        loc = {
            [134556] = { role = "entrance" },
            -- Shadow dial: active definition and parent.
            [134609] = { role = "door" },
            [134606] = { role = "door" },
            [134560] = { role = "chest", source = "final", marker = finalChestMarker },
            [134561] = { role = "chest", source = "final", state = "locked", marker = finalChestMarker },
            [134570] = { role = "chest", source = "ordinary" },
            [134571] = { role = "chest", source = "ordinary" },
            [134589] = { role = "anchor" },
            [134590] = { role = "anchor" },
            [134593] = { role = "anchor" },
            [134594] = { role = "anchor" },
            [134595] = { role = "anchor", state = "off" },
            [134596] = { role = "anchor", state = "on" },
            [134566] = { role = "chest", source = "shadow" },
            [134576] = { role = "chest", state = "locked" },
            [134577] = { role = "chest", state = "open" },
            [134579] = { role = "safe" },
            [134580] = { role = "safe" },
            [134581] = { role = "safe" },
            [134587] = { role = "safe", state = "locked" }
        },
        obj = { [59952] = { role = "loot-bag" } }
    },
    arsenal = require("data/arsenal_entities")
}
