-- Map blip
CreateThread(function()
    local c = Config.CheckIn.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 61)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Hospital')
    EndTextCommandSetBlipName(blip)
end)

local checkingIn = false

local function checkIn()
    if checkingIn or IsDead then return end
    checkingIn = true

    local ok, reason = lib.callback.await('rps_ambulance:canCheckIn', false)
    if not ok then
        checkingIn = false
        return lib.notify({ description = reason or 'You cannot check in right now.', type = 'error' })
    end

    if lib.progressBar({
        duration = Config.CheckIn.duration,
        label = 'Receiving treatment',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    }) then
        TriggerServerEvent('rps_ambulance:server:checkIn')
    end
    checkingIn = false
end

local point = lib.points.new({
    coords = Config.CheckIn.coords,
    distance = 10.0,
})

function point:nearby()
    DrawMarker(2, self.coords.x, self.coords.y, self.coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
        0.25, 0.25, 0.25, 200, 50, 50, 180, false, true, 2, false, nil, nil, false)

    if self.currentDistance < 1.5 then
        if not self.shown then
            lib.showTextUI(('[E] Check in ($%d)'):format(Config.CheckIn.fee), { icon = 'hospital' })
            self.shown = true
        end
        if IsControlJustPressed(0, 38) then checkIn() end
    elseif self.shown then
        lib.hideTextUI()
        self.shown = false
    end
end

function point:onExit()
    if self.shown then
        lib.hideTextUI()
        self.shown = false
    end
end
