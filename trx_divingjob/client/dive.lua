--[[
    trx_divingjob - everything that happens in the water

    gear      the tank on your back, its air and the props
    zones     which dive zone you are in, and the containers on its seabed
    contract  the blip and the timer of the contract you took
    rental    putting your boat in the water and handing it back
    anchor    [G] in a boat inside a zone
    hud       one panel on the side of the screen for all of it
]]

local config = require 'config.client'
local shared = require 'config.shared'

local Dive = {}

local FUEL_EXPORTS = { LegacyFuel = true, ['cdn-fuel'] = true, ['ps-fuel'] = true, lc_fuel = true }
local FALLBACK_MODEL = `prop_box_wood02a`

local function notify(description, kind, duration)
    lib.notify({ title = locale('info.title'), description = description, type = kind or 'inform', duration = duration })
end

local function await(name, ...)
    return lib.callback.await('trx_divingjob:server:' .. name, false, ...)
end

local function money(n)
    local s = tostring(math.floor(n or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return '$' .. out:gsub('^,', '')
end

local function depthOf(ped)
    return math.max(0.0, -GetEntityCoords(ped).z)
end

local textShown = nil
local function textUI(text, icon)
    if textShown == text then return end
    textShown = text
    if text then
        lib.showTextUI(text, { position = 'right-center', icon = icon or 'fa-solid fa-anchor' })
    else
        lib.hideTextUI()
    end
end

-- ===========================================================================
-- gear
-- ===========================================================================

local gear = nil -- { slot, label, tier, air, max, rating, airMult, unsynced, props, warned }
Dive.level = 1

local function removeProps()
    if not gear or not gear.props then return end
    for i = 1, #gear.props do
        local p = gear.props[i]
        if DoesEntityExist(p) then
            DetachEntity(p, false, true)
            DeleteEntity(p)
        end
    end
    gear.props = nil
end

local function attachProps()
    local mask, tank = lib.requestModel(`p_d_scuba_mask_s`, 5000), lib.requestModel(`p_s_scuba_tank_s`, 5000)
    if not mask or not tank then return end
    local ped = cache.ped
    local pos = GetEntityCoords(ped)
    local t = CreateObject(tank, pos.x, pos.y, pos.z + 1.0, true, true, false)
    AttachEntityToEntity(t, ped, GetPedBoneIndex(ped, 24818), -0.25, -0.25, 0.0, 180.0, 90.0, 0.0,
        true, true, false, false, 2, true)
    local m = CreateObject(mask, pos.x, pos.y, pos.z + 1.0, true, true, false)
    AttachEntityToEntity(m, ped, GetPedBoneIndex(ped, 12844), 0.0, 0.0, 0.0, 180.0, 90.0, 0.0,
        true, true, false, false, 2, true)
    SetModelAsNoLongerNeeded(mask)
    SetModelAsNoLongerNeeded(tank)
    gear.props = { t, m }
end

local function scuba(on)
    SetEnableScuba(cache.ped, on)
    SetPedMaxTimeUnderwater(cache.ped, on and 1500.0 or (config.breathHold + 0.0))
end

---Sends the air used since the last sync. Returns false if the tank is gone.
local function syncAir()
    if not gear or gear.unsynced <= 0 then return true end
    local used = gear.unsynced
    gear.unsynced = 0
    local res = await('air', gear.slot, used)
    if not gear then return false end
    if not res or not res.ok then
        return false, res and res.reason
    end
    gear.air = res.air
    return true
end

local function dropGear(reason)
    if not gear then return end
    removeProps()
    gear = nil
    scuba(false)
    await('unequip')
    if reason then notify(reason, 'error') end
end

function Dive.hasGear() return gear ~= nil end

---Takes the gear off (also /divegear, so an empty or moved tank can never trap you in it).
function Dive.takeOff()
    if not gear then return notify(locale('error.no_gear'), 'error') end
    local swimming = IsPedSwimming(cache.ped)
    if lib.progressBar({
        duration = 3000, label = locale('info.taking_off'), canCancel = true, useWhileDead = false,
        -- ox_lib cancels a progress bar the moment the ped is swimming unless told otherwise
        allowSwimming = true, allowFalling = true,
        disable = { move = not swimming, combat = true },
        anim = not swimming and { dict = 'clothingshirt', clip = 'try_shirt_positive_d', blendIn = 8.0 } or nil,
    }) then
        syncAir()
        local label = gear and gear.label
        dropGear()
        notify(locale('info.gear_off', label or ''))
    end
end

---ox_inventory calls this through client/main.lua when a tank is used.
function Dive.useTank(slot)
    if gear and gear.slot == slot then return Dive.takeOff() end

    if cache.vehicle or IsPedSwimming(cache.ped) then
        return notify(locale('error.solid_ground'), 'error')
    end

    if gear then -- swapping tanks: settle the old one first
        syncAir()
        dropGear()
    end

    local res = await('equip', slot)
    if not res or not res.ok then
        return notify(res and res.reason or locale('error.no_tank'), 'error')
    end

    if not lib.progressBar({
        duration = 5000, label = locale('info.putting_on', res.label), canCancel = true, useWhileDead = false,
        disable = { move = true, combat = true },
        anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d', blendIn = 8.0 },
    }) then
        await('unequip')
        return notify(locale('error.cancelled'), 'error')
    end

    gear = {
        slot = res.slot, label = res.label, tier = res.tier, air = res.air, max = res.max,
        rating = res.rating, airMult = res.airMult or 1.0, unsynced = 0, warned = false,
    }
    attachProps()
    scuba(true)
    notify(locale('info.gear_on', res.label, math.floor(res.air / 60), res.rating), 'success')
end

---The server refilled the tank you are wearing.
function Dive.setAir(air)
    if not gear then return end
    gear.air = air
    gear.unsynced = 0
    gear.warned = false
    scuba(true)
end

function Dive.setLevel(level, airMult)
    Dive.level = level or Dive.level
    if gear and airMult then gear.airMult = airMult end
end

-- ===========================================================================
-- zones + containers
-- ===========================================================================

local here = nil          -- the zone you are in (config entry), or nil
local locked = nil        -- level needed when `here` is locked
local objects = {}        -- [id] = { obj, kind, target, x, y, z }
local opening = false
local zoneBlips = {}

local function zoneAt(pos)
    for i = 1, #shared.zones do
        local z = shared.zones[i]
        local dx, dy = pos.x - z.coords.x, pos.y - z.coords.y
        if dx * dx + dy * dy <= z.radius * z.radius then return z end
    end
end

local function seabed(x, y, floor)
    RequestCollisionAtCoord(x, y, floor)
    for _ = 1, 10 do
        local found, z = GetGroundZFor_3dCoord(x, y, 0.0, false)
        if found and z < -0.5 then return z end
        Wait(50)
    end
    return floor
end

local function deleteObject(id)
    local o = objects[id]
    if not o then return end
    if o.obj and DoesEntityExist(o.obj) then
        exports.ox_target:removeLocalEntity(o.obj, 'trx_divingjob:open')
        DeleteEntity(o.obj)
    end
    objects[id] = nil
end

local function clearObjects()
    for id in pairs(objects) do deleteObject(id) end
end

local openContainer -- forward

local function createObject(c)
    -- reserve the id first: creating yields, and a second refill must not make a twin
    local slot = { pending = true, kind = c.kind, target = c.target, x = c.x, y = c.y }
    objects[c.id] = slot
    local def = shared.containers[c.kind]
    local model = joaat(def.model)
    if not IsModelInCdimage(model) then
        if config.debug then lib.print.warn(('container model %s is missing, using a crate'):format(def.model)) end
        model = FALLBACK_MODEL
    end
    if not lib.requestModel(model, 5000) then
        objects[c.id] = nil
        return
    end
    local z = seabed(c.x, c.y, c.floor)
    if objects[c.id] ~= slot then
        SetModelAsNoLongerNeeded(model)
        return -- removed while we were finding the seabed
    end
    local obj = CreateObject(model, c.x, c.y, z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityHeading(obj, math.random(0, 359) + 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)

    local id = c.id
    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'trx_divingjob:open',
            icon = c.target and 'fa-solid fa-crosshairs' or 'fa-solid fa-box-open',
            label = locale(c.target and 'target.open_contract' or 'target.open', def.label),
            distance = config.zones.targetDistance,
            canInteract = function() return not opening end,
            onSelect = function() openContainer(id) end,
        },
    })
    slot.obj, slot.z, slot.pending = obj, z, nil
