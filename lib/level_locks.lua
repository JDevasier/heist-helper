-- Which loot sources the player's boosted Agility can't reach
-- Each locked source is named by its MultiLoc parent: highlights
-- match it by parent ID, and its multiVar is the state field
-- the tracker counts, so both drop the same source
local Sources = require("data/locked_sources")
local Locks = {}

local function definition(name)
    local ok, loc = pcall(function() return config.Loc[name] end)
    return ok and loc or nil
end

-- Returns { parents = { [configID] = true }, fields = { [fieldName] = true } } for the
-- sources above the given level, or nil when none are locked
function Locks.locked(heist, agility)
    local sources = Sources[heist]
    if sources == nil or type(agility) ~= "number" then return nil end
    local parents, fields, any = {}, {}, false
    for _, source in ipairs(sources) do
        if agility < source.agility then
            local loc = definition(source.loc)
            if loc ~= nil then
                parents[loc.id], any = true, true
                local ok, field = pcall(function() return loc.multiVar.configName end)
                if ok and field ~= nil then fields[field] = true end
            end
        end
    end
    return any and { parents = parents, fields = fields } or nil
end

return Locks
