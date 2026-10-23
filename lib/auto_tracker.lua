-- Reads source progress directly. Never reconstruct bag points from actions,
-- visible marker counts, item stack count, or a presumed untouched run.
local Tracker = {}
Tracker.__index = Tracker

local function integer(value)
    return type(value) == "number" and value == value and math.abs(value) ~= math.huge and value % 1 == 0
end

local function readVariable(signal)
    local ok, value = pcall(function()
        if var == nil or var.VarPlayer == nil then return nil end
        local field = var.VarPlayer[signal.name]
        if field == nil and signal.id ~= nil then field = var.VarPlayer.FromID(signal.id) end
        if field ~= nil then
            local value = field.value
            if value ~= nil then return value end
        end
        -- Fall back to the packed base variable when VarBit lookups are unavailable.
        if signal.baseID ~= nil and signal.mask ~= nil then
            local base = var.VarPlayer.FromID(signal.baseID)
            local raw = base ~= nil and base.value or nil
            if not integer(raw) then return nil end
            local mask, shift = signal.mask, 0
            while (mask & 1) == 0 do mask, shift = mask >> 1, shift + 1 end
            return (raw & signal.mask) >> shift
        end
        return nil
    end)
    if not ok or not integer(value) then return nil end
    return value
end

function Tracker.new(signals, read)
    return setmetatable({ signals = signals, read = read or readVariable, revision = 0, resolved = {}, active = false }, Tracker)
end

function Tracker:publish(loot, counts, needed, summary)
    local changed = false
    for _, key in ipairs({ "heist", "loot", "body", "chest", "safe",
        "total", "needed", "shortfall", "maxPossible", "includeSafes", "bodyNeeded", "chestNeeded", "safeNeeded" }) do
        if (self.summary or {})[key] ~= (summary or {})[key] then changed = true end
    end
    if changed then self.revision = self.revision + 1 end
    self.loot, self.counts, self.needed, self.summary = loot, counts, needed, summary
end

function Tracker:reset()
    self.active = false
    self.resolved = {}
    self.values = {}
    self.sampledProfile, self.sampledSafes, self.sampledExcluded = nil, nil, nil
    self:publish()
end

