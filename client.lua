--[[
    cockpit — client

    Standalone vehicle controls. Nothing here talks to a framework, a database
    or another resource: every action is a game native applied to the vehicle
    the player is currently driving.
]]

local currentVehicle = 0

--- Which windows we rolled down. The game has no "is this window down" getter,
--- so the state is tracked here and reset whenever the player changes vehicle.
local windowsDown = {}

--- 0 none, 1 left, 2 right, 3 hazards.
local indicatorState = 0

--- Indicators on vehicles driven by other players, keyed by network id.
local remoteIndicators = {}

--- Speed the limiter is holding, in km/h, or nil when cruise is off.
local cruiseSpeed = nil

local DOORS = {
    ['1'] = 0, ['2'] = 1, ['3'] = 2, ['4'] = 3, ['5'] = 4, ['6'] = 5,
    fl = 0, fr = 1, rl = 2, rr = 3, hood = 4, trunk = 5, boot = 5, bonnet = 4,
}

local DOOR_LABELS = {
    [0] = 'Front left door',
    [1] = 'Front right door',
    [2] = 'Rear left door',
    [3] = 'Rear right door',
    [4] = 'Hood',
    [5] = 'Trunk',
}

local WINDOWS = {
    ['1'] = 0, ['2'] = 1, ['3'] = 2, ['4'] = 3,
    fl = 0, fr = 1, rl = 2, rr = 3,
}

local WINDOW_LABELS = {
    [0] = 'Front left window',
    [1] = 'Front right window',
    [2] = 'Rear left window',
    [3] = 'Rear right window',
}

--------------------------------------------------------------------- helpers

local function notify(message)
    if not Config.Notifications then return end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end

--- The vehicle the player is sitting in, or 0.
local function vehicleOf(ped)
    return GetVehiclePedIsIn(ped, false)
end

--- The seat the ped occupies, or nil when it is not in the vehicle.
local function seatOf(veh, ped)
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        if GetPedInVehicleSeat(veh, seat) == ped then return seat end
    end
    return nil
end

--- The vehicle the player is *driving*.
---
--- Everything except seat swapping goes through this. A passenger does not own
--- the vehicle on the network, so a door it opened would stay shut on every
--- other screen — refusing is clearer than doing nothing.
local function drivenVehicle()
    local ped = PlayerPedId()
    local veh = vehicleOf(ped)

    if veh == 0 then
        notify('~r~You are not in a vehicle.')
        return nil
    end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        notify('~r~Only the driver can do that.')
        return nil
    end

    return veh
end

------------------------------------------------------------------ indicators

--- Turn signal 1 is the left light, 0 is the right one.
local function applyIndicators(veh, state)
    if not DoesEntityExist(veh) then return end
    SetVehicleIndicatorLights(veh, 1, state == 1 or state == 3)
    SetVehicleIndicatorLights(veh, 0, state == 2 or state == 3)
end

local function broadcastIndicators(veh, state)
    if not Config.SyncIndicators then return end
    if not DoesEntityExist(veh) then return end
    TriggerServerEvent('cockpit:indicators', NetworkGetNetworkIdFromEntity(veh), state)
end

local function setIndicators(veh, state)
    indicatorState = state
    applyIndicators(veh, state)
    broadcastIndicators(veh, state)
end

RegisterNetEvent('cockpit:indicators', function(netId, state)
    if type(netId) ~= 'number' or type(state) ~= 'number' then return end
    if not NetworkDoesNetworkIdExist(netId) then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == currentVehicle then return end -- our own vehicle, already applied

    applyIndicators(veh, state)
    if state == 0 then
        remoteIndicators[netId] = nil
    else
        remoteIndicators[netId] = state
    end
end)

--- The game clears the indicator lights whenever the vehicle's lights change
--- state, so as long as something is blinking it gets re-applied.
CreateThread(function()
    while true do
        local sleep = 1000

        if indicatorState ~= 0 and currentVehicle ~= 0 then
            applyIndicators(currentVehicle, indicatorState)
            sleep = Config.IndicatorRefresh
        end

        for netId, state in pairs(remoteIndicators) do
            if NetworkDoesNetworkIdExist(netId) then
                applyIndicators(NetworkGetEntityFromNetworkId(netId), state)
                sleep = Config.IndicatorRefresh
            else
                remoteIndicators[netId] = nil
            end
        end

        Wait(sleep)
    end
end)

---------------------------------------------------------------------- cruise

--- fInitialDriveMaxFlatVel is the handling's top speed in m/s, and a vehicle
--- can reach roughly 20% past it, so that is the ceiling handed back when the
--- limiter is released.
local function releaseSpeedLimit(veh)
    if not DoesEntityExist(veh) then return end

    local handlingMax = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    if not handlingMax or handlingMax <= 0.0 then handlingMax = 150.0 end

    SetEntityMaxSpeed(veh, handlingMax * 1.2)
end

local function stopCruise(veh, quiet)
    if not cruiseSpeed then return end

    cruiseSpeed = nil
    releaseSpeedLimit(veh)
    if not quiet then notify('Cruise control ~r~off') end
