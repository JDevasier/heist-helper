-- Completion requires an open-chest definition, an exactly matched exhausted
-- body slot, or a senderless exhaustion message tied to a current Rummage target.
-- Missing entities, partial progress and aggregate loot totals are not proof.
local Catalog = require("lib/entity_catalog")
local Fields = require("data/tracking_fields")
local State = {}
State.__index = State
local SENDERS = { "senderNameUnfiltered", "senderNameFiltered", "senderNameSimple" }
local GAME_TYPES = { "GENERAL", "ENGINE", "SPAM", "GENERAL_LINKABLE" }

local function normalise(text)
    if type(text) ~= "string" then return "" end
    return (text:gsub("<[^>]*>", ""):gsub("[%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")):lower()
end

function State.new()
    return setmetatable({ completedBodies = {}, bodySlots = {}, bodyRemaining = {}, target = nil }, State)
end

function State:cancelTarget() self.target = nil end

function State:reset()
    self.completedBodies, self.target = {}, nil
    self.bodySlots, self.bodyRemaining = {}, {}
end

-- Called after body-variable events while body highlights are enabled. Reuse
-- the tracker's loot fields; the only extra native reads are eight NPC UIDs.
function State:sampleBodies(tracker)
    local slots, remaining = {}, {}
    if tracker.sampledProfile ~= nil and tracker.sampledProfile.key == "hereditas" then
        for index = 1, 8 do
            local prefix = "HEIST_PICKPOCKET_" .. index
            local uid = tracker.read(Fields[prefix .. "_NPC_UID"])
            if type(uid) == "number" and uid > 0 and uid % 1 == 0 then
                slots[uid] = slots[uid] == nil and index or false
            end
            local value = (tracker.values or {})[prefix .. "_LOOT_AVAILABLE"]
            if type(value) == "number" and value >= 0 and value <= 5 and value % 1 == 0 then
                remaining[index] = value
            end
        end
    end
    self.bodySlots, self.bodyRemaining = slots, remaining
end

function State:bodyLooted(entity)
    local slot = self.bodySlots[entity.uid]
    -- A MultiNPC controller can also explicitly identify the source slot.
    -- Never infer it from NPC definition IDs, list order or tile positions.
    local ok, controlled = pcall(function()
        local parent = entity.parentConfig
        local controller = parent ~= nil and parent.multiVar or nil
        local name = controller ~= nil and controller.configName or nil
        return type(name) == "string" and tonumber(name:match("^HEIST_PICKPOCKET_([1-8])_")
            or name:match("^HEIST_PICKPOCKET_([1-8])$")) or nil
    end)
    if ok and controlled ~= nil then
        if slot == false or (slot ~= nil and slot ~= controlled) then return nil end
        slot = controlled
    end
    local remaining = slot ~= nil and self.bodyRemaining[slot] or nil
    -- Base depletion progress, not bonus-inclusive bag gains: five successful
    -- rummages, two base points each. Bonuses never exhaust a body early.
    return remaining ~= nil and (5 - remaining) * 2 or nil
end

function State:isComplete(role, entity, heist)
    heist = heist or "hereditas"
    if heist == "arsenal" then
        -- Open doors remain useful passages; controls are repeatable. Neither
        -- is completed loot, so the completed-box preference cannot hide them.
        if role ~= "chest" and role ~= "safe" and role ~= "anchor" then return false end
        local entry = Catalog.currentEntry(heist, "loc", entity)
        return entry ~= nil and entry.role == role and (entry.state == "open" or entry.state == "on")
    end
    if role == "anchor" then
        return entity.configID == 134596 or (entity.config ~= nil
            and entity.config.configName == "HEIST_KHARIDET_SHADOW_ANCHOR_ON")
    end
    if role == "chest" then
        return entity.configID == 134577 or (entity.config ~= nil
            and entity.config.configName == "HEIST_KHARIDET_CHEST_OPEN")
    end
    if role == "body" and entity.coordGrid ~= nil then
        return self:bodyLooted(entity) == 10
            or self.completedBodies[entity.coordGrid:ToPacked()] == true
    end
    return false
end

function State:select(entry, now, heist)
    self:cancelTarget() -- A new non-rummage action cancels attribution too.
    if heist ~= "hereditas" or entry == nil or normalise(entry.verbText) ~= "rummage" then
        return false
    end
    local entity = entry.npcData ~= nil and entry.npcData.entity or nil
    if entity == nil or not entity.isValid or not Catalog.isCurrentBody(heist, entity)
        or Catalog.identify(heist, "npc", entity) ~= "body" or entity.coordGrid == nil then
        return false
    end
    self.target = { entity = entity, uid = entity.uid, tile = entity.coordGrid:ToPacked(), startedAt = now }
    return true
end

function State:chat(now, event, chatTypes)
    if normalise(event.chatMessage) ~= "you've taken everything you can from that target." then return nil end
    -- Accept only this specific completion signal; never retain other chat.
    local allowed = false
    for _, name in ipairs(GAME_TYPES) do
        if chatTypes[name] ~= nil and event.chatType == chatTypes[name] then allowed = true end
    end
    if not allowed then return nil end
    for _, field in ipairs(SENDERS) do
        if event[field] ~= nil and event[field] ~= "" then return nil end
    end
    local target = self.target
    if target == nil then return nil end
    if now < target.startedAt or now - target.startedAt > 60 then
        self:cancelTarget()
        return nil
    end
    local entity = target.entity
    if not entity.isValid or entity.uid ~= target.uid or entity.coordGrid == nil
        or entity.coordGrid:ToPacked() ~= target.tile or not Player.IsAvailable() then
        self:cancelTarget() return nil
    end
    local player = Player.GetEntity()
    local origin = player ~= nil and player.isValid and player.coordGrid or nil
    local body = entity.coordGrid
    if origin == nil or origin.level ~= body.level or math.abs(origin.x - body.x) > 2
        or math.abs(origin.z - body.z) > 2 then
        self:cancelTarget() return nil
    end
    self.completedBodies[target.tile] = true
    self:cancelTarget()
    return target.tile
end

return State
