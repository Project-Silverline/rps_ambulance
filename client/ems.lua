local busy = false

local function isEms()
    local job = LocalPlayer.state.job
    return job and job.name == Config.Job
end

local function hasItem(item)
    if not item or GetResourceState('ox_inventory') ~= 'started' then return true end
    return exports.ox_inventory:GetItemCount(item) > 0
end

local function getPatient()
    local playerId, ped = lib.getClosestPlayer(GetEntityCoords(cache.ped), Config.ActionDistance, false)
    if not playerId then return end
    return GetPlayerServerId(playerId), ped
end

local function canAct()
    if not isEms() then
        lib.notify({ description = 'Only paramedics can do that.', type = 'error' })
        return false
    end
    return not busy and not IsDead
end

local function attemptRevive()
    if not canAct() then return end

    if not hasItem(Config.Items.revive) then
        return lib.notify({ description = 'You need a medkit.', type = 'error' })
    end

    local target, ped = getPatient()
    if not target then
        return lib.notify({ description = 'No one is close enough.', type = 'error' })
    end
    if not Player(target).state.isDead then
        return lib.notify({ description = 'This person is conscious. Use /heal instead.', type = 'error' })
    end

    busy = true
    TaskTurnPedToFaceEntity(cache.ped, ped, 1000)
    Wait(800)

    if lib.progressBar({
        duration = Config.ReviveDuration,
        label = 'Performing CPR',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest', flag = 1 },
    }) then
        TriggerServerEvent('rps_ambulance:server:revive', target)
    end
    busy = false
end

local function attemptHeal()
    if not canAct() then return end

    if not hasItem(Config.Items.heal) then
        return lib.notify({ description = 'You need a bandage.', type = 'error' })
    end

    local target, ped = getPatient()
    if not target then
        return lib.notify({ description = 'No one is close enough.', type = 'error' })
    end
    if Player(target).state.isDead then
        return lib.notify({ description = 'This person is unconscious. Use /revive.', type = 'error' })
    end

    busy = true
    TaskTurnPedToFaceEntity(cache.ped, ped, 1000)
    Wait(800)

    if lib.progressBar({
        duration = Config.HealDuration,
        label = 'Treating wounds',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@medic@standing@tendtodead@idle_a', clip = 'idle_a', flag = 1 },
    }) then
        TriggerServerEvent('rps_ambulance:server:heal', target)
    end
    busy = false
end

RegisterCommand('revive', attemptRevive, false)
RegisterCommand('heal', attemptHeal, false)

TriggerEvent('chat:addSuggestion', '/revive', 'Revive the closest unconscious person (EMS)')
TriggerEvent('chat:addSuggestion', '/heal', 'Treat the closest injured person (EMS)')

-- Using a medkit from the inventory. The item is removed by the server only
-- when the revive succeeds, so a cancelled or invalid attempt costs nothing.
exports('medkit', function()
    attemptRevive()
end)

---------------------------------------------------------------------------
-- Distress calls
---------------------------------------------------------------------------
RegisterNetEvent('rps_ambulance:client:alert', function(coords)
    lib.notify({
        title = 'Medical emergency',
        description = 'Someone is down. Location marked on your map.',
        type = 'error',
        icon = 'truck-medical',
        duration = 8000,
    })
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 153)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Medical emergency')
    EndTextCommandSetBlipName(blip)

    SetTimeout(Config.AlertBlipTime * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)