end

local function startCruise(veh, kmh)
    cruiseSpeed = kmh
    SetEntityMaxSpeed(veh, kmh / 3.6)
    notify(('Cruise control ~g~on~s~ at ~y~%d~s~ km/h'):format(math.floor(kmh + 0.5)))
end

--- Braking releases the limiter, the way a real one does.
CreateThread(function()
    while true do
        local sleep = 500

        if cruiseSpeed then
            sleep = 0
            if currentVehicle == 0 or not DoesEntityExist(currentVehicle) then
                cruiseSpeed = nil
            elseif IsControlPressed(0, 72) then -- INPUT_VEH_BRAKE
                stopCruise(currentVehicle, false)
            end
        end

        Wait(sleep)
    end
end)

----------------------------------------------------------- vehicle bookkeeping

--- Leaving a vehicle releases the limiter but leaves the indicators alone:
--- hazards on a parked car are the whole point of hazards. Their state moves
--- to the remote table so the refresh loop keeps them alive.
local function onLeftVehicle(veh)
    stopCruise(veh, true)

    if indicatorState ~= 0 and DoesEntityExist(veh) then
        remoteIndicators[NetworkGetNetworkIdFromEntity(veh)] = indicatorState
    end
    indicatorState = 0
end

CreateThread(function()
    while true do
        local veh = vehicleOf(PlayerPedId())

        if veh ~= currentVehicle then
            if currentVehicle ~= 0 then onLeftVehicle(currentVehicle) end
            currentVehicle = veh
            windowsDown = {}
        end

        Wait(500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if currentVehicle ~= 0 and DoesEntityExist(currentVehicle) then
        releaseSpeedLimit(currentVehicle)
        applyIndicators(currentVehicle, 0)
    end
end)

-------------------------------------------------------------------- commands

local function registerCommand(name, handler)
    if not name then return end
    RegisterCommand(name, handler, false)
end

if Config.Features.engine then
    registerCommand(Config.Commands.engine, function()
        local veh = drivenVehicle()
        if not veh then return end

        local running = GetIsVehicleEngineRunning(veh)
        SetVehicleEngineOn(veh, not running, false, true)
        notify(running and 'Engine ~r~off' or 'Engine ~g~on')
    end)
end

if Config.Features.doors then
    local function toggleDoor(veh, index)
        if GetVehicleDoorAngleRatio(veh, index) > 0.01 then
            SetVehicleDoorShut(veh, index, false)
            return false
        end

        SetVehicleDoorOpen(veh, index, false, false)
        return true
    end

    local function anyDoorOpen(veh)
        for index = 0, 5 do
            if GetVehicleDoorAngleRatio(veh, index) > 0.01 then return true end
        end
        return false
    end

    local function doorCommand(_, args)
        local veh = drivenVehicle()
        if not veh then return end

        local target = (args[1] or ''):lower()

        if target == 'all' then
            local shutting = anyDoorOpen(veh)
            for index = 0, 5 do
                if shutting then
                    SetVehicleDoorShut(veh, index, false)
                else
                    SetVehicleDoorOpen(veh, index, false, false)
                end
            end
            notify(shutting and 'All doors ~r~closed' or 'All doors ~g~open')
            return
        end

        local index = DOORS[target]
        if not index then
            notify('~y~/' .. Config.Commands.door .. '~s~ 1-6 | fl fr rl rr hood trunk | all')
            return
        end

        local opened = toggleDoor(veh, index)
        notify(DOOR_LABELS[index] .. (opened and ' ~g~open' or ' ~r~closed'))
    end

    registerCommand(Config.Commands.door, doorCommand)
    registerCommand(Config.Commands.hood, function() doorCommand(nil, { 'hood' }) end)
    registerCommand(Config.Commands.trunk, function() doorCommand(nil, { 'trunk' }) end)
end

if Config.Features.windows then
    registerCommand(Config.Commands.window, function(_, args)
        local veh = drivenVehicle()
        if not veh then return end

        local target = (args[1] or ''):lower()

        if target == 'all' then
            local rollingUp = next(windowsDown) ~= nil
            for index = 0, 3 do
                if rollingUp then
                    RollUpWindow(veh, index)
                else
                    RollDownWindow(veh, index)
                    windowsDown[index] = true
                end
            end
            if rollingUp then windowsDown = {} end
            notify(rollingUp and 'All windows ~r~up' or 'All windows ~g~down')
            return
        end

        local index = WINDOWS[target]
        if not index then
            notify('~y~/' .. Config.Commands.window .. '~s~ 1-4 | fl fr rl rr | all')
            return
        end

        if windowsDown[index] then
            RollUpWindow(veh, index)
            windowsDown[index] = nil
            notify(WINDOW_LABELS[index] .. ' ~r~up')
        else
            RollDownWindow(veh, index)
            windowsDown[index] = true
            notify(WINDOW_LABELS[index] .. ' ~g~down')
        end
    end)
end

if Config.Features.seats then
    registerCommand(Config.Commands.seat, function(_, args)
        local ped = PlayerPedId()
        local veh = vehicleOf(ped)

        if veh == 0 then
            notify('~r~You are not in a vehicle.')
            return
        end

        if Config.SeatSwapMaxSpeed > 0.0 and GetEntitySpeed(veh) * 3.6 > Config.SeatSwapMaxSpeed then
            notify(('~r~Too fast to move seats (over %d km/h).'):format(math.floor(Config.SeatSwapMaxSpeed)))
            return
        end

        local lastSeat = GetVehicleMaxNumberOfPassengers(veh) - 1
        local wanted = tonumber(args[1])
        local target

        -- `/seat 2.5` would otherwise reach a native that expects an integer.
        if wanted then wanted = math.floor(wanted) end

        if wanted then
            -- /seat 1 is the driver, 2 the front passenger, then back to front.
            target = wanted - 2
            if target < -1 or target > lastSeat then
                notify(('~r~This vehicle has seats 1 to %d.'):format(lastSeat + 2))
                return
            end
            if not IsVehicleSeatFree(veh, target) then
                notify('~r~That seat is taken.')
                return
            end
        else
            local current = seatOf(veh, ped)
            for seat = -1, lastSeat do
                if seat ~= current and IsVehicleSeatFree(veh, seat) then
                    target = seat
                    break
                end
            end
            if not target then
                notify('~r~No free seat.')
                return
            end
        end

        SetPedIntoVehicle(ped, veh, target)
        notify(('Moved to seat ~y~%d'):format(target + 2))
    end)
end

if Config.Features.indicators then
    local function indicator(state)
        return function()
            local veh = drivenVehicle()
            if not veh then return end

            if indicatorState == state then
                setIndicators(veh, 0)
                notify('Indicators ~r~off')
                return
            end

            setIndicators(veh, state)
            if state == 1 then
                notify('Indicating ~y~left')
            elseif state == 2 then
                notify('Indicating ~y~right')
            else
                notify('Hazards ~y~on')
            end
        end
    end

    registerCommand(Config.Commands.left, indicator(1))
    registerCommand(Config.Commands.right, indicator(2))
    registerCommand(Config.Commands.hazards, indicator(3))
end

if Config.Features.cruise then
    registerCommand(Config.Commands.cruise, function(_, args)
        local veh = drivenVehicle()
        if not veh then return end

        if cruiseSpeed then
            stopCruise(veh, false)
            return
        end

        local wanted = tonumber(args[1]) or (GetEntitySpeed(veh) * 3.6)

        if wanted < 5.0 then
            notify('~r~Too slow to set cruise control.')
            return
        end
        if wanted > Config.CruiseMaxSpeed then
            wanted = Config.CruiseMaxSpeed
        end

        startCruise(veh, wanted)
    end)
end

----------------------------------------------------------------- key bindings

--- Registered once at start-up. A player who rebinds a key keeps their choice:
--- these are only the defaults offered in Settings > Key Bindings > FiveM.
local function bind(feature, command, key, description)
    if not Config.Features[feature] then return end
    if not command or not key then return end
    RegisterKeyMapping(command, description, 'keyboard', key)
end

bind('engine', Config.Commands.engine, Config.Keys.engine, 'Toggle engine')
bind('indicators', Config.Commands.left, Config.Keys.left, 'Indicate left')
bind('indicators', Config.Commands.right, Config.Keys.right, 'Indicate right')
bind('indicators', Config.Commands.hazards, Config.Keys.hazards, 'Toggle hazards')
bind('cruise', Config.Commands.cruise, Config.Keys.cruise, 'Toggle cruise control')

------------------------------------------------------------ chat suggestions

if Config.ChatSuggestions then
    CreateThread(function()
        local function suggest(feature, command, help, params)
            if not Config.Features[feature] then return end
            if not command then return end
            TriggerEvent('chat:addSuggestion', '/' .. command, help, params)
        end

        suggest('engine', Config.Commands.engine, 'Start or stop the engine')
        suggest('doors', Config.Commands.door, 'Open or close a door', {
            { name = 'door', help = '1-6, fl, fr, rl, rr, hood, trunk, or all' },
        })
        suggest('doors', Config.Commands.hood, 'Open or close the hood')
        suggest('doors', Config.Commands.trunk, 'Open or close the trunk')
        suggest('windows', Config.Commands.window, 'Roll a window down or up', {
            { name = 'window', help = '1-4, fl, fr, rl, rr, or all' },
        })
        suggest('seats', Config.Commands.seat, 'Move to another seat', {
            { name = 'seat', help = 'seat number, or empty for the next free one' },
        })
        suggest('indicators', Config.Commands.left, 'Indicate left')
        suggest('indicators', Config.Commands.right, 'Indicate right')
        suggest('indicators', Config.Commands.hazards, 'Toggle the hazards')
        suggest('cruise', Config.Commands.cruise, 'Hold a speed', {
            { name = 'speed', help = 'km/h, or empty for your current speed' },
        })
    end)
end
