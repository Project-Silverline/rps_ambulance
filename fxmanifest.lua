fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rps_ambulance'
description 'Death, respawn and ambulance job for rps_core'
version '0.2.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_script 'server/main.lua'

client_scripts {
    'client/death.lua',
    'client/ems.lua',
    'client/hospital.lua',
    'client/supplies.lua',
}

dependencies {
    'rps_core',
    'ox_lib',
}
