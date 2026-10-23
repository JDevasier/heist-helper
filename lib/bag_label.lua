-- Current loot on the stolen-goods bag's backpack icon; the tracker supplies the value
local BagLabel = {}
BagLabel.__index = BagLabel
local BAG = 59952
-- Backpack item icons are the dynamic children of TOPLEVEL_V2_INVENTORY component 5
local ICONS = 1473 * 65536 + 5
local DRAW_KEY, HOOK_KEY = "heist-helper-bag-label", "heist-helper-bag-drag"
local DROP_KEY, CHILDREN_KEY = "heist-helper-bag-drop", "heist-helper-bag-children"
local RESCAN_FRAMES = 30

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function bagID(component)
    local ok, value = pcall(function() return component.associatedObjectID end)
    return ok and value or nil
end

function BagLabel.new(database, output)
    local enabled = database:GetBool("showBagTotal") ~= false
    return setmetatable({ database = database, output = output, enabled = enabled, savedEnabled = enabled,
        misses = 0 }, BagLabel)
end

function BagLabel:save()
    if self.enabled == self.savedEnabled then return end
    if self.database:SetBool("showBagTotal", self.enabled) then self.savedEnabled = self.enabled
    elseif not self.warnedSave then
        self.output("Heist Helper: bag-total preference could not be saved; will retry on shutdown.")
        self.warnedSave = true
    end
end

-- The drop slot under the mouse is only a stand-in: the server decides where the bag
-- is; its next backpack update ends the stand-in either way, as the icons then show the
-- confirmed slot, or the old one again if the move was rejected
function BagLabel:expectDrop(icon)
    self.dropIcon = icon
    if icon == nil or self.awaitingDrop then return end
    Event.InventoryUpdated.Subscribe(DROP_KEY, function(event)
        if event.inv == nil or event.inv.id ~= config.Inv.INV.id then return end
        self:endDrop()
    end)
    self.awaitingDrop = true
end

function BagLabel:endDrop()
    if self.awaitingDrop then Event.InventoryUpdated.Unsubscribe(DROP_KEY) end
    self.awaitingDrop, self.dropIcon = false, nil
end

-- Hooks on the game's own icon only observe: returning false would stop the games own
-- drag handlers too, and the bag would then wait for the server before moving
function BagLabel:watch(icon)
    icon:Subscribe(ui.Hook.ONDRAG, HOOK_KEY, function()
        self.dragging = true
        return true
    end)
    icon:Subscribe(ui.Hook.ONDRAGCOMPLETE, HOOK_KEY, function()
        self.dragging = false
        self:expectDrop(self:iconUnderMouse())
        return true
    end)
end

function BagLabel:unwatch()
    if self.icon == nil then return end
    pcall(function()
        self.icon:Unsubscribe(ui.Hook.ONDRAG, HOOK_KEY)
        self.icon:Unsubscribe(ui.Hook.ONDRAGCOMPLETE, HOOK_KEY)
    end)
    self:endDrop()
    self.icon, self.dragging = nil, false
end

function BagLabel:iconUnderMouse()
    local mouse = Mouse.IsAvailable() and Mouse.GetPosition() or nil
    if mouse == nil or self.icons == nil then return nil end
    local found = nil
    self.icons:IterateDynamicComponents(function(child)
        if child == self.text then return false end
        local at = child.xyGlobal
        if mouse.x >= at.x and mouse.x < at.x + child.width and mouse.y >= at.y and mouse.y < at.y + child.height then
            found = child
            return true
        end
        return false
    end)
    return found
end

function BagLabel:findIcon()
    local found = nil
    self.icons:IterateDynamicComponents(function(child)
        if child ~= self.text and bagID(child) == BAG then found = child return true end
        return false
    end)
    return found
end

