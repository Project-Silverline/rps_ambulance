Config = {}

Config.Job = 'ambulance'

-- Downed state
Config.RespawnTime = 300            -- seconds a player must stay downed before they can respawn
Config.RespawnFee = 500             -- taken from bank, then cash; respawn is never blocked by lack of money
Config.RespawnPoint = vec4(341.0, -1397.3, 32.5, 48.5) -- Central Los Santos Medical Center

-- EMS actions
Config.ReviveDuration = 10000       -- ms
Config.ReviveReward = 250           -- paid to the medic's bank
Config.HealDuration = 5000          -- ms
Config.ActionDistance = 3.0         -- how close a medic must be to the patient

-- Distress calls
Config.AlertBlipTime = 120          -- seconds the alert blip stays on EMS maps

-- Hospital check-in (heals injured players when EMS are not available)
Config.CheckIn = {
    coords = vec3(340.0, -1396.0, 32.5),
    fee = 750,
    duration = 10000,               -- ms
    maxEms = 0,                     -- only allowed when this many or fewer EMS are online; nil = always
}

-- Inventory (ox_inventory). Everything below is ignored if ox_inventory isn't running.
Config.Items = {
    revive = 'medkit',              -- consumed per revive; nil = no item needed
    heal = 'bandage',               -- consumed per /heal; nil = no item needed
}

Config.ClearInventoryOnRespawn = false -- wipe the inventory when respawning at the hospital
Config.KeepOnRespawn = { 'money' }     -- items kept when it is wiped

-- EMS-only locker and supply shop (check these positions in-game)
Config.Locker = {
    coords = vec3(336.5, -1400.5, 32.5),
    slots = 50,
    weight = 100000,
    personal = true,                -- true = each medic has their own locker; false = shared
}

Config.Supply = {
    coords = vec3(343.5, -1398.5, 32.5),
    items = {
        { name = 'medkit', price = 50 },
        { name = 'bandage', price = 10 },
    },
}
