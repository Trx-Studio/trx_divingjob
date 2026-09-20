-- trx_divingjob schema. The resource also creates these itself on first start;
-- this file is only for importing by hand.

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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `trx_divingjob_rewards` (
        `citizenid`  VARCHAR(50)  NOT NULL,
        `level`      TINYINT UNSIGNED NOT NULL,
        `claimed_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`, `level`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
