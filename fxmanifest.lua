fx_version 'cerulean'
lua54 'on'
game 'gta5'

author 'Simple'
description 'Admin mode with external configuration'
version '1.1.0'

shared_scripts {
    'config.lua',
    'locale.lua',
    'locales/en.lua',
    'locales/de.lua',
    '@es_extended/imports.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
