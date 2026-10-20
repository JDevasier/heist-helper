-- A small, event-driven HUD. No component timer, sprite search/index or game
-- reads: the existing automatic tracker supplies every displayed value.
local Overlay = {}
Overlay.__index = Overlay
local WIDTH, HEIGHT, HEADER = 300, 148, 23
local ARSENAL_WIDTH = 240
local DEFAULT_X, DEFAULT_Y = 24, 180
local POSITION_KEY, RESIZE_KEY = "lootOverlayPositionV1", "heist-helper-loot-overlay-resize"

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function count(value) return value ~= nil and tostring(value) or "?" end

local function text(parent, x, y, width, height, colour)
    local label = ui.Text.new(parent)
    label:SetPos(x, y)
    label:SetSize(width, height)
    label.font, label.rgba = id.Font.MUSEO_SANS_15PT_REGULAR, colour or 0xE5E8EBFF
    label.maxLines, label.clickthrough = 1, true
    return label
end

local function rectangle(parent, x, y, width, height, colour, fill)
    local box = ui.Rectangle.new(parent)
    box:SetPos(x, y)
    box:SetSize(width, height)
    box.rgba, box.fill, box.clickthrough = colour, fill ~= false, true
    return box
end

local function icon(parent, x, y, item, names)
    local sprite = ui.Sprite.new(parent)
    sprite:SetPos(x, y)
    sprite:SetSize(26, 26)
    sprite.clickthrough = true
    if item ~= nil then
        sprite:SetAssociatedObject(item)
        sprite.associatedObjectQuantityMode = ui.ObjectQuantityDisplayMode.NEVER
    else
        for _, name in ipairs(names) do
            local ok, value = pcall(function() return id.Sprite[name] end)
            if ok and type(value) == "number" and value >= 0 then sprite.sprite = value return sprite end
        end
        -- Text labels remain visible even if an optional built-in icon changes.
        sprite.hidden = true
    end
    return sprite
end

function Overlay.new(database, output)
    local saved = database:GetStructuredData(POSITION_KEY)
    local valid = type(saved) == "table" and saved.schema == 1 and finite(saved.x) and finite(saved.y)
        and saved.x >= 0 and saved.y >= 0 and saved.x <= 100000 and saved.y <= 100000
    local enabled = database:GetBool("showLootOverlay") ~= false
    return setmetatable({ database = database, output = output, enabled = enabled, savedEnabled = enabled,
        x = valid and math.floor(saved.x) or DEFAULT_X, y = valid and math.floor(saved.y) or DEFAULT_Y,
        texts = {}, contents = {}, dirty = false, width = WIDTH }, Overlay)
end

function Overlay:save()
    if self.enabled ~= self.savedEnabled then
        if self.database:SetBool("showLootOverlay", self.enabled) then self.savedEnabled = self.enabled
        elseif not self.warnedPreference then
            self.output("Heist Helper: overlay preference could not be saved; will retry on shutdown.")
            self.warnedPreference = true
        end
    end
    if not self.dirty then return end
    if self.database:SetStructuredData(POSITION_KEY, { schema = 1, x = self.x, y = self.y }) then
        self.dirty = false
    elseif not self.warnedSave then
        self.output("Heist Helper: overlay position could not be saved; will retry on shutdown.")
        self.warnedSave = true
    end
end

function Overlay:place(x, y)
    local maximumX, maximumY = math.max(0, self.parent.width - self.width), math.max(0, self.parent.height - HEIGHT)
    x, y = math.floor(math.max(0, math.min(maximumX, x))), math.floor(math.max(0, math.min(maximumY, y)))
    self.x, self.y = x, y
    if self.root.x ~= x or self.root.y ~= y then self.root:SetPos(x, y) end
    if self.drag == nil then self.handle:SetPos(x, y) end
end

function Overlay:finishDrag()
    if self.drag == nil then return false end
    self.drag = nil
    self.handle:SetPos(self.x, self.y)
    self.handle:SetSize(self.width, HEADER)
    self:save()
    return false
end

