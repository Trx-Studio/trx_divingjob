--[[
    Bridge shared
    Framework values: 'qb', 'qbx', 'esx'
    Inventory values: 'ox', 'qb', 'qs'
]]

Bridge = Bridge or {}

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

local function detectFramework()
    if Config.Framework and Config.Framework ~= 'auto' then
        return Config.Framework
    end
    if resourceStarted('qbx_core') then return 'qbx' end
    if resourceStarted('qb-core') then return 'qb' end
    if resourceStarted('es_extended') then return 'esx' end
    return 'qb'
end

local function detectInventory()
    if Config.Inventory and Config.Inventory ~= 'auto' then
        return Config.Inventory
    end
    if resourceStarted('ox_inventory') then return 'ox' end
    if resourceStarted('qs-inventory') then return 'qs' end
    if resourceStarted('qb-inventory') then return 'qb' end
    return 'qb'
end

local function detectTarget()
    if Config.Target and Config.Target ~= 'auto' then
        return Config.Target
    end
    if resourceStarted('ox_target') then return 'ox' end
    if resourceStarted('qb-target') then return 'qb' end
    return 'drawtext'
end

Bridge.Framework = detectFramework()
Bridge.Inventory = detectInventory()
Bridge.TargetSystem = detectTarget()

function Bridge.UsingQB()
    return Bridge.Framework == 'qb' or Bridge.Framework == 'qbx'
end

function Bridge.UsingESX()
    return Bridge.Framework == 'esx'
end

function Bridge.UsingOxInventory()
    return Bridge.Inventory == 'ox'
end

function Bridge.UsingQBInventory()
    return Bridge.Inventory == 'qb'
end

function Bridge.UsingQSInventory()
    return Bridge.Inventory == 'qs'
end

function Bridge.UsingTarget()
    return Bridge.TargetSystem == 'ox' or Bridge.TargetSystem == 'qb'
end

function Bridge.UsingDrawText()
    return Bridge.TargetSystem == 'drawtext'
end

--- Calculates the player's current diving level based on XP.
--- @param divingXP number The player's diving XP.
--- @return number The calculated diving level.
function Bridge.GetLevelFromXP(divingXP)
    local level = 1
    for i = 1, #Config.Levels do
        if divingXP >= Config.Levels[i] then
            level = i
        end
    end
    return level
end

--- Calculates XP needed for the next level.
--- @param divingXP number The player's current diving XP.
--- @param divingLevel number The player's current diving level.
--- @return number XP needed for next level (0 if at max).
function Bridge.GetNextLevelXP(divingXP, divingLevel)
    if divingLevel >= #Config.Levels then
        return 0
    end
    
    local nextLevelXP = Config.Levels[divingLevel + 1] or 0
    return math.max(0, nextLevelXP - divingXP)
end

--- Calculates XP needed for the next level from current level.
--- @param divingLevel number The player's current diving level.
--- @return number XP needed for next level (0 if at max).
function Bridge.GetXPNeededForNextLevel(divingLevel)
    if divingLevel >= #Config.Levels then
        return 0
    end
    
    local currentLevelXP = Config.Levels[divingLevel] or 0
    local nextLevelXP = Config.Levels[divingLevel + 1] or 0
    return nextLevelXP - currentLevelXP
end

--- Gets the player's diving stats with calculated values.
--- @param divingXP number The player's diving XP.
--- @param divingLevel number The player's diving level.
--- @return table Stats object with level, exp, nextIn, and calculated values.
function Bridge.GetDivingStats(divingXP, divingLevel)
    divingXP = tonumber(divingXP) or 0
    divingLevel = tonumber(divingLevel) or 1

    local level = divingLevel
    local nextIn = Bridge.GetXPNeededForNextLevel(level)

    return {
        level = level,
        exp = divingXP,
        nextIn = nextIn,
        calculatedLevel = level
    }
end
