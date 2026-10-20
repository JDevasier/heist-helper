-- Names/rewards consume cached highlight anchors. No entity queries, terrain
-- reads or timer hooks. Project on every rendered frame while labels exist.
local Labels = {}
Labels.__index = Labels
local WIDTH, HEIGHT, LIMIT = 230, 22, 64
local DRAW_KEY = "heist-helper-source-labels"
local UI_KEY = "heist-helper-label-occlusion"
local MAX_UI_NODES, MAX_UI_DEPTH = 4096, 24

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function textWidth(content)
    local ok, width = pcall(function()
        local font = config.Font.FromID(id.Font.MUSEO_SANS_15PT_REGULAR)
        return font:GetStringWidthMultiline(content, WIDTH, false)
    end)
    -- Keep a two-unit margin on either side for the font's shadow. Measurement
    -- runs only when text changes; drawing consumes this cached width.
    return ok and finite(width) and width > 0 and math.min(WIDTH, math.ceil(width) + 4) or WIDTH
end

local function hidden(item, value)
    if item.hidden ~= value then item.text.hidden, item.hidden = value, value end
end

local function rect(component)
    local origin, width, height = component.xyGlobal, component.width, component.height
    if origin == nil or not finite(origin.x) or not finite(origin.y)
        or not finite(width) or not finite(height) or width <= 0 or height <= 0 then return nil end
    return { left = origin.x, top = origin.y, right = origin.x + width, bottom = origin.y + height }
end

local function overlaps(a, b)
    return a.left < b.right and a.right > b.left and a.top < b.bottom and a.bottom > b.top
end

local function intersect(a, b)
    if a == nil or b == nil then return nil end
    local result = { left = math.max(a.left, b.left), top = math.max(a.top, b.top),
        right = math.min(a.right, b.right), bottom = math.min(a.bottom, b.bottom) }
    return result.right > result.left and result.bottom > result.top and result or nil
end

local function visible(component)
    return component.visibleGlobal == true and component.hidden ~= true and component.alpha ~= 0
end

function Labels:queueUI()
    if self.root == nil or self.uiPending then return end
    self.uiPending = true
    Event.Logic.Subscribe(UI_KEY, function()
        Event.Logic.Unsubscribe(UI_KEY)
        self.uiPending = false
        if self.root ~= nil then self:discoverUI() end
    end)
end

function Labels:clearUI()
    Event.Logic.Unsubscribe(UI_KEY)
    for component, hooks in pairs(self.uiWatches or {}) do
        for _, hook in ipairs(hooks) do pcall(function() component:Unsubscribe(hook, UI_KEY) end) end
    end
    self.uiWatches, self.uiPanels, self.uiPending = {}, {}, false
end

