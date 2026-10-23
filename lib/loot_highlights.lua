-- Overlay for loaded recognised bodies/chests. Completion uses explicit state
-- evidence, never absence or a guessed number of rummages. Wall visibility is
-- configurable for these known loot markers; guards are never included.
local Catalog = require("lib/entity_catalog")
local SourceState = require("lib/source_state")
local Bounds = require("lib/entity_bounds")
local Context = require("lib/heist_context")
local SourceLabels = require("lib/source_labels")
local BoxOutline = require("lib/box_outline")
local Highlights = {}
Highlights.__index = Highlights
local COLOURS = { body = 0x00FFFFFF, chest = 0xFFC247FF, safe = 0xC080FFFF, anchor = 0x60FF80FF,
    door = 0x60A8FFFF, control = 0x60FF80FF }
local COMPLETED_COLOUR = 0x808080A0
local LINES = { 0,1, 1,2, 2,3, 3,0, 4,5, 5,6, 6,7, 7,4, 0,4, 1,5, 2,6, 3,7 }

local function setVisible(entry, visible)
    entry.visible = visible
    BoxOutline.show(entry, visible and (not entry.is2d or entry.outlineReady == true))
end

function Highlights.new(output, throughWalls, sourceState)
    return setmetatable({ enabled = true, entries = {}, nextID = 0,
        counts = { body = 0, chest = 0, safe = 0, anchor = 0, door = 0, control = 0 }, output = output, warned = false,
        roles = { body = true, chest = true, safe = false, anchor = true, door = true, control = true },
        throughWalls = throughWalls ~= false, completedMode = "hide", scoped = false,
        displayType = "3d", lineWidth = 4, outlines = BoxOutline.new(output),
        sourceState = sourceState or SourceState.new(), labels = SourceLabels.new(output) }, Highlights)
end

function Highlights:setRoleEnabled(role, enabled)
    if self.roles[role] == nil then return end
    self.roles[role] = enabled == true
    if not self.roles[role] then
        for key, entry in pairs(self.entries) do
            if entry.role == role then
                if entry.shape ~= nil and entry.shape.isValid then entry.shape:Destroy() end
                self.entries[key] = nil
            end
        end
        self.counts[role] = 0
        self.labels:sync(self.entries)
        self.outlines:sync(self.entries)
    end
end

function Highlights:setLabelsEnabled(enabled)
    self.labels:setEnabled(enabled)
    if self.enabled and self.labels.enabled then self.labels:sync(self.entries) end
end

function Highlights:setDisplayType(value)
    local mode = value == "2d" and "2d" or "3d"
    if self.displayType == mode then return end
    self.displayType, self.outlines.enabled = mode, mode == "2d"
    for _, entry in pairs(self.entries) do
        entry.is2d, entry.outlineReady, entry.outlineLines = mode == "2d", false, nil
        if entry.shape ~= nil and entry.shape.isValid then
            if mode == "2d" then BoxOutline.show(entry, false)
            elseif entry.mesh3d ~= nil and entry.shape:SetShapeData(entry.mesh3d) then
                BoxOutline.show(entry, entry.visible)
            else
                entry.shape:Destroy()
                entry.shape, entry.drawVisible = nil, false
            end
        end
    end
    self.outlines:sync(self.entries)
end

function Highlights:setCompletedMode(mode)
    self.completedMode = mode == "grey" and "grey" or "hide"
end

-- Sources the player's levels can't reach: locked parents (Agility shortcuts) and,
-- below the Thieving requirement, safes. Either set may be nil when nothing is hidden
function Highlights:setLocked(parents, safes)
    self.lockedParents, self.lockedSafes = parents, safes == true
end

function Highlights:setThroughWalls(enabled)
    self.throughWalls = enabled == true
    for _, entry in pairs(self.entries) do
        if entry.shape ~= nil and entry.shape.isValid then entry.shape.ignoreDepth = self.throughWalls end
    end
end

function Highlights:setLineWidth(value)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then value = 4 end
    local width = math.max(1, math.min(10, math.floor(value + 0.5)))
    if self.lineWidth == width then return end
    self.lineWidth = width
    for _, entry in pairs(self.entries) do
        if entry.shape ~= nil and entry.shape.isValid then entry.shape.lineWidth = width end
    end
end

