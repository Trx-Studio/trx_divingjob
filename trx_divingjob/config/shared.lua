--[[
    trx_divingjob - shared config (read by client AND server)

    Depth is measured from the sea surface (z = 0), so a diver at z = -34 is
    34 m down. Zone `depth` is only what the tablet shows; the real depth is
    whatever the seabed is where you swim.
]]

return {
    -- Job gate. false = anyone can dive. Set a job name ('diver') to lock the
    -- tablet's contracts, the shop and the rentals to that job.
    job = false,

    -- ---------------------------------------------------------------------
    -- The dive shop: the ped stands here. Target him to open the tablet with
    -- the Shop and Boats tabs unlocked. Using the tablet item anywhere opens
    -- the same tablet without them.
    -- ---------------------------------------------------------------------
    shop = {
        label = 'Vespucci Dive Shop.',
        short = 'Dive Co.',
        ped = vec4(-1338.52, -1261.21, 4.89, 24.98),
        range = 2.8, -- how close to the ped the server accepts shop actions
        blip = { sprite = 597, colour = 3, scale = 0.8 },
    },

    -- ox_inventory item names
    items = {
        tablet = 'dive_tablet',
    },

    -- ---------------------------------------------------------------------
    -- Levels. XP needed to REACH each level. `payMult` scales contract pay,
    -- `airMult` scales how fast a tank drains (0.80 = air lasts 25% longer).
    -- ---------------------------------------------------------------------
    levels = {
        { level = 1, xp = 0,    title = 'Snorkeler',        payMult = 1.00, airMult = 1.00 },
        { level = 2, xp = 800,  title = 'Open Water Diver', payMult = 1.10, airMult = 0.95 },
        { level = 3, xp = 1600, title = 'Advanced Diver',   payMult = 1.20, airMult = 0.90 },
        { level = 4, xp = 3200, title = 'Rescue Diver',     payMult = 1.35, airMult = 0.85 },
        { level = 5, xp = 6400, title = 'Dive Master',      payMult = 1.50, airMult = 0.80 },
    },

    -- ---------------------------------------------------------------------
    -- Scuba tanks. Each is its own ox_inventory item (see README).
    --   air    seconds of air in a full tank (at level 1, at or above its rating)
    --   rating deepest safe depth in metres. Below it the tank drains twice as fast.
    --          The seabed at Coral Reef is ~36 m, so every tank must cover at least that.
    --   price  shop price, refill = cost to refill from empty (scaled by air missing)
    -- ---------------------------------------------------------------------
    tanks = {
        { item = 'dive_tank_al40',  label = 'AL40 Pony',        tag = 'Aluminium · 5.7 L',   tier = 1, level = 1, air = 240,  rating = 45,  price = 750,  refill = 60,
          blurb = 'Small, light, cheap. Enough for a reef and back.' },
        { item = 'dive_tank_al80',  label = 'AL80 Standard',    tag = 'Aluminium · 11.1 L',  tier = 2, level = 2, air = 360,  rating = 60,  price = 1500, refill = 100,
          blurb = 'The tank every dive school hands you.' },
        { item = 'dive_tank_hp100', label = 'HP100 Steel',      tag = 'High pressure steel', tier = 3, level = 3, air = 540,  rating = 90,  price = 3000, refill = 160,
          blurb = 'More gas, less buoyancy. Built for wrecks.' },
        { item = 'dive_tank_twin',  label = 'Twin 12 Manifold', tag = 'Doubles · isolator',  tier = 4, level = 4, air = 780,  rating = 130,  price = 5500, refill = 240,
          blurb = 'Two cylinders on one manifold for long, deep work.' },
        { item = 'dive_tank_ccr',   label = 'CCR Rebreather',   tag = 'Closed circuit',      tier = 5, level = 5, air = 1200, rating = 200, price = 9000, refill = 350,
          blurb = 'Recycles every breath. Silent, deep and very long.' },
    },

    -- Other things the shop sells. Items your ox_inventory doesn't know are hidden.
    shopItems = {
        { item = 'dive_tablet', label = 'Dive Tablet', price = 250, level = 1,
          blurb = 'Contracts, scoreboard, your level and rewards - anywhere.' },
    },

    -- ---------------------------------------------------------------------
    -- Boats. Rented at the shop, waiting at the launch of the zone you pick.
    --   fee      kept by the shop
    --   deposit  returned when you hand the boat back (less damage and fuel used)
    --   type     CreateVehicleServerSetter type: 'boat' or 'submarine'
    -- ---------------------------------------------------------------------
    boats = {
        { model = 'dinghy',      label = 'Dinghy',      tag = 'Inflatable · 4 seats',  level = 1, fee = 150, deposit = 500,  type = 'boat', speed = 2, seats = 4,
          blurb = 'Slow, stable and hard to sink. Perfect dive platform.' },
        { model = 'seashark',    label = 'Seashark',    tag = 'Jet ski · 2 seats',     level = 2, fee = 200, deposit = 600,  type = 'boat', speed = 4, seats = 2,
          blurb = 'Quick out to the site. Nowhere to put your feet up.' },
        { model = 'tropic',      label = 'Tropic',      tag = 'Speedboat · 4 seats',   level = 3, fee = 350, deposit = 1000, type = 'boat', speed = 3, seats = 4,
          blurb = 'A proper boat with room for the whole team.' },
        { model = 'speeder',     label = 'Speeder',     tag = 'Performance · 4 seats', level = 4, fee = 500, deposit = 1500, type = 'boat', speed = 5, seats = 4,
          blurb = 'Gets to the far sites before your air does.' },
        { model = 'submersible', label = 'Submersible', tag = 'Submarine · 1 seat',    level = 5, fee = 900, deposit = 3000, type = 'submarine', speed = 1, seats = 1,
          blurb = 'Go down with the site. The dive master\'s ride.' },
    },

    -- ---------------------------------------------------------------------
    -- Things on the seabed. `loot` names a table in config/server.lua.
    -- `open` = ms to open it.
    -- ---------------------------------------------------------------------
    containers = {
        small_box        = { label = 'Small Box',        model = 'prop_box_wood02a',     open = 3500, xp = 8,  loot = 'common' },
        crate            = { label = 'Crate',            model = 'prop_box_wood04a',     open = 4500, xp = 12, loot = 'common' },
        coral_fragment   = { label = 'Coral Fragment',   model = 'prop_rock_4_c_2_cr',   open = 3500, xp = 10, loot = 'reef' },
        safe             = { label = 'Safe',             model = 'prop_ld_int_safe_01',  open = 7000, xp = 18, loot = 'wreck' },
        shipwreck_debris = { label = 'Wreck Debris',     model = 'prop_rub_carwreck_12', open = 5500, xp = 14, loot = 'wreck' },
        deep_sea_crate   = { label = 'Deep Sea Crate',   model = 'prop_box_wood05a',     open = 6000, xp = 20, loot = 'deep' },
        treasure_chest   = { label = 'Treasure Chest',   model = 'prop_treasure_chest',  open = 8000, xp = 30, loot = 'treasure' },
        black_box        = { label = 'Flight Recorder',  model = 'prop_ld_case_01',      open = 6500, xp = 35, loot = 'deep' },
    },

    -- ---------------------------------------------------------------------
    -- Dive zones. Containers only spawn while you are inside one you have
    -- unlocked. `launch` is where a rented boat waits (it must be on water).
    -- ---------------------------------------------------------------------
    zones = {
        {
            id = 'reef', code = 'R1', label = 'Coral Reef', color = '#4FA3E0', level = 1,
            area = 'Off Vespucci Beach', depth = 35, tier = 1,
            coords = vec3(-1808.66, -1378.91, -0.94), radius = 100.0,
            containers = { 'small_box', 'crate', 'coral_fragment' },
            launch = { label = 'Puerto Del Sol Marina', coords = vec4(-793.58, -1501.40, 0.12, 111.5) },
            blurb = 'Warm, busy and close to shore. The place to learn.',
        },
        {
            id = 'wreck', code = 'W2', label = 'Shipwreck Bay', color = '#5FB3A1', level = 2,
            area = 'Off Del Perro Pier', depth = 25, tier = 2,
            coords = vec3(-2000.33, -1113.67, -1.16), radius = 80.0,
            containers = { 'safe', 'crate', 'shipwreck_debris' },
            launch = { label = 'Puerto Del Sol Marina', coords = vec4(-793.58, -1501.40, 0.12, 111.5) },
            blurb = 'An old freighter broke up here. Its cargo never left.',
        },
        {
            id = 'shore', code = 'S2', label = 'Crash Site Shore', color = '#E0C04F', level = 2,
            area = 'East coast · Palomino', depth = 30, tier = 2,
            coords = vec3(3015.86, 82.25, -1.14), radius = 95.0,
            containers = { 'small_box', 'crate', 'shipwreck_debris' },
            launch = { label = 'Crash Site Shore', coords = vec4(2940.00, 82.25, 0.30, 90.0) },
            blurb = 'The edge of the debris field. Light scatter, easy access.',
        },
        {
            id = 'bay', code = 'B3', label = 'Crash Site Bay', color = '#B48EDB', level = 3,
            area = 'East coast · Palomino', depth = 50, tier = 3,
            coords = vec3(3047.98, -128.87, -1.19), radius = 65.0,
            containers = { 'safe', 'crate', 'shipwreck_debris' },
            launch = { label = 'Crash Site Bay', coords = vec4(2996.00, -128.87, 0.30, 90.0) },
            blurb = 'Heavier wreckage and the safes that went down with it.',
        },
        {
            id = 'trench', code = 'T4', label = 'Deep Trench', color = '#EE9A2E', level = 4,
            area = 'Off Pacific Bluffs', depth = 80, tier = 4,
            coords = vec3(-2082.02, -1351.45, -1.73), radius = 120.0,
            containers = { 'safe', 'crate', 'deep_sea_crate', 'treasure_chest' },
            launch = { label = 'Puerto Del Sol Marina', coords = vec4(-793.58, -1501.40, 0.12, 111.5) },
            blurb = 'Cold and dark. The good stuff sinks the furthest.',
        },
        {
            id = 'crash', code = 'X5', label = 'Crash Site', color = '#D9644A', level = 5,
            area = 'East coast · deep water', depth = 120, tier = 5,
            coords = vec3(3167.11, -356.38, -1.23), radius = 120.0,
            containers = { 'crate', 'deep_sea_crate', 'black_box' },
            launch = { label = 'Crash Site', coords = vec4(3071.00, -356.38, 0.30, 90.0) },
            blurb = 'Where the aircraft came down. Bring your best tank.',
        },
    },

    -- ---------------------------------------------------------------------
    -- Contracts. Pick one on the tablet. Open `goal` containers in the zone
    -- (only the listed `targets` count; nil = any container).
    --   pay     per counted container, to the bank, the moment it is opened
    --   bonus   paid when the goal is reached
    --   time    minutes to finish. Run out and the contract fails (you keep what you were paid).
    -- ---------------------------------------------------------------------
    contracts = {
        { id = 'reef_clean',   zone = 'reef',   label = 'Reef Clean-up',     goal = 6,  pay = 55,  bonus = 250,  xp = 50,  time = 20,
          blurb = 'Drop-offs from the beach bars. Get it off the coral.' },
        { id = 'reef_samples', zone = 'reef',   label = 'Coral Samples',     goal = 4,  pay = 80,  bonus = 300,  xp = 60,  time = 20, targets = { 'coral_fragment' },
          blurb = 'The university wants fragments. Only fragments.' },

        { id = 'wreck_salvage', zone = 'wreck', label = 'Wreck Salvage',     goal = 8,  pay = 70,  bonus = 450,  xp = 90,  time = 25,
          blurb = 'Anything worth lifting from the freighter.' },
        { id = 'wreck_safes',   zone = 'wreck', label = 'Captain\'s Safes',  goal = 3,  pay = 160, bonus = 500,  xp = 100, time = 25, targets = { 'safe' },
          blurb = 'Three safes are on the manifest. Find them.' },

        { id = 'shore_survey', zone = 'shore',  label = 'Debris Survey',     goal = 5,  pay = 75,  bonus = 400,  xp = 80,  time = 25, targets = { 'shipwreck_debris' },
          blurb = 'Tag and lift the big pieces for the investigators.' },
        { id = 'shore_sweep',  zone = 'shore',  label = 'Shore Sweep',       goal = 10, pay = 50,  bonus = 450,  xp = 95,  time = 25,
          blurb = 'Clear the shallows before the tourists find it.' },

        { id = 'bay_safes',   zone = 'bay',     label = 'Safe Recovery',     goal = 4,  pay = 170, bonus = 700,  xp = 140, time = 25, targets = { 'safe' },
          blurb = 'Passenger valuables. The insurers want them back.' },
        { id = 'bay_salvage', zone = 'bay',     label = 'Bay Salvage',       goal = 10, pay = 70,  bonus = 650,  xp = 130, time = 30,
          blurb = 'Everything in the bay, no questions asked.' },

        { id = 'trench_cargo',    zone = 'trench', label = 'Deep Cargo',     goal = 5,  pay = 150, bonus = 900,  xp = 180, time = 30, targets = { 'deep_sea_crate' },
          blurb = 'Sealed crates, stamped and deep. Mind your air.' },
        { id = 'trench_treasure', zone = 'trench', label = 'Treasure Hunt',  goal = 3,  pay = 260, bonus = 1100, xp = 220, time = 30, targets = { 'treasure_chest' },
          blurb = 'Old chests. Old gold. Old stories.' },

        { id = 'crash_boxes', zone = 'crash',   label = 'Black Box',         goal = 2,  pay = 450, bonus = 1500, xp = 280, time = 30, targets = { 'black_box' },
          blurb = 'Both flight recorders. The inquiry is waiting.' },
        { id = 'crash_wreck', zone = 'crash',   label = 'Wreckage Recovery', goal = 12, pay = 110, bonus = 1400, xp = 260, time = 35,
          blurb = 'Lift everything you can reach. Then go deeper.' },
    },

    -- ---------------------------------------------------------------------
    -- Level rewards. Claimed once per character from the Rewards tab.
    -- Items your ox_inventory doesn't know are skipped (the money is still paid).
    -- A tank given here arrives full.
    -- ---------------------------------------------------------------------
    rewards = {
        [1] = { label = 'Welcome kit',     money = 0,     items = { { name = 'dive_tank_al40', count = 1 } } },
        [2] = { label = 'Certified',       money = 1000,  items = {} },
        [3] = { label = 'Wreck ready',     money = 2500,  items = { { name = 'dive_tank_al80', count = 1 } } },
        [4] = { label = 'Rescue bonus',    money = 5000,  items = {} },
        [5] = { label = 'Dive Master',     money = 10000, items = {} },
    },

    maxContainers = 14,     -- containers around you at once inside a zone
    minSpacing = 8.0,       -- metres between containers
    openRange = 6.0,        -- how close (2D) you must be to open one
}
