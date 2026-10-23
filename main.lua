-- Automatic loot/source tracking reads the game's named progress fields.
local VERSION = "0.4.16"
local Heists = require("data/heists")
local AutoTracker = require("lib/auto_tracker")
local Tracking = require("data/tracking")
local Detector = require("lib/heist_detector")
local Context = require("lib/heist_context")
local Menu = require("lib/menu")
local LootOverlay = require("lib/loot_overlay")
local LootHighlights = require("lib/loot_highlights")
local SourceState = require("lib/source_state")
local profiles = {}
for _, profile in ipairs(Heists) do profiles[profile.key] = profile end
local currentHeist = nil
local detector = Detector.new()
local function currentKey() return currentHeist ~= nil and currentHeist.key or "unknown" end
local tracker = AutoTracker.new(Tracking)
local overlay = LootOverlay.new(PersistentDB, log)
local synchronizeRuntime, wake
local sourceState = SourceState.new()
local highlights = LootHighlights.new(log, PersistentDB:GetBool("throughWalls"), sourceState)
highlights:setCompletedMode(PersistentDB:GetString("completedMode"))
highlights:setLabelsEnabled(PersistentDB:GetBool("showSourceLabels") == true)
highlights:setDisplayType(PersistentDB:GetString("highlightDisplayType"))
highlights:setLineWidth(PersistentDB:GetInt("highlightLineWidth"))
local roleSettings = { chest = "showChests", safe = "showSafes", anchor = "showAnchors",
    door = "showDoors", control = "showControls" }
local savedRoles = {}
for role, key in pairs(roleSettings) do
    local saved = PersistentDB:GetBool(key)
    if saved ~= nil then highlights:setRoleEnabled(role, saved) end
    savedRoles[role] = highlights.roles[role]
end
local gameAllowed = true
local now, lastTick = 0, nil
local subscriptions, stopped = {}, false
local logicAttached, entryAttached, motionAttached, entitiesAttached = false, false, false, false
local bagPresent, contextDirty, wakeNeeded = false, true, true
local contextProbeUntil, retryAt, retryUntil = nil, nil, nil
local trackingDirty, detectionDirty, highlightsDirty, bodiesDirty = true, true, true, true
local skillDirty, safeEligible = true, false
local movementPlayer, movementTile
local savedThroughWalls = highlights.throughWalls
local savedCompletedMode = highlights.completedMode
local savedSourceLabels = highlights.labels.enabled
local savedDisplayType = highlights.displayType
local savedLineWidth = highlights.lineWidth
local chatGranted, chatAttached = false, false

local function savePreferences()
    if savedLineWidth ~= highlights.lineWidth then
        if PersistentDB:SetInt("highlightLineWidth", highlights.lineWidth) then savedLineWidth = highlights.lineWidth
        else log("Heist Helper: line thickness could not be saved; will retry on shutdown.") end
    end
    if savedDisplayType ~= highlights.displayType then
        if PersistentDB:SetString("highlightDisplayType", highlights.displayType) then savedDisplayType = highlights.displayType
        else log("Heist Helper: display-type preference could not be saved; will retry on shutdown.") end
    end
    if savedSourceLabels ~= highlights.labels.enabled then
        if PersistentDB:SetBool("showSourceLabels", highlights.labels.enabled) then
            savedSourceLabels = highlights.labels.enabled
        else log("Heist Helper: source-label preference could not be saved; will retry on shutdown.") end
    end
    for role, key in pairs(roleSettings) do
        if savedRoles[role] ~= highlights.roles[role] then
            if PersistentDB:SetBool(key, highlights.roles[role]) then savedRoles[role] = highlights.roles[role]
            else log("Heist Helper: could not save " .. role .. " highlight preference.") end
        end
    end
    if savedThroughWalls ~= highlights.throughWalls then
        if PersistentDB:SetBool("throughWalls", highlights.throughWalls) then
            savedThroughWalls = highlights.throughWalls
        else
            log("Heist Helper: could not save wall-visibility setting; will retry on change or shutdown.")
        end
    end
    if savedCompletedMode ~= highlights.completedMode then
        if PersistentDB:SetString("completedMode", highlights.completedMode) then savedCompletedMode = highlights.completedMode
        else log("Heist Helper: could not save completed-box setting; will retry on change or shutdown.") end
    end