function Overlay:beginDrag(component, x, y)
    if not finite(x) or not finite(y) then return false end
    local raw = Mouse.IsAvailable() and Mouse.GetPosition() or nil
    local global = component.xyGlobal
    local scale = 1
    -- Calibrate raw window pixels against this native hook's interface units.
    -- Deltas then remain correct under interface/OS scaling, without polling.
    if raw ~= nil then
        local expectedX, expectedY = global.x + x, global.y + y
        local expected, actual = expectedX, raw.x
        if math.abs(expectedY) > math.abs(expectedX) then expected, actual = expectedY, raw.y end
        if math.abs(expected) >= 32 then
            local measured = actual / expected
            if finite(measured) and measured >= 0.5 and measured <= 4 then scale = measured end
        end
    end
    self.drag = { x = self.x, y = self.y, raw = raw ~= nil and { x = raw.x, y = raw.y } or nil, scale = scale,
        hookX = global.x + x, hookY = global.y + y }
    -- Capture the pointer across the viewport only while the header is held.
    self.handle:SetPos(0, 0)
    self.handle:SetSize(0, 0, 1, 1)
    self.root:MoveToFront()
    self.handle:MoveToFront()
    return false
end

function Overlay:moveDrag(component, x, y)
    local drag = self.drag
    if drag == nil then return false end
    local nextX, nextY
    local raw = drag.raw ~= nil and Mouse.GetPosition() or nil
    if raw ~= nil then
        nextX, nextY = drag.x + (raw.x - drag.raw.x) / drag.scale, drag.y + (raw.y - drag.raw.y) / drag.scale
    elseif finite(x) and finite(y) then
        local global = component.xyGlobal
        nextX, nextY = drag.x + global.x + x - drag.hookX, drag.y + global.y + y - drag.hookY
    end
    if nextX ~= nil then
        local oldX, oldY = self.x, self.y
        self:place(nextX, nextY)
        if oldX ~= self.x or oldY ~= self.y then self.dirty = true end
    end
    return false
end

function Overlay:clear()
    if self.handle ~= nil then pcall(function() self:finishDrag() self.handle:Destroy() end) end
    if self.parent ~= nil then pcall(function() self.parent:Unsubscribe(ui.Hook.ONRESIZE, RESIZE_KEY) end) end
    if self.root ~= nil then pcall(function() self.root:Destroy() end) end
    self.root, self.parent, self.handle, self.drag, self.revision, self.profile = nil, nil, nil, nil, nil, nil
    self.texts, self.contents, self.barWidth, self.safeAccess = {}, {}, nil, nil
end

