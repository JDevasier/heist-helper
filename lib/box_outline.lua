-- Select only the perimeter edges of the projected bounds. Retained native
-- shapes still handle world movement, depth testing, thickness and colours.
local Outline = {}
Outline.__index = Outline
local DRAW_KEY = "heist-helper-box-outline"

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- Andrew's monotone chain. Keep original (zero-based) mesh indices; duplicate
-- projected corners and collinear edges must not produce internal diagonals.
function Outline.hull(points)
    local sorted = {}
    for _, point in ipairs(points) do sorted[#sorted + 1] = point end
    table.sort(sorted, function(a, b)
        if a.x ~= b.x then return a.x < b.x end
        if a.y ~= b.y then return a.y < b.y end
        return a.index < b.index
    end)
    local unique = {}
    for _, point in ipairs(sorted) do
        local last = unique[#unique]
        if last == nil or last.x ~= point.x or last.y ~= point.y then unique[#unique + 1] = point end
    end
    if #unique < 3 then return {} end
    local function cross(a, b, c) return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) end
    local chain = {}
    for _, point in ipairs(unique) do
        while #chain >= 2 and cross(chain[#chain - 1], chain[#chain], point) <= 0 do table.remove(chain) end
        chain[#chain + 1] = point
    end
    local lower = #chain
    for index = #unique - 1, 1, -1 do
        local point = unique[index]
        while #chain > lower and cross(chain[#chain - 1], chain[#chain], point) <= 0 do table.remove(chain) end
        chain[#chain + 1] = point
    end
    table.remove(chain)
    if #chain < 3 then return {} end
    local lines = {}
    for index, point in ipairs(chain) do
        lines[#lines + 1], lines[#lines + 2] = point.index, chain[index % #chain + 1].index
    end
    return lines
end

function Outline.show(entry, visible)
    if entry.shape ~= nil and entry.shape.isValid and entry.drawVisible ~= visible then
        entry.shape.visible, entry.drawVisible = visible, visible
    end
end

function Outline.new(output)
    return setmetatable({ enabled = false, entries = {}, meshes = {}, elapsed = 0, output = output }, Outline)
end

function Outline:clear()
    if self.attached then Event.Draw.Unsubscribe(DRAW_KEY) end
    self.entries, self.meshes, self.camera = {}, {}, nil
    self.attached, self.dirty, self.elapsed = false, false, 0
end

function Outline:sync(entries)
    if not self.enabled then self:clear() return end
    local active, meshes, count = {}, {}, 0
    for key, entry in pairs(entries) do
        if count < 64 and entry.visible and entry.is2d and entry.worldCorners ~= nil
            and entry.shape ~= nil and entry.shape.isValid then
            active[key], meshes[key], count = entry, entry.mesh3d, count + 1
            if self.entries[key] ~= entry or self.meshes[key] ~= entry.mesh3d then self.dirty = true end
        end
    end
    if count == 0 then self:clear() return end
    self.entries, self.meshes = active, meshes
    if not self.attached then
        Event.Draw.Subscribe(DRAW_KEY, function(event)
            local delta = event.timeDeltaSecs
            if not finite(delta) or delta < 0 then delta = 1 / 60 end
            self.elapsed = self.elapsed + delta
            if self.elapsed < 0.05 then return end
            self.elapsed = 0
            self:project()
        end)
        self.attached = true
    end
    if self.dirty then self:project() end
end

local function same(a, b)
    if a == nil or #a ~= #b then return false end
    for index, value in ipairs(b) do if a[index] ~= value then return false end end
    return true
end

function Outline:project()
    local ok = pcall(function()
        if not Camera.IsAvailable() then
            for _, entry in pairs(self.entries) do entry.outlineReady = false Outline.show(entry, false) end
            self.camera = nil
            return
        end
        local position, focus = Camera.GetPosition(), Camera.GetFocusPosition()
        local camera = { position.x, position.y, position.z, focus.x, focus.y, focus.z }
        if not self.dirty and same(self.camera, camera) then return end
        self.camera, self.dirty = camera, false
        local dx, dy, dz = focus.x - position.x, focus.y - position.y, focus.z - position.z
        for _, entry in pairs(self.entries) do
            if entry.shape ~= nil and entry.shape.isValid and entry.visible then
                local points = {}
                for index, corner in ipairs(entry.worldCorners) do
                    local front = (corner.x - position.x) * dx + (corner.y - position.y) * dy + (corner.z - position.z) * dz
                    -- Bounds crossing the camera plane are hidden, rather than
                    -- joining invalid projections into a screen-spanning line.
                    if front <= 0 then break end
                    local point = ScreenConvert.Vector3ToScreen(corner)
                    if point == nil or not finite(point.x) or not finite(point.y) then self.camera = nil break end
                    points[#points + 1] = { x = point.x, y = point.y, index = index - 1 }
                end
                local lines = #points == 8 and Outline.hull(points) or {}
                local ready = #lines >= 6
                if ready and not same(entry.outlineLines, lines) then
                    local mesh = ShapeData.new()
                    mesh.positions, mesh.rgba = entry.mesh3d.positions, entry.mesh3d.rgba
                    mesh.lines, mesh.tris = lines, {}
                    ready = entry.shape:SetShapeData(mesh)
                    if ready then entry.outlineLines = lines else self.camera = nil end
                end
                entry.outlineReady = ready
                Outline.show(entry, ready)
            end
        end
    end)
    if not ok then
        self.camera = nil
        for _, entry in pairs(self.entries) do
            entry.outlineReady = false
            pcall(function() Outline.show(entry, false) end)
        end
        if not self.warned then self.output("Heist Helper: 2D outline unavailable; retrying while active.") self.warned = true end
    end
end

return Outline
