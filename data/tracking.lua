-- Where reward types are mapped, use actual MultiLoc controllers. Arsenal's
-- aggregate count reads the shared slots without assigning reward types.
local Fields = require("data/tracking_fields")
local Mapping = {}
local byID, byName, byBase = {}, {}, {}
-- Only visual-controller bits require rediscovery; adjacent save, stealth
-- and completion-history bits are ignored.
local visualMasks = { [12466] = 0x3, [12467] = 0x1ffffff, [12469] = 0x3,
    [12470] = 0x1ff, [12482] = 0x7, [12485] = 0xffffff }
for name, field in pairs(Fields) do
    byID[field.id], byName[name] = field, field
    if field.baseID ~= nil then
        byBase[field.baseID] = byBase[field.baseID] or {}
        table.insert(byBase[field.baseID], field)
    end
end

-- VarTransmit may name a VarBit or its packed base. Ignore changes to adjacent
-- suspicion/guard bits when deciding whether loot counters need new reads.
function Mapping.changes(event)
    local variable = event.var
    if variable == nil or variable.typeName ~= "VarPlayer" or event.oldValue == event.newValue then return nil end
    local flags = {}
    local function maskChanged(mask)
        local old, new = event.oldValue, event.newValue
        return math.type(old) ~= "integer" or math.type(new) ~= "integer"
            or (old & mask) ~= (new & mask)
    end
    local function changed(field)
        local name = field.name
        if name:match("_NPC_UID$") then flags.body = true
        else
            flags.loot = true
            if name:match("^HEIST_PICKPOCKET_") then flags.body = true
            elseif name ~= "HEIST_LOOT_QUANTITY" then flags.scenery = true end
        end
    end
    local direct = byID[variable.id] or byName[variable.configName]
    if direct ~= nil then changed(direct)
    else
        for _, field in ipairs(byBase[variable.id] or {}) do
            if maskChanged(field.mask) then changed(field) end
        end
    end
    local numericID, mask = variable.id, visualMasks[variable.id]
    if (mask ~= nil and maskChanged(mask)) or (type(numericID) == "number" and
        (numericID == -60144 or numericID == -60126 or numericID == -60109
        or (numericID >= -60169 and numericID <= -60162)
        or (numericID >= -60141 and numericID <= -60133)
        or (numericID >= -60124 and numericID <= -60114))) then flags.scenery = true end
    return next(flags) ~= nil and flags or nil
end

local function fieldList(prefix, count, suffix)
    local fields = {}
    for index = 1, count do fields[index] = Fields[prefix .. index .. suffix] end
    return fields
end

local function chestGroup(prefixes, count)
    local fields, seen = {}, {}
    for index = 1, count do
        local found
        for _, prefix in ipairs(prefixes) do
            local ok, signal = pcall(function()
                local definition = config.Loc[prefix .. index]
                local controller = definition ~= nil and definition.multiVar or nil
                if controller == nil then return nil end
                local field = Fields[controller.configName]
                if field ~= nil and field.name:match("^HEIST_CHEST_%d+_STATE$") then return field end
                return nil
            end)
            if ok and signal ~= nil then found = signal break end
        end
        if found == nil or seen[found.name] then return nil end
        fields[index], seen[found.name] = found, true
    end
    return { fields = fields, maximum = 7 }
end

function Mapping.resolve(profile)
    local groups = {
        safe = { fields = fieldList("HEIST_SAFE_", 8, "_STATE"), maximum = 7 },
        rare = { fields = { Fields.HEIST_LOOT_FINAL_LOOT }, maximum = 1, invert = true }
    }
    if profile.key == "hereditas" then
        groups.body = { fields = fieldList("HEIST_PICKPOCKET_", 8, "_LOOT_AVAILABLE"),
            -- This field counts successful rummages left, not loot points.
            -- Five rummages at two base points each give ten per fresh body.
            maximum = 15, pointsPerUnit = 2 }
        groups.chest = chestGroup({ "HEIST_KHARIDET_STANDARD_CHEST_MULTI_", "HEIST_KHARIDET_STANDARD_CHEST_MULT_" }, 6)
        groups.shadow = chestGroup({ "HEIST_KHARIDET_SHADOW_CHEST_MULTI_" }, 7)
    else
        -- Arsenal has fourteen non-final chests across both reward types.
        -- Count their shared state slots without assuming that parent/variable
        -- indices 1..8 are ordinary, or assigning rewards to unknown types.
        groups.chest, groups.ornate = nil, nil
    end
    local seen = {}
    for _, key in ipairs({ "chest", "shadow", "ornate" }) do
        for _, field in ipairs(groups[key] ~= nil and groups[key].fields or {}) do
            if seen[field.name] then
                groups.chest, groups.shadow, groups.ornate = nil, nil, nil
                return { loot = Fields.HEIST_LOOT_QUANTITY, groups = groups }
            end
            seen[field.name] = true
        end
    end
    return { loot = Fields.HEIST_LOOT_QUANTITY, groups = groups,
        aggregateChests = profile.key == "arsenal" and {
            fields = fieldList("HEIST_CHEST_", 14, "_STATE"), total = 14, maximum = 7
        } or nil }
end

return Mapping
