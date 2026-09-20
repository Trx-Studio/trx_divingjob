local activeContainers = {}
local activeCount = 0
local isContainerSpawningActive = false
local playerInDivingZone = false
local currentZoneIndex = nil
local containerThreads = {}

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

CreateThread(function()
    while true do
        local sleep = 6000
        local isInZone, zoneIndex = IsPlayerInDivingZone()

        if isInZone then
            sleep = 2000

            if not playerInDivingZone then
                playerInDivingZone = true
                currentZoneIndex = zoneIndex

                if not isContainerSpawningActive then
                    StartContainerSpawning(zoneIndex)
                end
            elseif currentZoneIndex ~= zoneIndex then
                StopContainerSpawning()
                currentZoneIndex = zoneIndex
                StartContainerSpawning(zoneIndex)
            end
        else
            if playerInDivingZone then
                playerInDivingZone = false
                currentZoneIndex = nil

                StopContainerSpawning()
            end
        end

        Wait(sleep)
    end
end)

function StartContainerSpawning(zoneIndex)
    if isContainerSpawningActive then return end

    isContainerSpawningActive = true

    for i = 1, 20 do
        CreateThread(function()
            Wait(i * 100)
            SpawnContainerInZone(zoneIndex)
        end)
    end

    CreateThread(function()
        while isContainerSpawningActive and playerInDivingZone do
            Wait(0)
            local playerCoords = GetEntityCoords(cache.ped)
            local ePressed = Config.Target == 'drawtext' and IsControlJustPressed(0, 38) or false
            local closestContainerId = nil
            local minDistance = Config.InteractionDistance + 1

            for containerId, containerData in pairs(activeContainers) do
                if not containerData.shouldStop then
                    local containerCoords = containerData.coords
                    local distance = #(containerCoords - playerCoords)

                    if distance <= 40.0 then
                        DrawLightWithRange(containerCoords.x, containerCoords.y, containerCoords.z + 1.0, 255, 0, 0, 5.0, 3.0)
                    end

                    if Config.Target == 'drawtext' and distance <= 20.0 and not containerData.isOpened then
                        DrawText3D(containerCoords.x, containerCoords.y, containerCoords.z + 1.5,
                        '[E] Open ' .. containerData.type.label)
                    end

                    if Config.Target == 'drawtext' and distance <= 8 and distance < minDistance and not containerData.isOpened then
                        minDistance = distance
                        closestContainerId = containerId
                    end

                end
            end
            
            if Config.Target == 'drawtext' and ePressed and closestContainerId then
                OpenContainer(closestContainerId)
            end
        end
    end)

    CreateThread(function()
        while isContainerSpawningActive and playerInDivingZone do
            Wait(10000)

            if activeCount < 20 then
                local missing = 20 - activeCount
                for i = 1, missing do
                    if activeCount < Config.MaxContainers then
                        CreateThread(function()
                            Wait(i * 200)
                            SpawnContainerInZone(currentZoneIndex)
                        end)
                    end
                end
            end
        end
    end)
end

function StopContainerSpawning()
    if not isContainerSpawningActive then return end

    isContainerSpawningActive = false

    for containerId, threads in pairs(containerThreads) do
        if threads.fallingThread then
            threads.fallingThread = nil
        end
    end
    containerThreads = {}

    for containerId in pairs(activeContainers) do
        RemoveContainer(containerId)
    end
end

RegisterNetEvent('MrJ-diving:client:StopContainerSpawning', function()
    StopContainerSpawning()
end)

