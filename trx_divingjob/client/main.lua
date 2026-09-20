--[[
    trx_divingjob - client entry: shop ped, tablet (item + ped), item exports, server events
]]

local config = require 'config.client'
local shared = require 'config.shared'
local Dive   = require 'client.dive'

local shopPed = nil
local shopBlip = nil
local tablet = { open = false, prop = nil, fromShop = false }

local function notify(description, kind, duration)
    lib.notify({ title = locale('info.title'), description = description, type = kind or 'inform', duration = duration })
end

local function await(name, ...)
    return lib.callback.await('trx_divingjob:server:' .. name, false, ...)
end

local function loggedIn()
    return LocalPlayer.state.isLoggedIn == true
end

-- ---------------------------------------------------------------------------
-- tablet
-- ---------------------------------------------------------------------------

local function tabletProp(on)
    local t = config.tablet
    if on then
        if tablet.prop then return end
        local dict = lib.requestAnimDict(t.dict, 5000)
        local model = lib.requestModel(t.prop, 5000)
        if not dict or not model then return end
        local coords = GetEntityCoords(cache.ped)
        local prop = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
        SetModelAsNoLongerNeeded(model)
        AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, t.bone),
            t.offset.x, t.offset.y, t.offset.z, t.rotation.x, t.rotation.y, t.rotation.z,
            true, true, false, true, 1, true)
        TaskPlayAnim(cache.ped, t.dict, t.clip, 3.0, 3.0, -1, 49, 0, false, false, false)
        RemoveAnimDict(t.dict)
        tablet.prop = prop
    else
        if tablet.prop then
            DeleteEntity(tablet.prop)
            tablet.prop = nil
        end
        StopAnimTask(cache.ped, t.dict, t.clip, 2.0)
    end
end

local function closeTablet()
    if not tablet.open then return end
    tablet.open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    tabletProp(false)
end

local function openTablet(fromShop)
    if tablet.open then return end
    local data = await('tablet', fromShop)
    if not data then
        return notify(locale(fromShop and 'error.try_again' or 'error.no_tablet'), 'error')
    end
    Dive.setLevel(data.diver.level, data.diver.airMult)

    tablet.open = true
    tablet.fromShop = fromShop
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)
    if not cache.vehicle and not IsPedSwimming(cache.ped) then tabletProp(true) end

    CreateThread(function()
        local origin = GetEntityCoords(cache.ped)
        while tablet.open do
            if IsEntityDead(cache.ped) then
                closeTablet()
                break
            end
            if fromShop and #(GetEntityCoords(cache.ped) - origin) > config.tablet.walkAwayClose then
                closeTablet()
                break
            end
            Wait(500)
        end
    end)
end

local function refreshTablet()
    if tablet.open then SendNUIMessage({ action = 'refresh' }) end
end

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb(1)
end)

RegisterNUICallback('refresh', function(_, cb)
    local data = await('tablet', tablet.fromShop)
    if data then Dive.setLevel(data.diver.level, data.diver.airMult) end
    cb(data or false)
end)

RegisterNUICallback('scoreboard', function(body, cb)
    cb(await('scoreboard', body.period, body.sort) or false)
end)

RegisterNUICallback('buy', function(body, cb)
    cb(await('buy', body.item) or { ok = false })
end)

RegisterNUICallback('refill', function(body, cb)
    cb(await('refill', body.slot) or { ok = false })
end)

RegisterNUICallback('sell', function(body, cb)
    cb(await('sell', body.item, body.count) or { ok = false })
end)

RegisterNUICallback('accept', function(body, cb)
    local res = await('accept', body.id)
    cb(res or { ok = false })
    if res and res.ok and res.contract then
        SetNewWaypoint(res.contract.coords.x, res.contract.coords.y)
        notify(locale('info.contract_accepted', res.contract.label, res.contract.zoneLabel), 'success', 7000)
    end
end)

RegisterNUICallback('cancel', function(_, cb)
    cb(await('cancel') or { ok = false })
end)

RegisterNUICallback('claim', function(body, cb)
    cb(await('claim', body.level) or { ok = false })
end)

RegisterNUICallback('rent', function(body, cb)
    cb(await('rent', body.model, body.zone) or { ok = false })
end)

RegisterNUICallback('returnBoat', function(_, cb)
    cb(Dive.returnBoat() or { ok = false })
end)

RegisterNUICallback('gps', function(body, cb)
    cb(1)
    local x, y = tonumber(body.x), tonumber(body.y)
    if x and y then
        SetNewWaypoint(x, y)
        notify(locale('info.gps_set', tostring(body.label or '')))
    end
end)

-- ---------------------------------------------------------------------------
-- items (ox_inventory: client = { export = 'trx_divingjob.useTablet' })
-- ---------------------------------------------------------------------------

exports('useTablet', function()
    if not loggedIn() then return end
    if tablet.open then return end
    -- the shop tabs unlock when you use the tablet standing at the counter
    local atShop = #(GetEntityCoords(cache.ped) - shared.shop.ped.xyz) <= shared.shop.range - 1.0
    openTablet(atShop)
end)

