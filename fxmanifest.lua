fx_version 'cerulean'
lua54 'on'
game 'gta5'

author 'Simple'
description 'Admin mode with external configuration'
version '1.1.1'

shared_scripts {
    'config.lua',
    'locale.lua',
    'locales/en.lua',
    'locales/de.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
