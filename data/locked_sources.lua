-- Loot sources behind Agility shortcuts, by the MultiLoc parent that controls each one
-- A source reachable more than one way lists its lowest requirement
-- The comments give the source-map tile and the obstacle to check an entry against
return {
    hereditas = {
        { loc = "HEIST_KHARIDET_SHADOW_CHEST_MULTI_1", agility = 72 }, -- 949, 2889, 0: crevice
        { loc = "HEIST_KHARIDET_STANDARD_CHEST_MULTI_5", agility = 72 }, -- 927, 2869, 0: crevice
        { loc = "HEIST_KHARIDET_SAFE_MULTI_4", agility = 72 } -- 956, 2860, 0: crevice
    },
    arsenal = {
        { loc = "HEIST_DRAGONKIN_SAFE_MULTI_1", agility = 85 }, -- 1006, 2870, 0: crevice
        { loc = "HEIST_DRAGONKIN_SAFE_MULTI_3", agility = 85 }, -- 981, 2901, 0: crevice
        { loc = "HEIST_DRAGONKIN_CHEST_MULTI_6", agility = 85 }, -- 998, 2882, 0: crevice
        { loc = "HEIST_DRAGONKIN_CHEST_MULTI_12", agility = 85 }, -- crevice
        { loc = "HEIST_DRAGONKIN_CHEST_MULTI_10", agility = 75 }, -- 977, 2893, 1: rubble
        { loc = "HEIST_DRAGONKIN_CHEST_MULTI_11", agility = 75 }, -- 977, 2889, 2: rubble
        { loc = "HEIST_DRAGONKIN_SAFE_MULTI_5", agility = 75 }, -- 964, 2893, 2: rubble
        { loc = "HEIST_DRAGONKIN_SAFE_MULTI_7", agility = 85 } -- 996, 2885, 2: crevice, or railing at 97
    }
}