function BagLabel:build()
    local icons = ui.Interfaces:GetComponent(ICONS)
    if icons == nil then return false end
    self.icons = icons
    self.text = ui.Text.new(icons)
    self.text:SetSize(36, 16)
    self.text.font, self.text.rgba, self.text.maxLines = id.Font.B12_FULL, 0xFFFFFFFF, 1
    self.text.clickthrough, self.text.isShadowed = true, true
    self.text.content = self.content
    self.text.hidden = true
    -- Switching interface layout (modern/classic) rebuilds the icons inside this container
    -- and drops the text, although the text and the old icons still report as valid. The
    -- container survives and signals the rebuild, so the next frame checks the text is
    -- still one of its children
    icons:Subscribe(ui.Hook.ONSUBCHANGE, CHILDREN_KEY, function()
        self.checkChildren = true
        return true
    end)
    return true
end

function BagLabel:dropped()
    local found = false
    self.icons:IterateDynamicComponents(function(child)
        if child == self.text then found = true return true end
        return false
    end)
    return not found
end

function BagLabel:follow()
    if self.text == nil then
        local ok, built = pcall(self.build, self)
        if not ok or not built then
            if not ok and not self.warnedBuild then
                self.output("Heist Helper: bag total could not be created; will retry while in the heist.")
                self.warnedBuild = true
            end
            self:clearText()
            return
        end
    end
    if self.checkChildren then
        self.checkChildren = false
        if self:dropped() then self:clearText() return end
    end
    if self.icon == nil or bagID(self.icon) ~= BAG then
        self:unwatch()
        -- A missing bag (moved, or the backpack not built yet) is rescanned at most
        -- every RESCAN_FRAMES frames rather than on every frame
        if self.misses > 0 then
            self.misses = self.misses - 1
            self.text.hidden = true
            return
        end
        self.icon = self:findIcon()
        if self.icon == nil then
            self.misses = RESCAN_FRAMES
            self.text.hidden = true
            return
        end
        self:watch(self.icon)
    end
    -- The game draws a dragged item as a floating copy the API doesn't expose, so the
    -- total hides for the drag rather than drifting beside it
    if self.dragging then self.text.hidden = true return end
    -- A dropped item shows in its new slot at once, but associatedObjectID changes only
    -- when the server confirms, so the slot under the mouse stands in until then
    if self.dropIcon == self.icon then self:endDrop() end
    local shown = self.dropIcon or self.icon
    local at = shown.xyLocal
    if finite(at.x) and finite(at.y) and (self.x ~= at.x or self.y ~= at.y) then
        self.text:SetPos(at.x + 1, at.y)
        self.x, self.y = at.x, at.y
    end
    local hidden = shown.visibleGlobal ~= true
    if self.text.hidden ~= hidden then self.text.hidden = hidden end
end

function BagLabel:clearText()
    self:unwatch()
    if self.icons ~= nil then pcall(function() self.icons:Unsubscribe(ui.Hook.ONSUBCHANGE, CHILDREN_KEY) end) end
    self.checkChildren = false
    if self.text ~= nil then pcall(function() self.text:Destroy() end) end
    self.text, self.icons, self.x, self.y, self.misses = nil, nil, nil, nil, 0
end

function BagLabel:clear()
    if self.attached then Event.Draw.Unsubscribe(DRAW_KEY) end
    self.attached, self.content = false, nil
    self:clearText()
end

-- Positions follow the icon every rendered frame, so panel moves and slot changes need
-- no event; the value itself changes only with the tracker
function BagLabel:update(tracker)
    local loot = tracker.active and (tracker.summary or {}).loot or nil
    if not self.enabled or loot == nil then
        if self.attached or self.text ~= nil then self:clear() end
        return
    end
    local content = tostring(loot)
    if self.content ~= content then
        self.content = content
        if self.text ~= nil then self.text.content = content end
    end
    if not self.attached then
        Event.Draw.Subscribe(DRAW_KEY, function()
            local ok = pcall(self.follow, self)
            if not ok then
                self:clearText()
                if not self.warnedDraw then
                    self.output("Heist Helper: bag total could not be placed; will retry on the next frame.")
                    self.warnedDraw = true
                end
            end
        end)
        self.attached = true
    end
end

function BagLabel:setEnabled(enabled, tracker)
    self.enabled = enabled == true
    self:save()
    self:update(tracker)
end

return BagLabel