-- Discover geometry only. Never read interface text, inventories or chat.
-- Walk after creation/UI events, not from Draw. Transparent full-window
-- containers are traversed; smaller painted containers become panel bounds.
function Labels:discoverUI()
    self:clearUI()
    local ok, reason = pcall(function()
        local path, top, node = {}, self.parent, self.parent
        for _ = 1, MAX_UI_DEPTH do
            if node == nil or path[node] then break end
            path[node], top, node = true, node, node.parent
        end
        local viewport = rect(top)
        local worldBounds = rect(self.parent)
        local types, containers, paints = ui.ComponentType, {}, {}
        for _, name in ipairs({ "LAYER", "PANEL", "GRID", "PAGED_LAYER", "PAGED_CAROUSEL",
            "GROUP_BOX", "CUTSCENE_LAYER" }) do
            if types[name] ~= nil then containers[types[name]] = true end
        end
        for _, name in ipairs({ "RECTANGLE", "SPRITE", "LABEL", "CANVAS", "LINE", "BUTTON",
            "CHECK", "INPUTFIELD", "SLIDER", "COMBO", "LIST", "RADIO_GROUP", "RADIAL_PROGRESS_OVERLAY" }) do
            if types[name] ~= nil then paints[types[name]] = true end
        end
        local seen, visited, watches = {}, 0, {}
        local function watch(component)
            watches[component] = true
            local hooks = {}
            self.uiWatches[component] = hooks
            for _, hook in ipairs({ ui.Hook.ONSUBCHANGE, ui.Hook.ONRESIZE }) do
                component:Subscribe(hook, UI_KEY, function() self:queueUI() end)
                hooks[#hooks + 1] = hook
            end
        end
        local function visit(component, depth, ancestors)
            if component == self.root or component.parent == self.root or seen[component]
                or depth > MAX_UI_DEPTH or visited >= MAX_UI_NODES then
                return {}, {}
            end
            seen[component], visited = true, visited + 1
            local kind = component.type
            local panels, witnesses = {}, {}
            if paints[kind] and not path[component] then
                panels[1] = { component = component, clips = ancestors }
                witnesses[1] = component
            elseif containers[kind] or path[component] then
                local nextAncestors = {}
                for index, ancestor in ipairs(ancestors) do nextAncestors[index] = ancestor end
                nextAncestors[#nextAncestors + 1] = component
                -- Static top-level hosts notify when sub-interfaces load. Watch
                -- these plus the resulting panels, rather than every UI leaf.
                if path[component] or component.interfaceID == self.parent.interfaceID then watch(component) end
                local function child(childComponent)
                    local childPanels, childWitnesses = visit(childComponent, depth + 1, nextAncestors)
                    for _, panel in ipairs(childPanels) do panels[#panels + 1] = panel end
                    for _, witness in ipairs(childWitnesses) do witnesses[#witnesses + 1] = witness end
                    return visited >= MAX_UI_NODES
                end
                component:IterateStaticComponents(child)
                component:IterateDynamicComponents(child)
                local bounds = rect(component)
                local function covers(area)
                    return bounds ~= nil and area ~= nil
                        and bounds.right - bounds.left >= (area.right - area.left) * 0.95
                        and bounds.bottom - bounds.top >= (area.bottom - area.top) * 0.95
                end
                local fullWindow = covers(viewport) or covers(worldBounds)
                if not path[component] and not fullWindow and #witnesses > 0 then
                    -- Only merge a pane when a painted child covers its bounds.
                    -- Empty/transparent layout wrappers are not occluders.
                    local backgrounds = {}
                    for _, witness in ipairs(witnesses) do
                        local painted = intersect(bounds, rect(witness))
                        if painted ~= nil and (painted.right - painted.left) * (painted.bottom - painted.top)
                            >= (bounds.right - bounds.left) * (bounds.bottom - bounds.top) * 0.8 then
                            backgrounds[#backgrounds + 1] = witness
                        end
                    end
                    if #backgrounds > 0 then
                        panels = { { component = component, witnesses = backgrounds, clips = ancestors } }
                    end
                end
            end
            return panels, witnesses
        end
        self.uiPanels = visit(top, 0, {})
        for _, panel in ipairs(self.uiPanels) do
            if panel.witnesses ~= nil and not watches[panel.component] then watch(panel.component) end
        end
    end)
    -- Unsupported/native-unavailable UI must not break highlights or tracking.
    self.uiAvailable = ok
    if not ok then
        self:clearUI()
        if not self.uiWarned then
            self.output("Heist Helper: label UI bounds unavailable: " .. tostring(reason))
            self.uiWarned = true
        end
    end
end

-- Read only cached component references while drawing. This is UI geometry,
-- like camera projection: no hierarchy traversal, source scans or counter reads.
function Labels:uiRects()
    if not self.uiAvailable then return nil end
    local rectangles, cachedBounds = {}, {}
    local function bounds(component)
        if cachedBounds[component] == nil then
            local ok, value = pcall(function() return visible(component) and rect(component) or nil end)
            cachedBounds[component] = ok and value or false
            if not ok then self:queueUI() end
        end
        return cachedBounds[component] or nil
    end
    for _, panel in ipairs(self.uiPanels or {}) do
        local rectangle = bounds(panel.component)
        if rectangle ~= nil and panel.witnesses ~= nil then
            local painted = false
            for _, witness in ipairs(panel.witnesses) do
                if bounds(witness) ~= nil then painted = true break end
            end
            if not painted then rectangle = nil end
        end
        for _, ancestor in ipairs(panel.clips) do
            if rectangle == nil then break end
            rectangle = intersect(rectangle, bounds(ancestor))
        end
        if rectangle ~= nil then rectangles[#rectangles + 1] = rectangle end
    end
    return rectangles
end

function Labels.new(output)
    return setmetatable({ enabled = false, items = {}, count = 0, output = output }, Labels)
end

function Labels:clear()
    self.failed = false
    self:clearUI()
    if self.attached then Event.Draw.Unsubscribe(DRAW_KEY) end
    if self.root ~= nil then pcall(function() self.root:Destroy() end) end
    self.root, self.parent, self.attached = nil, nil, false
    self.items, self.count, self.dirty = {}, 0, false
end

function Labels:setEnabled(enabled)
    self.enabled = enabled == true
    if not self.enabled then self:clear() end
end

local function alive(root)
    local ok, parent = pcall(function() return root.parent end)
    return ok and parent ~= nil
end

function Labels:sync(entries)
    if not self.enabled then return end
    self.failed = false
    local any = false
    for _, entry in pairs(entries) do
        if entry.visible and entry.labelText ~= nil and entry.labelPosition ~= nil then any = true break end
    end
    if not any then if self.root ~= nil then self:clear() end return end
    if self.root ~= nil and not alive(self.root) then self:clear() end
    local ok = pcall(function()
        if self.root == nil then
            -- Keep labels in the game area; UI overlap is handled explicitly.
            local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
            if parent == nil then self.failed = true return end
            self.parent, self.root = parent, ui.Layer.new(parent)
            self.root:SetPos(0, 0)
            self.root:SetSize(0, 0, 1, 1)
            self.root.clickthrough = true
            self.root:MoveToBack()
            self:discoverUI()
        end
        local seen, count = {}, 0
        for key, entry in pairs(entries) do
            local position = entry.labelPosition
            if count < LIMIT and entry.visible and entry.labelText ~= nil and position ~= nil
                and finite(position.x) and finite(position.y) and finite(position.z) then
                local item = self.items[key]
                if item == nil then
                    local text = ui.Text.new(self.root)
                    text:SetSize(WIDTH, HEIGHT)
                    text.font, text.maxLines, text.clickthrough = id.Font.MUSEO_SANS_15PT_REGULAR, 1, true
                    text.alignHorizontal, text.alignVertical = ui.AlignMode.CENTRE, ui.AlignMode.CENTRE
                    text.isShadowed, text.hidden = true, true
                    item = { text = text, hidden = true }
                    self.items[key] = item
                    self.dirty = true
                end
                if item.content ~= entry.labelText then
                    item.text.content, item.content = entry.labelText, entry.labelText
                    item.inkWidth = textWidth(entry.labelText)
                    local lines = entry.labelText:find("<br>", 1, true) and 2 or 1
                    item.height = HEIGHT * lines
                    item.text:SetSize(WIDTH, item.height)
                    item.text.maxLines = lines
                    self.dirty = true
                end
                if item.colour ~= entry.drawColour then
                    item.text.rgba, item.colour = entry.drawColour, entry.drawColour
                end
                if item.position == nil or item.position.x ~= position.x or item.position.y ~= position.y
                    or item.position.z ~= position.z then self.dirty = true end
                item.position = position
                seen[key], count = true, count + 1
            end
        end
        for key, item in pairs(self.items) do
            if not seen[key] then item.text:Destroy() self.items[key] = nil end
        end
        self.count = count
        if count == 0 then self:clear() return end
        if not self.attached then
            Event.Draw.Subscribe(DRAW_KEY, function() self:project() end)
            self.attached = true
        end
        if self.dirty then self:project() end
    end)
    if not ok then
        self:clear()
        self.failed = true
        if not self.warned then self.output("Heist Helper: source labels unavailable; retrying while active.") self.warned = true end
    end
end

function Labels:project()
    if self.root == nil or self.count == 0 then return end
    if not alive(self.root) then self:clear() return end
    if not self.uiAvailable then
        for _, item in pairs(self.items) do hidden(item, true) end
        return
    end
    local ok = pcall(function()
        if not Camera.IsAvailable() then
            for _, item in pairs(self.items) do hidden(item, true) end
            return
        end
        local position, focus = Camera.GetPosition(), Camera.GetFocusPosition()
        local origin, width, height = self.parent.xyGlobal, self.parent.width, self.parent.height
        local setting = game ~= nil and game.options ~= nil and game.options.InterfaceScale or nil
        local scale = setting ~= nil and tonumber(setting.setting) or 100
        scale = finite(scale) and scale > 0 and scale / 100 or 1
        -- Native projection includes render interpolation and view changes that
        -- need not change the logic camera position/focus (for example FOV).
        self.dirty = false
        local dx, dy, dz = focus.x - position.x, focus.y - position.y, focus.z - position.z
        local blockers = self:uiRects()
        for _, item in pairs(self.items) do
            local anchor = item.position
            local front = (anchor.x - position.x) * dx + (anchor.y - position.y) * dy + (anchor.z - position.z) * dz
            local point = front > 0 and ScreenConvert.Vector3ToScreen(anchor) or nil
            local x, y = point ~= nil and point.x / scale - origin.x or nil,
                point ~= nil and point.y / scale - origin.y or nil
            local visible = blockers ~= nil and finite(x) and finite(y)
                and x >= 0 and y >= 0 and x <= width and y <= height
            if visible then
                x = math.floor(math.max(0, math.min(math.max(0, width - WIDTH), x - WIDTH / 2)))
                y = math.floor(math.max(0, y - item.height))
                if item.x ~= x or item.y ~= y then item.text:SetPos(x, y) item.x, item.y = x, y end
                local inkWidth = item.inkWidth or WIDTH
                local inkLeft = x + origin.x + (WIDTH - inkWidth) / 2
                local labelBounds = { left = inkLeft, top = y + origin.y,
                    right = inkLeft + inkWidth, bottom = y + origin.y + item.height }
                for _, blocker in ipairs(blockers) do
                    if overlaps(labelBounds, blocker) then visible = false break end
                end
            end
            hidden(item, not visible)
        end
    end)
    if not ok then
        -- Projection/UI failure must not interrupt loot tracking or highlights.
        for _, item in pairs(self.items) do pcall(function() hidden(item, true) end) end
    end
end

return Labels
