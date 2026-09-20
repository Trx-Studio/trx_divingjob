local zonePeds = {}
local zoneBlips = {}

CreateThread(function()
    Wait(2000)

    if not Config or not Config.DivingZones then
        return
    end

    if Config.ShopPed and Config.ShopPed.enabled then
        CreateShopPed(Config.ShopPed)
    end

    for zoneIndex, zone in ipairs(Config.DivingZones) do
        if zone.blip then
            CreateZoneBlip(zoneIndex, zone.blip, zone.coords)
        end
    end

    CreateDivingShopBlip()
end)

function CreateShopPed(pedConfig)
    if not pedConfig or not pedConfig.model or not pedConfig.coords then
        return
    end

    local pedModel = GetHashKey(pedConfig.model)
    RequestModel(pedModel)

    local attempts = 0
    while not HasModelLoaded(pedModel) and attempts < 100 do
        Wait(10)
        attempts = attempts + 1
    end

    if not HasModelLoaded(pedModel) then
        return
    end

    local ped = CreatePed(4, pedModel, pedConfig.coords.x, pedConfig.coords.y, pedConfig.coords.z - 1, pedConfig.coords.w, false, true)

    if not ped or ped == 0 then
        SetModelAsNoLongerNeeded(pedModel)
        return
    end

    SetEntityHeading(ped, pedConfig.coords.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if pedConfig.scenario then
        TaskStartScenarioInPlace(ped, pedConfig.scenario, 0, true)
    end

    zonePeds['shop'] = { ped = ped }


    SetModelAsNoLongerNeeded(pedModel)

    Bridge.Target.AddPed(ped, {
        name = 'diving_job_menu_shop',
        icon = 'fas fa-swimming-pool',
        label = 'Diving Job Menu',
        distance = Config.TargetDistance or 2.5,
        onSelect = function()
            ShowDivingJobMenu(nil)
        end
    })

    Bridge.Target.AddPed(ped, {
        name = 'diving_job_menu_sell',
        icon = 'fas fa-dollar-sign',
        label = 'Sell Diving Loot',
        distance = Config.TargetDistance or 2.5,
        onSelect = function()
            OpenSellMenu(nil)
        end
    })
end

function CreateZoneBlip(zoneIndex, blipConfig, zoneCoords)
    if not blipConfig or not zoneCoords then
        return
    end


    local blip = AddBlipForCoord(zoneCoords.x, zoneCoords.y, zoneCoords.z)

    if not blip or blip == 0 then
        return
    end

    SetBlipSprite(blip, blipConfig.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipConfig.scale)
    SetBlipColour(blip, blipConfig.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipConfig.name)
    EndTextCommandSetBlipName(blip)


    zoneBlips[zoneIndex] = blip

    CreateZoneRadiusBlip(zoneIndex, zoneCoords, blipConfig.color)
end

function CreateZoneRadiusBlip(zoneIndex, zoneCoords, blipColor)
    local zone = Config.DivingZones[zoneIndex]
    if not zone or not zone.radius then
        return
    end


    local radiusBlip = AddBlipForRadius(zoneCoords.x, zoneCoords.y, zoneCoords.z, zone.radius)

    if not radiusBlip or radiusBlip == 0 then
        return
    end

    SetBlipRotation(radiusBlip, 0)
    SetBlipColour(radiusBlip, blipColor)
    SetBlipAlpha(radiusBlip, 100)
    SetBlipAsShortRange(radiusBlip, true)


    zoneBlips[zoneIndex .. '_radius'] = radiusBlip
end

function OpenDivingShop(zoneIndex)
    if not Config.ShopItems or #Config.ShopItems == 0 then
        lib.notify({ title = 'Diving Shop', description = 'Shop is currently unavailable', type = 'error' })
        return
    end
    local playerStats = Bridge.GetPlayerStats()
    local stats = Bridge.GetDivingStats(playerStats.divingXP, playerStats.divingLevel)
    OpenDivingShopMenu(zoneIndex, stats.level)
end

function OpenDivingShopMenu(zoneIndex, playerLevel)
    local options = {}
    for _, item in ipairs(Config.ShopItems) do
        local itemImage = item.image and ("https://cfx-nui-" .. Config.InventoryImagesPath .. item.image) or nil
        
        if not item.level or playerLevel >= item.level then
            table.insert(options, {
                title = item.label,
                description = string.format('Price: $%s%s',
                    math.groupdigits and math.groupdigits(item.price) or item.price,
                    item.level and string.format(' (Level %d+)', item.level) or ''
                ),
                icon = 'fas fa-shopping-cart',
                iconColor = '#66bb6a',
                image = itemImage,
                metadata = {
                    { label = 'Price', value = '$' .. (math.groupdigits and math.groupdigits(item.price) or item.price) },
                    { label = 'Level Required', value = item.level or 'None' }
                },
                onSelect = function()
                    PurchaseItem(item)
                end
            })
        else
            table.insert(options, {
                title = item.label,
                description = string.format('Price: $%s (Requires Level %d)',
                    math.groupdigits and math.groupdigits(item.price) or item.price,
                    item.level
                ),
                icon = 'fas fa-lock',
                iconColor = '#ff6b6b',
                disabled = true,
                image = itemImage,
                metadata = {
                    { label = 'Price', value = '$' .. (math.groupdigits and math.groupdigits(item.price) or item.price) },
                    { label = 'Level Required', value = item.level }
                }
            })
        end
    end
    lib.registerContext({
        id = 'diving_shop_menu_' .. zoneIndex,
        title = 'Diving Shop',
        menu = 'diving_job_menu',
        options = options
    })
    lib.showContext('diving_shop_menu_' .. zoneIndex)
end

function PurchaseItem(item)
    local input = lib.inputDialog('Purchase ' .. item.label, {
        {
            type = 'number',
            label = 'Quantity',
            description = 'How many would you like to purchase?',
            default = 1,
            min = 1,
            max = 10
        }
    })

    if not input then return end

    local quantity = input[1]
    local totalPrice = item.price * quantity

    local confirm = lib.alertDialog({
        header = 'Confirm Purchase',
        content = string.format('Purchase %dx %s for $%s?', quantity, item.label,
            math.groupdigits and math.groupdigits(totalPrice) or totalPrice),
        centered = true,
        cancel = true
    })

    if confirm == 'confirm' then
        TriggerServerEvent('MrJ-diving:server:PurchaseItem', item.item, quantity, totalPrice)
    end
end

--- Opens the sell menu for diving loot based on config sell prices.
--- @param zoneIndex number|nil
function OpenSellMenu(zoneIndex)
    if not Config.SellPrices or next(Config.SellPrices) == nil then
        lib.notify({ title = 'Diving', description = 'No sell prices configured', type = 'error' })
        return
    end

    local options = {}
    for itemName, itemData in pairs(Config.SellPrices) do
        local hasItem = Bridge.HasItem(itemName, 1)
        if hasItem then
            local price = itemData.price
            local imagePath = "https://cfx-nui-" .. Config.InventoryImagesPath .. itemData.image
            
            table.insert(options, {
                title = (itemName:gsub('^%l', string.upper)),
                description = string.format('Unit Price: $%s', math.groupdigits and math.groupdigits(price) or price),
                icon = imagePath,
                iconColor = '#ffffff',
                metadata = {
                    { label = 'Price', value = '$' .. (math.groupdigits and math.groupdigits(price) or price) }
                },
                onSelect = function()
                    SellItem(itemName)
                end
            })
        end
    end

    if #options == 0 then
        lib.notify({ title = 'Diving', description = 'You have nothing to sell', type = 'inform' })
        return
    end

    lib.registerContext({
        id = 'diving_sell_menu' .. (zoneIndex and ('_'..zoneIndex) or ''),
        title = 'Sell Diving Loot',
        menu = 'diving_job_menu',
        options = options
    })
    lib.showContext('diving_sell_menu' .. (zoneIndex and ('_'..zoneIndex) or ''))
end

--- Opens a quantity prompt and triggers server event to sell an item.
--- @param itemName string
function SellItem(itemName)
    local itemData = Config.SellPrices and Config.SellPrices[itemName]
    local unitPrice = itemData and itemData.price or 0
    if unitPrice <= 0 then
        lib.notify({ title = 'Diving', description = 'Item cannot be sold', type = 'error' })
        return
    end
    local input = lib.inputDialog('Sell ' .. itemName, {
        {
            type = 'number',
            label = 'Quantity',
            description = 'Enter amount to sell (0 = sell all)',
            default = 1,
            min = 0,
            max = 1000
        }
    })
    if not input then return end
    local qty = tonumber(input[1]) or 0
    TriggerServerEvent('MrJ-diving:server:SellItem', itemName, qty)
end

function RemoveZoneEntities()
    for key, pedData in pairs(zonePeds) do
        if DoesEntityExist(pedData.ped) then
            Bridge.Target.RemovePed(pedData.ped, 'diving_job_menu_shop')
            Bridge.Target.RemovePed(pedData.ped, 'diving_job_menu_sell')
            Bridge.Target.RemovePed(pedData.ped, 'diving_shop')
            DeleteEntity(pedData.ped)
        end
    end

    for blipKey, blip in pairs(zoneBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    zonePeds = {}
    zoneBlips = {}
end

function CreateDivingShopBlip()
    local blip = AddBlipForCoord(911.0, 3644.65, 32.68)

    if not blip or blip == 0 then
        return
    end

    SetBlipSprite(blip, 597)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Diving Shop")
    EndTextCommandSetBlipName(blip)

    zoneBlips['diving_shop'] = blip
end