-- a way out of the gear that never depends on the tank item being usable
RegisterCommand('divegear', function()
    if loggedIn() then Dive.takeOff() end
end, false)
TriggerEvent('chat:addSuggestion', '/divegear', locale('info.cmd_divegear'))

exports('useTank', function(_, slot)
    if not loggedIn() or not slot or not slot.slot then return end
    Dive.useTank(slot.slot)
end)

-- ---------------------------------------------------------------------------
-- server events
-- ---------------------------------------------------------------------------

RegisterNetEvent('trx_divingjob:client:contract', function(view)
    Dive.setContract(view)
    refreshTablet()
end)

RegisterNetEvent('trx_divingjob:client:containers', function(list)
    Dive.setContainers(list)
end)

RegisterNetEvent('trx_divingjob:client:rental', function(view, launch)
    Dive.setRental(view, launch)
    refreshTablet()
end)

RegisterNetEvent('trx_divingjob:client:air', function(air)
    Dive.setAir(air)
end)

RegisterNetEvent('trx_divingjob:client:levelUp', function(level)
    local airMult
    for i = 1, #shared.levels do
        if shared.levels[i].level == level then airMult = shared.levels[i].airMult end
    end
    Dive.setLevel(level, airMult)
    Dive.refreshBlips()
    PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
    refreshTablet()
end)

RegisterNetEvent('trx_divingjob:client:summary', function(summary)
    SendNUIMessage({ action = 'summary', data = summary })
    PlaySoundFrontend(-1, summary.how == 'complete' and 'CHECKPOINT_PERFECT' or 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
end)

-- ---------------------------------------------------------------------------
-- rental boats: third-eye to hand yours back
-- ---------------------------------------------------------------------------

exports.ox_target:addGlobalVehicle({
    {
        name = 'trx_divingjob:return',
        icon = 'fa-solid fa-ship',
        label = locale('target.return_boat'),
        distance = 4.0,
        canInteract = function(entity)
            return GetVehicleClass(entity) == 14 and Dive.isMyBoat(entity) and GetEntitySpeed(entity) < 2.0
        end,
        onSelect = function()
            Dive.returnBoat()
            refreshTablet()
        end,
    },
})

-- ---------------------------------------------------------------------------
-- shop ped + blip
-- ---------------------------------------------------------------------------

local function spawnPed()
    if shopPed and DoesEntityExist(shopPed) then return end
    local p, c = config.shopPed, shared.shop.ped
    local model = lib.requestModel(p.model, 10000)
    if not model then return end

    local ped = CreatePed(4, model, c.x, c.y, c.z + (p.zOffset or 0.0), c.w, false, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    if p.scenario then TaskStartScenarioInPlace(ped, p.scenario, 0, true) end

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'trx_divingjob:shop',
            icon = p.icon,
            label = locale('target.open_shop'),
            groups = shared.job or nil,
            distance = p.targetDistance,
            onSelect = function() openTablet(true) end,
        },
        {
            name = 'trx_divingjob:cancelRental',
            icon = 'fa-solid fa-rotate-left',
            label = locale('target.cancel_rental'),
            distance = p.targetDistance,
            canInteract = function()
                local r = Dive.rentalView()
                return r ~= nil and not r.launched
            end,
            onSelect = function()
                Dive.returnBoat()
                refreshTablet()
            end,
        },
    })
    shopPed = ped
end

local function removePed()
    if not shopPed then return end
    if DoesEntityExist(shopPed) then
        exports.ox_target:removeLocalEntity(shopPed, { 'trx_divingjob:shop', 'trx_divingjob:cancelRental' })
        DeletePed(shopPed)
    end
    shopPed = nil
end

lib.points.new({
    coords = shared.shop.ped.xyz,
    distance = config.shopPed.spawnDistance,
    onEnter = spawnPed,
    onExit = removePed,
})

local function makeShopBlip()
    if shopBlip then return end
    local c, b = shared.shop.ped, shared.shop.blip
    shopBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(shopBlip, b.sprite)
    SetBlipColour(shopBlip, b.colour)
    SetBlipScale(shopBlip, b.scale)
    SetBlipDisplay(shopBlip, 4)
    SetBlipAsShortRange(shopBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(shared.shop.label)
    EndTextCommandSetBlipName(shopBlip)
end

-- ---------------------------------------------------------------------------
-- player state
-- ---------------------------------------------------------------------------

local function onLoaded()
    makeShopBlip()
    local state = await('level')
    if not state then return end
    Dive.setLevel(state.level, state.airMult)
    Dive.refreshBlips()
    Dive.setContract(state.contract)
    Dive.setRental(state.rental, state.launch)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(500, onLoaded)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    closeTablet()
    Dive.cleanup()
end)

AddEventHandler('onResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    if loggedIn() then CreateThread(onLoaded) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if tablet.open then SetNuiFocus(false, false) end
    tabletProp(false)
    Dive.stop()
    removePed()
    if shopBlip then RemoveBlip(shopBlip) end
end)
