--[[
    cockpit — server

    The only thing that needs a server at all: indicator lights are a local
    effect, so they have to be relayed for the other players to see them.
    Nothing is stored, nothing is trusted beyond what it costs.
]]

--- Shortest gap allowed between two relays from the same player, in ms.
local RELAY_COOLDOWN = 120

local lastRelay = {}

RegisterNetEvent('cockpit:indicators', function(netId, state)
    local src = source

    if type(netId) ~= 'number' or type(state) ~= 'number' then return end

    netId = math.floor(netId)
    state = math.floor(state)
    if netId <= 0 or state < 0 or state > 3 then return end

    -- A client could still blink a vehicle it is not driving. That is the
    -- entire blast radius of this event, and the rate limit keeps it from
    -- being used as a flood, so it is not worth a heavier check here.
    local now = GetGameTimer()
    if lastRelay[src] and now - lastRelay[src] < RELAY_COOLDOWN then return end
    lastRelay[src] = now

    TriggerClientEvent('cockpit:indicators', -1, netId, state)
end)

AddEventHandler('playerDropped', function()
    lastRelay[source] = nil
end)
