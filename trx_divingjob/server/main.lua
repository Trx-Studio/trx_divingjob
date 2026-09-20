--[[
    trx_divingjob - server

    The server owns everything that counts: where each diver's containers are,
    whether you were close enough and took long enough to open one, what was
    inside, how much air is left in each tank, the contract, the rental and
    the money. The client draws it.
]]

local config  = require 'config.server'
local shared  = require 'config.shared'
local Storage = require 'server.storage'
local Inv     = require 'server.integrations'

---@type table<integer, table> per-player state
local divers = {}

-- ---------------------------------------------------------------------------
-- lookups built once from the shared config
-- ---------------------------------------------------------------------------

local zoneById, contractById, tankByItem, boatByModel, shopItemByName = {}, {}, {}, {}, {}
for i = 1, #shared.zones do zoneById[shared.zones[i].id] = shared.zones[i] end
for i = 1, #shared.tanks do tankByItem[shared.tanks[i].item] = shared.tanks[i] end
for i = 1, #shared.boats do boatByModel[shared.boats[i].model] = shared.boats[i] end
for i = 1, #shared.shopItems do shopItemByName[shared.shopItems[i].item] = shared.shopItems[i] end

do -- fail loudly at boot on a typo in the tables, not mid-dive
    for i = 1, #shared.contracts do
        local c = shared.contracts[i]
        if not zoneById[c.zone] then error(('contract "%s" uses unknown zone "%s"'):format(c.id, c.zone)) end
        for _, t in ipairs(c.targets or {}) do
            if not shared.containers[t] then error(('contract "%s" uses unknown container "%s"'):format(c.id, t)) end
        end
        contractById[c.id] = c
    end
    for i = 1, #shared.zones do
        for _, t in ipairs(shared.zones[i].containers) do
            local def = shared.containers[t]
            if not def then error(('zone "%s" uses unknown container "%s"'):format(shared.zones[i].id, t)) end
            if not config.loot[def.loot] then error(('container "%s" uses unknown loot table "%s"'):format(t, def.loot)) end
        end
    end
end

local function levelFor(xp)
    local current, nextLevel = shared.levels[1], nil
    for i = 1, #shared.levels do
        if (xp or 0) >= shared.levels[i].xp then
            current = shared.levels[i]
            nextLevel = shared.levels[i + 1]
        end
    end
    return current, nextLevel
end

local function toint(v)
    local n = tonumber(v)
    return n and math.tointeger(math.floor(n)) or nil
end

local function notify(src, description, kind, duration)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('info.title'), description = description, type = kind or 'inform', duration = duration,
    })
end

