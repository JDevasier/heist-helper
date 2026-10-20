-- Detect from the live instance ID and loaded entities, scoped by bag possession.
-- Saved progression variables cannot identify the active run.
local Context = require("lib/heist_context")
local Catalog = require("lib/entity_catalog")
local Detector = {}
Detector.__index = Detector
local PREFIXES = { hereditas = "HEIST_KHARIDET_", arsenal = "HEIST_DRAGONKIN_" }
-- Boss-instance identifiers are separate from scenery definition IDs.
local INSTANCE_KEYS = { [501] = "hereditas", [500] = "arsenal" }

local function instanceID()
    local ok, value = pcall(function()
        if var == nil or var.VarPlayer == nil then return nil end
        local field = var.VarPlayer.BOSS_INSTANCE_CURRENT_BOSS
        if field == nil then field = var.VarPlayer.FromID(4680) end
        return field ~= nil and field.value or nil
    end)
    if ok and type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0 then
        return value
    end
    return nil
end

function Detector.new()
    return setmetatable({}, Detector)
end

-- Reused by entry reconciliation without extra entity discovery.
Detector.readInstanceID = instanceID

function Detector:reset()
    self.key, self.scan = nil, nil
    self.instanceID = nil
end

function Detector:invalidate() self.scan = nil end

function Detector:dirtyScan() self.scan = nil end

local function identifies(key, kind, entity)
    local role = Catalog.identify(key, kind, entity)
    if role ~= nil and role ~= "entrance" and role ~= "exit" then return true end
    if role == "entrance" or role == "exit" then return false end
    local prefix = PREFIXES[key]
    for _, definition in pairs({ entity.config, entity.parentConfig }) do
        local name = definition.configName
        if type(name) == "string" and name:sub(1, #prefix) == prefix then
            local suffix = name:sub(#prefix + 1)
            -- An entrance beside the outside player is not inside-run evidence.
            if not suffix:match("^ENTRANCE") and not suffix:match("^EXIT") then return true end
        end
    end
    return false
end

Detector.identifies = identifies

function Detector:update(tick, allowed, options)
    if not allowed or not Player.IsAvailable() or not World.IsAvailable() then
        self:reset() return nil
    end
    local bagPresent
    if options ~= nil then bagPresent = options.bagPresent end
    if bagPresent == nil then bagPresent = Context.bagPresent() end
    if not bagPresent then
        self:reset() return nil
    end
    local currentInstance = instanceID()
    if self.instanceID ~= currentInstance then
        -- Leaving/changing an instance must not retain the old loading grace.
        self.key = nil
        self.scan = nil
    end
    self.instanceID = currentInstance
    -- Zero is outside a boss instance. Do not search the surrounding world just
    -- because the player still carries stolen goods after leaving the heist.
    if currentInstance == 0 then
        self.key, self.scan = nil, nil
        return nil
    end
    local found = {}
    local instanceKey = INSTANCE_KEYS[currentInstance]
    if instanceKey ~= nil then found[instanceKey] = true end
    local scan
    if instanceKey == nil or options == nil or options.scanHighlights ~= false then
        local player = Player.GetEntity()
        local origin = player ~= nil and player.isValid and player.coordGrid or nil
        if origin == nil then self:reset() return nil end
        local packed = origin:ToPacked()
        local previous = self.scan
        -- Event-driven callers retain discovery until movement, entity/area
        -- events or a MultiLoc controller invalidate it. No periodic expiry.
        if instanceKey ~= nil and options ~= nil and options.cacheScans and previous ~= nil
            and previous.packed == packed then
            scan = previous
            scan.tick, scan.origin = tick, origin
        else
            scan = { tick = tick, packed = packed, origin = origin,
                loc = LocList.ByDistance(origin, 24, true), npc = NPCList.ByDistance(origin, 24, true) }
        end
    end
    self.scan = scan
    for _, kind in ipairs({ "loc", "npc" }) do
        for index, entity in ipairs(scan ~= nil and scan[kind] or {}) do
            if index > 128 then break end
            if entity.isValid and (kind ~= "loc" or not entity.isHidden) then
                local coord = entity.coordGrid
                if coord ~= nil and coord.level == scan.origin.level then
                    for key in pairs(PREFIXES) do if identifies(key, kind, entity) then found[key] = true end end
                end
            end
        end
    end
    if found.hereditas and found.arsenal then
        self.key = nil -- Conflicting evidence is unknown.
    elseif found.hereditas or found.arsenal then
        self.key = found.hereditas and "hereditas" or "arsenal"
    else
        self.key = nil
    end
    return self.key, scan
end

return Detector