end

---Makes the objects on the seabed match what the server says is there.
function Dive.setContainers(list)
    if not list then
        clearObjects()
        return
    end
    local keep = {}
    for i = 1, #list do
        local c = list[i]
        keep[c.id] = true
        local o = objects[c.id]
        if o and o.target ~= c.target then
            deleteObject(c.id) -- re-created with the right marking
            o = nil
        end
        if not o then createObject(c) end
    end
    for id in pairs(objects) do
        if not keep[id] then deleteObject(id) end
    end
end

local function describeLoot(found)
    local parts = {}
    for i = 1, #found do parts[#parts + 1] = ('%dx %s'):format(found[i].count, found[i].label) end
    return #parts > 0 and table.concat(parts, ', ') or locale('info.nothing_inside')
end

openContainer = function(id)
    if opening then return end
    local o = objects[id]
    if not o then return end
    opening = true

    local res = await('beginOpen', id)
    if not res or not res.ok then
        opening = false
        return notify(res and res.reason or locale('error.container_gone'), 'error')
    end

    local ped = cache.ped
    local swimming = IsPedSwimming(ped)
    -- a land scenario would pull the diver out of the swim state, so only use it on the seabed floor
    if not swimming then
        TaskTurnPedToFaceCoord(ped, o.x, o.y, o.z, 600)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_WELDING', 0, true)
    end
    local done = lib.progressBar({
        duration = res.time,
        label = locale('info.opening', shared.containers[o.kind].label),
        canCancel = true,
        useWhileDead = false,
        -- containers are opened underwater: without these ox_lib cancels at once
        allowSwimming = true,
        allowFalling = true,
        disable = { move = true, combat = true, car = true },
    })
    if not swimming then ClearPedTasks(ped) end

    if not done then
        opening = false
        return notify(locale('error.cancelled'), 'error')
    end

    local r = await('finishOpen', id)
    opening = false
    if not r or not r.ok then
        return notify(r and r.reason or locale('error.container_gone'), 'error')
    end

    deleteObject(id)
    local extra = {}
    if r.paid and r.paid > 0 then extra[#extra + 1] = money(r.paid) end
    if r.xp and r.xp > 0 then extra[#extra + 1] = ('+%d XP'):format(r.xp) end
    notify(locale('info.opened', r.label, describeLoot(r.found)) .. (#extra > 0 and (' · ' .. table.concat(extra, ' · ')) or ''),
        r.counted and 'success' or 'inform', 6000)
    Dive.level = r.level or Dive.level
    if r.containers then Dive.setContainers(r.containers) end
    if Dive.onChange then Dive.onChange() end
end

local function enterZone(zone)
    local res = await('zone', zone and zone.id or nil)
    if zone ~= here then return end -- moved on while waiting
    if type(res) == 'table' and res.locked then
        locked = res.locked
        clearObjects()
    elseif type(res) == 'table' then
        locked = nil
        Dive.setContainers(res.containers)
    else
        locked = nil
        clearObjects()
    end
end

function Dive.refreshBlips()
    for i = 1, #zoneBlips do RemoveBlip(zoneBlips[i]) end
    zoneBlips = {}
    if not config.zones.blips then return end
    for i = 1, #shared.zones do
        local z = shared.zones[i]
        local open = Dive.level >= z.level
        local radius = AddBlipForRadius(z.coords.x, z.coords.y, z.coords.z, z.radius)
        SetBlipColour(radius, open and 3 or 40)
        SetBlipAlpha(radius, open and 90 or 50)
        local blip = AddBlipForCoord(z.coords.x, z.coords.y, z.coords.z)
        SetBlipSprite(blip, config.zones.blipSprite)
        SetBlipColour(blip, open and 3 or 40)
        SetBlipScale(blip, 0.75)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(open and locale('info.blip_zone', z.label) or locale('info.blip_zone_locked', z.label, z.level))
        EndTextCommandSetBlipName(blip)
        zoneBlips[#zoneBlips + 1] = radius
        zoneBlips[#zoneBlips + 1] = blip
    end
end

-- ===========================================================================
-- contract
-- ===========================================================================

local contract = nil -- the server's view + skew
local contractBlips = {}

local function clearContractBlips()
    for i = 1, #contractBlips do RemoveBlip(contractBlips[i]) end
    contractBlips = {}
end

function Dive.setContract(view)
    clearContractBlips()
    contract = view or nil
    if not contract then return end
    contract.skew = (contract.now or 0) - GetCloudTimeAsInt()

    local radius = AddBlipForRadius(contract.coords.x, contract.coords.y, 0.0, contract.radius + 0.0)
    SetBlipColour(radius, 47)
    SetBlipAlpha(radius, 120)
    local blip = AddBlipForCoord(contract.coords.x, contract.coords.y, 0.0)
    SetBlipSprite(blip, 729)
    SetBlipColour(blip, 47)
    SetBlipScale(blip, 0.95)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 47)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('info.blip_contract', contract.label))
    EndTextCommandSetBlipName(blip)
    contractBlips = { radius, blip }
end

function Dive.contract() return contract end

local function contractLeft()
    if not contract then return 0 end
    return math.max(0, contract.expires - (GetCloudTimeAsInt() + contract.skew))
end

-- ===========================================================================
-- rental
-- ===========================================================================

local rental = nil      -- server view
local launchAt = nil    -- vec4
local rentalBlip = nil
local launching = false

local function clearRentalBlip()
    if rentalBlip then RemoveBlip(rentalBlip) end
    rentalBlip = nil
end

local function boatEntity()
    if not rental or not rental.netId then return nil end
    if not NetworkDoesEntityExistWithNetworkId(rental.netId) then return nil end
    local veh = NetToVeh(rental.netId)
    return veh ~= 0 and DoesEntityExist(veh) and veh or nil
end

local function readFuel(veh)
    if rental and rental.fuelSystem == 'ox_fuel' then
        local level = Entity(veh).state.fuel
        if level then return level + 0.0 end
    end
    return GetVehicleFuelLevel(veh)
end

function Dive.setRental(view, launch)
    rental = view or nil
    launchAt = launch and vec4(launch.x, launch.y, launch.z, launch.w) or nil
    clearRentalBlip()
    if not rental then return end

    if not rental.launched then
        rentalBlip = AddBlipForCoord(launchAt.x, launchAt.y, launchAt.z)
        SetBlipSprite(rentalBlip, 410)
        SetBlipColour(rentalBlip, config.rental.blipColour)
        SetBlipRoute(rentalBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(locale('info.blip_launch', rental.label))
        EndTextCommandSetBlipName(rentalBlip)
    else
        Dive.blipBoat()
    end
end

function Dive.blipBoat()
    local veh = boatEntity()
    if not veh or rentalBlip then return end
    rentalBlip = AddBlipForEntity(veh)
    SetBlipSprite(rentalBlip, 427)
    SetBlipColour(rentalBlip, config.rental.blipColour)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('info.blip_boat', rental.label))
    EndTextCommandSetBlipName(rentalBlip)
end

local function tryLaunch()
    if launching or not rental or rental.launched or not launchAt then return end
    if #(GetEntityCoords(cache.ped) - launchAt.xyz) > config.rental.launchDistance then return end
    launching = true
    local res = await('launch')
    launching = false
    if not res then return end

    -- lib.waitFor throws on timeout
    local found, veh = pcall(lib.waitFor, function()
        if NetworkDoesEntityExistWithNetworkId(res.netId) then
            local v = NetToVeh(res.netId)
            if v ~= 0 and DoesEntityExist(v) then return v end
        end
    end, 'boat did not stream in', 10000)
    if not found or not veh then return end

    SetVehicleEngineOn(veh, false, true, true)
    SetBoatAnchor(veh, true)
    SetVehicleFuelLevel(veh, res.fuel + 0.0)
    if FUEL_EXPORTS[res.fuelSystem] then
        pcall(function() exports[res.fuelSystem]:SetFuel(veh, res.fuel + 0.0) end)
    end
    SetTimeout(2500, function()
        if DoesEntityExist(veh) and not IsEntityInWater(veh) then
            lib.print.warn(('rental launch point %s is not on water - fix it in config/shared.lua'):format(tostring(launchAt)))
        end
    end)
    Dive.blipBoat()
    notify(locale('info.boat_ready', rental and rental.label or ''), 'success', 7000)
end

function Dive.returnBoat()
    local veh = boatEntity()
    local res = await('returnBoat', veh and readFuel(veh) or nil)
    if not res then return end
    notify(res.message or res.reason, res.ok and 'success' or 'error', 8000)
    return res
end

function Dive.isMyBoat(entity)
    local state = Entity(entity).state['trx_divingjob:rental']
    return state ~= nil and state == cache.serverId
end

function Dive.rentalView() return rental end

-- ===========================================================================
-- anchor
-- ===========================================================================

local anchored = {}
local anchorRunning = false

local function anchorLoop()
    if anchorRunning then return end
    anchorRunning = true
    CreateThread(function()
        while cache.vehicle do
            local veh = cache.vehicle
            local sleep = 500
            if GetVehicleClass(veh) == 14 and here and GetPedInVehicleSeat(veh, -1) == cache.ped then
                sleep = 0
                local down = anchored[veh] == true
                textUI(locale(down and 'info.raise_anchor' or 'info.drop_anchor'), 'fa-solid fa-anchor')
                if IsControlJustPressed(0, config.anchorKey) then
                    if not down and GetEntitySpeed(veh) > 3.0 then
                        notify(locale('error.slow_down'), 'error')
                    else
                        down = not down
                        anchored[veh] = down or nil
                        SetBoatAnchor(veh, down)
                        SetBoatFrozenWhenAnchored(veh, down)
                        if down then SetEntityVelocity(veh, 0.0, 0.0, 0.0) end
                        notify(locale(down and 'info.anchor_down' or 'info.anchor_up'))
                    end
                end
            else
                textUI(nil)
            end
            Wait(sleep)
        end
        textUI(nil)
        anchorRunning = false
    end)
end

lib.onCache('vehicle', function(veh)
    if veh then SetTimeout(0, anchorLoop) end
end)

-- ===========================================================================
-- HUD
-- ===========================================================================

local hudShown = false
local lastHud = nil

local function nearbyCount(pos)
    local n, targets = 0, 0
    for _, o in pairs(objects) do
        local dx, dy = o.x - pos.x, o.y - pos.y
        if dx * dx + dy * dy < 60.0 * 60.0 then
            n = n + 1
            if o.target then targets = targets + 1 end
        end
    end
    return n, targets
end

local function hudTick(underwater)
    if not config.hud.enabled then return end
    local ped = cache.ped
    local pos = GetEntityCoords(ped)
    local depth = depthOf(ped)
    local swimming = IsPedSwimming(ped)
    local boat = cache.vehicle and GetVehicleClass(cache.vehicle) == 14 and cache.vehicle or nil
    local show = contract ~= nil or (gear ~= nil and (swimming or boat ~= nil)) or (here ~= nil and (swimming or boat ~= nil))

    if not show then
        if hudShown then
            hudShown = false
            lastHud = nil
            SendNUIMessage({ action = 'hud', data = false })
        end
        return
    end

    local near, nearTargets = nearbyCount(pos)
    local data = {
        position = config.hud.position,
        top = config.hud.top,
        lowAir = config.hud.lowAir,
        depth = math.floor(depth * 10) / 10,
        underwater = underwater,
        gear = gear and {
            label = gear.label, tier = gear.tier, air = math.floor(gear.air), max = gear.max,
            rating = gear.rating, over = underwater and depth > gear.rating,
        } or false,
        zone = here and { label = here.label, code = here.code, color = here.color, locked = locked, near = near, targets = nearTargets } or false,
        contract = contract and {
            label = contract.label, zone = contract.zoneLabel, code = contract.code, color = contract.color,
            done = contract.done, goal = contract.goal, left = contractLeft(), earned = contract.earned,
            inZone = here ~= nil and here.id == contract.zone,
        } or false,
        fuel = boat and math.floor(readFuel(boat)) or false,
    }
    local encoded = json.encode(data)
    if encoded == lastHud then return end
    lastHud = encoded
    hudShown = true
    SendNUIMessage({ action = 'hud', data = data })
end

function Dive.hideHud()
    hudShown = false
    lastHud = nil
    SendNUIMessage({ action = 'hud', data = false })
end

-- ===========================================================================
-- the loops
-- ===========================================================================

-- zone detection + container refills
CreateThread(function()
    local lastFill = 0
    local refill = 12000
    while true do
        local zone = zoneAt(GetEntityCoords(cache.ped))
        if zone ~= here then
            here = zone
            locked = nil
            lastFill = GetGameTimer()
            enterZone(zone)
        elseif here and not locked and GetGameTimer() - lastFill > refill then
            lastFill = GetGameTimer()
            enterZone(here)
        end
        tryLaunch()
        if rental and rental.launched and not (rentalBlip and DoesBlipExist(rentalBlip)) then
            rentalBlip = nil
            Dive.blipBoat()
        end
        Wait(1500)
    end
end)

-- container lights and target markers (only while something is on the seabed)
CreateThread(function()
    local range = config.zones.light
    while true do
        if next(objects) then
            local pos = GetEntityCoords(cache.ped)
            for _, o in pairs(objects) do
                local d2 = math.huge
                if o.z then
                    local dx, dy, dz = o.x - pos.x, o.y - pos.y, o.z - pos.z
                    d2 = dx * dx + dy * dy + dz * dz
                end
                if d2 < range * range then
                    if o.target then
                        DrawLightWithRange(o.x, o.y, o.z + 1.2, 238, 154, 46, 6.0, 4.0)
                    else
                        DrawLightWithRange(o.x, o.y, o.z + 1.2, 79, 163, 224, 4.5, 2.5)
                    end
                end
                if o.target and d2 < 90.0 * 90.0 then
                    DrawMarker(2, o.x, o.y, o.z + 2.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.6, 0.6, 0.4,
                        238, 154, 46, 180, true, true, 2, false, nil, nil, false)
                end
            end
            Wait(0)
        else
            Wait(750)
        end
    end
end)

-- air + HUD, once a second
CreateThread(function()
    local sinceSync = 0
    local wasUnder = false
    while true do
        local ped = cache.ped
        local underwater = IsPedSwimmingUnderWater(ped)

        if gear then
            if IsEntityDead(ped) then
                syncAir()
                dropGear()
            else
                if underwater and gear.air > 0 then
                    local depth = depthOf(ped)
                    local drain = gear.airMult * (depth > gear.rating and 2.0 or 1.0)
                    gear.air = math.max(0, gear.air - drain)
                    gear.unsynced = gear.unsynced + drain

                    local pct = gear.air / gear.max * 100
                    if not gear.warned and pct <= config.hud.lowAir then
                        gear.warned = true
                        notify(locale('info.low_air'), 'error', 6000)
                        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
                    end
                    if gear.air <= 0 then
                        scuba(false)
                        notify(locale('info.out_of_air'), 'error', 8000)
                        PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
                    end
                end

                sinceSync = sinceSync + 1
                if gear.unsynced > 0 and (sinceSync >= 10 or (wasUnder and not underwater)) then
                    sinceSync = 0
                    local ok, reason = syncAir()
                    if not ok then dropGear(reason or locale('error.tank_gone')) end
                end
            end
        end

        wasUnder = underwater
        hudTick(underwater)
        Wait(1000)
    end
end)

function Dive.cleanup()
    if gear then
        syncAir()
        dropGear()
    end
    clearObjects()
    clearContractBlips()
    clearRentalBlip()
    for i = 1, #zoneBlips do RemoveBlip(zoneBlips[i]) end
    zoneBlips = {}
    contract, rental = nil, nil
    textUI(nil)
    Dive.hideHud()
end

-- props only; no server calls while the resource is stopping
function Dive.stop()
    if gear then
        removeProps()
        scuba(false)
    end
    for _, o in pairs(objects) do
        if o.obj and DoesEntityExist(o.obj) then DeleteEntity(o.obj) end
    end
    clearContractBlips()
    clearRentalBlip()
    for i = 1, #zoneBlips do RemoveBlip(zoneBlips[i]) end
    textUI(nil)
end

return Dive
