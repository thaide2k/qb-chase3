fx_version 'cerulean'
game 'gta5'

description 'QB Chase3 - Perseguição Implacável'
author 'Claude'
version '1.1.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
    'debug.lua',
}

server_scripts {
    'server.lua',
    'debug.lua',
}

lua54 'yes'