function Highlights:clear(resetCompletion, preserveTarget)
    self.failed = false
    self.labels:clear()
    self.outlines:clear()
    for _, entry in pairs(self.entries) do
        if entry.shape ~= nil and entry.shape.isValid then entry.shape:Destroy() end
    end
    self.entries = {}
    self.counts = { body = 0, chest = 0, safe = 0, anchor = 0, door = 0, control = 0 }
    self.scoped = false
    if resetCompletion then self.sourceState:reset()
    elseif not preserveTarget then self.sourceState:cancelTarget() end
end

function Highlights:invalidate()
    -- Area geometry refreshes can occur while walking toward a clicked body.
    -- Keep that target; completion still validates its UID, tile and proximity.
    local scoped = self.scoped
    self:clear(false, true)
    self.scoped = scoped
end

function Highlights:toggle()
    self.enabled = not self.enabled
    if not self.enabled then self:clear() end
end

local function extent(value)
    if type(value) ~= "number" or value ~= value then return 1 end
    return math.max(1, math.min(8, math.floor(value)))
end

function Highlights:build(entry, coord, width, length, role, bounds, markerScale, markerHeight)
    local centre
    local positions = {}
    if bounds ~= nil then
        centre = Vector3.new((bounds[1] + bounds[4]) / 2, (bounds[2] + bounds[5]) / 2,
            (bounds[3] + bounds[6]) / 2)
        local x, y, z = (bounds[4] - bounds[1]) / 2 + 6, (bounds[5] - bounds[2]) / 2 + 6,
            (bounds[6] - bounds[3]) / 2 + 6
        for index, corner in ipairs({ { -x, -z }, { x, -z }, { x, z }, { -x, z } }) do
            positions[index] = Vector3.new(corner[1], -y, corner[2])
            positions[index + 4] = Vector3.new(corner[1], y, corner[2])
        end
    else
        centre = coord:ToCoordFine(true).position
        centre.x, centre.y = centre.x + (width - 1) * 256, 0
        centre.z = centre.z + (length - 1) * 256
        local x, z = width * 256 * markerScale - 6, length * 256 * markerScale - 6
        for index, corner in ipairs({ { -x, -z }, { x, -z }, { x, z }, { -x, z } }) do
            local height, success = World.GetGroundHeight(coord.level, centre.x + corner[1], centre.z + corner[2])
            if not success or height == nil or height < 0 then return false end
            positions[index] = Vector3.new(corner[1], height + 18, corner[2])
            positions[index + 4] = Vector3.new(corner[1], height + markerHeight, corner[2])
        end
    end
    local mesh = ShapeData.new()
    mesh.positions, mesh.lines, mesh.tris = positions, LINES, {}
    mesh.rgba = { 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF,
        0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF }
    if entry.shape == nil or not entry.shape.isValid then
        self.nextID = self.nextID + 1
        entry.shape = ShapeList.CreateInstance("heist-loot-preview-" .. self.nextID)
    end
    local shape = entry.shape
    if shape == nil then return false end
    shape.visible, shape.ignoreDepth = false, self.throughWalls
    entry.visible, entry.drawVisible = false, false
    shape.lineWidth, shape.colour = self.lineWidth, COLOURS[role]
    entry.drawColour = COLOURS[role]
    shape.translation = Vector3.new(centre.x, centre.y, centre.z)
    if not shape:SetShapeData(mesh) then shape:Destroy() entry.shape = nil return false end
    entry.mesh3d, entry.is2d = mesh, self.displayType == "2d"
    entry.outlineLines, entry.outlineReady = nil, false
    entry.worldCorners = {}
    for index, point in ipairs(positions) do
        entry.worldCorners[index] = Vector3.new(centre.x + point.x, centre.y + point.y, centre.z + point.z)
    end
    entry.packed, entry.width, entry.length, entry.role = coord:ToPacked(), width, length, role
    entry.bounds = bounds
    entry.markerScale, entry.markerHeight = markerScale, markerHeight
    local top = -math.huge
    for index = 5, 8 do top = math.max(top, centre.y + positions[index].y) end
    entry.labelPosition = Vector3.new(centre.x, top + 64, centre.z)
    return true
end