end

local function subscribe(event, name, callback)
    event.Subscribe(name, callback)
    subscriptions[#subscriptions + 1] = { event = event, name = name }
end

local synchronizeChat

local function clearWorld()
    detector:reset()
    currentHeist = nil
    highlights:clear(true)
    tracker:reset()
    bagPresent, contextDirty, wakeNeeded = false, true, false
    contextProbeUntil, retryAt, retryUntil = nil, nil, nil
    trackingDirty, detectionDirty, highlightsDirty, bodiesDirty, skillDirty = true, true, true, true, true
    movementPlayer, movementTile = nil, nil
    if synchronizeChat ~= nil then synchronizeChat() end
    overlay:update(tracker)
    if synchronizeRuntime ~= nil then synchronizeRuntime() end
end

synchronizeChat = function()
    chatGranted = Plugin.HasPermission(PluginPermissions.chatAccess)
    local shouldAttach = not stopped and gameAllowed and currentHeist ~= nil and currentHeist.key == "hereditas" and highlights.enabled and chatGranted
    if shouldAttach and not chatAttached then
        Event.MiniMenuEntrySelected.Subscribe("heist-helper-body-target", function(event)
            if highlights.scoped then
                sourceState:select(event.entry, now, currentKey())
                if sourceState.target ~= nil then sourceState.target.needsClock = true end
            else sourceState:cancelTarget() end
            if sourceState.target ~= nil then wake(false) else synchronizeRuntime() end
        end)
        Event.ChatMessage.Subscribe("heist-helper-body-exhausted", function(event)
            if not highlights.scoped then sourceState:cancelTarget() return end
            local previousTarget = sourceState.target
            local tile = sourceState:chat(now, event, ChatType)
            if tile ~= nil then
                highlightsDirty = true
                wake(false)
            elseif previousTarget ~= sourceState.target then
                synchronizeRuntime()
            end
        end)
        chatAttached = true
    elseif not shouldAttach and chatAttached then
        Event.MiniMenuEntrySelected.Unsubscribe("heist-helper-body-target")
        Event.ChatMessage.Unsubscribe("heist-helper-body-exhausted")
        chatAttached = false
        sourceState:cancelTarget()
    end
end

local app = {
    version = VERSION,
    highlights = highlights, overlay = overlay,
    toggleHighlights = function()
        highlights:toggle() synchronizeChat()
        detectionDirty, highlightsDirty, bodiesDirty = true, true, true
        wake(false)
    end,
    toggleSourceLabels = function()
        highlights:setLabelsEnabled(not highlights.labels.enabled)
        highlightsDirty = true
        wake(false)
        savePreferences()
    end,
    setDisplayType = function(mode) highlights:setDisplayType(mode) savePreferences() end,
    setLineWidth = function(width) highlights:setLineWidth(width) savePreferences() end,
    toggleOverlay = function()
        overlay:setEnabled(not overlay.enabled, tracker)
        highlights.labels:queueUI()
        wake(false)
    end,
    resetOverlayPosition = function() overlay:resetPosition() end,
    toggleRole = function(role)
        highlights:setRoleEnabled(role, not highlights.roles[role])
        detectionDirty, highlightsDirty = true, true
        wake(false)
        savePreferences()
    end,
    toggleThroughWalls = function()
        highlights:setThroughWalls(not highlights.throughWalls)
        savePreferences()
    end,
    toggleCompletedMode = function()
        highlights:setCompletedMode(highlights.completedMode == "hide" and "grey" or "hide")
        highlightsDirty = true
        wake(false)
        savePreferences()
    end
}

local function setDetectedProfile(key)
    local nextHeist = profiles[key]
    if currentHeist == nextHeist then return end
    currentHeist = nextHeist
    highlights:clear(true)
    tracker:reset()
    trackingDirty, highlightsDirty, bodiesDirty, skillDirty = true, true, true, true
    movementPlayer, movementTile = nil, nil
    synchronizeChat()
end

local function safeAccess()
    local ok, level = pcall(function() return Player.GetLevelGameplay(SkillType.THIEVING) end)
    return ok and type(level) == "number" and currentHeist ~= nil and level >= (currentHeist.key == "hereditas" and 102 or 114)
end

local function refreshContext(tick)
    if not gameAllowed then bagPresent = false return false end
    if Player.IsAvailable() and World.IsAvailable() then
        bagPresent = Context.bagPresent()
        local instance = not bagPresent and Detector.readInstanceID() or nil
        if bagPresent or instance == 0 or (instance == nil and contextProbeUntil == nil) then
            contextDirty, contextProbeUntil = false, nil
            return false
        end
        -- Entry state and inventory can settle on different ticks. A positive
        -- instance with no bag is a pending entry, never permission to draw.
    else
        bagPresent = false
    end
    -- Bounded readiness recovery after an event, never ongoing detection.
    -- Keep the context dirty after expiry so the next event can retry it.
    if contextProbeUntil == nil then contextProbeUntil = tick + 100 end
    return tick < contextProbeUntil
end

local function onLogic(event)
    if stopped then return end
    if lastTick ~= nil and event.logicTick < lastTick then
        clearWorld()
        contextDirty, detectionDirty, wakeNeeded = true, true, true
    end
    lastTick, now = event.logicTick, event.logicTick / 50
    local target = sourceState.target
    if target ~= nil then
        if target.needsClock then target.startedAt, target.needsClock = now, nil end
        if now - target.startedAt > 60 then sourceState:cancelTarget() end
    end
    if not wakeNeeded and (retryAt == nil or event.logicTick < retryAt) then synchronizeRuntime() return end
    wakeNeeded, retryAt = false, nil
    local contextPending = contextDirty and refreshContext(event.logicTick)
    if detectionDirty or contextPending then
        detectionDirty = false
        local detectedKey
        if gameAllowed and bagPresent then
            detectedKey = detector:update(event.logicTick, true,
                { bagPresent = true, scanHighlights = highlights.enabled, cacheScans = true })
        else detector:reset() end
        setDetectedProfile(detectedKey)
    end
    if currentHeist ~= nil then
        if skillDirty then safeEligible, skillDirty = safeAccess(), false end
        if trackingDirty then
            trackingDirty = false
            tracker:update(event.logicTick, currentHeist, true, safeEligible)
        end
        if bodiesDirty and highlights.enabled and highlights.roles.body
            and currentHeist.key == "hereditas" then
            sourceState:sampleBodies(tracker)
            highlightsDirty = true
        end
        bodiesDirty = false
        if highlightsDirty and highlights.enabled and detector.scan ~= nil then
            highlightsDirty = false
            detector.scan.tick = event.logicTick
            highlights:update(event.logicTick, currentKey(), detector.scan, true)
        end
    end
    local previousOverlayRoot = overlay.root
    overlay:update(tracker)
    if previousOverlayRoot ~= overlay.root then highlights.labels:queueUI() end
    local pending = contextPending
    -- Missing native UI/geometry can settle after the notifying event. Retry
    -- for two seconds only; later area/UI/source events can start a new attempt.
    local failed = currentHeist ~= nil and ((overlay.enabled and overlay.root == nil)
        or (highlights.enabled and (highlights.failed or (highlights.labels.enabled and highlights.labels.failed))))
    if failed then
        if retryUntil == nil then retryUntil = event.logicTick + 100 end
        pending = pending or event.logicTick < retryUntil
    else retryUntil = nil end
    if pending then
        retryAt = event.logicTick + 25
        detectionDirty = currentHeist == nil or contextPending
        highlightsDirty = highlightsDirty or failed
    end
    synchronizeRuntime()
end

local function sceneChanged(event)
    if currentHeist == nil then
        -- Late entry entities can identify a run without repeatedly searching
        -- an unknown instance. Unrelated payloads never cause game queries.
        local entity, kind = event ~= nil and event.npcEntity or nil, "npc"
        if entity == nil and event ~= nil and event.config ~= nil then
            entity, kind = { configID = event.config.id, config = event.config }, "loc"
        elseif entity ~= nil and not entity.isValid then return end
        if entity == nil then return end
        local recognised = false
        for _, key in ipairs({ "hereditas", "arsenal" }) do
            if Detector.identifies(key, kind, entity) then recognised = true end
        end
        if not recognised then return end
        detector:dirtyScan()
        detectionDirty, highlightsDirty = true, true
        wake(true)
        return
    end
    local origin = detector.scan ~= nil and detector.scan.origin or nil
    local coord = event ~= nil and event.coordGrid or nil
    if coord == nil and event ~= nil and event.npcEntity ~= nil and event.npcEntity.isValid then
        coord = event.npcEntity.coordGrid
    end
    if origin ~= nil and coord ~= nil and (origin.level ~= coord.level
        or math.abs(origin.x - coord.x) > 24 or math.abs(origin.z - coord.z) > 24) then return end
    detector:dirtyScan()
    detectionDirty, highlightsDirty = true, true
    wake(false)
end

local function serverPacket()
    -- The API has no player-moved event. Observe only the cached local-player
    -- tile after a server packet; stationary packets never search or read loot.
    if movementPlayer == nil or not movementPlayer.isValid then
        movementPlayer = Player.IsAvailable() and Player.GetEntity() or nil
    end
    local tile = movementPlayer ~= nil and movementPlayer.isValid and movementPlayer.coordGrid or nil
    local packed = tile ~= nil and tile:ToPacked() or nil
    if packed ~= movementTile then movementTile = packed sceneChanged() end
end

local sceneEvents = { "NPCEntityAdded", "NPCEntityRemoved", "LocAdded", "LocRemoved", "LocCustomised", "LocAnimation" }

synchronizeRuntime = function()
    -- Instance entry must remain observable after a bag disappears on exit.
    -- The event-payload filter performs no inventory/instance-value queries,
    -- entity searches or idle polling by itself.
    local wantsEntry = not stopped and gameAllowed
    if wantsEntry and not entryAttached then
        Event.VarTransmit.Subscribe("heist-helper-entry", function(event)
            if event.var == nil or event.oldValue == event.newValue then return end
            if event.var.typeName ~= "VarPlayer" then return end
            local id = event.var.id
            if id == 4680 or event.var.configName == "BOSS_INSTANCE_CURRENT_BOSS" then
                detector:invalidate()
                wake(true)
            elseif currentHeist ~= nil then
                local changes = Tracking.changes(event)
                if changes ~= nil then
                    trackingDirty = trackingDirty or changes.loot == true
                    bodiesDirty = bodiesDirty or changes.body == true
                    highlightsDirty = true
                    if changes.scenery then detector:dirtyScan() detectionDirty = true end
                    wake(false)
                end
            end
        end)
        entryAttached = true
    elseif not wantsEntry and entryAttached then
        Event.VarTransmit.Unsubscribe("heist-helper-entry")
        entryAttached = false
    end
    local active = not stopped and gameAllowed and currentHeist ~= nil
    local wantsScene = active and highlights.enabled
    local candidate = not stopped and gameAllowed and bagPresent and currentHeist == nil and detector.instanceID ~= 0
    local wantsEntities = candidate or (active and (highlights.enabled or (detector.instanceID ~= 500 and detector.instanceID ~= 501)))
    if wantsEntities and not entitiesAttached then
        for _, name in ipairs(sceneEvents) do Event[name].Subscribe("heist-helper-scene", sceneChanged) end
        entitiesAttached = true
    elseif not wantsEntities and entitiesAttached then
        for _, name in ipairs(sceneEvents) do Event[name].Unsubscribe("heist-helper-scene") end
        entitiesAttached = false
    end
    if wantsScene and not motionAttached then
        movementPlayer = Player.IsAvailable() and Player.GetEntity() or nil
        local tile = movementPlayer ~= nil and movementPlayer.isValid and movementPlayer.coordGrid or nil
        movementTile = tile ~= nil and tile:ToPacked() or nil
        Event.ServerLogic.Subscribe("heist-helper-movement", serverPacket)
        motionAttached = true
    elseif not wantsScene and motionAttached then
        Event.ServerLogic.Unsubscribe("heist-helper-movement")
        motionAttached, movementPlayer, movementTile = false, nil, nil
    end
    local wanted = not stopped and gameAllowed and (wakeNeeded or retryAt ~= nil or sourceState.target ~= nil)
    if wanted and not logicAttached then
        Event.Logic.Subscribe("heist-helper-clock", onLogic)
        logicAttached = true
    elseif not wanted and logicAttached then
        Event.Logic.Unsubscribe("heist-helper-clock")
        logicAttached = false
    end
end

wake = function(refreshInventory)
    if stopped or not gameAllowed then return end
    if not refreshInventory and currentHeist == nil then return end
    if refreshInventory then contextDirty, contextProbeUntil, detectionDirty = true, nil, true end
    if currentHeist ~= nil and not highlights.enabled and not refreshInventory then
        highlightsDirty = false
    end
    wakeNeeded, retryAt, retryUntil = true, nil, nil
    synchronizeRuntime()
end

local function backpackEvent(event)
    if config == nil or config.Inv == nil or event.inv == nil or event.inv.id ~= config.Inv.INV.id then return end
    wake(true)
end
subscribe(Event.InventoryAdded, "heist-helper-bag-added", backpackEvent)
subscribe(Event.InventoryUpdated, "heist-helper-bag-updated", backpackEvent)
subscribe(Event.InventoryRemoved, "heist-helper-bag-removed", backpackEvent)
subscribe(Event.SkillTransmit, "heist-helper-safe-access", function(event)
    if currentHeist == nil or event.skill ~= SkillType.THIEVING or event.oldGameplayLevel == event.newGameplayLevel then return end
    local level = event.newGameplayLevel
    if type(level) ~= "number" or level ~= level or level < 0 then return end
    local eligible = level >= (currentHeist.key == "hereditas" and 102 or 114)
    if eligible ~= safeEligible then
        safeEligible, skillDirty, trackingDirty = eligible, false, true
        wake(false)
    end
end)
subscribe(Event.GameStateChanged, "heist-helper-state", function(event)
    gameAllowed = event.newState == GameState.GAME
    if event.newState ~= GameState.GAME then clearWorld() end
    if gameAllowed then wake(true) end
    synchronizeChat()
end)
subscribe(Event.OptionalPermissionChanged, "heist-helper-chat-permission", function(event)
    if event.permissionName == "chatAccess" then synchronizeChat() end
end)
subscribe(Event.WindowFocusChanged, "heist-helper-overlay-focus", function(event)
    if not event.hasFocus then overlay:finishDrag() end
end)
local function newArea() clearWorld() wake(true) end
local function updateArea()
    detector:invalidate() highlights:invalidate()
    detectionDirty, highlightsDirty = true, true
    wake(true)
end
subscribe(Event.WorldCreated, "heist-helper-world", newArea)
subscribe(Event.RegionCreated, "heist-helper-region", newArea)
subscribe(Event.WorldUpdated, "heist-helper-world-update", updateArea)
subscribe(Event.RegionUpdated, "heist-helper-region-update", updateArea)
local function build(event)
    Menu.build(event.component, app)
    highlights.labels:queueUI()
    if currentHeist ~= nil then highlightsDirty = true wake(false) end
end
subscribe(Event.SettingsLayerReady, "heist-helper-settings", build)
subscribe(Event.ContentLayerReady, "heist-helper-content", build)
subscribe(Event.WindowSizeChanged, "heist-helper-viewport", function()
    highlights.labels:queueUI()
    if currentHeist ~= nil then highlightsDirty = true wake(false) end
end)
synchronizeChat()
synchronizeRuntime()

function PluginShutdown()
    stopped = true
    synchronizeRuntime()
    synchronizeChat()
    highlights:clear()
    for _, subscription in ipairs(subscriptions) do subscription.event.Unsubscribe(subscription.name) end
    savePreferences()
    overlay:clear()
    overlay:save()
end

log("Heist Helper " .. VERSION .. " loaded. Heist selection and loot updates are automatic. Source counters show needed; maximum uses remaining base loot.")
log(chatGranted and "Heist Helper: body completion messages enabled."
    or "Heist Helper: body completion needs permission. Run ppe heist-helper chatAccess, then ppr heist-helper.")
