--[[
    trx_divingjob - client config
]]

return {
    debug = false,

    shopPed = {
        model = 's_m_y_baywatch_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        zOffset = -1.0,         -- nudge the ped up/down if it floats or sinks
        spawnDistance = 60.0,
        targetDistance = 2.5,
        icon = 'fa-solid fa-tablet-screen-button',
    },

    -- tablet prop + animation while the tablet is open (skipped in water / vehicles)
    tablet = {
        prop = 'prop_cs_tablet',
        dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base',
        clip = 'base',
        bone = 60309,
        offset = vec3(0.03, 0.002, -0.0),
        rotation = vec3(10.0, 160.0, 0.0),
        walkAwayClose = 8.0,    -- opened at the shop: walking this far closes it
    },

    hud = {
        enabled = true,
        position = 'right',     -- 'right' | 'left'
        top = 18,               -- % of screen height from the top
        lowAir = 20,            -- % at which the air gauge turns red and warns
    },

    zones = {
        blips = true,           -- show every zone on the map (locked ones greyed)
        blipSprite = 597,
        light = 40.0,           -- containers closer than this glow
        targetDistance = 3.0,
    },

    rental = {
        launchDistance = 150.0, -- the rented boat is put in the water when you get this close
        blipColour = 3,
    },

    breathHold = 25.0,          -- seconds of breath underwater with no tank on
    anchorKey = 47,             -- G: drop / raise anchor in a boat inside a zone
}
