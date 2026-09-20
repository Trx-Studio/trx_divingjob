ox_inventory items
return {
	["ruby"] = {
		label = 'Ruby',
		weight = 100,
	},

	["diamond"] = {
		label = 'Diamond',
		weight = 100,
	},

    ["emerald"] = {
		label = 'Emerald',
		weight = 100,
	},
    ['dive_tablet'] = {
        label = 'Dive Tablet', 
        weight = 500, 
        stack = false, 
        close = true,
        description = 'Contracts, scoreboard, your level and rewards',
        client = { 
            export = 'trx_divingjob.useTablet' 
        },
    },
    ['dive_tank_al40'] = {
        label = 'AL40 Pony Tank', 
        weight = 4000, 
        stack = false, 
        close = true,
        description = 'Scuba tank. Use it to put it on or take it off.',
        client = { 
            export = 'trx_divingjob.useTank' 
        },
    },
    ['dive_tank_al80'] = {
        label = 'AL80 Standard Tank', 
        weight = 7000, 
        stack = false, 
        close = true,
        description = 'Scuba tank. Use it to put it on or take it off.',
        client = { 
            export = 'trx_divingjob.useTank' 
        },
    },
    ['dive_tank_hp100'] = {
        label = 'HP100 Steel Tank', 
        weight = 9000, 
        stack = false, 
        close = true,
        description = 'Scuba tank. Use it to put it on or take it off.',
        client = { 
            export = 'trx_divingjob.useTank' 
        },
    },
    ['dive_tank_twin'] = {
        label = 'Twin 12 Manifold', 
        weight = 14000, 
        stack = false, 
        close = true,
        description = 'Double scuba tanks. Use them to put them on or take them off.',
        client = { 
            export = 'trx_divingjob.useTank' 
        },
    },
    ['dive_tank_ccr'] = {
        label = 'CCR Rebreather', 
        weight = 12000, 
        stack = false, 
        close = true,
        description = 'Closed-circuit rebreather. Use it to put it on or take it off.',
        client = { 
            export = 'trx_divingjob.useTank' 
        },
    },

}