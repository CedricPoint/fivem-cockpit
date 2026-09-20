--[[
    cockpit — tests

        lua5.4 test/run.lua        (from the resource folder)

    The commands are the real ones from client.lua. Only the game underneath
    them is fake, so what is checked here is the logic that actually ships.
]]

local harness = dofile('test/harness.lua')
dofile('config.lua')
dofile('client.lua')

local world = function() return harness.world end

local failures = 0
local checks = 0

local function check(name, fn)
    local ok, err = pcall(fn)
    checks = checks + 1
    if ok then
        print('  ok   ' .. name)
    else
        failures = failures + 1
        print('  FAIL ' .. name .. '\n       ' .. tostring(err))
    end
end

local function equal(actual, expected, label)
    if actual ~= expected then
        error(('%s: expected %s, got %s'):format(label or 'value', tostring(expected), tostring(actual)), 2)
    end
end

--- A clean world, with any indicator or cruise state from an earlier test
--- released first.
local function fresh()
    harness.reset()

    world().netIdExists = false
    harness.tick() -- the refresh loop drops vehicles that no longer exist
    world().netIdExists = true

    -- /hazards lands on "all off" whatever it was toggled to before.
    harness.run('/hazards')
    if world().indicators[0] or world().indicators[1] then harness.run('/hazards') end

    world().braking = true
    harness.tick() -- braking releases cruise control
    world().braking = false

    harness.reset()
    harness.tick()
end

print('cockpit')

------------------------------------------------------------------- the basics

check('the engine toggles off and back on', function()
    fresh()
    equal(world().engineOn, true, 'engine at start')

    harness.run('/engine')
    equal(world().engineOn, false, 'after one toggle')

    harness.run('/engine')
    equal(world().engineOn, true, 'after two toggles')
end)

check('a door opens and closes', function()
    fresh()
    harness.run('/door hood')
    equal(world().doors[4], 1.0, 'hood open')

    harness.run('/door hood')
    equal(world().doors[4], 0.0, 'hood shut')
end)

check('doors answer to numbers, names and aliases', function()
    fresh()
    harness.run('/door 1')
    equal(world().doors[0], 1.0, 'door 1 is the front left one')

    harness.run('/door fr')
    equal(world().doors[1], 1.0, 'fr is the front right one')

    harness.run('/trunk')
    equal(world().doors[5], 1.0, 'the trunk alias opens the trunk')
end)

check('/door all opens everything, then shuts everything', function()
    fresh()
    harness.run('/door all')
    for index = 0, 5 do equal(world().doors[index], 1.0, 'door ' .. index) end

    harness.run('/door all')
    for index = 0, 5 do equal(world().doors[index], 0.0, 'door ' .. index) end
end)

check('an unknown door is refused, and nothing moves', function()
    fresh()
    harness.run('/door banana')
    for index = 0, 5 do equal(world().doors[index], 0.0, 'door ' .. index) end
    assert(harness.lastNotification():find('/door'), 'the usage line should be shown')
end)

check('windows roll down and up, one at a time or all at once', function()
    fresh()
    harness.run('/window 1')
    equal(world().windows[0], 'down', 'front left down')

    harness.run('/window 1')
    equal(world().windows[0], 'up', 'front left back up')

    harness.run('/window all')
    for index = 0, 3 do equal(world().windows[index], 'down', 'window ' .. index) end

    harness.run('/window all')
    for index = 0, 3 do equal(world().windows[index], 'up', 'window ' .. index) end
end)

------------------------------------------------------------------------ seats

check('the player moves to a free seat and back', function()
    fresh()
    harness.run('/seat 2')
    equal(world().seats[0], 1, 'now in the front passenger seat')
    equal(world().seats[-1], nil, 'and no longer driving')

    harness.run('/seat 1')
    equal(world().seats[-1], 1, 'back behind the wheel')
end)

check('an occupied seat is refused', function()
    fresh()
    world().seats[0] = 2 -- somebody else

    harness.run('/seat 2')
    equal(world().seats[0], 2, 'the other player stays put')
    equal(world().seats[-1], 1, 'and we stay where we were')
end)

check('a seat the vehicle does not have is refused', function()
    fresh()
    harness.run('/seat 9')
    equal(world().seats[-1], 1, 'still driving')
    assert(harness.lastNotification():find('1 to 4'), 'the message should name the real range')
end)

check('seats cannot be swapped at speed', function()
    fresh()
    world().speed = 20.0 -- 72 km/h

    harness.run('/seat 2')
    equal(world().seats[-1], 1, 'still driving')
    assert(harness.lastNotification():find('Too fast'), 'the refusal should say why')
end)

