--[[
    cockpit — configuration

    Everything here is optional to change. Turn a feature off and the rest of
    the resource carries on without it: no feature depends on another.
]]

Config = {}

--- Chat commands. Rename any of them if they clash with a resource you run.
Config.Commands = {
    engine  = 'engine',
    door    = 'door',
    hood    = 'hood',
    trunk   = 'trunk',
    window  = 'window',
    seat    = 'seat',
    left    = 'left',
    right   = 'right',
    hazards = 'hazards',
    cruise  = 'cruise',
}

--- Default key bindings. Every player can rebind them in
--- Settings > Key Bindings > FiveM, so these are only the defaults.
--- Set one to false to register the command with no default key.
--- Numpad keys are used because almost nothing else claims them.
Config.Keys = {
    engine  = 'NUMPAD0',
    left    = 'NUMPAD4',
    hazards = 'NUMPAD5',
    right   = 'NUMPAD6',
    cruise  = 'NUMPAD8',
}

--- Features, all independent.
Config.Features = {
    engine     = true,  -- toggle the engine
    doors      = true,  -- open and close doors, hood and trunk
    windows    = true,  -- roll windows up and down
    seats      = true,  -- move between seats without getting out
    indicators = true,  -- turn signals and hazards
    cruise     = true,  -- speed limiter
}

--- Only the driver can use engine, doors, windows, indicators and cruise.
--- A passenger does not own the vehicle on the network, so changes made from
--- the passenger seat would not be seen by anyone else. Seat swapping is
--- always allowed: it only moves your own ped.
--- Changing seats is refused above this speed, in km/h. 0 removes the check.
Config.SeatSwapMaxSpeed = 30.0

--- Fastest speed `/cruise` will hold, in km/h.
Config.CruiseMaxSpeed = 250.0

--- Send indicator changes to the other players. Turn this off and your turn
--- signals blink on your screen only.
Config.SyncIndicators = true

--- The game clears indicator lights whenever the vehicle's lights change, so
--- they are re-applied on this interval, in milliseconds, while they are on.
Config.IndicatorRefresh = 400

--- Show a notification for every action.
Config.Notifications = true

--- Register the commands in the chat suggestion list (/ autocomplete).
Config.ChatSuggestions = true
