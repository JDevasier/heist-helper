-- ID/family recognition. Source totals are read independently from game vars.
local Registry = require("data/entities")
local Rewards = {}
for _, profile in ipairs(require("data/heists")) do
    Rewards[profile.key] = {}
    for _, source in ipairs(profile.sources) do Rewards[profile.key][source.key] = source.points end
end
local Catalog = {}
local LootNames = { safe = "Safe", ordinary = "Chest", shadow = "Shadow chest",
    ornate = "Ornate chest", final = "Rare chest" }

function Catalog.supports(heist) return Registry[heist] ~= nil end

function Catalog.currentEntry(heist, kind, entity)
    local profile = Registry[heist]
    return profile ~= nil and profile[kind] ~= nil and profile[kind][entity.configID] or nil
end

-- Only registered current body definitions qualify. A matching parent can
-- also have blank/inactive children, which must never draw or accept Rummage.
function Catalog.isCurrentBody(heist, entity)
    local entry = Catalog.currentEntry(heist, "npc", entity)
    return entry ~= nil and entry.role == "body"
end

-- Definition IDs and controllers identify reward types; display names and
-- controller ordering do not. Values share the tracker profile's rewards.
function Catalog.lootLabel(heist, kind, entity, completed, bodyLooted)
    local profile = Registry[heist]
    if profile == nil or profile[kind] == nil then return nil end
    local current = profile[kind][entity.configID]
    local parent = profile[kind][entity.parentConfigID]
    local role = current ~= nil and current.role or (parent ~= nil and parent.role or nil)
    local source = current ~= nil and current.source or nil
    source = source or (parent ~= nil and parent.source or nil)
    if role == "body" then source = "body"
    elseif role == "safe" then source = "safe" end
    if heist == "hereditas" and source == nil and kind == "loc" then
        for _, definition in pairs({ entity.config, entity.parentConfig }) do
            local name = definition.configName
            if name == "HEIST_KHARIDET_FINAL_LOOT_MULTI" then source = "final"
            elseif type(name) == "string" and name:match("^HEIST_KHARIDET_SHADOW_CHEST_MULTI_%d+$") then source = "shadow"
            elseif type(name) == "string" and name:match("^HEIST_KHARIDET_STANDARD_CHEST_MULTI?_%d+$") then source = "ordinary" end
        end
    end
    if role == nil then role = Catalog.identify(heist, kind, entity) end
    if role ~= "body" and role ~= "chest" and role ~= "safe" then return nil end
    local key = source == "ordinary" and "chest" or (source == "final" and "rare" or source)
    local points = key ~= nil and Rewards[heist][key] or nil
    local name = LootNames[source] or "Chest"
    if role == "body" then
        name = entity.displayName
        if type(name) ~= "string" or name == "" then
            name = entity.config ~= nil and entity.config.name or nil
        end
        if type(name) ~= "string" or name == "" then name = "Dead legionary" end
        local looted = completed and points or bodyLooted
        return name .. "<br>Looted " .. (looted ~= nil and tostring(looted) or "?") .. "/" .. tostring(points)
    end
    if completed then return name .. "<br>Looted" end
    return name .. "<br>" .. (points ~= nil and tostring(points) or "?") .. " Loot"
end

function Catalog.identify(heist, kind, entity)
    local profile = Registry[heist]
    if profile == nil or profile[kind] == nil then return nil end
    for _, numericID in pairs({ entity.configID, entity.parentConfigID }) do
        local entry = profile[kind][numericID]
        if entry ~= nil then
            local parent = profile[kind][entity.parentConfigID]
            return entry.role, entry.marker or (parent ~= nil and parent.marker or nil)
        end
    end
    if heist == "hereditas" and kind == "loc" then
        for _, definition in pairs({ entity.config, entity.parentConfig }) do
            local name = definition.configName
            if name == "HEIST_KHARIDET_FINAL_LOOT_MULTI" then
                return "chest", profile.loc[134560].marker
            end
            if type(name) == "string" and name:match("^HEIST_KHARIDET_STANDARD_CHEST_MULTI?_%d+$") then
                return "chest"
            end
            if type(name) == "string" and name:match("^HEIST_KHARIDET_SHADOW_CHEST_MULTI_%d+$") then
                return "chest"
            end
            if type(name) == "string" and name:match("^HEIST_KHARIDET_SHADOW_ANCHOR_%d+$") then
                return "anchor"
            end
            if name == "HEIST_KHARIDET_VAULT_BUTTON_ACTIVE"
                or (type(name) == "string" and name:match("^HEIST_KHARIDET_VAULT_BUTTON_%d+$")) then
                return "door"
            end
        end
    end
    if heist == "arsenal" and kind == "loc" then
        for _, definition in pairs({ entity.config, entity.parentConfig }) do
            local name = definition.configName
            if type(name) == "string" and name:match("^HEIST_DRAGONKIN_DOOR_MULTI_%d+$") then
                return "door", profile.loc[134532].marker
            end
            if type(name) == "string" and name:match("^HEIST_DRAGONKIN_CHEST_MULTI_%d+$") then
                return "chest"
            end
        end
    end
    return nil
end

return Catalog
