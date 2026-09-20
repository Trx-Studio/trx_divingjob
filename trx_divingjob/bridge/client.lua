--[[
    Client bridge
    - Bridge.HasItem(name, amount)
    - Bridge.Notify(message, type)
]]

if not Bridge then Bridge = {} end

local function notifyLib(title, description, type)
    if lib and lib.notify then
        lib.notify({ title = title or 'Diving', description = description or '', type = type or 'inform' })
        return true
    end
    return false
end

function Bridge.Notify(message, type)
    if not notifyLib('Diving', message, type) then
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message or '')
        DrawNotification(false, false)
    end
end

function Bridge.HasItem(name, amount)
    amount = amount or 1
    if Bridge.Inventory == 'ox' then
        return (exports.ox_inventory:Search('count', name) or 0) >= amount
    elseif Bridge.Inventory == 'qs' then
        local items = exports['qs-inventory']:GetItems()
        if not items then return false end
        local count = 0
        for _, item in pairs(items) do
            if item and item.name == name then
                count = count + (item.amount or 0)
            end
        end
        return count >= amount
    elseif Bridge.Inventory == 'qb' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayerData()
        if not Player then return false end
        local item = exports['qb-inventory'] and exports['qb-inventory']:HasItem(name, amount) 
        if type(item) == 'boolean' then return item end
        return false
    end
    return false
end

function Bridge.GetMeta(key, default)
    if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
        local QBCore = exports['qb-core']:GetCoreObject()
        if not QBCore then
            QBCore = exports['qbx_core']:GetCoreObject()
        end
        if QBCore then
            local Player = QBCore.Functions.GetPlayerData()
            if Player and Player.metadata then
                local val = Player.metadata[key]
                if val ~= nil then return val end
            end
        end
    elseif Bridge.Framework == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        if ESX then
            local Player = ESX.GetPlayerData()
            if Player and Player.metadata then
                local val = Player.metadata[key]
                if val ~= nil then return val end
            end
        end
    end
    return default
end

function Bridge.GetPlayerStats()
    local divingXP = Bridge.GetMeta('divingXP', 0)
    local divingLevel = Bridge.GetMeta('divingLevel', 1)
    if divingXP == nil then divingXP = 0 end
    if divingLevel == nil then divingLevel = 1 end
    return { divingXP = divingXP, divingLevel = divingLevel }
end


local function mapTargetOption(opt)
    local ox = {
        name = opt.name or ('bridge_opt_'..tostring(math.random(100000,999999)) ),
        icon = opt.icon or 'fas fa-hand',
        label = opt.label or 'Interact',
        onSelect = function()
            if type(opt.onSelect) == 'function' then opt.onSelect() end
        end
    }
    local qb = {
        icon = opt.icon or 'fas fa-hand',
        label = opt.label or 'Interact',
        action = function()
            if type(opt.onSelect) == 'function' then opt.onSelect() end
        end
    }
    return ox, qb
end

Bridge.Target = Bridge.Target or {}

function Bridge.Target.AddEntity(entity, option)
    if not entity or entity == 0 then return end
    local oxOpt, qbOpt = mapTargetOption(option)
    local distance = option.distance or (Config.TargetDistance or 2.5)
    oxOpt.distance = distance
    if Bridge.TargetSystem == 'ox' and GetResourceState('ox_target') == 'started' then
        exports.ox_target:addLocalEntity(entity, { oxOpt })
        return
    end
    if Bridge.TargetSystem == 'qb' and GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(entity, { options = { qbOpt }, distance = distance })
        return
    end
end

function Bridge.Target.RemoveEntity(entity, name)
    if not entity or entity == 0 then return end
    if Bridge.TargetSystem == 'ox' and GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeLocalEntity(entity, name)
        return
    end
    if Bridge.TargetSystem == 'qb' and GetResourceState('qb-target') == 'started' then
        local ok = pcall(function()
            exports['qb-target']:RemoveTargetEntity(entity, name)
        end)
        if not ok then
            pcall(function() exports['qb-target']:RemoveTargetEntity(entity) end)
        end
        return
    end
end

function Bridge.Target.AddPed(ped, option)
    if Bridge.TargetSystem == 'drawtext' then
        if GetResourceState('ox_target') == 'started' then
            Bridge.TargetSystem = 'ox'
        elseif GetResourceState('qb-target') == 'started' then
            Bridge.TargetSystem = 'qb'
        end
    end
    Bridge.Target.AddEntity(ped, option)
end

function Bridge.Target.RemovePed(ped, name)
    Bridge.Target.RemoveEntity(ped, name)
end

