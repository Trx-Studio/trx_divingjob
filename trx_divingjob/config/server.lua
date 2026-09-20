--[[
    trx_divingjob - server config (never sent to clients)
]]

return {
    -- Contract pay and level rewards go to this account.
    payAccount = 'bank',

    -- The shop (tanks, refills, rentals) takes money from these accounts, in order.
    shopAccounts = { 'cash', 'bank' },

    -- Loot sold at the shop is paid into this account.
    sellAccount = 'cash',

    xp = {
        rareFind = 20,      -- extra XP for every rare item found (see `rare` below)
        freeDive = 0.6,     -- containers opened OUTSIDE a contract give this share of their XP
    },

    -- ---------------------------------------------------------------------
    -- Loot. Each container rolls `rolls` picks (min..max) from its table,
    -- weighted, without repeats. Items that don't exist in ox_inventory are
    -- skipped and named once in the server console.
    -- ---------------------------------------------------------------------
    loot = {
        common = {
            rolls = { 1, 3 },
            items = {
                { name = 'plastic',    min = 2, max = 8, weight = 50 },
                { name = 'copper',     min = 2, max = 6, weight = 45 },
                { name = 'metalscrap', min = 2, max = 8, weight = 45 },
                { name = 'rubber',     min = 1, max = 5, weight = 35 },
                { name = 'aluminum',   min = 2, max = 6, weight = 35 },
                { name = 'iron',       min = 1, max = 5, weight = 30 },
                { name = 'money',      min = 10, max = 60, weight = 15 },
            },
        },
        reef = {
            rolls = { 1, 2 },
            items = {
                { name = 'plastic',    min = 2, max = 6, weight = 50 },
                { name = 'rubber',     min = 1, max = 4, weight = 35 },
                { name = 'copper',     min = 1, max = 4, weight = 30 },
                { name = 'emerald',    min = 1, max = 1, weight = 3 },
                { name = 'ruby',       min = 1, max = 1, weight = 3 },
            },
        },
        wreck = {
            rolls = { 2, 4 },
            items = {
                { name = 'steel',      min = 2, max = 8, weight = 45 },
                { name = 'metalscrap', min = 3, max = 10, weight = 45 },
                { name = 'copper',     min = 2, max = 8, weight = 40 },
                { name = 'iron',       min = 2, max = 8, weight = 35 },
                { name = 'money',      min = 40, max = 180, weight = 20 },
                { name = 'goldbar',    min = 1, max = 1, weight = 4 },
                { name = 'diamond',    min = 1, max = 1, weight = 3 },
            },
        },
        deep = {
            rolls = { 2, 5 },
            items = {
                { name = 'steel',      min = 3, max = 10, weight = 40 },
                { name = 'aluminum',   min = 3, max = 10, weight = 35 },
                { name = 'money',      min = 80, max = 260, weight = 20 },
                { name = 'goldbar',    min = 1, max = 2, weight = 7 },
                { name = 'diamond',    min = 1, max = 1, weight = 5 },
                { name = 'emerald',    min = 1, max = 1, weight = 5 },
                { name = 'ruby',       min = 1, max = 1, weight = 5 },
            },
        },
        treasure = {
            rolls = { 3, 5 },
            items = {
                { name = 'money',      min = 150, max = 500, weight = 35 },
                { name = 'goldbar',    min = 1, max = 3, weight = 25 },
                { name = 'diamond',    min = 1, max = 2, weight = 18 },
                { name = 'emerald',    min = 1, max = 2, weight = 18 },
                { name = 'ruby',       min = 1, max = 2, weight = 18 },
                { name = 'copper',     min = 3, max = 10, weight = 20 },
            },
        },
    },

    -- items that count as a "rare find" for the XP bonus
    rare = { goldbar = true, diamond = true, emerald = true, ruby = true },

    -- Unit prices the shop pays for loot. Items not listed can't be sold here.
    sell = {
        copper = 50, plastic = 30, metalscrap = 40, aluminum = 45, steel = 55,
        rubber = 25, iron = 35, tech_trash = 90,
        goldbar = 1500, diamond = 1200, emerald = 900, ruby = 800,
    },

    -- ox_fuel is detected automatically. 'auto' tries ox_fuel (statebag), then
    -- LegacyFuel / cdn-fuel / ps-fuel / lc_fuel, then the native.
    fuel = {
        system = 'auto',
        start = 100.0,          -- a rented boat leaves with a full tank
        pricePerPercent = 4,    -- fuel used is taken out of the deposit at this rate
    },

    -- Vehicle keys: 'auto' picks Renewed-Vehiclekeys, then qbx_vehiclekeys,
    -- then the qb 'vehiclekeys:client:SetOwner' event. 'none' gives no keys.
    keys = 'auto',

    plate = 'DIVE', -- rental plate prefix + 4 digits

    rental = {
        spawnDistance = 180.0,  -- the boat is launched when you get this close to the launch point
        returnRange = 12.0,     -- how close you must be to the boat to hand it back
        damageFloor = 0.0,      -- a wrecked boat returns this share of the deposit
        abandonMinutes = 60,    -- a rental nobody touched for this long is removed (deposit lost)
    },

    antiExploit = {
        openSlack = 600,        -- ms of network slack allowed on a container's open time
        tolerance = 4.0,        -- extra metres allowed over openRange server-side
        maxDepthForOpen = -0.5, -- the diver's z must be below this to open a container
        airSlack = 1.5,         -- a client may report at most this x the real time as air used
        dropPlayer = false,
    },

    contract = {
        cooldown = 20,          -- seconds between accepting contracts
        spawnRefill = 12,       -- seconds between container refills around a diver
    },

    scoreboard = {
        limit = 25,
        cacheSeconds = 30,
        nameFormat = 'short',   -- 'short' = "Rex W." | 'full' = "Rex West"
    },

    recentDives = 6,

    -- Characters from the old MrJ-divingjob keep their progress: the first
    -- time they open the tablet, their `divingLevel` / `divingXP` metadata is
    -- turned into XP here.
    migrateMetadata = true,
}
