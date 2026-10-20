-- Base reward profiles shared by the automatic tracker and source labels.
return {
    {
        key = "hereditas",
        sources = {
            { key = "body", total = 8, points = 10 },
            { key = "chest", total = 6, points = 10 },
            { key = "shadow", total = 7, points = 15 },
            { key = "safe", total = 8, points = 30, safe = true },
            { key = "rare", total = 1, points = 50 }
        }
    },
    {
        key = "arsenal",
        sources = {
            { key = "chest", total = 8, points = 15 },
            { key = "safe", total = 8, points = 35, safe = true },
            { key = "ornate", total = 6, points = 25 },
            { key = "rare", total = 1, points = 75 }
        }
    }
}
