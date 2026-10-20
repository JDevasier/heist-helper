local Context = {}

function Context.bagPresent()
    if Inventory == nil or config == nil or config.Inv == nil then return false end
    local inventory = Inventory.Find(config.Inv.INV)
    if inventory == nil then return false end
    local ok, valid = pcall(function() return inventory.isValid end)
    if not ok or valid == nil then ok, valid = pcall(function() return inventory.valid end) end
    return ok and valid == true and inventory:GetTotal(59952) > 0
end

return Context