-- `excluded` names state fields of sources the player can't reach (Agility shortcuts)
-- like unreachable safes, they stay counted as remaining but add no reward
function Tracker:update(tick, profile, inHeist, includeSafes, excluded)
    if type(inHeist) == "function" then inHeist = inHeist() end
    if not inHeist then
        if self.active or self.sampledProfile ~= nil then self:reset() end
        return
    end
    self.active = true
    if type(includeSafes) == "function" then includeSafes = includeSafes() end
    local mapping = self.signals[profile.key]
    if self.signals.resolve ~= nil then
        if self.resolved[profile.key] == nil then self.resolved[profile.key] = self.signals.resolve(profile) end
        mapping = self.resolved[profile.key]
    end
    if mapping == nil then self:publish() return end
    -- The runtime calls this only after relevant events (or initialisation).
    -- Stable samples do not recount, sort or publish UI work.
    local values, sampledNames = {}, {}
    local changed = self.sampledProfile ~= profile or self.sampledSafes ~= includeSafes
        or self.sampledExcluded ~= excluded
    local function sample(field)
        if sampledNames[field.name] then return end
        sampledNames[field.name] = true
        local value = self.read(field)
        values[field.name] = value
        if self.values == nil or self.values[field.name] ~= value then changed = true end
    end
    if mapping.loot ~= nil then sample(mapping.loot) end
    for _, source in ipairs(profile.sources) do
        local group = mapping.groups[source.key]
        for _, field in ipairs(group ~= nil and group.fields or {}) do sample(field) end
    end
    for _, field in ipairs(mapping.aggregateChests ~= nil and mapping.aggregateChests.fields or {}) do sample(field) end
    self.values = values
    self.sampledProfile, self.sampledSafes, self.sampledExcluded = profile, includeSafes, excluded
    if not changed then return end
    local loot = mapping.loot ~= nil and values[mapping.loot.name] or nil
    if not integer(loot) or loot < 0 or loot > 500 then loot = nil end
    local counts, rewards, allKnown = {}, {}, true
    local bodyCount, chestCount, safeCount = 0, 0, 0
    for _, source in ipairs(profile.sources) do
        local group = mapping.groups[source.key]
        local remaining, known = 0, group ~= nil and #group.fields == source.total
        for _, field in ipairs(group ~= nil and group.fields or {}) do
            local value = values[field.name]
            if not integer(value) or value < 0 or (group.maximum ~= nil and value > group.maximum) then
                known = false
            else
                if group.invert then value = 1 - value end
                if value > 0 then
                    remaining = remaining + 1
                    if (not source.safe or includeSafes) and not (excluded ~= nil and excluded[field.name]) then
                        rewards[#rewards + 1] = {
                            points = group.pointsPerUnit ~= nil and value * group.pointsPerUnit or source.points,
                            role = source.key == "body" and "body" or (source.safe and "safe" or "chest"),
                            order = #rewards + 1
                        }
                    end
                end
            end
        end
        counts[source.key] = known and remaining or nil
        if not known then allKnown = false end
        if source.key == "body" then bodyCount = known and remaining or nil
        elseif source.safe then safeCount = known and remaining or nil
        elseif known and chestCount ~= nil then chestCount = chestCount + remaining
        else chestCount = nil end
    end
    -- A reliable combined count does not require per-chest reward attribution.
    -- The final chest remains a separate flag, included exactly once here.
    local aggregate = mapping.aggregateChests
    if aggregate ~= nil then
        local remaining, known = 0, #aggregate.fields == aggregate.total
        for _, field in ipairs(aggregate.fields) do
            local value = values[field.name]
            if not integer(value) or value < 0 or value > aggregate.maximum then known = false
            elseif value > 0 then remaining = remaining + 1 end
        end
        chestCount = known and counts.rare ~= nil and (remaining + counts.rare) or nil
    end
    -- allKnown still gates reward estimates. Aggregate counts can publish even
    -- when a chest's ordinary/ornate reward has not been identified.
    local totalKnown = bodyCount ~= nil and chestCount ~= nil and safeCount ~= nil
    local total = totalKnown and (bodyCount + chestCount + safeCount) or nil
    local needed, shortfall, plan, maxPossible
    if loot == 500 then needed, plan, maxPossible = 0, { body = 0, chest = 0, safe = 0 }, 500
    elseif loot ~= nil and allKnown then
        local available = 0
        for _, reward in ipairs(rewards) do available = available + reward.points end
        maxPossible = math.min(500, loot + available)
        table.sort(rewards, function(first, second)
            if first.points ~= second.points then return first.points > second.points end
            return first.order < second.order
        end)
        local gap = 500 - loot
        needed, plan = 0, { body = 0, chest = 0, safe = 0 }
        for _, reward in ipairs(rewards) do
            if gap <= 0 then break end
            gap, needed = gap - reward.points, needed + 1
            plan[reward.role] = plan[reward.role] + 1
        end
        -- If base rewards cannot reach the cap, retain the all-sources plan.
        -- Its target is the displayed maximum rather than an impossible 500.
        if gap > 0 then shortfall = gap end
    end
    self:publish(loot, counts, needed, { heist = profile.key, loot = loot, body = bodyCount,
        chest = chestCount, safe = safeCount, total = total, needed = needed,
        shortfall = shortfall, maxPossible = maxPossible, includeSafes = includeSafes,
        bodyNeeded = plan ~= nil and plan.body or nil,
        chestNeeded = plan ~= nil and plan.chest or nil,
        safeNeeded = plan ~= nil and plan.safe or nil })
end

return Tracker