check('/seat with no argument takes the next free seat', function()
    fresh()
    harness.run('/seat')
    equal(world().seats[0], 1, 'moved to the first free seat')
end)

------------------------------------------------------------------- indicators

check('the turn signals light the right side', function()
    fresh()
    harness.run('/left')
    equal(world().indicators[1], true, 'left lamp on')
    equal(world().indicators[0], false, 'right lamp off')

    harness.run('/right')
    equal(world().indicators[1], false, 'left lamp off')
    equal(world().indicators[0], true, 'right lamp on')

    harness.run('/right')
    equal(world().indicators[0], false, 'pressing the same side again turns it off')
end)

check('the hazards light both sides', function()
    fresh()
    harness.run('/hazards')
    equal(world().indicators[0], true, 'right lamp')
    equal(world().indicators[1], true, 'left lamp')
end)

check('indicator changes are sent to the other players', function()
    fresh()
    harness.run('/left')

    local sent = harness.sentToServer[#harness.sentToServer]
    equal(sent.name, 'cockpit:indicators', 'event name')
    equal(sent.args[1], 55, 'network id of the vehicle')
    equal(sent.args[2], 1, 'left')

    harness.run('/left')
    equal(harness.sentToServer[#harness.sentToServer].args[2], 0, 'turning them off is sent too')
end)

check('hazards keep blinking on a car the player left', function()
    fresh()
    harness.run('/hazards')

    world().onFoot = true
    harness.tick() -- the player walks away

    world().indicators[0] = false
    world().indicators[1] = false
    harness.tick() -- the refresh loop puts them back

    equal(world().indicators[0], true, 'right lamp still blinking')
    equal(world().indicators[1], true, 'left lamp still blinking')
end)

----------------------------------------------------------------------- cruise

check('cruise control holds the speed it was given', function()
    fresh()
    harness.run('/cruise 90')
    equal(world().maxSpeed, 90 / 3.6, 'limiter set in m/s')

    harness.run('/cruise')
    equal(world().maxSpeed, 48.0, 'released back to the handling top speed')
end)

check('cruise control without an argument uses the current speed', function()
    fresh()
    world().speed = 25.0 -- 90 km/h

    harness.run('/cruise')
    equal(world().maxSpeed, 25.0, 'limiter set to the speed we were doing')
end)

check('cruise control is capped by the config', function()
    fresh()
    harness.run('/cruise 999')
    equal(world().maxSpeed, Config.CruiseMaxSpeed / 3.6, 'clamped to the maximum')
end)

check('cruise control refuses to hold a standstill', function()
    fresh()
    world().speed = 0.0

    harness.run('/cruise')
    equal(world().maxSpeed, nil, 'no limiter was set')
end)

check('braking releases cruise control', function()
    fresh()
    harness.run('/cruise 90')

    world().braking = true
    harness.tick()

    equal(world().maxSpeed, 48.0, 'released')
end)

check('leaving the vehicle releases cruise control', function()
    fresh()
    harness.run('/cruise 90')

    world().onFoot = true
    harness.tick()

    equal(world().maxSpeed, 48.0, 'released')
end)

--------------------------------------------------------------------- refusals

check('a passenger cannot touch the vehicle', function()
    fresh()
    world().seats[-1] = nil
    world().seats[0] = 1 -- we are riding shotgun

    harness.run('/engine')
    equal(world().engineOn, true, 'the engine is untouched')
    assert(harness.lastNotification():find('driver'), 'the refusal should say why')
end)

check('nothing happens on foot', function()
    fresh()
    world().onFoot = true

    harness.run('/engine')
    harness.run('/door all')
    harness.run('/cruise 90')

    equal(world().engineOn, true, 'engine untouched')
    equal(world().doors[0], 0.0, 'doors untouched')
    equal(world().maxSpeed, nil, 'no limiter')
end)

---------------------------------------------------------------- registrations

check('every feature registers its command', function()
    for _, name in pairs(Config.Commands) do
        assert(harness.commands[name], 'missing command: ' .. name)
    end
end)

check('the default keys are offered', function()
    equal(#harness.keyBindings, 5, 'number of bindings')
    for _, binding in ipairs(harness.keyBindings) do
        assert(binding.key and binding.key ~= '', 'a binding without a key: ' .. binding.command)
        assert(harness.commands[binding.command], 'a binding for an unknown command')
    end
end)

check('the commands show up in chat autocomplete', function()
    harness.tick()
    assert(#harness.suggestions >= 8, 'expected a suggestion per command, got ' .. #harness.suggestions)
end)

print(('\n%d checks, %d failed'):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
