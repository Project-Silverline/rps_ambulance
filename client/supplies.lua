-- EMS locker and supply shop points. Only shown to the ambulance job,
-- and only when ox_inventory is installed.
if GetResourceState('ox_inventory') == 'missing' then return end

local function isEms()
    local job = LocalPlayer.state.job
    return job and job.name == Config.Job
end

local function addPoint(coords, label, icon, onUse)
    local point = lib.points.new({ coords = coords, distance = 8.0 })

    function point:nearby()
        if not isEms() or IsDead then
            if self.shown then lib.hideTextUI() self.shown = false end
            return
        end

        DrawMarker(2, self.coords.x, self.coords.y, self.coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
            0.25, 0.25, 0.25, 50, 120, 220, 180, false, true, 2, false, nil, nil, false)

        if self.currentDistance < 1.5 then
            if not self.shown then
                lib.showTextUI(label, { icon = icon })
                self.shown = true
            end
            if IsControlJustPressed(0, 38) then onUse() end
        elseif self.shown then
            lib.hideTextUI()
            self.shown = false
        end
    end

    function point:onExit()
        if self.shown then lib.hideTextUI() self.shown = false end
    end
end

addPoint(Config.Locker.coords, '[E] EMS locker', 'box-archive', function()
    exports.ox_inventory:openInventory('stash', 'rps_ems_locker')
end)

addPoint(Config.Supply.coords, '[E] EMS supplies', 'kit-medical', function()
    exports.ox_inventory:openInventory('shop', { type = 'rps_ems_supply', id = 1 })
end)
