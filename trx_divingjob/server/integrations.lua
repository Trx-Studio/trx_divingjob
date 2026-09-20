--[[
    trx_divingjob - fuel, keys, inventory and money (server side)
]]

local config = require 'config.server'

local Integrations = {}

local function started(name)
    return GetResourceState(name) == 'started'
end

-- ---------------------------------------------------------------------------
-- Fuel
-- ---------------------------------------------------------------------------

local FUEL_EXPORTS = { 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lc_fuel' }

---Which fuel system is live. Resolved per call so a late-started ox_fuel is still seen.
---@return string
function Integrations.fuelSystem()
    local wanted = config.fuel.system
    if wanted ~= 'auto' then return wanted end
    if started('ox_fuel') then return 'ox_fuel' end
    for i = 1, #FUEL_EXPORTS do
        if started(FUEL_EXPORTS[i]) then return FUEL_EXPORTS[i] end
    end
    return 'native'
end

---Fills a freshly spawned boat. ox_fuel keeps the level in the replicated
---`fuel` statebag and reads it from there when someone takes the helm, so
---setting it here is the whole integration. Export-based systems are
---client-side, so the client is told which one to use.
---@return string system
function Integrations.fillTank(veh)
    local system = Integrations.fuelSystem()
    if system == 'ox_fuel' then
        Entity(veh).state:set('fuel', config.fuel.start + 0.0, true)
    end
    return system
end

---The fuel level the server can see. Only ox_fuel keeps it where the server can read it.
---@return number? level
function Integrations.readFuel(veh)
    if Integrations.fuelSystem() ~= 'ox_fuel' then return nil end
    local level = Entity(veh).state.fuel
    return level and (level + 0.0) or nil
end

-- ---------------------------------------------------------------------------
-- Keys
-- ---------------------------------------------------------------------------

function Integrations.keySystem()
    if config.keys ~= 'auto' then return config.keys end
    if started('Renewed-Vehiclekeys') then return 'Renewed-Vehiclekeys' end
    if started('qbx_vehiclekeys') then return 'qbx_vehiclekeys' end
    return 'event'
end

function Integrations.giveKeys(src, veh, plate)
    local system = Integrations.keySystem()
    local ok, err = pcall(function()
        if system == 'Renewed-Vehiclekeys' then
            exports['Renewed-Vehiclekeys']:addKey(src, plate)
        elseif system == 'qbx_vehiclekeys' then
            exports.qbx_vehiclekeys:GiveKeys(src, veh, true)
        elseif system ~= 'none' then
            TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate)
        end
    end)
    if not ok then lib.print.warn(('could not give keys with %s: %s'):format(system, err)) end
end

function Integrations.removeKeys(src, plate)
    if Integrations.keySystem() ~= 'Renewed-Vehiclekeys' then return end
    pcall(function() exports['Renewed-Vehiclekeys']:removeKey(src, plate) end)
end

-- ---------------------------------------------------------------------------
-- Inventory (ox_inventory)
-- ---------------------------------------------------------------------------

local itemCache = {}

---@return table? item ox_inventory's item definition, or nil when it doesn't exist
function Integrations.item(name)
    local cached = itemCache[name]
    if cached ~= nil then return cached or nil end
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    itemCache[name] = (ok and item) or false
    return itemCache[name] or nil
end

function Integrations.label(name)
    local item = Integrations.item(name)
    return item and item.label or name
end

function Integrations.count(src, name)
    return exports.ox_inventory:Search(src, 'count', name) or 0
end

---@return boolean
function Integrations.give(src, name, count, metadata)
    if not Integrations.item(name) then return false end
    local ok, added = pcall(function()
        if not exports.ox_inventory:CanCarryItem(src, name, count, metadata) then return false end
        return exports.ox_inventory:AddItem(src, name, count, metadata)
    end)
    return ok and added and true or false
end

function Integrations.take(src, name, count)
    return exports.ox_inventory:RemoveItem(src, name, count) and true or false
end

function Integrations.slot(src, slot)
    return exports.ox_inventory:GetSlot(src, slot)
end

function Integrations.setMetadata(src, slot, metadata)
    exports.ox_inventory:SetMetadata(src, slot, metadata)
end

---Every slot holding one of `names`.
---@param names table<string, any>
function Integrations.slotsOf(src, names)
    local out = {}
    local items = exports.ox_inventory:GetInventoryItems(src) or {}
    for _, it in pairs(items) do
        if it and names[it.name] then out[#out + 1] = it end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

function Integrations.resetCache()
    itemCache = {}
end

-- ---------------------------------------------------------------------------
-- Loot
-- ---------------------------------------------------------------------------

local warned = {}

---Rolls a loot table and gives the result to `src`.
---@return { name: string, label: string, count: integer }[] found, integer rare
function Integrations.rollLoot(src, tableName)
    local tbl = config.loot[tableName]
    if not tbl then return {}, 0 end

    local pool, total = {}, 0
    for i = 1, #tbl.items do
        local e = tbl.items[i]
        if Integrations.item(e.name) then
            pool[#pool + 1] = e
            total = total + e.weight
        elseif not warned[e.name] then
            warned[e.name] = true
            lib.print.warn(('loot item "%s" is not in ox_inventory - skipped'):format(e.name))
        end
    end

    local found, rare = {}, 0
    local rolls = math.random(tbl.rolls[1], tbl.rolls[2])
    for _ = 1, rolls do
        if total <= 0 or #pool == 0 then break end
        local pick, idx = math.random() * total, #pool
        for i = 1, #pool do
            pick = pick - pool[i].weight
            if pick <= 0 then idx = i break end
        end
        local e = table.remove(pool, idx)
        total = total - e.weight
        local count = math.random(e.min, math.max(e.min, e.max))
        if Integrations.give(src, e.name, count) then
            found[#found + 1] = { name = e.name, label = Integrations.label(e.name), count = count }
            if config.rare[e.name] then rare = rare + 1 end
        end
    end
    return found, rare
end

-- ---------------------------------------------------------------------------
-- Money
-- ---------------------------------------------------------------------------

---Takes `amount` from the first configured account that can cover all of it.
---@return string? account the account it came from, or nil if none could pay
function Integrations.charge(player, amount, reason)
    if amount <= 0 then return config.shopAccounts[1] end
    for i = 1, #config.shopAccounts do
        local account = config.shopAccounts[i]
        if (player.PlayerData.money[account] or 0) >= amount then
            if player.Functions.RemoveMoney(account, amount, reason) then return account end
        end
    end
end

function Integrations.pay(player, account, amount, reason)
    if amount <= 0 then return true end
    return player.Functions.AddMoney(account, amount, reason)
end

return Integrations