function Highlights:update(tick, heist, scan, scoped)
    if not self.enabled then return end
    self.failed = false
    -- A detected profile and actual bag possession scope the loot overlay.
    if not Catalog.supports(heist) or (not scoped and (not Player.IsAvailable()
        or not World.IsAvailable() or not Context.bagPresent())) then
        self:clear(true)
        return
    end
    -- Explicit UI/body changes reuse event-invalidated discovery. Entity
    -- proxies are checked again below; no extra native search is needed.
    local player = scan == nil and Player.GetEntity() or nil
    local origin = scan ~= nil and scan.origin or (player ~= nil and player.isValid and player.coordGrid or nil)
    if origin == nil then self:clear(true) return end
    self.scoped = true
    local seen, counts, total = {}, { body = 0, chest = 0, safe = 0, anchor = 0, door = 0, control = 0 }, 0
    for _, group in ipairs({ { "loc", LocList }, { "npc", NPCList } }) do
        local entities = scan ~= nil and scan[group[1]] or group[2].ByDistance(origin, 24, true)
        for index, entity in ipairs(entities) do
            if index > 128 or total >= 64 then break end
            if entity.isValid and (group[1] ~= "loc" or not entity.isHidden) then
                local role, marker = Catalog.identify(heist, group[1], entity)
                -- NPC parent families can include blank/inactive states. Only
                -- registered current body definitions draw.
                if role == "body" and not Catalog.isCurrentBody(heist, entity) then role = nil end
                -- A safe's current definition must be known. Arsenal's looted
                -- child is mapped too, so it can honour the grey setting.
                local current = Catalog.currentEntry(heist, group[1], entity)
                if role == "safe" and not (current ~= nil and current.role == "safe" and current.state ~= nil)
                    and not (heist == "hereditas" and entity.config ~= nil
                    and entity.config.configName == "HEIST_KHARIDET_SAFE_LOCKED") then role = nil end
                if role ~= nil and self.lockedParents ~= nil
                    and self.lockedParents[entity.parentConfigID or entity.configID] then role = nil end
                if role == "safe" and self.lockedSafes then role = nil end
                local coord = entity.coordGrid
                if COLOURS[role] ~= nil and self.roles[role] and coord ~= nil and coord.level == origin.level then
                    local key = group[1] .. ":" .. (group[1] == "npc" and tostring(entity.uid)
                        or tostring(coord:ToPacked()) .. ":" .. tostring(entity.parentConfigID or entity.configID))
                    if not seen[key] then
                        seen[key], total = true, total + 1
                        local entry = self.entries[key] or { role = role }
                        self.entries[key] = entry
                        entry.labelText = nil
                        local completed = self.sourceState:isComplete(role, entity, heist)
                        local hide = completed and (role == "anchor" or self.completedMode == "hide")
                        if hide then
                            setVisible(entry, false)
                        else
                            local width = group[1] == "loc" and extent(entity.width) or 1
                            local length = group[1] == "loc" and extent(entity.length) or 1
                            local bounds
                            if group[1] == "npc" then bounds = Bounds.npc(entity)
                            else bounds = Bounds.scenery(entity) end
                            local markerScale, markerHeight = marker ~= nil and marker.scale or 1,
                                marker ~= nil and marker.height or 220
                            local changed = entry.shape == nil or not entry.shape.isValid
                                or entry.packed ~= coord:ToPacked() or entry.width ~= width or entry.length ~= length
                                or entry.role ~= role or not Bounds.same(entry.bounds, bounds)
                                or entry.markerScale ~= markerScale or entry.markerHeight ~= markerHeight
                            local ready = not changed or self:build(entry, coord, width, length, role,
                                bounds, markerScale, markerHeight)
                            if not ready then self.failed = true end
                            if ready then
                                local colour = completed and COMPLETED_COLOUR or COLOURS[role]
                                if entry.drawColour ~= colour then entry.shape.colour = colour entry.drawColour = colour end
                                setVisible(entry, true)
                                local bodyLooted = role == "body" and self.labels.enabled
                                    and self.sourceState:bodyLooted(entity) or nil
                                entry.labelText = Catalog.lootLabel(heist, group[1], entity, completed, bodyLooted)
                                counts[role] = counts[role] + 1
                            elseif not self.warned then
                                setVisible(entry, false)
                                self.output("Heist Helper: loot highlight terrain/shape unavailable; retrying.")
                                self.warned = true
                            elseif entry.shape ~= nil and entry.shape.isValid then
                                setVisible(entry, false)
                            end
                        end
                    end
                end
            end
        end
    end
    for key, entry in pairs(self.entries) do
        if not seen[key] then
            if entry.shape ~= nil and entry.shape.isValid then entry.shape:Destroy() end
            self.entries[key] = nil
        end
    end
    self.counts = counts
    self.labels:sync(self.entries)
    self.outlines:sync(self.entries)
end

return Highlights
