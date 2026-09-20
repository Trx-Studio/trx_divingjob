local QBCore = nil
local ESX = nil

if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
end

if GetResourceState('qbx_core') == 'started' then
    exports.qbx_core:CreateUseableItem('diving_gear', function(source)
        TriggerClientEvent('MrJ-divegear:client:useGear', source)
    end)
elseif GetResourceState('qb-core') == 'started' and QBCore then
    if QBCore.Functions and QBCore.Functions.CreateUseableItem then
        QBCore.Functions.CreateUseableItem('diving_gear', function(source)
            TriggerClientEvent('MrJ-divegear:client:useGear', source)
        end)
    end
elseif GetResourceState('es_extended') == 'started' and ESX then
    if ESX.RegisterUsableItem then
        ESX.RegisterUsableItem('diving_gear', function(source)
            TriggerClientEvent('MrJ-divegear:client:useGear', source)
        end)
    end
elseif GetResourceState('ox_inventory') == 'started' then
end
