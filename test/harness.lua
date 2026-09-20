--[[
    A fake game.

    Every native client.lua touches is stubbed here against a small world made
    of one player and one vehicle, which is enough to run the commands for real
    under plain Lua 5.4 and check what they did. No FiveM, no GTA, no server.
]]

local harness = {}

local VEHICLE = 100
local PED = 1

--- Reset the world to a player sitting in the driver seat of a running car.
function harness.reset()
    harness.world = {
        onFoot = false,
        seats = { [-1] = PED },  -- seat index -> ped, driver is -1
        maxPassengers = 3,       -- a four seater
        engineOn = true,
        doors = { [0] = 0.0, [1] = 0.0, [2] = 0.0, [3] = 0.0, [4] = 0.0, [5] = 0.0 },
        windows = { [0] = 'up', [1] = 'up', [2] = 'up', [3] = 'up' },
        indicators = { [0] = false, [1] = false },
        maxSpeed = nil,
        speed = 0.0,             -- m/s
        braking = false,
        netIdExists = true,
    }
    harness.notifications = {}
    harness.sentToServer = {}
end

harness.commands = {}
harness.keyBindings = {}
harness.suggestions = {}
harness.netEvents = {}
harness.threads = {}

--- Run a command the way a player would type it.
function harness.run(line)
    local parts = {}
    for word in line:gmatch('%S+') do parts[#parts + 1] = word end

    local name = (table.remove(parts, 1) or ''):gsub('^/', '')
    local handler = harness.commands[name]
    assert(handler, ('no command named %q is registered'):format(name))

    handler(0, parts, line)
end

--- The last thing the player was told, or nil.
function harness.lastNotification()
    return harness.notifications[#harness.notifications]
end

local function seatOfPed(ped)
    for seat, occupant in pairs(harness.world.seats) do
        if occupant == ped then return seat end
    end
    return nil
end

---------------------------------------------------------------- game natives

function PlayerPedId() return PED end
function DoesEntityExist(entity) return entity ~= 0 end
function GetCurrentResourceName() return 'cockpit' end
function GetGameTimer() return 0 end

function GetVehiclePedIsIn(ped, _)
    if harness.world.onFoot then return 0 end
    return seatOfPed(ped) and VEHICLE or 0
end

function GetPedInVehicleSeat(_, seat) return harness.world.seats[seat] or 0 end
function GetVehicleMaxNumberOfPassengers(_) return harness.world.maxPassengers end
function IsVehicleSeatFree(_, seat) return harness.world.seats[seat] == nil end
function GetEntitySpeed(_) return harness.world.speed end

function SetPedIntoVehicle(ped, _, seat)
    local current = seatOfPed(ped)
    if current then harness.world.seats[current] = nil end
    harness.world.seats[seat] = ped
end

function GetIsVehicleEngineRunning(_) return harness.world.engineOn end
function SetVehicleEngineOn(_, state, _, _) harness.world.engineOn = state end

function GetVehicleDoorAngleRatio(_, door) return harness.world.doors[door] or 0.0 end
function SetVehicleDoorOpen(_, door, _, _) harness.world.doors[door] = 1.0 end
function SetVehicleDoorShut(_, door, _) harness.world.doors[door] = 0.0 end

function RollDownWindow(_, window) harness.world.windows[window] = 'down' end
function RollUpWindow(_, window) harness.world.windows[window] = 'up' end

function SetVehicleIndicatorLights(_, signal, on) harness.world.indicators[signal] = on end

function SetEntityMaxSpeed(_, speed) harness.world.maxSpeed = speed end
function GetVehicleHandlingFloat(_, _, _) return 40.0 end

function IsControlPressed(_, control) return control == 72 and harness.world.braking end

function NetworkGetNetworkIdFromEntity(_) return 55 end
function NetworkDoesNetworkIdExist(_) return harness.world.netIdExists end
function NetworkGetEntityFromNetworkId(_) return VEHICLE end

local pendingNotification = nil
function BeginTextCommandThefeedPost(_) pendingNotification = nil end
function AddTextComponentSubstringPlayerName(text) pendingNotification = text end
function EndTextCommandThefeedPostTicker(_, _)
    harness.notifications[#harness.notifications + 1] = pendingNotification
end

------------------------------------------------------------- resource natives

--- Threads are `while true` loops, so Wait() aborts the one that is running.
--- harness.tick() then means "run one iteration of every loop".
local STOP = {}

function CreateThread(fn) harness.threads[#harness.threads + 1] = fn end
function Wait(_) error(STOP) end

function harness.tick()
    for _, fn in ipairs(harness.threads) do
        local ok, err = pcall(fn)
        if not ok and err ~= STOP then error(err, 0) end
    end
end

function RegisterCommand(name, handler, _) harness.commands[name] = handler end
function RegisterKeyMapping(command, description, _, key)
    harness.keyBindings[#harness.keyBindings + 1] = { command = command, description = description, key = key }
end

function RegisterNetEvent(name, handler) harness.netEvents[name] = handler end
function AddEventHandler(_, _) end

function TriggerServerEvent(name, ...)
    harness.sentToServer[#harness.sentToServer + 1] = { name = name, args = { ... } }
end

function TriggerEvent(name, ...)
    if name == 'chat:addSuggestion' then
        harness.suggestions[#harness.suggestions + 1] = ({ ... })[1]
    end
end

harness.reset()

return harness