local function money(n)
    local s = tostring(math.floor(n or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return '$' .. out:gsub('^,', '')
end

local function clock(sec)
    sec = math.max(0, math.floor(sec or 0))
    return ('%d:%02d'):format(sec // 60, sec % 60)
end

local function fail(reason) return { ok = false, reason = reason } end

-- ---------------------------------------------------------------------------
-- players
-- ---------------------------------------------------------------------------

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function displayName(player)
    local info = player.PlayerData.charinfo or {}
    local first, last = info.firstname or 'Unknown', info.lastname or ''
    if config.scoreboard.nameFormat == 'full' then
        return (first .. ' ' .. last):gsub('%s+$', '')
    end
    return last ~= '' and ('%s %s.'):format(first, last:sub(1, 1)) or first
end

---@return boolean ok, string? reason
local function canWork(player)
    if not shared.job then return true end
    local job = player and player.PlayerData.job
    if not job or job.name ~= shared.job then return false, locale('error.wrong_job') end
    return true
end

local function pedCoords(src)
    return GetEntityCoords(GetPlayerPed(src))
end

local function atShop(src)
    return #(pedCoords(src) - shared.shop.ped.xyz) <= shared.shop.range
end

local function exploit(src, what)
    lib.print.warn(('player %s failed a diving check: %s'):format(src, what))
    if config.antiExploit.dropPlayer then DropPlayer(src, locale('error.exploit_attempt')) end
    return fail(locale('error.check_failed'))
end

---Loads (or returns) a diver's state. XP in `d.xp` is the stored XP plus
---everything earned in the entry that is still open.
local function getDiver(src)
    local d = divers[src]
    if d then return d end
    local player = getPlayer(src)
    if not player then return nil end
    local citizenid = player.PlayerData.citizenid
    local row, exists = Storage.getDiver(citizenid)

    -- oxmysql returns TINYINT(1) as a boolean
    local migrated = row.migrated == true or row.migrated == 1
    if config.migrateMetadata and not migrated then
        local md = player.PlayerData.metadata or {}
        local oldLevel, oldXp = tonumber(md.divingLevel) or 1, tonumber(md.divingXP) or 0
        -- the old resource kept XP *within* the level, against these thresholds
        local OLD = { 0, 250, 450, 750, 1000, 2000, 3500, 5000, 7500, 10000 }
        local seeded = (OLD[math.max(1, math.min(#OLD, oldLevel))] or 0) + oldXp
        if not exists and seeded > 0 then
            Storage.seed(citizenid, displayName(player), math.floor(seeded))
            row = Storage.getDiver(citizenid)
            lib.print.info(('migrated %s from MrJ-divingjob: %d XP'):format(citizenid, math.floor(seeded)))
        elseif exists then
            MySQL.update('UPDATE `trx_divingjob_divers` SET `migrated` = 1 WHERE `citizenid` = ?', { citizenid })
        end
    end

    d = {
        src = src,
        citizenid = citizenid,
        name = displayName(player),
        stored = row,
        xp = tonumber(row.xp) or 0,
        entry = nil,        -- the open log entry (a contract or a free dive)
        contract = nil,     -- the active contract (also d.entry)
        spawned = {},       -- [id] = container
        nextId = 0,
        opening = nil,      -- { id, at }
        tank = nil,         -- { slot, item, def, synced }
        rental = nil,
        lastAccept = 0,
        zone = nil,
    }
    divers[src] = d
    return d
end

local function levelOf(d) return levelFor(d.xp) end

---Adds XP and announces a level-up. `direct` = already written to the database.
local function addXp(d, amount, direct)
    amount = math.floor(amount + 0.5)
    if amount <= 0 then return 0 end
    local before = levelOf(d)
    d.xp = d.xp + amount
    if d.entry and not direct then d.entry.xp = d.entry.xp + amount end
    local after = levelOf(d)
    if after.level > before.level then
        notify(d.src, locale('info.level_up', after.level, after.title), 'success', 9000)
        TriggerClientEvent('trx_divingjob:client:levelUp', d.src, after.level)
    end
    return amount
end

-- ---------------------------------------------------------------------------
-- log entries: a contract, or a free dive in one zone
-- ---------------------------------------------------------------------------

local function openEntry(d, kind, zone)
    d.entry = {
        kind = kind, zone = zone, containers = 0, earnings = 0, xp = 0,
        depth = 0, startedAt = os.time(), touched = os.time(),
    }
    return d.entry
end

---Writes the open entry to the database.
local function closeEntry(d, completed, extra)
    local e = d.entry
    if not e then return end
    d.entry = nil
    if e.kind == 'free' and e.containers == 0 then return end
    local ok, err = pcall(Storage.record, {
        citizenid = d.citizenid, name = d.name, kind = e.kind, zone = e.zone,
        contract = extra and extra.contract, goal = extra and extra.goal,
        containers = e.containers, earnings = e.earnings, xp = e.xp,
        completed = completed, duration = os.time() - e.startedAt, depth = e.depth,
    })
    if not ok then lib.print.error(('could not save dive for %s: %s'):format(d.citizenid, err)) end
end

-- ---------------------------------------------------------------------------
-- tanks
-- ---------------------------------------------------------------------------

local function tankMeta(def, air)
    air = math.max(0, math.min(def.air, air))
    return {
        air = math.floor(air * 10) / 10,
        -- never 0: ox_inventory refuses to use an item at 0 durability, and an
        -- empty tank still has to be usable so the diver can take it off
        durability = math.max(1, math.floor(air / def.air * 1000) / 10),
        description = locale('info.tank_meta', clock(air), clock(def.air), def.rating),
    }
end

---@return table? slot, table? def
local function tankInSlot(src, slot)
    slot = toint(slot)
    if not slot then return nil end
    local item = Inv.slot(src, slot)
    local def = item and tankByItem[item.name]
    if not def then return nil end
    return item, def
end

local function airOf(item, def)
    local air = item.metadata and tonumber(item.metadata.air)
    if air == nil then return def.air end -- a tank given without metadata counts as full
    return math.max(0, math.min(def.air, air))
end

local function refillCost(def, air)
    return math.ceil(def.refill * (1 - air / def.air))
end

local function myTanks(d)
    local list = Inv.slotsOf(d.src, tankByItem)
    local out = {}
    for i = 1, #list do
        local it = list[i]
        local def = tankByItem[it.name]
        local air = airOf(it, def)
        -- repair tanks saved at 0 durability by 2.0.0 (ox_inventory wouldn't let them be used)
        local dur = it.metadata and tonumber(it.metadata.durability)
        if dur and dur < 1 then Inv.setMetadata(d.src, it.slot, tankMeta(def, air)) end
        out[#out + 1] = {
            slot = it.slot, item = it.name, label = def.label, tier = def.tier,
            air = air, max = def.air, rating = def.rating,
            cost = refillCost(def, air),
            equipped = d.tank ~= nil and d.tank.slot == it.slot,
        }
    end
    return out
end

-- ---------------------------------------------------------------------------
-- containers
-- ---------------------------------------------------------------------------

local function inZone(src, zone, slack)
    local p = pedCoords(src)
    local dx, dy = p.x - zone.coords.x, p.y - zone.coords.y
    return math.sqrt(dx * dx + dy * dy) <= zone.radius + (slack or 0)
end

local function pickPosition(d, zone)
    local spacing = shared.minSpacing
    for attempt = 1, 40 do
        local ang = math.random() * math.pi * 2
        local r = math.sqrt(math.random()) * zone.radius * 0.8
        local x, y = zone.coords.x + math.cos(ang) * r, zone.coords.y + math.sin(ang) * r
        local clear = true
        for _, c in pairs(d.spawned) do
            local dx, dy = c.x - x, c.y - y
            if dx * dx + dy * dy < spacing * spacing then clear = false break end
        end
        if clear or attempt == 40 then return x, y end
    end
end

---Does this container type count towards the diver's contract?
local function counts(d, zone, kind)
    local c = d.contract
    if not c or c.zone ~= zone.id then return false end
    if not c.def.targets then return true end
    for i = 1, #c.def.targets do
        if c.def.targets[i] == kind then return true end
    end
    return false
end

local function spawnOne(d, zone, kind)
    d.nextId = d.nextId + 1
    local x, y = pickPosition(d, zone)
    local c = { id = d.nextId, kind = kind, zone = zone.id, x = x, y = y }
    d.spawned[c.id] = c
    return c
end

local function containerView(d, c)
    local zone = zoneById[c.zone]
    return { id = c.id, kind = c.kind, x = c.x, y = c.y, target = counts(d, zone, c.kind), floor = zone.coords.z - zone.depth }
end

---Tops the diver's containers up in `zone` and returns all of them.
local function fill(d, zone)
    -- containers belong to one zone at a time
    for id, c in pairs(d.spawned) do
        if c.zone ~= zone.id then d.spawned[id] = nil end
    end

    local have, targets = 0, 0
    for _, c in pairs(d.spawned) do
        have = have + 1
        if counts(d, zone, c.kind) then targets = targets + 1 end
    end

    -- a contract always has some of its targets on the seabed
    local contract = d.contract
    if contract and contract.zone == zone.id and contract.def.targets then
        local want = math.min(contract.def.goal - contract.done, 4)
        while targets < want do
            local list = contract.def.targets
            spawnOne(d, zone, list[math.random(#list)])
            targets = targets + 1
            have = have + 1
        end
    end

    while have < shared.maxContainers do
        spawnOne(d, zone, zone.containers[math.random(#zone.containers)])
        have = have + 1
    end

    local out = {}
    for _, c in pairs(d.spawned) do out[#out + 1] = containerView(d, c) end
    return out
end

-- ---------------------------------------------------------------------------
-- contracts
-- ---------------------------------------------------------------------------

local function contractView(d)
    local c = d.contract
    if not c then return false end
    local zone = zoneById[c.zone]
    return {
        id = c.def.id, label = c.def.label, zone = zone.id, zoneLabel = zone.label, code = zone.code, color = zone.color,
        goal = c.def.goal, done = c.done, earned = c.entry.earnings, xp = c.entry.xp,
        pay = c.pay, bonus = c.bonus, expires = c.expires, startedAt = c.entry.startedAt,
        targets = c.def.targets and (function()
            local l = {}
            for i = 1, #c.def.targets do l[i] = shared.containers[c.def.targets[i]].label end
            return l
        end)() or false,
        coords = { x = zone.coords.x, y = zone.coords.y },
        radius = zone.radius,
        now = os.time(),
    }
end

local function syncContract(d)
    TriggerClientEvent('trx_divingjob:client:contract', d.src, contractView(d))
end

---@param how 'complete'|'failed'|'cancelled'|'dropped'
local function endContract(d, how)
    local c = d.contract
    if not c then return end
    local e = c.entry
    local level = levelOf(d)
    local summary = {
        how = how, label = c.def.label, zone = zoneById[c.zone].label, code = zoneById[c.zone].code,
        color = zoneById[c.zone].color, goal = c.def.goal, done = c.done, containers = e.containers,
        earned = e.earnings, bonus = 0, xp = e.xp, duration = os.time() - e.startedAt, depth = e.depth,
        levelBefore = c.levelAtStart,
    }

    if how == 'complete' then
        local player = getPlayer(d.src)
        if player and Inv.pay(player, config.payAccount, c.bonus, 'trx-divingjob-contract') then
            e.earnings = e.earnings + c.bonus
            summary.bonus = c.bonus
            summary.earned = e.earnings
        end
        addXp(d, c.def.xp * level.payMult)
        summary.xp = e.xp
    end

    d.contract = nil
    closeEntry(d, how == 'complete', { contract = c.def.id, goal = c.def.goal })
    summary.levelAfter = levelOf(d).level
    summary.title = levelOf(d).title

    if how ~= 'dropped' then
        syncContract(d)
        TriggerClientEvent('trx_divingjob:client:summary', d.src, summary)
        -- the same containers stay on the seabed; only their contract marking changes
        local zone = d.zone and zoneById[d.zone]
        if zone and how ~= 'complete' then
            TriggerClientEvent('trx_divingjob:client:containers', d.src, fill(d, zone))
        end
    end
end

-- ---------------------------------------------------------------------------
-- rentals
-- ---------------------------------------------------------------------------

local function rentalView(d)
    local r = d.rental
    if not r then return false end
    local fuel, health
    if r.veh and DoesEntityExist(r.veh) then
        fuel = Inv.readFuel(r.veh)
        health = math.floor(math.max(0, GetVehicleBodyHealth(r.veh)) / 10)
    end
    return {
        model = r.boat.model, label = r.boat.label, plate = r.plate, fee = r.fee, deposit = r.deposit,
        launch = r.launchLabel, lx = r.launch.x, ly = r.launch.y, launched = r.launched,
        lost = r.launched and not (r.veh and DoesEntityExist(r.veh)) or false,
        netId = r.netId, fuel = fuel, health = health, fuelSystem = r.fuelSystem,
    }
end

local function syncRental(d)
    TriggerClientEvent('trx_divingjob:client:rental', d.src, rentalView(d), d.rental and {
        x = d.rental.launch.x, y = d.rental.launch.y, z = d.rental.launch.z, w = d.rental.launch.w,
    } or nil)
end

local function removeBoat(d)
    local r = d.rental
    if not r then return end
    if r.veh and DoesEntityExist(r.veh) then DeleteEntity(r.veh) end
    Inv.removeKeys(d.src, r.plate)
    d.rental = nil
end

local function boatSpawnFree(coords)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if #(GetEntityCoords(vehicles[i]) - coords.xyz) < 4.0 then return false end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- tablet
-- ---------------------------------------------------------------------------

local function plainZones(level)
    local out = {}
    for i = 1, #shared.zones do
        local z = shared.zones[i]
        local kinds = {}
        for j = 1, #z.containers do kinds[j] = shared.containers[z.containers[j]].label end
        out[i] = {
            id = z.id, code = z.code, label = z.label, color = z.color, level = z.level, area = z.area,
            depth = z.depth, tier = z.tier, radius = z.radius, x = z.coords.x, y = z.coords.y,
            launch = z.launch.label, containers = kinds, blurb = z.blurb, unlocked = level >= z.level,
        }
    end
    return out
end

local function plainContainers()
    local out = {}
    for id, c in pairs(shared.containers) do out[id] = { label = c.label, xp = c.xp } end
    return out
end

local function available(list, key)
    local out = {}
    for i = 1, #list do
        local e = list[i]
        local copy = {}
        for k, v in pairs(e) do copy[k] = v end
        copy.exists = Inv.item(e[key]) ~= nil
        out[#out + 1] = copy
    end
    return out
end

local function rewardsView(d, level)
    local claimed = Storage.claimed(d.citizenid)
    local out = {}
    for i = 1, #shared.levels do
        local l = shared.levels[i].level
        local r = shared.rewards[l]
        if r then
            local items = {}
            for j = 1, #(r.items or {}) do
                local it = r.items[j]
                if Inv.item(it.name) then
                    items[#items + 1] = { name = it.name, label = Inv.label(it.name), count = it.count }
                end
            end
            out[#out + 1] = {
                level = l, label = r.label, money = r.money or 0, items = items,
                state = claimed[l] and 'claimed' or (level >= l and 'ready' or 'locked'),
            }
        end
    end
    return out
end

local function sellView(src)
    local out = {}
    for name, price in pairs(config.sell) do
        if Inv.item(name) then
            local count = Inv.count(src, name)
            if count > 0 then
                out[#out + 1] = { name = name, label = Inv.label(name), price = price, count = count }
            end
        end
    end
    table.sort(out, function(a, b) return a.price * a.count > b.price * b.count end)
    return out
end

local function tabletData(src, fromShop)
    local player = getPlayer(src)
    local d = getDiver(src)
    if not player or not d then return nil end
    d.name = displayName(player)
    local ok, reason = canWork(player)
    local level, nextLevel = levelOf(d)
    local shop = fromShop and atShop(src) or false

    return {
        now = os.time(),
        allowed = ok,
        reason = reason,
        atShop = shop,
        shop = { label = shared.shop.label, short = shared.shop.short, x = shared.shop.ped.x, y = shared.shop.ped.y },
        diver = {
            name = d.name, xp = d.xp, level = level.level, title = level.title,
            payMult = level.payMult, airMult = level.airMult,
            levelXp = level.xp, nextXp = nextLevel and nextLevel.xp or nil, nextTitle = nextLevel and nextLevel.title or nil,
            containers = (tonumber(d.stored.containers) or 0) + (d.entry and d.entry.containers or 0),
            earnings = (tonumber(d.stored.earnings) or 0) + (d.entry and d.entry.earnings or 0),
            contracts = tonumber(d.stored.contracts) or 0,
            dives = tonumber(d.stored.dives) or 0,
            deepest = math.max(tonumber(d.stored.deepest) or 0, d.entry and d.entry.depth or 0),
        },
        levels = shared.levels,
        zones = plainZones(level.level),
        containers = plainContainers(),
        contracts = shared.contracts,
        tanks = available(shared.tanks, 'item'),
        shopItems = available(shared.shopItems, 'item'),
        boats = shared.boats,
        rewards = rewardsView(d, level.level),
        myTanks = myTanks(d),
        sell = shop and sellView(src) or {},
        contract = contractView(d),
        rental = rentalView(d),
        cooldown = math.max(0, d.lastAccept + config.contract.cooldown - os.time()),
        fuel = Inv.fuelSystem(),
        fuelPrice = config.fuel.pricePerPercent,
        recent = Storage.recent(d.citizenid, config.recentDives),
    }
end

-- refresh the stored totals whenever the tablet is opened
local function reloadStored(d)
    local row = Storage.getDiver(d.citizenid)
    d.stored = row
    d.xp = (tonumber(row.xp) or 0) + (d.entry and d.entry.xp or 0)
end

lib.callback.register('trx_divingjob:server:tablet', function(src, fromShop)
    local d = getDiver(src)
    if not d then return nil end
    if not fromShop and Inv.count(src, shared.items.tablet) < 1 then
        return nil -- the tablet item was used, so the player must still have one
    end
    reloadStored(d)
    return tabletData(src, fromShop == true)
end)

lib.callback.register('trx_divingjob:server:level', function(src)
    local d = getDiver(src)
    if not d then return nil end
    local level = levelOf(d)
    return { level = level.level, airMult = level.airMult, contract = contractView(d), rental = rentalView(d),
        launch = d.rental and { x = d.rental.launch.x, y = d.rental.launch.y, z = d.rental.launch.z, w = d.rental.launch.w } or nil }
end)

-- the weekly board is YEARWEEK(..., 1), which starts on Monday 00:00
local function secondsToMonday()
    local t = os.date('*t')
    local days = (9 - t.wday) % 7
    if days == 0 then days = 7 end
    return days * 86400 - (t.hour * 3600 + t.min * 60 + t.sec)
end

local boardCache = {}

lib.callback.register('trx_divingjob:server:scoreboard', function(src, period, sort)
    period = period == 'all' and 'all' or 'week'
    local key = period .. ':' .. tostring(sort)
    local cached = boardCache[key]
    local rows
    if cached and os.time() - cached.at < config.scoreboard.cacheSeconds then
        rows = cached.rows
    else
        rows = Storage.board(period, sort)
        boardCache[key] = { at = os.time(), rows = rows }
    end

    local d = getDiver(src)
    local me = d and d.citizenid
    local out, mine = {}, nil
    for i = 1, #rows do
        local r = rows[i]
        local entry = {
            rank = i,
            name = r.name,
            level = levelFor(tonumber(r.totalXp) or 0).level,
            containers = tonumber(r.containers) or 0,
            earnings = tonumber(r.earnings) or 0,
            contracts = tonumber(r.contracts) or 0,
            xp = tonumber(r.xp) or 0,
            deepest = tonumber(r.deepest) or 0,
            me = r.citizenid == me,
        }
        if entry.me then mine = entry end
        if i <= config.scoreboard.limit then out[#out + 1] = entry end
    end
    return { period = period, sort = sort, rows = out, me = mine, divers = #rows, resetsIn = secondsToMonday() }
end)

-- ---------------------------------------------------------------------------
-- shop: buy, refill, sell
-- ---------------------------------------------------------------------------

local function shopGate(src)
    local player = getPlayer(src)
    local d = getDiver(src)
    if not player or not d then return nil end
    local ok, reason = canWork(player)
    if not ok then return nil, nil, fail(reason) end
    if not atShop(src) then return nil, nil, fail(locale('error.not_at_shop')) end
    return player, d
end

lib.callback.register('trx_divingjob:server:buy', function(src, name)
    local player, d, err = shopGate(src)
    if not player then return err or fail() end
    if type(name) ~= 'string' then return fail(locale('error.bad_request')) end

    local tank, other = tankByItem[name], shopItemByName[name]
    local def = tank or other
    if not def or not Inv.item(name) then return fail(locale('error.bad_request')) end
    if levelOf(d).level < def.level then return fail(locale('error.locked', def.level)) end

    local metadata = tank and tankMeta(tank, tank.air) or nil
    if not exports.ox_inventory:CanCarryItem(src, name, 1, metadata) then return fail(locale('error.cant_carry')) end

    local paidFrom = Inv.charge(player, def.price, 'trx-divingjob-shop')
    if not paidFrom then return fail(locale('error.no_money', money(def.price))) end
    if not Inv.give(src, name, 1, metadata) then
        Inv.pay(player, paidFrom, def.price, 'trx-divingjob-refund')
        return fail(locale('error.cant_carry'))
    end
    return { ok = true, message = locale('info.bought', def.label, money(def.price)), tanks = myTanks(d) }
end)

local function refillSlot(d, item, def)
    local air = airOf(item, def)
    Inv.setMetadata(d.src, item.slot, tankMeta(def, def.air))
    if d.tank and d.tank.slot == item.slot then
        d.tank.synced = os.time()
        TriggerClientEvent('trx_divingjob:client:air', d.src, def.air)
    end
    return def.air - air
end

lib.callback.register('trx_divingjob:server:refill', function(src, slot)
    local player, d, err = shopGate(src)
    if not player then return err or fail() end

    local targets = {}
    if slot == 'all' then
        local list = Inv.slotsOf(src, tankByItem)
        for i = 1, #list do targets[#targets + 1] = list[i] end
    else
        local item = tankInSlot(src, slot)
        if not item then return fail(locale('error.no_tank')) end
        targets[1] = item
    end

    local total, work = 0, {}
    for i = 1, #targets do
        local def = tankByItem[targets[i].name]
        local cost = refillCost(def, airOf(targets[i], def))
        if cost > 0 then
            total = total + cost
            work[#work + 1] = { item = targets[i], def = def }
        end
    end
    if #work == 0 then return fail(locale('error.already_full')) end

    if not Inv.charge(player, total, 'trx-divingjob-refill') then return fail(locale('error.no_money', money(total))) end
    for i = 1, #work do refillSlot(d, work[i].item, work[i].def) end
    return { ok = true, message = locale('info.refilled', #work, money(total)), tanks = myTanks(d) }
end)

lib.callback.register('trx_divingjob:server:sell', function(src, name, count)
    local player, d, err = shopGate(src)
    if not player then return err or fail() end

    local names = {}
    if name == 'all' then
        for n in pairs(config.sell) do names[#names + 1] = n end
    elseif type(name) == 'string' and config.sell[name] then
        names[1] = name
    else
        return fail(locale('error.cant_sell'))
    end

    local total, sold = 0, 0
    for i = 1, #names do
        local n = names[i]
        if Inv.item(n) then
            local have = Inv.count(src, n)
            local qty = (name ~= 'all' and toint(count)) or have
            qty = math.min(math.max(qty, 0), have)
            if qty > 0 and Inv.take(src, n, qty) then
                total = total + qty * config.sell[n]
                sold = sold + qty
            end
        end
    end
    if sold == 0 then return fail(locale('error.nothing_to_sell')) end

    Inv.pay(player, config.sellAccount, total, 'trx-divingjob-sell')
    pcall(Storage.record, { citizenid = d.citizenid, name = d.name, kind = 'sale', earnings = total })
    d.stored.earnings = (tonumber(d.stored.earnings) or 0) + total
    return { ok = true, message = locale('info.sold', sold, money(total)), sell = sellView(src) }
end)

-- ---------------------------------------------------------------------------
-- tank use: equip, air, unequip
-- ---------------------------------------------------------------------------

lib.callback.register('trx_divingjob:server:equip', function(src, slot)
    local d = getDiver(src)
    if not d then return fail() end
    local item, def = tankInSlot(src, slot)
    if not item then return fail(locale('error.no_tank')) end
    local air = airOf(item, def)
    if air <= 0 then return fail(locale('error.tank_empty', def.label)) end
    d.tank = { slot = item.slot, item = item.name, def = def, synced = os.time() }
    return {
        ok = true, slot = item.slot, label = def.label, tier = def.tier, air = air, max = def.air,
        rating = def.rating, airMult = levelOf(d).airMult,
    }
end)

lib.callback.register('trx_divingjob:server:air', function(src, slot, used)
    local d = getDiver(src)
    if not d or not d.tank then return fail() end
    slot, used = toint(slot), tonumber(used)
    if slot ~= d.tank.slot or not used or used < 0 then return fail(locale('error.no_tank')) end

    local item, def = tankInSlot(src, slot)
    if not item or item.name ~= d.tank.item then
        d.tank = nil
        return fail(locale('error.tank_gone'))
    end

    local now = os.time()
    -- drain can be up to 2x (below rating); anything more than that plus slack is a lie
    local allowed = (now - d.tank.synced + 2) * 2 * config.antiExploit.airSlack
    if used > allowed then used = allowed end
    d.tank.synced = now

    local air = math.max(0, airOf(item, def) - used)
    Inv.setMetadata(src, slot, tankMeta(def, air))
    return { ok = true, air = air }
end)

lib.callback.register('trx_divingjob:server:unequip', function(src)
    local d = divers[src]
    if d then d.tank = nil end
    return true
end)

-- ---------------------------------------------------------------------------
-- zones + containers
-- ---------------------------------------------------------------------------

---The client says which zone it is in (or nil). Returns its containers.
lib.callback.register('trx_divingjob:server:zone', function(src, zoneId)
    local d = getDiver(src)
    if not d then return false end
    local player = getPlayer(src)
    local ok = player and canWork(player)
    local zone = zoneById[zoneId]

    if not zone or not ok then
        if d.entry and d.entry.kind == 'free' then closeEntry(d, false) end
        d.zone = nil
        if not d.contract then d.spawned = {} end
        return false
    end
    if not inZone(src, zone, 25.0) then return false end
    if levelOf(d).level < zone.level then return { locked = zone.level } end

    if d.entry and d.entry.kind == 'free' and d.entry.zone ~= zone.id then closeEntry(d, false) end
    d.zone = zone.id
    return { containers = fill(d, zone) }
end)

lib.callback.register('trx_divingjob:server:beginOpen', function(src, id)
    local d = divers[src]
    local c = d and d.spawned[toint(id) or -1]
    if not c then return fail(locale('error.container_gone')) end
    local p = pedCoords(src)
    local dx, dy = p.x - c.x, p.y - c.y
    if math.sqrt(dx * dx + dy * dy) > shared.openRange + config.antiExploit.tolerance then
        return fail(locale('error.too_far'))
    end
    if p.z > config.antiExploit.maxDepthForOpen then return fail(locale('error.not_underwater')) end
    d.opening = { id = c.id, at = GetGameTimer() }
    return { ok = true, time = shared.containers[c.kind].open }
end)

lib.callback.register('trx_divingjob:server:finishOpen', function(src, id)
    local d = divers[src]
    if not d then return fail() end
    id = toint(id)
    local c = id and d.spawned[id]
    local o = d.opening
    d.opening = nil
    if not c or not o or o.id ~= id then return fail(locale('error.container_gone')) end

    local def = shared.containers[c.kind]
    if GetGameTimer() - o.at < def.open - config.antiExploit.openSlack then
        return exploit(src, ('opened %s too fast'):format(c.kind))
    end
    local p = pedCoords(src)
    local dx, dy = p.x - c.x, p.y - c.y
    if math.sqrt(dx * dx + dy * dy) > shared.openRange + config.antiExploit.tolerance then
        return exploit(src, 'moved away while opening')
    end

    local zone = zoneById[c.zone]
    local player = getPlayer(src)
    if not player then return fail() end
    d.spawned[id] = nil

    if not d.entry then openEntry(d, 'free', zone.id) end
    local e = d.entry
    e.touched = os.time()
    e.containers = e.containers + 1
    e.depth = math.max(e.depth, math.floor(-p.z))

    local found, rare = Inv.rollLoot(src, def.loot)
    local counted = counts(d, zone, c.kind)
    local level = levelOf(d)

    local xp = def.xp * (counted and 1 or config.xp.freeDive) + rare * config.xp.rareFind
    local gained = addXp(d, xp)

    local paid = 0
    local contract = d.contract
    if counted then
        contract.done = contract.done + 1
        if Inv.pay(player, config.payAccount, contract.pay, 'trx-divingjob-contract') then
            paid = contract.pay
            e.earnings = e.earnings + paid
        end
    end

    local res = {
        ok = true, label = def.label, found = found, xp = gained, paid = paid, counted = counted,
        level = levelOf(d).level, levelBefore = level.level,
    }

    if counted and contract.done >= contract.def.goal then
        endContract(d, 'complete')
        res.complete = true
    elseif counted then
        syncContract(d)
    end

    -- replace what was opened
    if d.zone == zone.id then
        res.containers = fill(d, zone)
    end
    return res
end)

-- ---------------------------------------------------------------------------
-- contracts
-- ---------------------------------------------------------------------------

lib.callback.register('trx_divingjob:server:accept', function(src, id)
    local player = getPlayer(src)
    local d = getDiver(src)
    if not player or not d then return fail() end
    local ok, reason = canWork(player)
    if not ok then return fail(reason) end
    if d.contract then return fail(locale('error.contract_active')) end

    local def = contractById[id]
    if not def then return fail(locale('error.bad_request')) end
    local zone = zoneById[def.zone]
    local level = levelOf(d)
    if level.level < zone.level then return fail(locale('error.locked', zone.level)) end

    local wait = d.lastAccept + config.contract.cooldown - os.time()
    if wait > 0 then return fail(locale('error.cooldown', wait)) end
    d.lastAccept = os.time()

    if d.entry then closeEntry(d, false) end
    local entry = openEntry(d, 'contract', zone.id)
    d.contract = {
        def = def, zone = zone.id, done = 0, entry = entry,
        pay = math.floor(def.pay * level.payMult + 0.5),
        bonus = math.floor(def.bonus * level.payMult + 0.5),
        expires = os.time() + def.time * 60,
        levelAtStart = level.level,
    }
    syncContract(d)
    if d.zone == zone.id then
        TriggerClientEvent('trx_divingjob:client:containers', src, fill(d, zone))
    end
    return { ok = true, contract = contractView(d) }
end)

lib.callback.register('trx_divingjob:server:cancel', function(src)
    local d = divers[src]
    if not d or not d.contract then return fail(locale('error.no_contract')) end
    endContract(d, 'cancelled')
    return { ok = true }
end)

-- ---------------------------------------------------------------------------
-- rewards
-- ---------------------------------------------------------------------------

lib.callback.register('trx_divingjob:server:claim', function(src, lvl)
    local player = getPlayer(src)
    local d = getDiver(src)
    if not player or not d then return fail() end
    lvl = toint(lvl)
    local reward = lvl and shared.rewards[lvl]
    if not reward then return fail(locale('error.bad_request')) end
    if levelOf(d).level < lvl then return fail(locale('error.locked', lvl)) end

    local give = {}
    for i = 1, #(reward.items or {}) do
        local it = reward.items[i]
        if Inv.item(it.name) then
            local tank = tankByItem[it.name]
            local metadata = tank and tankMeta(tank, tank.air) or nil
            if not exports.ox_inventory:CanCarryItem(src, it.name, it.count, metadata) then
                return fail(locale('error.cant_carry'))
            end
            give[#give + 1] = { name = it.name, count = it.count, metadata = metadata }
        end
    end

    if not Storage.claim(d.citizenid, lvl) then return fail(locale('error.claimed')) end

    for i = 1, #give do
        Inv.give(src, give[i].name, give[i].count, give[i].metadata)
    end
    if (reward.money or 0) > 0 then
        Inv.pay(player, config.payAccount, reward.money, 'trx-divingjob-reward')
    end
    return { ok = true, message = locale('info.claimed', reward.label), rewards = rewardsView(d, levelOf(d).level) }
end)

-- ---------------------------------------------------------------------------
-- boat rental
-- ---------------------------------------------------------------------------

lib.callback.register('trx_divingjob:server:rent', function(src, model, zoneId)
    local player, d, err = shopGate(src)
    if not player then return err or fail() end
    if d.rental then return fail(locale('error.rental_active')) end

    local boat, zone = boatByModel[model], zoneById[zoneId]
    if not boat or not zone then return fail(locale('error.bad_request')) end
    local level = levelOf(d).level
    if level < boat.level then return fail(locale('error.locked', boat.level)) end
    if level < zone.level then return fail(locale('error.locked', zone.level)) end

    local total = boat.fee + boat.deposit
    local paidFrom = Inv.charge(player, total, 'trx-divingjob-rental')
    if not paidFrom then return fail(locale('error.no_money', money(total))) end

    d.rental = {
        boat = boat, fee = boat.fee, deposit = boat.deposit, paidFrom = paidFrom,
        launch = zone.launch.coords, launchLabel = zone.launch.label,
        plate = ('%s%04d'):format(config.plate, math.random(0, 9999)),
        launched = false, lastUse = os.time(),
    }
    syncRental(d)
    return { ok = true, message = locale('info.rented', boat.label, zone.launch.label) }
end)

---The client is close to its launch point: put the boat in the water now, so
---a player is in scope to own it.
lib.callback.register('trx_divingjob:server:launch', function(src)
    local d = divers[src]
    local r = d and d.rental
    if not r or r.launched or r.launching then return false end
    if #(pedCoords(src) - r.launch.xyz) > config.rental.spawnDistance + 40.0 then return false end
    if not boatSpawnFree(r.launch) then
        notify(src, locale('error.launch_blocked'), 'error')
        return false
    end

    r.launching = true
    local veh = CreateVehicleServerSetter(joaat(r.boat.model), r.boat.type, r.launch.x, r.launch.y, r.launch.z, r.launch.w)
    local tries = 0
    while not DoesEntityExist(veh) and tries < 50 do
        Wait(20)
        tries = tries + 1
    end
    r.launching = false
    if veh == 0 or not DoesEntityExist(veh) then
        notify(src, locale('error.failed_to_spawn'), 'error')
        return false
    end
    if divers[src] ~= d or d.rental ~= r then
        DeleteEntity(veh)
        return false
    end

    SetVehicleNumberPlateText(veh, r.plate)
    Entity(veh).state:set('trx_divingjob:rental', src, true)
    r.veh = veh
    r.netId = NetworkGetNetworkIdFromEntity(veh)
    r.launched = true
    r.lastUse = os.time()
    r.fuelSystem = Inv.fillTank(veh)
    Inv.giveKeys(src, veh, r.plate)
    syncRental(d)
    return { netId = r.netId, fuelSystem = r.fuelSystem, fuel = config.fuel.start, plate = r.plate }
end)

---Hands the boat back. Before launch: full refund. After: the deposit, less
---damage and the fuel used (when the fuel system lets the server read it).
lib.callback.register('trx_divingjob:server:returnBoat', function(src, clientFuel)
    local d = divers[src]
    local r = d and d.rental
    if not r then return fail(locale('error.no_rental')) end
    local player = getPlayer(src)
    if not player then return fail() end

    if not r.launched then
        if not atShop(src) then return fail(locale('error.not_at_shop')) end
        Inv.pay(player, r.paidFrom, r.fee + r.deposit, 'trx-divingjob-rental-refund')
        removeBoat(d)
        syncRental(d)
        return { ok = true, message = locale('info.rental_cancelled', money(r.fee + r.deposit)) }
    end

    if not (r.veh and DoesEntityExist(r.veh)) then
        removeBoat(d)
        syncRental(d)
        return { ok = true, message = locale('info.rental_lost') }
    end

    if #(pedCoords(src) - GetEntityCoords(r.veh)) > config.rental.returnRange then
        return fail(locale('error.boat_far'))
    end

    local health = math.max(0, math.min(1000, GetVehicleBodyHealth(r.veh))) / 1000
    local refund = r.deposit * (config.rental.damageFloor + (1 - config.rental.damageFloor) * health)

    -- ox_fuel: the server reads the statebag. Other systems: the client's reading, capped.
    local fuel = Inv.readFuel(r.veh)
    if not fuel then fuel = math.max(0, math.min(100, tonumber(clientFuel) or config.fuel.start)) end
    local used = math.max(0, config.fuel.start - fuel)
    local fuelCost = math.floor(used * config.fuel.pricePerPercent + 0.5)
    refund = math.max(0, math.floor(refund - fuelCost))

    Inv.pay(player, r.paidFrom, refund, 'trx-divingjob-deposit')
    local label = r.boat.label
    removeBoat(d)
    syncRental(d)
    return { ok = true, message = locale('info.returned', label, money(refund), math.floor(used), money(fuelCost)) }
end)

-- ---------------------------------------------------------------------------
-- housekeeping
-- ---------------------------------------------------------------------------

local function dropDiver(src, keepRental)
    local d = divers[src]
    if not d then return end
    if d.contract then endContract(d, 'dropped') end
    if d.entry then closeEntry(d, false) end
    if not keepRental then removeBoat(d) end
    divers[src] = nil
end

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for src, d in pairs(divers) do
            if d.contract and now >= d.contract.expires then
                notify(src, locale('info.contract_failed', d.contract.def.label), 'error', 8000)
                endContract(d, 'failed')
            end
            -- a free dive nobody touched for 10 minutes is over
            if d.entry and d.entry.kind == 'free' and now - d.entry.touched > 600 then
                closeEntry(d, false)
            end
            local r = d.rental
            if r and r.launched and r.veh and DoesEntityExist(r.veh) then
                if #(pedCoords(src) - GetEntityCoords(r.veh)) < 150.0 then
                    r.lastUse = now
                elseif now - r.lastUse > config.rental.abandonMinutes * 60 then
                    notify(src, locale('info.rental_abandoned', r.boat.label), 'error', 8000)
                    removeBoat(d)
                    syncRental(d)
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    dropDiver(source)
end)

-- a local event from qbx_core (never a net event: a client could name any source)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    if src then dropDiver(src) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for src in pairs(divers) do dropDiver(src) end
end)

AddEventHandler('ox_inventory:itemList', function()
    Inv.resetCache()
end)

MySQL.ready(function()
    Storage.init()
    local missing = {}
    for i = 1, #shared.tanks do
        if not Inv.item(shared.tanks[i].item) then missing[#missing + 1] = shared.tanks[i].item end
    end
    if not Inv.item(shared.items.tablet) then missing[#missing + 1] = shared.items.tablet end
    if #missing > 0 then
        lib.print.warn(('add these items to ox_inventory (see README): %s'):format(table.concat(missing, ', ')))
    end
    --lib.print.info(('ready - fuel: %s, keys: %s'):format(Inv.fuelSystem(), Inv.keySystem()))
end)

lib.addCommand('diverxp', {
    help = 'Give a player diving XP (admin)',
    params = {
        { name = 'id', help = 'Player ID', type = 'playerId' },
        { name = 'xp', help = 'XP to add', type = 'number' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local d = getDiver(args.id)
    local xp = math.floor(tonumber(args.xp) or 0)
    if not d or xp <= 0 then return end
    pcall(Storage.record, { citizenid = d.citizenid, name = d.name, kind = 'admin', xp = xp })
    addXp(d, xp, true)
    if source > 0 then notify(source, locale('info.admin_xp', args.xp, args.id), 'success') end
end)

-- ---------------------------------------------------------------------------
-- exports
-- ---------------------------------------------------------------------------

exports('GetDiver', function(src)
    local d = getDiver(src)
    if not d then return nil end
    local level = levelOf(d)
    return { xp = d.xp, level = level.level, title = level.title, contract = contractView(d) or nil }
end)

exports('IsOnContract', function(src)
    local d = divers[src]
    return d ~= nil and d.contract ~= nil
end)
