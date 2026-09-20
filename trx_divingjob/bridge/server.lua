--[[
    Server bridge
    - Bridge.GetPlayer(src)
    - Bridge.AddItem(src, name, amount, metadata)
    - Bridge.RemoveMoney(src, account, amount, reason)
    - Bridge.AddMoney(src, account, amount, reason)
    - Bridge.HasItem(src, name, amount)
    - Bridge.GetMoney(src, account)
    - Bridge.GetIdentifier(src)
    - Bridge.GetPlayerName(src)
    - Bridge.GetMeta(src, key, default)
    - Bridge.SetMeta(src, key, value)
]]

if not Bridge then Bridge = {} end

local QBCore
local ESX

if Bridge.Framework == 'qb' or Bridge.Framework == 'qbx' then
    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok and core then
        QBCore = core
    else
        local ok2, core2 = pcall(function()
            return exports['qbx_core']:GetCoreObject()
        end)
        if ok2 and core2 then
            QBCore = core2
        end
    end
elseif Bridge.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
end

function Bridge.GetPlayer(source)
    if QBCore then
        return QBCore.Functions.GetPlayer(source)
    end
    if ESX then
        return ESX.GetPlayerFromId(source)
    end
    if Bridge.Framework == 'qbx' then
        local ok, player = pcall(function()
            return exports['qbx_core']:GetPlayer(source)
        end)
        if ok then return player end
    end
    return nil
end

function Bridge.GetIdentifier(source)
    if QBCore then
        local Player = Bridge.GetPlayer(source)
        return Player and Player.PlayerData and Player.PlayerData.citizenid or tostring(source)
    end
    if ESX then
        local xPlayer = Bridge.GetPlayer(source)
        return xPlayer and xPlayer.identifier or tostring(source)
    end
    return tostring(source)
end

function Bridge.GetPlayerName(source)
    if QBCore then
        local Player = Bridge.GetPlayer(source)
        return Player and Player.PlayerData and Player.PlayerData.name or ('Player '..source)
    end
    if ESX then
        local xPlayer = Bridge.GetPlayer(source)
        if xPlayer and xPlayer.getName then return xPlayer.getName() end
        return ('Player '..source)
    end
    return ('Player '..source)
end

function Bridge.AddItem(source, name, amount, metadata)
    if Bridge.Inventory == 'ox' then
        return exports.ox_inventory:AddItem(source, name, amount or 1, metadata)
    elseif Bridge.Inventory == 'qs' then
        return exports['qs-inventory']:AddItem(source, name, amount or 1, false, metadata)
    elseif Bridge.Inventory == 'qb' then
        if QBCore then
            local Player = Bridge.GetPlayer(source)
            if not Player then return false end
            return Player.Functions.AddItem(name, amount or 1, false, metadata)
        end
        return false
    end
end

function Bridge.HasItem(source, name, amount)
    amount = amount or 1
    if Bridge.Inventory == 'ox' then
        return (exports.ox_inventory:Search(source, 'count', name) or 0) >= amount
    elseif Bridge.Inventory == 'qs' then
        local Player = Bridge.GetPlayer(source)
        if not Player then return false end
        local item = exports['qs-inventory']:GetItemByName(source, name)
        return (item and item.amount or 0) >= amount
    elseif Bridge.Inventory == 'qb' then
        local Player = Bridge.GetPlayer(source)
        if not Player then return false end
        local item = Player.Functions.GetItemByName(name)
        return (item and item.amount or 0) >= amount
    end
    return false
end

function Bridge.RemoveItem(source, name, amount, metadata)
    amount = amount or 1
    if Bridge.Inventory == 'ox' then
        return exports.ox_inventory:RemoveItem(source, name, amount, metadata)
    elseif Bridge.Inventory == 'qs' then
        return exports['qs-inventory']:RemoveItem(source, name, amount)
    elseif Bridge.Inventory == 'qb' then
        local Player = Bridge.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.RemoveItem(name, amount)
    end
    return false
end

function Bridge.RemoveMoney(source, account, amount, reason)
    account = account or 'cash'
    reason = reason or 'MrJ-diving'
    if QBCore then
        local Player = Bridge.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.RemoveMoney(account, amount, reason)
    end
    if ESX then
        if account == 'bank' then
            return ESX.GetPlayerFromId(source).removeAccountMoney('bank', amount)
        else
            return ESX.GetPlayerFromId(source).removeMoney(amount)
        end
    end
    return false
end

function Bridge.AddMoney(source, account, amount, reason)
    account = account or 'cash'
    reason = reason or 'MrJ-diving'
    if QBCore then
        local Player = Bridge.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.AddMoney(account, amount, reason)
    end
    if ESX then
        if account == 'bank' then
            return ESX.GetPlayerFromId(source).addAccountMoney('bank', amount)
        else
            return ESX.GetPlayerFromId(source).addMoney(amount)
        end
    end
    return false
end

function Bridge.GetMoney(source, account)
    account = account or 'cash'
    if QBCore then
        local Player = Bridge.GetPlayer(source)
        if not Player then return 0 end
        if Player.Functions.GetMoney then
            return Player.Functions.GetMoney(account) or 0
        end
        return (Player.PlayerData and Player.PlayerData.money and Player.PlayerData.money[account]) or 0
    end
    if ESX then
        local xPlayer = Bridge.GetPlayer(source)
        if not xPlayer then return 0 end
        if account == 'bank' and xPlayer.getAccount then
            local acc = xPlayer.getAccount('bank')
            return acc and acc.money or 0
        end
        if xPlayer.getMoney then return xPlayer.getMoney() end
        return 0
    end
    return 0
end

function Bridge.GetMeta(source, key, default)
    if QBCore then
        local Player = Bridge.GetPlayer(source)
        if not Player then return default end
        local md = Player.PlayerData and Player.PlayerData.metadata or {}
        local val = md[key]
        if val == nil then return default end
        return val
    end
    if ESX then
        local xPlayer = Bridge.GetPlayer(source)
        if xPlayer and xPlayer.getMeta then
            local val = xPlayer.getMeta(key)
            if val ~= nil then return val end
        end
        return default
    end
    return default
end

function Bridge.SetMeta(source, key, value)
    if QBCore then
        local Player = Bridge.GetPlayer(source)
        if not Player then return end
        if Player.Functions and Player.Functions.SetMetaData then
            Player.Functions.SetMetaData(key, value)
        elseif Player.Functions and Player.Functions.SetMetadata then
            Player.Functions.SetMetadata(key, value)
        end
        return
    end
    if ESX then
        local xPlayer = Bridge.GetPlayer(source)
        if xPlayer and xPlayer.setMeta then
            xPlayer.setMeta(key, value)
        end
        return
    end
end
