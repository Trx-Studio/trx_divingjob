fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'trx_divingjob'
description 'TRX diving job - dive shop, scuba tank tiers with real air, dive tablet item, contracts, levels, rewards, boat rentals and a weekly scoreboard'
author 'TRX RP'
version '2.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'config/client.lua',
    'config/shared.lua',
    'client/dive.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}


dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
}
