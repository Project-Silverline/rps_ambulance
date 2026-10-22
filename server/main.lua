local Core = exports.rps_core
local Dead = {} -- [source] = { time = os.time(), alerted = bool }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function notify(src, msg, kind)
    if src == 0 then return print(('[rps_ambulance] %s'):format(msg)) end
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = kind or 'inform' })
end

local function isEms(player)
    return player and player.getJob().name == Config.Job
end

local function getOnlineEms()
    local list = {}
    for _, src in ipairs(Core:GetPlayers()) do
        if isEms(Core:GetPlayer(src)) then list[#list + 1] = src end
    end
    return list
end

local function distance(a, b)
    return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b)))
end

-- Takes the fee from bank, then cash. Returns true if paid in full.
local function charge(player, amount, reason, allowPartial)
    if amount <= 0 then return true end
    if player.removeMoney('bank', amount, reason) then return true end
    if player.removeMoney('cash', amount, reason) then return true end
    if allowPartial then
        local bank = player.getMoney('bank')
        if bank > 0 then player.removeMoney('bank', bank, reason) end
    end
    return false
end

local function hasInventory()
    return GetResourceState('ox_inventory') == 'started'
end

-- Removes one of the item. Always succeeds when no item is configured or ox_inventory isn't running.
local function takeItem(src, item)
    if not item or not hasInventory() then return true end
    return exports.ox_inventory:RemoveItem(src, item, 1) == true
end

-- `isDead` is ours; `dead` is read by ox_inventory to close and lock the inventory
local function setDeadState(src, value)
    local state = Player(src).state
    state:set('isDead', value, true)
    state:set('dead', value, true)
end

local function markDead(src, player)
    if Dead[src] then return end
    Dead[src] = { time = os.time(), alerted = false }
    player.setMeta('isDead', true)
    setDeadState(src, true)
end

local function revive(src)
    Dead[src] = nil
    setDeadState(src, false)
    local player = Core:GetPlayer(src)
    if player then player.setMeta('isDead', false) end
    TriggerClientEvent('rps_ambulance:client:revive', src)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
AddEventHandler('rps_core:server:playerLoaded', function(src, player)
    if player.getMeta('isDead') then
        markDead(src, player) -- timer restarts, so combat-logging doesn't skip it
    else
        setDeadState(src, false)
    end
end)

AddEventHandler('rps_core:server:playerUnloaded', function(src)
    Dead[src] = nil
    setDeadState(src, nil)
end)

-- Rebuild state if this resource restarts while players are online
CreateThread(function()
    for _, src in ipairs(Core:GetPlayers()) do
        local player = Core:GetPlayer(src)
        if player and player.getMeta('isDead') then markDead(src, player) end
    end
end)

---------------------------------------------------------------------------
-- Death & respawn
---------------------------------------------------------------------------
RegisterNetEvent('rps_ambulance:server:setDead', function()
    local src = source
    local player = Core:GetPlayer(src)
    if player then markDead(src, player) end
end)

RegisterNetEvent('rps_ambulance:server:respawn', function()
    local src = source
    local state = Dead[src]
    local player = Core:GetPlayer(src)
    if not state or not player then return end

    -- small allowance for timer drift between client and server
    if os.time() - state.time < Config.RespawnTime - 2 then return end

    local paid = charge(player, Config.RespawnFee, 'hospital_respawn', true)

    if Config.ClearInventoryOnRespawn and hasInventory() then
        exports.ox_inventory:ClearInventory(src, Config.KeepOnRespawn)
    end

    revive(src)
    TriggerClientEvent('rps_ambulance:client:respawn', src, Config.RespawnPoint)

    notify(src, paid and ('You were treated at the hospital. Bill: $%d'):format(Config.RespawnFee)
        or 'You were treated at the hospital. You could not cover the full bill.', 'inform')
end)

RegisterNetEvent('rps_ambulance:server:alert', function()
    local src = source
    local state = Dead[src]
    if not state or state.alerted then return end
    state.alerted = true

    local ems = getOnlineEms()
    if #ems == 0 then
        return notify(src, 'No EMS are on duty. Wait to respawn at the hospital.', 'error')
    end

    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, medic in ipairs(ems) do
        TriggerClientEvent('rps_ambulance:client:alert', medic, coords)
    end
    notify(src, 'EMS have been notified of your location.', 'success')
end)

