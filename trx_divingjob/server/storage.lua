--[[
    trx_divingjob - persistence (oxmysql)

    trx_divingjob_divers   one row per character, all-time totals
    trx_divingjob_log      one row per contract, per free dive and per loot sale
    trx_divingjob_rewards  one row per claimed level reward
]]

local Storage = {}

local SCHEMA = {
    [[
    CREATE TABLE IF NOT EXISTS `trx_divingjob_divers` (
        `citizenid`  VARCHAR(50)  NOT NULL,
        `name`       VARCHAR(100) NOT NULL DEFAULT '',
        `xp`         INT UNSIGNED NOT NULL DEFAULT 0,
        `containers` INT UNSIGNED NOT NULL DEFAULT 0,
        `earnings`   INT UNSIGNED NOT NULL DEFAULT 0,
        `contracts`  INT UNSIGNED NOT NULL DEFAULT 0,
        `dives`      INT UNSIGNED NOT NULL DEFAULT 0,
        `deepest`    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
        `migrated`   TINYINT(1)   NOT NULL DEFAULT 0,
        `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
    CREATE TABLE IF NOT EXISTS `trx_divingjob_log` (
        `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid`  VARCHAR(50)  NOT NULL,
        `kind`       VARCHAR(12)  NOT NULL,
        `zone`       VARCHAR(32)  NOT NULL DEFAULT '',
        `contract`   VARCHAR(32)  NOT NULL DEFAULT '',
        `containers` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
        `goal`       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
        `earnings`   INT UNSIGNED NOT NULL DEFAULT 0,
        `xp`         INT UNSIGNED NOT NULL DEFAULT 0,
        `completed`  TINYINT(1)   NOT NULL DEFAULT 0,
        `duration`   INT UNSIGNED NOT NULL DEFAULT 0,
        `depth`      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
        `ended_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_citizen` (`citizenid`),
        KEY `idx_ended` (`ended_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
    CREATE TABLE IF NOT EXISTS `trx_divingjob_rewards` (
        `citizenid`  VARCHAR(50)  NOT NULL,
        `level`      TINYINT UNSIGNED NOT NULL,
        `claimed_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `level`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
}

function Storage.init()
    for i = 1, #SCHEMA do
        MySQL.query.await(SCHEMA[i])
    end
end

local EMPTY = { xp = 0, containers = 0, earnings = 0, contracts = 0, dives = 0, deepest = 0, migrated = 0 }

---@param citizenid string
---@return table diver, boolean exists
function Storage.getDiver(citizenid)
    local row = MySQL.single.await('SELECT * FROM `trx_divingjob_divers` WHERE `citizenid` = ?', { citizenid })
    if row then return row, true end
    local out = { citizenid = citizenid, name = '' }
    for k, v in pairs(EMPTY) do out[k] = v end
    return out, false
end

---One-off: seed XP from the old resource's metadata.
function Storage.seed(citizenid, name, xp)
    MySQL.insert.await([[
        INSERT INTO `trx_divingjob_divers` (`citizenid`, `name`, `xp`, `migrated`) VALUES (?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE `migrated` = 1
    ]], { citizenid, name, xp })
end

---Adds one entry to the log and the diver's totals in one transaction.
---@param e { citizenid: string, name: string, kind: 'contract'|'free'|'sale'|'reward', zone?: string, contract?: string, containers?: integer, goal?: integer, earnings?: integer, xp?: integer, completed?: boolean, duration?: integer, depth?: integer }
function Storage.record(e)
    local containers, earnings, xp = e.containers or 0, e.earnings or 0, e.xp or 0
    local depth = math.floor(e.depth or 0)
    local contracts = (e.kind == 'contract' and e.completed) and 1 or 0
    local dives = (e.kind == 'contract' or e.kind == 'free') and 1 or 0
    return MySQL.transaction.await({
        {
            query = [[
                INSERT INTO `trx_divingjob_divers` (`citizenid`, `name`, `xp`, `containers`, `earnings`, `contracts`, `dives`, `deepest`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    `name` = VALUES(`name`),
                    `xp` = `xp` + VALUES(`xp`),
                    `containers` = `containers` + VALUES(`containers`),
                    `earnings` = `earnings` + VALUES(`earnings`),
                    `contracts` = `contracts` + VALUES(`contracts`),
                    `dives` = `dives` + VALUES(`dives`),
                    `deepest` = GREATEST(`deepest`, VALUES(`deepest`))
            ]],
            values = { e.citizenid, e.name, xp, containers, earnings, contracts, dives, depth },
        },
        {
            query = [[
                INSERT INTO `trx_divingjob_log`
                    (`citizenid`, `kind`, `zone`, `contract`, `containers`, `goal`, `earnings`, `xp`, `completed`, `duration`, `depth`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]],
            values = { e.citizenid, e.kind, e.zone or '', e.contract or '', containers, e.goal or 0, earnings, xp,
                e.completed and 1 or 0, math.floor(e.duration or 0), depth },
        },
    })
end

---@param citizenid string
---@param limit integer
function Storage.recent(citizenid, limit)
    return MySQL.query.await([[
        SELECT `kind`, `zone`, `contract`, `containers`, `goal`, `earnings`, `xp`, `completed`, `duration`, `depth`,
               UNIX_TIMESTAMP(`ended_at`) AS `ended`
        FROM `trx_divingjob_log` WHERE `citizenid` = ? AND `kind` IN ('contract', 'free')
        ORDER BY `id` DESC LIMIT ?
    ]], { citizenid, limit }) or {}
end

---@return table<integer, true>
function Storage.claimed(citizenid)
    local rows = MySQL.query.await('SELECT `level` FROM `trx_divingjob_rewards` WHERE `citizenid` = ?', { citizenid }) or {}
    local out = {}
    for i = 1, #rows do out[tonumber(rows[i].level)] = true end
    return out
end

---Marks a reward claimed. Returns false if it already was (the primary key decides, so a double click can't pay twice).
function Storage.claim(citizenid, level)
    local affected = MySQL.update.await('INSERT IGNORE INTO `trx_divingjob_rewards` (`citizenid`, `level`) VALUES (?, ?)', { citizenid, level })
    return (tonumber(affected) or 0) > 0
end

---Undo a claim whose payout failed.
function Storage.unclaim(citizenid, level)
    MySQL.query.await('DELETE FROM `trx_divingjob_rewards` WHERE `citizenid` = ? AND `level` = ?', { citizenid, level })
end

local SORTS = { containers = true, earnings = true, contracts = true, xp = true }

---@param period 'week'|'all'
---@param sort 'containers'|'earnings'|'contracts'|'xp'
function Storage.board(period, sort)
    if not SORTS[sort] then sort = 'containers' end

    if period == 'week' then
        -- `sort` is whitelisted above, so interpolating it is safe
        return MySQL.query.await(([[
            SELECT l.`citizenid`, d.`name`, d.`xp` AS `totalXp`,
                   SUM(l.`containers`) AS `containers`, SUM(l.`earnings`) AS `earnings`,
                   SUM(CASE WHEN l.`kind` = 'contract' THEN l.`completed` ELSE 0 END) AS `contracts`,
                   SUM(l.`xp`) AS `xp`, MAX(l.`depth`) AS `deepest`
            FROM `trx_divingjob_log` l
            JOIN `trx_divingjob_divers` d ON d.`citizenid` = l.`citizenid`
            WHERE YEARWEEK(l.`ended_at`, 1) = YEARWEEK(CURRENT_DATE, 1)
            GROUP BY l.`citizenid`, d.`name`, d.`xp`
            ORDER BY `%s` DESC, `containers` DESC
        ]]):format(sort)) or {}
    end

    return MySQL.query.await(([[
        SELECT `citizenid`, `name`, `xp` AS `totalXp`, `containers`, `earnings`, `contracts`, `xp`, `deepest`
        FROM `trx_divingjob_divers`
        WHERE `dives` > 0 OR `earnings` > 0
        ORDER BY `%s` DESC, `containers` DESC
    ]]):format(sort)) or {}
end

return Storage
