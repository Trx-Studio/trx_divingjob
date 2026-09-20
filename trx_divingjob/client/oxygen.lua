local oxygenTimer = 0
local maxOxygenTime = Config.OxygenTime
local isOxygenSystemActive = false
local oxygenUI = false
local hasDivingGear = false
local playerLevel = 1

local function GetMaxOxygenTime(level, hasGear)
    local baseTime = hasGear and Config.OxygenTimeWithGear or Config.OxygenTime
    return baseTime + ((level - 1) * 10)
end

local function IsPlayerInDivingZone()
    if not Config.DivingZones then return false, nil end
    local playerCoords = GetEntityCoords(PlayerPedId())
    for zoneIndex, zone in ipairs(Config.DivingZones) do
        local distance = #(playerCoords - zone.coords)
        if distance <= zone.radius then
            return true, zoneIndex
        end
    end
    return false, nil
end

local function UpdatePlayerLevel(cb)
    local playerStats = Bridge.GetPlayerStats()
    local stats = Bridge.GetDivingStats(playerStats.divingXP, playerStats.divingLevel)
    playerLevel = stats.level or 1
    maxOxygenTime = GetMaxOxygenTime(playerLevel, hasDivingGear)
    if cb then cb() end
end

CreateThread(function()
    if not Config.Oxygen or Config.Oxygen.Enabled == false then
        return
    end
    UpdatePlayerLevel()
    local notifiedDeplete = false
    local overrideBreath = Config.Oxygen.OverrideNativeBreath
    while true do
        local sleep = 2000
        local playerPed = PlayerPedId()
        if overrideBreath then
            SetPedMaxTimeUnderwater(playerPed, 2000.0)
        end
        local isInZone, zoneIndex = IsPlayerInDivingZone()
        if isInZone then
            local isUnderwater = IsPedSwimmingUnderWater(playerPed)
            if isUnderwater then
                sleep = 1000
                if not isOxygenSystemActive then
                    isOxygenSystemActive = true
                    oxygenTimer = 0
                    notifiedDeplete = false
                    currentDivingZone = zoneIndex
                    UpdatePlayerLevel(function()
                        maxOxygenTime = GetMaxOxygenTime(playerLevel, hasDivingGear)
                    end)
                    if not oxygenUI then
                        oxygenUI = true
                        SendNUIMessage({ type = 'showOxygen', show = true })
                    end
                end
                oxygenTimer = oxygenTimer + 1
                if oxygenTimer >= maxOxygenTime then
                    if Config.Oxygen.KillOnDeplete then
                        SetEntityHealth(playerPed, 0)
                    end
                    if not notifiedDeplete then
                        notifiedDeplete = true
                        TriggerEvent('MrJ-diving:client:OutOfOxygen')
                    end
                end
                local oxygenPercent = math.max(0, 100 - (oxygenTimer / maxOxygenTime) * 100)
                local timeRemaining = math.max(0, maxOxygenTime - oxygenTimer)
                local depth = GetEntityHeightAboveGround(playerPed)
                SendNUIMessage({
                    type = 'updateOxygen',
                    oxygen = oxygenPercent,
                    time = timeRemaining,
                    maxTime = maxOxygenTime,
                    hasDivingGear = hasDivingGear,
                    depth = math.abs(depth)
                })
            else
                sleep = 2500
                if isOxygenSystemActive then
                    isOxygenSystemActive = false
                    oxygenTimer = 0
                    currentDivingZone = nil
                    if oxygenUI then
                        oxygenUI = false
                        SendNUIMessage({ type = 'showOxygen', show = false })
                    end
                end
            end
        else
            sleep = 3000
            if isOxygenSystemActive then
                isOxygenSystemActive = false
                oxygenTimer = 0
                currentDivingZone = nil
                if oxygenUI then
                    oxygenUI = false
                    SendNUIMessage({ type = 'showOxygen', show = false })
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('MrJ-diving:client:OutOfOxygen', function()
    lib.notify({ title = 'Diving', description = 'You ran out of oxygen!', type = 'error' })
end)

local currentGear = {
    mask = 0,
    tank = 0,
    enabled = false
}

local function enableScuba()
    SetEnableScuba(cache.ped, true)
    SetPedMaxTimeUnderwater(cache.ped, 2000.00)
end

local function deleteGear()
    if currentGear.mask ~= 0 then
        DetachEntity(currentGear.mask, false, true)
        DeleteEntity(currentGear.mask)
        currentGear.mask = 0
    end
    if currentGear.tank ~= 0 then
        DetachEntity(currentGear.tank, false, true)
        DeleteEntity(currentGear.tank)
        currentGear.tank = 0
    end
end

local function attachGear()
    local maskModel = `p_d_scuba_mask_s`
    local tankModel = `p_s_scuba_tank_s`
    lib.requestModel(maskModel)
    lib.requestModel(tankModel)
    currentGear.tank = CreateObject(tankModel, 1.0, 1.0, 1.0, true, true, false)
    local bone1 = GetPedBoneIndex(cache.ped, 24818)
    AttachEntityToEntity(currentGear.tank, cache.ped, bone1, -0.25, -0.25, 0.0, 180.0, 90.0, 0.0, true, true, false,
        false, 2, true)
    currentGear.mask = CreateObject(maskModel, 1.0, 1.0, 1.0, true, true, false)
    local bone2 = GetPedBoneIndex(cache.ped, 12844)
    AttachEntityToEntity(currentGear.mask, cache.ped, bone2, 0.0, 0.0, 0.0, 180.0, 90.0, 0.0, true, true, false, false, 2,
        true)
    SetModelAsNoLongerNeeded(maskModel)
    SetModelAsNoLongerNeeded(tankModel)
end

local function takeOffSuit()
    if lib.progressBar({
            duration = 3000,
            label = 'Taking off diving suit...',
            useWhileDead = false,
            canCancel = true,
            anim = {
                dict = 'clothingshirt',
                clip = 'try_shirt_positive_d',
                blendIn = 8.0
            }
        }) then
        SetEnableScuba(cache.ped, false)
        SetPedMaxTimeUnderwater(cache.ped, 50.00)
        currentGear.enabled = false
        deleteGear()
        lib.notify({
            title = 'Diving Gear',
            description = 'Diving suit removed successfully',
            type = 'success'
        })
        hasDivingGear = false
        maxOxygenTime = GetMaxOxygenTime(playerLevel, hasDivingGear)
    end
end

local function putOnSuit()
    if IsPedSwimming(cache.ped) or cache.vehicle then
        lib.notify({
            title = 'Diving Gear',
            description = 'You must be standing on solid ground',
            type = 'error'
        })
        return
    end
    if lib.progressBar({
            duration = 5000,
            label = 'Putting on diving suit...',
            useWhileDead = false,
            canCancel = true,
            anim = {
                dict = 'clothingshirt',
                clip = 'try_shirt_positive_d',
                blendIn = 8.0
            }
        }) then
        deleteGear()
        attachGear()
        enableScuba()
        currentGear.enabled = true
        lib.notify({
            title = 'Diving Gear',
            description = 'Diving suit equipped successfully',
            type = 'success'
        })
        hasDivingGear = true
        maxOxygenTime = GetMaxOxygenTime(playerLevel, hasDivingGear)
    end
end

RegisterNetEvent('MrJ-divegear:client:useGear', function()
    if currentGear.enabled then
        takeOffSuit()
    else
        putOnSuit()
    end
end)