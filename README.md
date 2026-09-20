# cockpit

**Vehicle controls for FiveM that work on any server.** Doors, windows, seats,
engine, turn signals and cruise control — no framework, no dependency, no
database, four files.

[![CI](https://github.com/CedricPoint/fivem-cockpit/actions/workflows/ci.yml/badge.svg)](https://github.com/CedricPoint/fivem-cockpit/actions/workflows/ci.yml)
[![standalone](https://img.shields.io/badge/framework-none-brightgreen.svg)](#compatibility)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Every action is a plain game native applied to the car you are driving. There is
nothing to migrate, nothing to configure before it runs, and nothing that breaks
when you change framework — because it never asks which one you use.

## What you get

| | command | default key | |
| --- | --- | --- | --- |
| 🔑 | `/engine` | `NUMPAD 0` | start or stop the engine |
| 🚪 | `/door 1-6 \| fl fr rl rr hood trunk \| all` | — | open or close any door |
| 🧰 | `/hood`, `/trunk` | — | the two you actually use, in one word |
| 🪟 | `/window 1-4 \| fl fr rl rr \| all` | — | roll windows down and up |
| 💺 | `/seat [1-4]` | — | move seat without getting out — empty takes the next free one |
| ↔️ | `/left`, `/right` | `NUMPAD 4`, `NUMPAD 6` | turn signals, seen by every player |
| ⚠️ | `/hazards` | `NUMPAD 5` | hazards, and they keep blinking on a car you left |
| 🎯 | `/cruise [km/h]` | `NUMPAD 8` | hold a speed — empty holds the one you are doing |

Keys are only defaults: every player can rebind them in
**Settings → Key Bindings → FiveM**, and commands work from the chat either way.

## Install

```bash
cd resources
git clone https://github.com/CedricPoint/fivem-cockpit.git cockpit
```

Then add it to your `server.cfg`:

```cfg
ensure cockpit
```

That is the whole installation. Any current FiveM server build, nothing else.

## Configuration

`config.lua`, and it is optional — the defaults are the intended experience.

```lua
Config.Features = {
    engine     = true,
    doors      = true,
    windows    = true,
    seats      = true,
    indicators = true,
    cruise     = true,
}

Config.SeatSwapMaxSpeed = 30.0   -- km/h, 0 removes the check
Config.CruiseMaxSpeed   = 250.0  -- km/h
Config.SyncIndicators   = true   -- show your turn signals to other players
Config.Notifications    = true
```

Commands and default keys live there too, so you can rename anything that
clashes with a resource you already run. Turning a feature off unregisters its
command and its key binding; nothing else changes.

## How it behaves

A few decisions worth knowing before you read the code:

- **Only the driver controls the vehicle.** A passenger does not own the car on
  the network, so a door it opened would stay shut on every other screen.
  Refusing is clearer than doing nothing. Seat swapping is the exception — it
  only moves your own ped, so anyone can do it.
- **Hazards survive you.** Walk away from a car with the hazards on and they
  keep blinking, for you and for everyone else, the way they should.
- **Braking cancels cruise control**, like a real limiter. So does leaving the
  vehicle.
- **Turn signals are relayed through the server** because the game keeps them
  local. The relay is rate limited, and the worst a crafted packet can do is
  blink someone's indicators.
- **Nothing is stored.** No database, no state file, no player data.

## Compatibility

Standalone means standalone: no ESX, no QBCore, no ox_lib, no NUI, no exports
from anything. It also means it sits next to those frameworks without touching
them — if your framework already handles seats, turn that one feature off and
keep the rest.

The one thing to watch for is another resource that owns the same command names
(`/engine` and `/seat` are popular). Rename them in `config.lua` and you are
done.

## Tests

The command logic runs outside the game. `test/harness.lua` stubs every native
against a small fake world — one player, one four-seater — so the real handlers
from `client.lua` can be exercised under plain Lua:

```bash
lua5.4 test/run.lua
```

```
cockpit
  ok   the engine toggles off and back on
  ok   /door all opens everything, then shuts everything
  ok   seats cannot be swapped at speed
  ok   hazards keep blinking on a car the player left
  ok   braking releases cruise control
  ok   a passenger cannot touch the vehicle
  ...
  26 checks, 0 failed
```

It is not a substitute for driving a car around, but it means a typo in the
argument parsing or an inverted toggle never reaches your server.

## License

MIT — do what you like with it.