function SpawnContainerInZone(zoneIndex)
    local zone = Config.DivingZones[zoneIndex]
    if not zone then return end

    local spawnX, spawnY, spawnZ = FindValidSpawnPosition(zoneIndex, zone)
    if not spawnX then
        return
    end

    local zoneContainers = zone.containers
    local randomContainerName = zoneContainers[math.random(#zoneContainers)]

    local containerType = nil
    for _, container in ipairs(Config.Containers) do
        if container.name == randomContainerName then
            containerType = container
            break
        end
    end

    if not containerType then return end

    local modelHash = GetHashKey(containerType.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(1)
    end

    local container = CreateObject(modelHash, spawnX, spawnY, spawnZ, false, false, false)
    SetEntityCollision(container, true, true)
    SetEntityInvincible(container, true)

    local containerId = 'container_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)

    local groundZ = 0
    local foundGround, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, spawnZ, false)
    if not foundGround then
        groundZ = zone.coords.z - zone.depth
    end

    local initialCoords = vector3(spawnX, spawnY, spawnZ)

    activeContainers[containerId] = {
        object = container,
        type = containerType,
        startZ = spawnZ,
        endZ = groundZ,
        currentZ = spawnZ,
        coords = initialCoords,
        isFalling = true,
        isOpened = false,
        spawnX = spawnX,
        spawnY = spawnY,
        zoneIndex = zoneIndex,
        shouldStop = false,
        hasTarget = false
    }
    activeCount = activeCount + 1

    CreateThread(function()
        local containerData = activeContainers[containerId]
        if not containerData then return end

        while containerData.isFalling and containerData.currentZ > containerData.endZ and not containerData.shouldStop and playerInDivingZone do
            Wait(50)

            containerData.currentZ = containerData.currentZ - Config.ContainerFallSpeed
            SetEntityCoords(containerData.object, containerData.spawnX, containerData.spawnY, containerData.currentZ,
                false, false, false, false)
            containerData.coords = vector3(containerData.spawnX, containerData.spawnY, containerData.currentZ)

            if containerData.currentZ <= containerData.endZ then
                containerData.isFalling = false
                SetEntityCoords(containerData.object, containerData.spawnX, containerData.spawnY, containerData.endZ,
                    false, false, false, false)
                containerData.coords = vector3(containerData.spawnX, containerData.spawnY, containerData.endZ)
                SetEntityCollision(containerData.object, true, true)
                break
            end
        end
        if not containerData.shouldStop then
            SetEntityCollision(containerData.object, true, true)
            -- Only add target for containers if NOT using drawtext
            if Bridge and Bridge.UsingTarget and Bridge.UsingTarget() and not Bridge.UsingDrawText() then
                local option = {
                    name = 'diving_open_' .. containerId,
                    icon = 'fas fa-box-open',
                    label = 'Open ' .. (containerData.type.label or 'Container'),
                    distance = Config.TargetDistance or 2.5,
                    onSelect = function()
                        OpenContainer(containerId)
                        if DoesEntityExist(containerData.object) then
                            Bridge.Target.RemoveEntity(containerData.object, 'diving_open_' .. containerId)
                        end
                    end
                }
                if not containerData.hasTarget then
                    Bridge.Target.AddEntity(containerData.object, option)
                    containerData.hasTarget = true
                end
            end
        end
    end)

    -- Only add target for containers if NOT using drawtext
    if Bridge and Bridge.UsingTarget and Bridge.UsingTarget() and not Bridge.UsingDrawText() then
        local data = activeContainers[containerId]
        if data and not data.hasTarget then
            local option = {
                name = 'diving_open_' .. containerId,
                icon = 'fas fa-box-open',
                label = 'Open ' .. (containerType.label or 'Container'),
                distance = Config.TargetDistance or 2.5,
                onSelect = function()
                    OpenContainer(containerId)
                    if DoesEntityExist(data.object) then
                        Bridge.Target.RemoveEntity(data.object, 'diving_open_' .. containerId)
                    end
                end
            }
            Bridge.Target.AddEntity(container, option)
            data.hasTarget = true
        end
    end

    SetModelAsNoLongerNeeded(modelHash)
end

function FindValidSpawnPosition(zoneIndex, zone)
    local minDistance = Config.MinContainerDistance
    local maxAttempts = 50

    for attempt = 1, maxAttempts do
        local angle = math.random() * 2 * math.pi
        local radius = math.random() * (zone.radius * 0.7)
        local spawnX = zone.coords.x + math.cos(angle) * radius
        local spawnY = zone.coords.y + math.sin(angle) * radius
        local spawnZ = zone.coords.z + Config.ContainerSpawnHeight

        local candidateCoords = vector3(spawnX, spawnY, spawnZ)
        local isValidPosition = true

        for containerId, containerData in pairs(activeContainers) do
            if containerData.zoneIndex == zoneIndex and containerData.object and DoesEntityExist(containerData.object) then
                local distance = #(candidateCoords - containerData.coords)
                if distance < minDistance then
                    isValidPosition = false
                    break
                end
            end
        end

        if isValidPosition then
            return spawnX, spawnY, spawnZ
        end
    end

    for attempt = 1, 20 do
        local angle = math.random() * 2 * math.pi
        local radius = math.random() * (zone.radius * 0.7)
        local spawnX = zone.coords.x + math.cos(angle) * radius
        local spawnY = zone.coords.y + math.sin(angle) * radius
        local spawnZ = zone.coords.z + Config.ContainerSpawnHeight

        local candidateCoords = vector3(spawnX, spawnY, spawnZ)
        local isValidPosition = true

        for containerId, containerData in pairs(activeContainers) do
            if containerData.zoneIndex == zoneIndex and containerData.object and DoesEntityExist(containerData.object) then
                local distance = #(candidateCoords - containerData.coords)
                if distance < (minDistance * 0.5) then
                    isValidPosition = false
                    break
                end
            end
        end

        if isValidPosition then
            return spawnX, spawnY, spawnZ
        end
    end

    return nil, nil, nil
end

function OpenContainer(containerId)
    Citizen.CreateThread(function()
    local containerData = activeContainers[containerId]
    if not containerData or containerData.isOpened then return end

    containerData.isOpened = true

    local playerPed = PlayerPedId()

    TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_WELDING", 0, true)

    Wait(5000)

    TriggerServerEvent('MrJ-diving:server:GiveContainerLoot', containerId, containerData.type.name,
        containerData.zoneIndex)

    RemoveContainer(containerId)

    CreateThread(function()
        SpawnContainerInZone(containerData.zoneIndex)
    end)

    ClearPedTasks(playerPed)
    ClearPedSecondaryTask(playerPed)
    StopAnimTask(playerPed, "WORLD_HUMAN_WELDING", "base", 1.0)
end)
end

function RemoveContainer(containerId)
    local containerData = activeContainers[containerId]
    if not containerData then return end

    containerData.shouldStop = true

    if containerThreads[containerId] then
        containerThreads[containerId] = nil
    end

    if Bridge and Bridge.UsingTarget and Bridge.UsingTarget() and not Bridge.UsingDrawText() and DoesEntityExist(containerData.object) then
        Bridge.Target.RemoveEntity(containerData.object, 'diving_open_' .. containerId)
    end

    if DoesEntityExist(containerData.object) then
        DeleteEntity(containerData.object)
    end

    activeContainers[containerId] = nil
    activeCount = activeCount - 1
end

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end

function GetActiveContainersCount()
    return activeCount
end
