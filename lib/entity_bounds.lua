-- Snapshot documented bounds into plain numbers; never retain native vectors.
local Bounds = {}

function Bounds.read(aabb)
    if aabb == nil then return nil end
    local minimum, maximum = aabb.minimum, aabb.maximum
    if minimum == nil or maximum == nil then return nil end
    local values = { minimum.x, minimum.y, minimum.z, maximum.x, maximum.y, maximum.z }
    for index = 1, 6 do
        local value = values[index]
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return nil end
    end
    for axis = 1, 3 do if values[axis + 3] <= values[axis] then return nil end end
    return values
end

function Bounds.npc(entity)
    local ok, values = pcall(function() return Bounds.read(entity.aabb) end)
    if ok then return values end
    return nil
end

function Bounds.scenery(entity)
    -- Config click bounds are local to the model's origin. Quarter-turn them
    -- with the loc, then translate using its actual world position, not its tile.
    local ok, values = pcall(function()
        local localBounds = entity.config ~= nil and Bounds.read(entity.config.customBounding) or nil
        if localBounds == nil then return nil end
        local origin, rotation = entity.position, entity.rotationType
        if origin == nil or (rotation ~= 0 and rotation ~= 1 and rotation ~= 2 and rotation ~= 3) then return nil end
        for _, axis in ipairs({ "x", "y", "z" }) do
            local value = origin[axis]
            if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return nil end
        end
        local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
        for _, x in ipairs({ localBounds[1], localBounds[4] }) do
            for _, z in ipairs({ localBounds[3], localBounds[6] }) do
                local rotatedX, rotatedZ = x, z
                if rotation == 1 then rotatedX, rotatedZ = z, -x
                elseif rotation == 2 then rotatedX, rotatedZ = -x, -z
                elseif rotation == 3 then rotatedX, rotatedZ = -z, x end
                minX, maxX = math.min(minX, rotatedX), math.max(maxX, rotatedX)
                minZ, maxZ = math.min(minZ, rotatedZ), math.max(maxZ, rotatedZ)
            end
        end
        return { origin.x + minX, origin.y + localBounds[2], origin.z + minZ,
            origin.x + maxX, origin.y + localBounds[5], origin.z + maxZ }
    end)
    if ok then return values end
    return nil
end

function Bounds.same(first, second)
    if first == nil or second == nil then return first == second end
    for index = 1, 6 do if first[index] ~= second[index] then return false end end
    return true
end

return Bounds