function Overlay:build(profile)
    local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
    if parent == nil then return false end
    self.parent = parent
    self.profile = profile
    self.width = profile == "arsenal" and ARSENAL_WIDTH or WIDTH
    local width = self.width
    self.root = ui.Layer.new(parent)
    self.root:SetSize(width, HEIGHT)
    self.root.clickthrough = true
    rectangle(self.root, 0, 0, width, HEIGHT, 0x111B24EE)
    rectangle(self.root, 0, 0, width, HEIGHT, 0x817153CC, false)
    rectangle(self.root, 1, 1, width - 2, HEADER, 0x24313BF2)
    text(self.root, 10, 2, width - 150, 20, 0xD8C18FFF).content = "Heist loot"
    text(self.root, width - 132, 2, 100, 20, 0xA7B4BFFF).content = "Needed"
    text(self.root, width - 28, 2, 22, 20, 0x9AAAB5FF).content = "::"
    icon(self.root, 12, 29, 59952) -- Stolen-goods icon; loot comes from the tracker.
    local gapX = profile == "arsenal" and 128 or 165
    self.texts.loot = text(self.root, 48, 30, gapX - 50, 25, 0xF2D28EFF)
    self.texts.gap = text(self.root, gapX, 34, width - gapX - 10, 20, 0xBBC6CFFF)
    rectangle(self.root, 12, 63, width - 24, 3, 0x34434FFF)
    self.bar = rectangle(self.root, 12, 63, 0, 3, 0xD4B575FF)
    local columns = profile == "arsenal" and {
        { "chest", "Chests", nil, { "MENAPHOS_TOMBS_ICON_CHEST" } },
        { "safe", "Safes", nil, { "RS3_ICON_LOCK" } }
    } or { { "body", "Bodies", nil, { "RP_SKULL_AND_BONES" } },
        { "chest", "Chests", nil, { "MENAPHOS_TOMBS_ICON_CHEST" } },
        { "safe", "Safes", nil, { "RS3_ICON_LOCK" } } }
    for index, source in ipairs(columns) do
        local x = 12 + (index - 1) * ((width - 24) / #columns)
        icon(self.root, x, 80, source[3], source[4])
        self.texts[source[1]] = text(self.root, x + 29, 75, (width - 24) / #columns - 29, 22)
        text(self.root, x + 32, 98, 60, 20, 0xA7B4BFFF).content = source[2]
    end
    self.texts.footer = text(self.root, 12, 124, width - 24, 20, 0xA7B4BFFF)
    self.handle = ui.Layer.new(parent)
    self.handle:SetSize(width, HEADER)
    self.handle.clickthrough = false
    self.handle:Subscribe(ui.Hook.ONCLICK, function(component, x, y) return self:beginDrag(component, x, y) end)
    self.handle:Subscribe(ui.Hook.ONHOLD, function(component, x, y) return self:moveDrag(component, x, y) end)
    self.handle:Subscribe(ui.Hook.ONRELEASE, function(component, x, y)
        self:moveDrag(component, x, y)
        return self:finishDrag()
    end)
    self.handle:Subscribe(ui.Hook.ONDRAGCOMPLETE, function()
        self:moveDrag(self.handle)
        return self:finishDrag()
    end)
    parent:Subscribe(ui.Hook.ONRESIZE, RESIZE_KEY, function()
        self:finishDrag()
        self:place(self.x, self.y)
        return true
    end)
    self:place(self.x, self.y)
    self.root:MoveToFront()
    self.handle:MoveToFront()
    return true
end

function Overlay:update(tracker)
    if not self.enabled or not tracker.active then
        if self.root ~= nil then self:clear() end
        return
    end
    local summary = tracker.summary or {}
    local profile = summary.heist == "arsenal" and "arsenal" or "hereditas"
    if self.root ~= nil and self.profile ~= profile then self:clear() end
    if self.root ~= nil then
        local ok, parent = pcall(function() return self.root.parent end)
        if not ok or parent == nil then self:clear() end
    end
    if self.root == nil then
        local ok, built = pcall(self.build, self, profile)
        if not ok then
            self:clear()
            if not self.warnedBuild then
                self.output("Heist Helper: loot overlay could not be created; will retry while in the heist.")
                self.warnedBuild = true
            end
            return
        end
        if not built then return end
    end
    if self.revision == tracker.revision then return end
    local contents = { loot = count(summary.loot) .. " / 500",
        gap = summary.shortfall ~= nil and (summary.shortfall .. " points short") or "",
        chest = count(summary.chestNeeded),
        safe = count(summary.safeNeeded),
        footer = "Max possible: " .. count(summary.maxPossible) .. " (base)" }
    if profile ~= "arsenal" then contents.body = count(summary.bodyNeeded) end
    for key, value in pairs(contents) do
        if self.contents[key] ~= value then self.texts[key].content = value self.contents[key] = value end
    end
    local width = math.floor((summary.loot or 0) / 500 * (self.width - 24))
    if self.barWidth ~= width then self.bar:SetSize(width, 3) self.barWidth = width end
    if self.safeAccess ~= summary.includeSafes then
        self.texts.safe.rgba = summary.includeSafes == false and 0x7F8B95FF or 0xE5E8EBFF
        self.safeAccess = summary.includeSafes
    end
    self.revision = tracker.revision
end

function Overlay:setEnabled(enabled, tracker)
    self.enabled = enabled == true
    self:save()
    self:update(tracker)
end

function Overlay:resetPosition()
    self:finishDrag()
    local oldX, oldY = self.x, self.y
    if self.root ~= nil then self:place(DEFAULT_X, DEFAULT_Y)
    else self.x, self.y = DEFAULT_X, DEFAULT_Y end
    self.dirty = self.dirty or self.x ~= oldX or self.y ~= oldY
    self:save()
end

return Overlay
