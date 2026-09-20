local isTextShown = false
local lastPrompt = nil
local anchoredVehicle = 0
local isAnchored = false

--- Determines if the player is within any defined diving zone.
--- @return boolean, number|nil
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

--- Shows or updates the text UI prompt.
--- @param text string
local function ShowPrompt(text)
    if lastPrompt ~= text or not isTextShown then
        lib.showTextUI(text)
        isTextShown = true
        lastPrompt = text
    else
        lib.showTextUI(text)
        isTextShown = true
    end
end

--- Hides the text UI prompt if visible.
local function HidePrompt()
    if isTextShown then
        lib.hideTextUI()
        isTextShown = false
        lastPrompt = nil
    end
end

--- Applies anchor state to the given vehicle.
--- @param veh number
--- @param anchor boolean
local function SetAnchorState(veh, anchor)
    anchoredVehicle = veh
    isAnchored = anchor
    if anchor then
        SetBoatFrozenWhenAnchored(veh, true)
        SetBoatAnchor(veh, true)
        SetEntityVelocity(veh, 0.0, 0.0, 0.0)
        FreezeEntityPosition(veh, true)
        lib.notify({ title = 'Diving', description = 'Anchor dropped', type = 'success' })
    else
        SetBoatAnchor(veh, false)
        FreezeEntityPosition(veh, false)
        lib.notify({ title = 'Diving', description = 'Anchor raised', type = 'inform' })
    end
end

CreateThread(function()
    while true do
        local sleep = 0
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                local vehClass = GetVehicleClass(veh)
                local inZone = IsPlayerInDivingZone()
                if vehClass == 14 and inZone then
                    sleep = 0
                    local prompt = isAnchored and 'Press [G] Raise Anchor' or 'Press [G] Drop Anchor'
                    ShowPrompt(prompt)
                    if GetPedInVehicleSeat(veh, -1) == ped and IsControlJustPressed(0, 47) then
                        if anchoredVehicle ~= veh then
                            anchoredVehicle = 0
                            isAnchored = false
                        end
                        SetAnchorState(veh, not isAnchored)
                    end
                else
                    HidePrompt()
                end
            else
                HidePrompt()
            end
        else
            HidePrompt()
        end
        Wait(sleep)
    end
end)



