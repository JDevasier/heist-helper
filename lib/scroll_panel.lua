-- A clipped settings viewport with explicit wheel handling. Moving our own
-- content layer works even when the supplied host layer is not scrollable.
local ScrollPanel = {}
ScrollPanel.__index = ScrollPanel

function ScrollPanel.new(parent)
    local self = setmetatable({ offset = 0, contentHeight = 1 }, ScrollPanel)
    -- Reuse a single closure for every control in this presentation.
    self.wheelHandler = function(_, delta)
        self:scroll(delta * 32)
        return false
    end
    self.viewport = ui.Layer.new(parent)
    self.viewport:SetPos(0, 0)
    self.viewport:SetSize(-24, 0, 1, 1)
    self.content = ui.Layer.new(self.viewport)
    self.content:SetPos(0, 0)
    self.content:SetSize(0, 1, 1, 0)

    self.rail = ui.Layer.new(parent)
    self.rail:SetPos(-22, 0, 1, 0)
    self.rail:SetSize(22, 0, 0, 1)
    self.track = ui.Rectangle.new(self.rail)
    self.track:SetPos(6, 24)
    self.track:SetSize(10, -48, 0, 1)
    self.track.fill = true
    self.track.rgba = 0x23303FFF
    self.thumb = ui.Rectangle.new(self.rail)
    self.thumb.fill = true
    self.thumb.rgba = 0x8194A8FF

    local function arrow(label, bottom, direction)
        local button = ui.Button.new(self.rail)
        button:SetSize(22, 22)
        button:SetPos(0, bottom and -22 or 0, 0, bottom and 1 or 0)
        button.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
        button.label = label
        button:Subscribe(ui.Hook.ONBUTTONPRESSED, function() self:scroll(direction * 48) end)
        self:watch(button)
    end
    arrow("^", false, -1)
    arrow("v", true, 1)
    self:watch(self.viewport)
    self:watch(self.content)
    self:watch(self.rail)
    self:watch(self.track)
    self:watch(self.thumb)
    self.viewport:Subscribe(ui.Hook.ONRESIZE, function() self:layout() end)
    return self
end

function ScrollPanel:watch(component)
    component:Subscribe(ui.Hook.ONSCROLLWHEEL, self.wheelHandler)
    return component
end

function ScrollPanel:layout()
    local height = math.max(0, self.viewport.height)
    local maximum = math.max(0, self.contentHeight - height)
    self.offset = math.max(0, math.min(maximum, self.offset))
    if self.lastHeight == height and self.lastContentHeight == self.contentHeight
        and self.lastOffset == self.offset then return end
    self.lastHeight, self.lastContentHeight, self.lastOffset = height, self.contentHeight, self.offset
    self.content:SetPos(0, -self.offset)
    self.rail.hidden = maximum == 0
    self.viewport:SetSize(maximum > 0 and -24 or 0, 0, 1, 1)
    local trackHeight = math.max(0, height - 48)
    local thumbHeight = math.min(trackHeight, math.max(16,
        math.floor(trackHeight * height / self.contentHeight)))
    local thumbY = maximum > 0 and math.floor((trackHeight - thumbHeight) * self.offset / maximum) or 0
    self.thumb:SetPos(6, 24 + thumbY)
    self.thumb:SetSize(10, thumbHeight)
end

function ScrollPanel:scroll(delta)
    self.offset = self.offset + delta
    self:layout()
end

function ScrollPanel:setContentHeight(height)
    height = math.max(1, height)
    if self.contentHeight ~= height then
        self.contentHeight = height
        self.content:SetSize(0, self.contentHeight, 1, 0)
    end
    self:layout()
end

return ScrollPanel
