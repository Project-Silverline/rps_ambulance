IsDead = false
local loaded = false
local respawning = false
local endTime = 0
local alerted = false

local DEAD_DICT, DEAD_CLIP = 'dead', 'dead_a'
local CAR_DICT, CAR_CLIP = 'veh@low@front_ps@idle_duck', 'sit'

-- Controls left usable while downed: look around, chat, push-to-talk, pause menu
local ALLOWED = { 1, 2, 245, 249, 199, 200 }

local function formatTime(seconds)
    return ('%d:%02d'):format(seconds // 60, seconds % 60)
end

local function playDownedAnim(ped)
    local dict, clip = DEAD_DICT, DEAD_CLIP
    if IsPedInAnyVehicle(ped, false) then dict, clip = CAR_DICT, CAR_CLIP end
    if not IsEntityPlayingAnim(ped, dict, clip, 3) then
        lib.requestAnimDict(dict)
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, -1, 1, 0, false, false, false)
        RemoveAnimDict(dict)
    end
end

local function startDownedLoops()
    endTime = GetGameTimer() + Config.RespawnTime * 1000
    alerted = false

    -- controls + animation every frame
    CreateThread(function()
        while IsDead do
            DisableAllControlActions(0)
            for i = 1, #ALLOWED do EnableControlAction(0, ALLOWED[i], true) end

            playDownedAnim(PlayerPedId())

            if not alerted and IsDisabledControlJustPressed(0, 47) then -- G
                alerted = true
                TriggerServerEvent('rps_ambulance:server:alert')
            end

            if not respawning and GetGameTimer() >= endTime and IsDisabledControlJustPressed(0, 38) then -- E
                respawning = true
                TriggerServerEvent('rps_ambulance:server:respawn')
            end

            Wait(0)
        end
    end)

    -- on-screen prompt, refreshed once a second
    CreateThread(function()
        local last
        while IsDead do
            local remaining = math.max(0, math.ceil((endTime - GetGameTimer()) / 1000))
            local text = remaining > 0
                and ('You are unconscious  \nRespawn in %s'):format(formatTime(remaining))
                or ('[E] Respawn at hospital ($%d)'):format(Config.RespawnFee)
            if not alerted then text = text .. '  \n[G] Call EMS' end

            if text ~= last then
                lib.showTextUI(text, { position = 'top-center', icon = 'heart-pulse' })
                last = text
            end
            Wait(1000)
        end
        lib.hideTextUI()
    end)
end

local function onDeath()
    IsDead = true
    respawning = false
    TriggerServerEvent('rps_ambulance:server:setDead')

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local seat
    if vehicle ~= 0 then
        for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
            if GetPedInVehicleSeat(vehicle, i) == ped then seat = i break end
        end
    end

    -- let the ragdoll settle before picking the body up
    local settle = GetGameTimer() + 3000
    while GetEntitySpeed(ped) > 0.5 and GetGameTimer() < settle do Wait(100) end

    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    ped = PlayerPedId()

    if vehicle ~= 0 and DoesEntityExist(vehicle) and seat then
        SetPedIntoVehicle(ped, vehicle, seat)
    end

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetEntityInvincible(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    startDownedLoops()
end

local function reviveLocal()
    IsDead = false
    respawning = false
    lib.hideTextUI()

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then ClearPedTasks(ped) else ClearPedTasksImmediately(ped) end
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end

---------------------------------------------------------------------------
-- Detection
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        if loaded and not IsDead and IsEntityDead(PlayerPedId()) then
            onDeath()
        end
        Wait(250)
    end
end)

---------------------------------------------------------------------------
-- Events from rps_core
---------------------------------------------------------------------------
AddEventHandler('rps_core:client:playerLoaded', function(data)
    loaded = true
    if data.metadata and data.metadata.isDead then
        Wait(1000)
        SetEntityHealth(PlayerPedId(), 0) -- detection loop puts them back into the downed state
    end
end)

AddEventHandler('rps_core:client:playerUnloaded', function()
    loaded = false
    if IsDead then
        IsDead = false
        lib.hideTextUI()
        SetEntityInvincible(PlayerPedId(), false)
    end
end)

CreateThread(function()
    -- handles this resource restarting while the player is in-game
    if exports.rps_core:IsLoaded() then
        loaded = true
        if LocalPlayer.state.isDead then SetEntityHealth(PlayerPedId(), 0) end
    end
end)

---------------------------------------------------------------------------
-- Events from server
---------------------------------------------------------------------------
RegisterNetEvent('rps_ambulance:client:revive', reviveLocal)

RegisterNetEvent('rps_ambulance:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('rps_ambulance:client:respawn', function(pos)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    reviveLocal()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) end

    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.w)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end

    DoScreenFadeIn(500)
end)

exports('IsDead', function() return IsDead end)