---------------------------------------------------------------------------
-- EMS actions
---------------------------------------------------------------------------
RegisterNetEvent('rps_ambulance:server:revive', function(target)
    local src = source
    target = tonumber(target)
    local medic = Core:GetPlayer(src)

    if not isEms(medic) or not target or target == src then return end
    if Dead[src] or not Dead[target] then return end
    if distance(src, target) > Config.ActionDistance + 2.0 then return end

    if not takeItem(src, Config.Items.revive) then
        return notify(src, 'You need a medkit.', 'error')
    end

    revive(target)
    notify(target, 'You were revived by a paramedic.', 'success')

    if Config.ReviveReward > 0 then
        medic.addMoney('bank', Config.ReviveReward, 'ems_revive')
        notify(src, ('Patient revived. +$%d'):format(Config.ReviveReward), 'success')
    end
end)

RegisterNetEvent('rps_ambulance:server:heal', function(target)
    local src = source
    target = tonumber(target)
    local medic = Core:GetPlayer(src)

    if not isEms(medic) or not target or target == src then return end
    if Dead[src] or Dead[target] or not Core:GetPlayer(target) then return end
    if distance(src, target) > Config.ActionDistance + 2.0 then return end

    if not takeItem(src, Config.Items.heal) then
        return notify(src, 'You need a bandage.', 'error')
    end

    TriggerClientEvent('rps_ambulance:client:heal', target)
    notify(target, 'A paramedic treated your wounds.', 'success')
    notify(src, 'Patient treated.', 'success')
end)

---------------------------------------------------------------------------
-- Hospital check-in
---------------------------------------------------------------------------
lib.callback.register('rps_ambulance:canCheckIn', function(src)
    if Dead[src] then return false, 'You need a paramedic.' end
    if Config.CheckIn.maxEms and #getOnlineEms() > Config.CheckIn.maxEms then
        return false, 'Paramedics are on duty. Call them for treatment.'
    end
    local player = Core:GetPlayer(src)
    if not player then return false end
    if player.getMoney('bank') < Config.CheckIn.fee and player.getMoney('cash') < Config.CheckIn.fee then
        return false, ('Treatment costs $%d.'):format(Config.CheckIn.fee)
    end
    return true
end)

RegisterNetEvent('rps_ambulance:server:checkIn', function()
    local src = source
    local player = Core:GetPlayer(src)
    if not player or Dead[src] then return end

    local coords = GetEntityCoords(GetPlayerPed(src))
    if #(coords - Config.CheckIn.coords) > 5.0 then return end

    if not charge(player, Config.CheckIn.fee, 'hospital_checkin', false) then
        return notify(src, 'You cannot afford treatment.', 'error')
    end

    TriggerClientEvent('rps_ambulance:client:heal', src)
    notify(src, ('You were treated. Bill: $%d'):format(Config.CheckIn.fee), 'success')
end)

---------------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------------
lib.addCommand('adrevive', {
    help = 'Revive or heal a player (yourself if no ID)',
    params = { { name = 'target', type = 'playerId', help = 'Server ID', optional = true } },
    restricted = 'group.admin',
}, function(source, args)
    local target = args.target or source
    if target == 0 then return notify(0, 'Specify a player ID from the console.') end
    if not Core:GetPlayer(target) then return notify(source, 'That player has no character loaded', 'error') end

    if Dead[target] then revive(target) else TriggerClientEvent('rps_ambulance:client:heal', target) end
    notify(target, 'You were revived by an admin.', 'success')
end)

---------------------------------------------------------------------------
-- EMS locker and supply shop
---------------------------------------------------------------------------
local function registerInventories()
    if not hasInventory() then return end
    local groups = { [Config.Job] = 0 }

    exports.ox_inventory:RegisterStash('rps_ems_locker', 'EMS Locker', Config.Locker.slots, Config.Locker.weight,
        Config.Locker.personal or nil, groups, Config.Locker.coords)

    exports.ox_inventory:RegisterShop('rps_ems_supply', {
        name = 'EMS Supplies',
        groups = groups,
        inventory = Config.Supply.items,
        locations = { Config.Supply.coords },
    })
end

CreateThread(registerInventories)

AddEventHandler('onResourceStart', function(resource)
    if resource == 'ox_inventory' then
        Wait(1000)
        registerInventories()
    end
end)

exports('IsDead', function(src) return Dead[tonumber(src)] ~= nil end)
exports('Revive', revive)
